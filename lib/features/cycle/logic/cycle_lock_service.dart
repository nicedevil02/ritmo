// C-06, C-07, C-08: CycleLockService
// Sole source of truth for Cycle lock state, secure hashed PIN storage, independent from App PIN,
// with exponential backoff brute-force protection, app-lock PIN integration, and biometric authentication.
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/security/pin_hasher.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:sqflite/sqflite.dart';

enum CycleLockSource { dedicated, appLock }

class CycleLockService {
  CycleLockService._();
  static final CycleLockService instance = CycleLockService._();

  final LocalAuthentication _auth = LocalAuthentication();

  static const String _keyPinHash = 'cycle_lock_pin_hash';
  static const String _keySalt = 'cycle_lock_salt';
  static const String _keyFailedAttempts = 'cycle_lock_failed_attempts';
  static const String _keyLockoutUntilMs = 'cycle_lockout_until_ms';
  static const String keyLockSource = 'cycle_lock_source';

  /// RITF-071: Constant-time byte comparison without early return on length mismatch.
  bool _constantTimeEquals(String a, String b) {
    final aUnits = utf8.encode(a);
    final bUnits = utf8.encode(b);
    final maxLength = max(aUnits.length, bUnits.length);
    var diff = aUnits.length ^ bUnits.length;
    for (var i = 0; i < maxLength; i++) {
      final aByte = i < aUnits.length ? aUnits[i] : 0;
      final bByte = i < bUnits.length ? bUnits[i] : 0;
      diff |= aByte ^ bByte;
    }
    return diff == 0;
  }

  /// Hashes [pin] with [salt] using HMAC-SHA256.
  String _hashPin(String pin, String salt) {
    final hmac = Hmac(sha256, utf8.encode(salt));
    final digest = hmac.convert(utf8.encode(pin));
    return digest.toString();
  }

