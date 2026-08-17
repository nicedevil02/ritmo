// C-06, C-07, C-08: CycleLockService
// Sole source of truth for Cycle lock state, secure hashed PIN storage, independent from App PIN,
// with exponential backoff brute-force protection and biometric authentication.
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:sqflite/sqflite.dart';

class CycleLockService {
  CycleLockService._();
  static final CycleLockService instance = CycleLockService._();

  final LocalAuthentication _auth = LocalAuthentication();

  static const String _keyPinHash = 'cycle_lock_pin_hash';
  static const String _keySalt = 'cycle_lock_salt';
  static const String _keyFailedAttempts = 'cycle_lock_failed_attempts';
  static const String _keyLockoutUntilMs = 'cycle_lockout_until_ms';

  /// Constant-time string comparison to prevent timing attacks.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Hashes [pin] with [salt] using HMAC-SHA256.
  String _hashPin(String pin, String salt) {
    final hmac = Hmac(sha256, utf8.encode(salt));
    final digest = hmac.convert(utf8.encode(pin));
    return digest.toString();
  }

  /// Generates a cryptographically secure random salt.
  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
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
      return await hasCyclePin(dbExecutor);
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockService] error reading lock enabled setting',
        error: e,
        stack: st,
      );
      return false;
    }
  }

  /// Sets whether the cycle lock is enabled.
  Future<void> setLockEnabled(
    bool enabled, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('app_settings', {
        'key': 'cycle_lock_enabled',
        'value': enabled ? 'true' : 'false',
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockService] error saving lock enabled setting',
        error: e,
        stack: st,
      );
    }
  }

  /// Checks if a cycle PIN is stored in SecureKeyStore.
  Future<bool> hasCyclePin([DatabaseExecutor? dbExecutor]) async {
    final hash = await SecureKeyStore.getKey(_keyPinHash, dbExecutor);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets a new cycle PIN. Hashes it securely with a salt and stores only in SecureKeyStore.
  Future<void> setPin(String newPin, [DatabaseExecutor? dbExecutor]) async {
    final salt = _generateSalt();
    final hash = _hashPin(newPin, salt);

    await SecureKeyStore.setKey(_keySalt, salt, dbExecutor);
    await SecureKeyStore.setKey(_keyPinHash, hash, dbExecutor);
    await SecureKeyStore.setKey(_keyFailedAttempts, '0', dbExecutor);
    await SecureKeyStore.setKey(_keyLockoutUntilMs, '0', dbExecutor);

    await setLockEnabled(true, dbExecutor);
  }

  /// Clears the cycle PIN and resets lockout state.
  Future<void> clearPin([DatabaseExecutor? dbExecutor]) async {
    await SecureKeyStore.deleteKey(_keyPinHash, dbExecutor);
    await SecureKeyStore.deleteKey(_keySalt, dbExecutor);
    await SecureKeyStore.deleteKey(_keyFailedAttempts, dbExecutor);
    await SecureKeyStore.deleteKey(_keyLockoutUntilMs, dbExecutor);

    await setLockEnabled(false, dbExecutor);
  }

  /// Calculates remaining lockout seconds. Returns 0 if not locked out.
  Future<int> remainingLockoutSeconds([DatabaseExecutor? dbExecutor]) async {
    final lockoutMsStr = await SecureKeyStore.getKey(
      _keyLockoutUntilMs,
      dbExecutor,
    );
    if (lockoutMsStr == null || lockoutMsStr.isEmpty) return 0;

    final lockoutMs = int.tryParse(lockoutMsStr) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final diffMs = lockoutMs - nowMs;

    if (diffMs <= 0) return 0;
    return (diffMs / 1000).ceil();
  }

  /// Checks if PIN verification is currently locked out.
  Future<bool> isLockedOut([DatabaseExecutor? dbExecutor]) async {
    return (await remainingLockoutSeconds(dbExecutor)) > 0;
  }

  /// Verifies [enteredPin] against stored hash with brute-force rate limiting.
  Future<bool> verifyPin(
    String enteredPin, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    // 1. Check if locked out
    final remaining = await remainingLockoutSeconds(dbExecutor);
    if (remaining > 0) {
      return false;
    }

    // 2. Fetch stored salt and hash
    final salt = await SecureKeyStore.getKey(_keySalt, dbExecutor);
    final storedHash = await SecureKeyStore.getKey(_keyPinHash, dbExecutor);

    if (salt == null || storedHash == null || storedHash.isEmpty) {
      return false;
    }

    final computedHash = _hashPin(enteredPin, salt);
    final isMatch = _constantTimeEquals(computedHash, storedHash);

    if (isMatch) {
      // Reset failed attempts on success
      await SecureKeyStore.setKey(_keyFailedAttempts, '0', dbExecutor);
      await SecureKeyStore.setKey(_keyLockoutUntilMs, '0', dbExecutor);
      return true;
    } else {
      // Increment failed attempts
      final attemptsStr = await SecureKeyStore.getKey(
        _keyFailedAttempts,
        dbExecutor,
      );
      final attempts = (int.tryParse(attemptsStr ?? '0') ?? 0) + 1;
      await SecureKeyStore.setKey(
        _keyFailedAttempts,
        attempts.toString(),
        dbExecutor,
      );

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
            DateTime.now().millisecondsSinceEpoch + (lockoutSecs * 1000);
        await SecureKeyStore.setKey(
          _keyLockoutUntilMs,
          lockoutUntilMs.toString(),
          dbExecutor,
        );
      }

      return false;
    }
  }

  /// Authenticates using biometrics. Returns true ONLY on successful authentication.
  Future<bool> authenticateBiometric({
    String localizedReason = 'Cycle Vault Authentication',
  }) async {
    if (kIsWeb) return false;

    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!isSupported || !canCheck) return false;

      final didAuth = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: false,
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
