// lib/core/backend/auth_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/backend/appwrite_gateway.dart';
import 'package:ritmo/core/backend/models/auth_result.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

class UserAccountState {
  final bool isLoggedIn;
  final String provider; // 'anonymous', 'phone', 'google', 'email'
  final String maskedIdentifier;
  final bool isGoogleLinked;

  const UserAccountState({
    required this.isLoggedIn,
    required this.provider,
    required this.maskedIdentifier,
    required this.isGoogleLinked,
  });

  factory UserAccountState.anonymous() => const UserAccountState(
        isLoggedIn: false,
        provider: 'anonymous',
        maskedIdentifier: '',
        isGoogleLinked: false,
      );
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  final AppwriteGateway _gateway = AppwriteGateway.instance;
  UserAccountState _state = UserAccountState.anonymous();

  UserAccountState get state => _state;
  bool get isLoggedIn => _state.isLoggedIn;
  String get maskedIdentifier => _state.maskedIdentifier;
  String get provider => _state.provider;
  bool get isGoogleLinked => _state.isGoogleLinked;

  /// Normalizes Persian/Arabic numbers, removes non-digits, formats to +989xxxxxxxxx
  static String? normalizeIranianPhone(String raw) {
    if (raw.trim().isEmpty) return null;

    // Convert Persian & Arabic digits to ASCII
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    String s = raw.trim();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(persianDigits[i], '$i').replaceAll(arabicDigits[i], '$i');
    }

    // Remove any character except + and digits
    s = s.replaceAll(RegExp(r'[^\d+]'), '');

    if (s.startsWith('+98')) {
      s = s.substring(3);
    } else if (s.startsWith('0098')) {
      s = s.substring(4);
    } else if (s.startsWith('0')) {
      s = s.substring(1);
    }

    // Iranian mobile numbers must be 10 digits starting with 9 (e.g. 9123456789)
    if (RegExp(r'^9\d{9}$').hasMatch(s)) {
      return '+98$s';
    }