  /// Returns the current lock source (dedicated or appLock).
  Future<CycleLockSource> getLockSource([DatabaseExecutor? dbExecutor]) async {
    try {
      final val = await SecureKeyStore.getKey(keyLockSource, dbExecutor);
      if (val == 'app_lock') {
        return CycleLockSource.appLock;
      }
      return CycleLockSource.dedicated;
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockService] error reading lock source setting',
        error: e,
        stack: st,
      );
      return CycleLockSource.dedicated;
    }
  }

  /// Sets whether the cycle lock source is dedicated or uses main app lock.
  Future<void> setLockSource(
    CycleLockSource source, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      if (source == CycleLockSource.appLock) {
        // RITF-002: Close backdoor by purging old dedicated PIN and salt
        await SecureKeyStore.deleteKey(_keyPinHash, dbExecutor);
        await SecureKeyStore.deleteKey(_keySalt, dbExecutor);
      }
      await SecureKeyStore.setKey(
        keyLockSource,
        source == CycleLockSource.appLock ? 'app_lock' : 'dedicated',
        dbExecutor,
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockService] error saving lock source setting',
        error: e,
        stack: st,
      );
    }
  }

  /// Returns whether the main app lock password exists in SecureKeyStore.
  Future<bool> hasAppLockPassword([DatabaseExecutor? dbExecutor]) async {
    final appPass = await SecureKeyStore.getKey(
      'app_lock_password',
      dbExecutor,
    );
    return appPass != null && appPass.isNotEmpty;
  }

  /// Returns whether the cycle lock is enabled.
  /// Defaults to true (fail-secure) if PIN exists, unless cycle_lock_enabled is explicitly 'false'.
  Future<bool> isLockEnabled([DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['cycle_lock_enabled'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final val = rows.first['value']?.toString();
        if (val == 'false') return false;
        if (val == 'true') return true;
      }
      // If setting is unset, lock is enabled if a PIN is configured
      return await hasAnyActivePin(dbExecutor);
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockService] error reading lock enabled setting',
        error: e,
        stack: st,
      );
      // RITF-069: Fail-closed / fail-secure
      return true;
    }
  }

  /// Sets whether the cycle lock is enabled.
  Future<void> setLockEnabled(
    bool enabled, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final now = CycleClock.nowMillisecondsSinceEpoch;
      // RITF-070: Use atomic UpsertHelper instead of ConflictAlgorithm.replace
      await UpsertHelper.upsert(
        db,
        'app_settings',
        {
          'key': 'cycle_lock_enabled',
          'value': enabled ? 'true' : 'false',
          'updatedAt': now,
        },
        conflictColumns: const ['key'],
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockService] error saving lock enabled setting',
        error: e,
        stack: st,
      );
    }
  }

  /// Checks if a dedicated cycle PIN is stored in SecureKeyStore.
  Future<bool> hasCyclePin([DatabaseExecutor? dbExecutor]) async {
    final hash = await SecureKeyStore.getKey(_keyPinHash, dbExecutor);
    return hash != null && hash.isNotEmpty;
  }

  /// Checks if any active PIN is configured (dedicated or app lock according to source).
  Future<bool> hasAnyActivePin([DatabaseExecutor? dbExecutor]) async {
    final source = await getLockSource(dbExecutor);
    if (source == CycleLockSource.appLock) {
      final hasApp = await hasAppLockPassword(dbExecutor);
      if (hasApp) return true;
    }
    return await hasCyclePin(dbExecutor);
  }

  /// RITF-066: Non-secret failed attempts storage in app_settings with fail-closed default.
  Future<int> _getFailedAttempts([DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [_keyFailedAttempts],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      return int.tryParse(rows.first['value']?.toString() ?? '0') ?? 0;
    } catch (e, st) {
      RitmoLogger.error('[CycleLockService] error reading failed attempts', error: e, stack: st);
      return 15; // fail-closed
    }
  }

  Future<void> _setFailedAttempts(int attempts, [DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final now = CycleClock.nowMillisecondsSinceEpoch;
      await UpsertHelper.upsert(
        db,
        'app_settings',
        {
          'key': _keyFailedAttempts,
          'value': attempts.toString(),
          'updatedAt': now,
        },
        conflictColumns: const ['key'],
      );
    } catch (e, st) {
      RitmoLogger.error('[CycleLockService] error saving failed attempts', error: e, stack: st);
    }
  }

  /// RITF-066: Lockout until timestamp storage in app_settings with fail-closed handling.
  Future<int> _getLockoutUntilMs([DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [_keyLockoutUntilMs],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      return int.tryParse(rows.first['value']?.toString() ?? '0') ?? 0;
    } catch (e, st) {
      RitmoLogger.error('[CycleLockService] error reading lockout until ms', error: e, stack: st);
      return CycleClock.nowMillisecondsSinceEpoch + 300000; // fail-closed: 5 min
    }
  }

  Future<void> _setLockoutUntilMs(int lockoutUntilMs, [DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final now = CycleClock.nowMillisecondsSinceEpoch;
      await UpsertHelper.upsert(
        db,
        'app_settings',
        {
          'key': _keyLockoutUntilMs,
          'value': lockoutUntilMs.toString(),
          'updatedAt': now,
        },
        conflictColumns: const ['key'],
      );
    } catch (e, st) {
      RitmoLogger.error('[CycleLockService] error saving lockout until ms', error: e, stack: st);
    }
  }

  /// Sets a new dedicated cycle PIN. Hashes it securely with PBKDF2 via PinHasher (RITF-003, RITF-068).
  Future<void> setPin(String newPin, [DatabaseExecutor? dbExecutor]) async {
    final hash = PinHasher.hashPin(newPin);

    // Atomic composite key write
    await SecureKeyStore.setKey(_keyPinHash, hash, dbExecutor);
    await SecureKeyStore.deleteKey(_keySalt, dbExecutor);
    await _setFailedAttempts(0, dbExecutor);
    await _setLockoutUntilMs(0, dbExecutor);

    await setLockSource(CycleLockSource.dedicated, dbExecutor);
    await setLockEnabled(true, dbExecutor);
  }

  /// Clears the dedicated cycle PIN and resets lockout state.
  Future<void> clearPin([DatabaseExecutor? dbExecutor]) async {
    await SecureKeyStore.deleteKey(_keyPinHash, dbExecutor);
    await SecureKeyStore.deleteKey(_keySalt, dbExecutor);
    await _setFailedAttempts(0, dbExecutor);
    await _setLockoutUntilMs(0, dbExecutor);
    await SecureKeyStore.deleteKey(keyLockSource, dbExecutor);

    await setLockEnabled(false, dbExecutor);
  }

  /// Calculates remaining lockout seconds. Returns 0 if not locked out (RITF-067).
  Future<int> remainingLockoutSeconds([DatabaseExecutor? dbExecutor]) async {
    final lockoutMs = await _getLockoutUntilMs(dbExecutor);
    if (lockoutMs <= 0) return 0;

    final nowMs = CycleClock.nowMillisecondsSinceEpoch;
    final diffMs = lockoutMs - nowMs;

    if (diffMs <= 0) {
      // RITF-067: Lockout expired, reset lockout timestamp and failed attempts
      await _setLockoutUntilMs(0, dbExecutor);
      await _setFailedAttempts(0, dbExecutor);
      return 0;
    }
    return (diffMs / 1000).ceil();
  }

  /// Checks if PIN verification is currently locked out.
  Future<bool> isLockedOut([DatabaseExecutor? dbExecutor]) async {
    return (await remainingLockoutSeconds(dbExecutor)) > 0;
  }

  /// Specifically verifies against the main app lock PIN.
  Future<bool> verifyAppLockPin(
    String enteredPin, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    final storedHash = await SecureKeyStore.getKey(
      'app_lock_password',
      dbExecutor,
    );
    if (storedHash == null || storedHash.isEmpty) return false;
    return PinHasher.verifyPin(enteredPin, storedHash);
  }

  /// Specifically verifies against the dedicated cycle PIN with transparent v2 auto-upgrade (RITF-003).
  Future<bool> verifyDedicatedPin(
    String enteredPin, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    final storedHash = await SecureKeyStore.getKey(_keyPinHash, dbExecutor);
    if (storedHash == null || storedHash.isEmpty) return false;

    if (storedHash.startsWith('v2:')) {
      return PinHasher.verifyPin(enteredPin, storedHash);
    }

    // Legacy HMAC-SHA256 transparent upgrade
    final salt = await SecureKeyStore.getKey(_keySalt, dbExecutor);
    if (salt != null && salt.isNotEmpty) {
      final computedHash = _hashPin(enteredPin, salt);
      final isMatch = _constantTimeEquals(computedHash, storedHash);
      if (isMatch) {
        await setPin(enteredPin, dbExecutor);
      }
      return isMatch;
    }

    return false;
  }

  /// Verifies [enteredPin] against active source with brute-force rate limiting (RITF-002, RITF-066, RITF-067).
  Future<bool> verifyPin(
    String enteredPin, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    // 1. Check if locked out
    final remaining = await remainingLockoutSeconds(dbExecutor);
    if (remaining > 0) {
      return false;
    }

    final source = await getLockSource(dbExecutor);
    bool isMatch = false;

    // RITF-002: Strictly verify active source only (no unintended backdoor fallback)
    if (source == CycleLockSource.appLock) {
      isMatch = await verifyAppLockPin(enteredPin, dbExecutor);
    } else {
      isMatch = await verifyDedicatedPin(enteredPin, dbExecutor);
    }

    if (isMatch) {
      // Reset failed attempts on success
      await _setFailedAttempts(0, dbExecutor);
      await _setLockoutUntilMs(0, dbExecutor);
      return true;
    } else {
      // Increment failed attempts
      final attempts = (await _getFailedAttempts(dbExecutor)) + 1;
      await _setFailedAttempts(attempts, dbExecutor);

      // Calculate exponential backoff lockout
      int lockoutSecs = 0;
      if (attempts >= 15) {
        lockoutSecs = 1800; // 30 minutes
      } else if (attempts >= 10) {
        lockoutSecs = 300; // 5 minutes
      } else if (attempts >= 5) {
        lockoutSecs = 30; // 30 seconds
      }

      if (lockoutSecs > 0) {
        final lockoutUntilMs =
            CycleClock.nowMillisecondsSinceEpoch + (lockoutSecs * 1000);
        await _setLockoutUntilMs(lockoutUntilMs, dbExecutor);
      }

      return false;
    }
  }

  /// Authenticates using biometrics (RITF-002: biometricOnly true).
  Future<bool> authenticateBiometric({
    String localizedReason = 'Cycle Vault Biometric Authentication',
  }) async {
    if (kIsWeb) return false;

    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!isSupported || !canCheck) return false;

      final didAuth = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return didAuth;
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockService] biometric auth failed',
        error: e,
        stack: st,
      );
      return false;
    }
  }
}