    return null;
  }

  /// Masks phone number or email for display (e.g. +98912***3456)
  static String maskIdentifier(String identifier) {
    if (identifier.contains('@')) {
      final parts = identifier.split('@');
      if (parts[0].length <= 2) return identifier;
      return '${parts[0].substring(0, 2)}***@${parts[1]}';
    } else if (identifier.startsWith('+98')) {
      if (identifier.length < 13) return identifier;
      return '${identifier.substring(0, 6)}***${identifier.substring(10)}';
    }
    return identifier;
  }

  /// Regular expression for email validation (RFC 5322 compatible subset - RIT-054)
  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// Non-blocking initialization of local account state & background SDK sync
  Future<void> init() async {
    await _loadStateFromLocalDb();
    // Background SDK warm-up
    unawaited(_gateway.init().then((_) => checkRemoteSession()));
  }

  Future<void> _loadStateFromLocalDb() async {
    try {
      final db = await DatabaseHelper.instance.database;
      // Targeted WHERE clause to avoid table-scan and type casting fragility (RIT-053)
      final rows = await db.query(
        'app_settings',
        where: "key IN ('auth_logged_in', 'auth_provider', 'auth_identifier_masked', 'auth_google_linked')",
      );
      final map = <String, String>{};
      for (final r in rows) {
        final k = r['key']?.toString();
        final v = r['value']?.toString();
        if (k != null && v != null) {
          map[k] = v;
        }
      }

      final loggedIn = map['auth_logged_in'] == 'true';
      final provider = map['auth_provider'] ?? 'anonymous';
      final masked = map['auth_identifier_masked'] ?? '';
      final googleLinked = map['auth_google_linked'] == 'true';

      _state = UserAccountState(
        isLoggedIn: loggedIn,
        provider: provider,
        maskedIdentifier: masked,
        isGoogleLinked: googleLinked,
      );
      notifyListeners();
    } catch (e, st) {
      RitmoLog.error('AuthService', 'Error loading local auth state', e, st);
    }
  }

  Future<void> _saveStateToLocalDb({
    required bool loggedIn,
    required String provider,
    required String maskedIdentifier,
    required bool isGoogleLinked,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final batch = db.batch();
      batch.insert(
        'app_settings',
        {
          'key': 'auth_logged_in',
          'value': loggedIn ? 'true' : 'false',
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {
          'key': 'auth_provider',
          'value': provider,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {
          'key': 'auth_identifier_masked',
          'value': maskedIdentifier,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      batch.insert(
        'app_settings',
        {
          'key': 'auth_google_linked',
          'value': isGoogleLinked ? 'true' : 'false',
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);

      _state = UserAccountState(
        isLoggedIn: loggedIn,
        provider: provider,
        maskedIdentifier: maskedIdentifier,
        isGoogleLinked: isGoogleLinked,
      );
      notifyListeners();
    } catch (e, st) {
      RitmoLog.error('AuthService', 'Error saving local auth state', e, st);
    }
  }

  /// Verifies current remote session status quietly in background
  Future<void> checkRemoteSession({String? explicitProvider}) async {
    // Retry any pending remote logout first (RIT-035)
    try {
      final db = await DatabaseHelper.instance.database;
      final pendingRows = await db.query(
        'app_settings',
        where: "key = 'auth_pending_remote_logout'",
      );
      if (pendingRows.isNotEmpty && pendingRows.first['value'] == 'true') {
        final retryLogout = await _gateway.logout();
        if (retryLogout.isSuccess) {
          await db.delete(
            'app_settings',
            where: "key = 'auth_pending_remote_logout'",
          );
        }
        return;
      }
    } catch (_) {}

    final result = await _gateway.getCurrentUser();
    if (result.isSuccess && result.data != null) {
      final user = result.data!;
      final phone = user.phone;
      final email = user.email;
      final rawId = email.isNotEmpty ? email : (phone.isNotEmpty ? phone : user.name);
      final masked = maskIdentifier(rawId);

      // Determine provider without brittle heuristics (RIT-052)
      final resolvedProvider = explicitProvider ??
          (_state.provider != 'anonymous'
              ? _state.provider
              : (email.isNotEmpty ? 'email' : (phone.isNotEmpty ? 'phone' : 'google')));
      final googleLinked = resolvedProvider == 'google';

      await _saveStateToLocalDb(
        loggedIn: true,
        provider: resolvedProvider,
        maskedIdentifier: masked,
        isGoogleLinked: googleLinked,
      );
    } else if (result.errorCode == AuthErrorCode.sessionExpired ||
               result.errorCode == AuthErrorCode.unauthorized) {
      // Remote session expired/invalidated: clear local auth state (RIT-051)
      RitmoLog.warning(
        'AuthService',
        'Remote session expired/unauthorized. Invalidating local session.',
      );
      await _saveStateToLocalDb(
        loggedIn: false,
        provider: 'anonymous',
        maskedIdentifier: '',
        isGoogleLinked: false,
      );
    }
  }

  /// Flow 1: Continue as Guest
  Future<void> continueAsGuest() async {
    await _saveStateToLocalDb(
      loggedIn: false,
      provider: 'anonymous',
      maskedIdentifier: '',
      isGoogleLinked: false,
    );
  }

  /// Flow 2: Google Login
  Future<AuthResult<bool>> loginWithGoogle() async {
    final res = await _gateway.loginWithGoogle();
    if (res.isSuccess) {
      await _saveStateToLocalDb(
        loggedIn: true,
        provider: 'google',
        maskedIdentifier: _state.maskedIdentifier,
        isGoogleLinked: true,
      );
      await checkRemoteSession(explicitProvider: 'google');
    }
    return res;
  }

  /// Flow 3: Email OTP (Magic Token)
  Future<AuthResult<String>> requestEmailOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_emailRegExp.hasMatch(cleanEmail)) {
      return const AuthResult.failure(
        AuthErrorCode.invalidEmail,
        'ایمیل واردشده معتبر نیست.',
      );
    }
    final res = await _gateway.createEmailToken('unique()', cleanEmail);
    if (!res.isSuccess || res.data == null) return AuthResult.failure(res.errorCode, res.errorMessage);
    return AuthResult.success(res.data!.userId);
  }

  Future<AuthResult<bool>> verifyEmailOtp(String userId, String secret) async {
    final res = await _gateway.createSessionWithToken(userId, secret.trim());
    if (!res.isSuccess) return AuthResult.failure(res.errorCode, res.errorMessage);
    await _saveStateToLocalDb(
      loggedIn: true,
      provider: 'email',
      maskedIdentifier: _state.maskedIdentifier,
      isGoogleLinked: false,
    );
    await checkRemoteSession(explicitProvider: 'email');
    return const AuthResult.success(true);
  }

  /// Logout (Preserves local SQLite data completely and schedules remote retry if offline - RIT-035)
  Future<AuthResult<bool>> logout() async {
    final res = await _gateway.logout();
    if (!res.isSuccess) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('app_settings', {
          'key': 'auth_pending_remote_logout',
          'value': 'true',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    } else {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete(
          'app_settings',
          where: "key = 'auth_pending_remote_logout'",
        );
      } catch (_) {}
    }

    await _saveStateToLocalDb(
      loggedIn: false,
      provider: 'anonymous',
      maskedIdentifier: '',
      isGoogleLinked: false,
    );
    return res.isSuccess ? const AuthResult.success(true) : AuthResult.failure(res.errorCode, res.errorMessage);
  }
}
