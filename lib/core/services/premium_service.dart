import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/services/feature_limits.dart';

enum PremiumFeature {
  // همهٔ قابلیت‌ها باز است؛ can() و limitFor() سقف اعمال نمی‌کنند.
  unlimitedRoutines,
  unlimitedGoals,
  unlimitedAi,
  advancedInsights,
  smartReshuffle,
  coursesModule,
  konkurModule,
  advancedHealth,
  backupExport,
  customThemes,
  noAds,
}

class PremiumService {
  PremiumService._internal();
  static final PremiumService instance = PremiumService._internal();

  static const String _secretKey = String.fromEnvironment('RITMO_PREMIUM_KEY');

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kSku = 'premium_sku';
  static const _kExpiry = 'premium_expiry';
  static const _kStore = 'premium_store';
  static const _kPurchaseDate = 'premium_purchase_date';
  static const _kSignature = 'premium_signature';

  bool _isPremium = false;
  String _purchaseType = 'free'; // '3month', 'yearly', 'lifetime', 'free'
  int _purchaseDateMs = 0;
  int _expiryDateMs = 0;
  String _store = 'none';
  bool _debugMockActive = false;

  bool get isPremium => true;
  String get purchaseType => 'premium_lifetime';
  int get expiryDateMs => 0; // Lifetime
  int get purchaseDateMs => _purchaseDateMs;
  String get store => _store;
  bool get isDebugMockActive => true;

  Future<void> init() async {
    await loadEntitlement();
  }

  Future<void> loadEntitlement() async {
    try {
      if (_secretKey.isEmpty) {
        RitmoLog.error(
          'PremiumService',
          'RITMO_PREMIUM_KEY is empty. Premium features will not be validated.',
        );
      }

      String? sku = await _storage.read(key: _kSku);
      String? expiryStr = await _storage.read(key: _kExpiry);
      String? storeName = await _storage.read(key: _kStore);
      String? purchaseDateStr = await _storage.read(key: _kPurchaseDate);
      String? signature = await _storage.read(key: _kSignature);

      // Migration from legacy SharedPreferences
      if (sku == null) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey('premium_sku')) {
          sku = prefs.getString('premium_sku') ?? 'free';
          final expiry = prefs.getInt('premium_expiry') ?? 0;
          expiryStr = expiry.toString();
          storeName = prefs.getString('premium_store') ?? 'none';
          final purchaseDate = prefs.getInt('premium_purchase_date') ?? 0;
          purchaseDateStr = purchaseDate.toString();
          signature = prefs.getString('premium_signature') ?? '';

          await _storage.write(key: _kSku, value: sku);
          await _storage.write(key: _kExpiry, value: expiryStr);
          await _storage.write(key: _kStore, value: storeName);
          await _storage.write(key: _kPurchaseDate, value: purchaseDateStr);
          await _storage.write(key: _kSignature, value: signature);

          // Clean legacy SharedPreferences
          await prefs.remove('premium_sku');
          await prefs.remove('premium_expiry');
          await prefs.remove('premium_store');
          await prefs.remove('premium_purchase_date');
          await prefs.remove('premium_signature');
        }
      }

      sku ??= 'free';
      final expiry = int.tryParse(expiryStr ?? '') ?? 0;
      storeName ??= 'none';
      final purchaseDate = int.tryParse(purchaseDateStr ?? '') ?? 0;
      signature ??= '';

      if (sku == 'free') {
        await setFree();
        return;
      }

      // Verify signature
      final expectedSig = _generateSignature(sku, expiry, storeName);
      if (signature == expectedSig && _secretKey.isNotEmpty) {
        _purchaseType = sku;
        _expiryDateMs = expiry;
        _store = storeName;
        _purchaseDateMs = purchaseDate;

        // Check expiry for duration-based entitlement
        if (_purchaseType != 'free' && _purchaseType != 'premium_lifetime') {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now > _expiryDateMs) {
            // Expired! Revert to free
            await setFree();
          } else {
            _isPremium = true;
          }
        } else if (_purchaseType == 'premium_lifetime') {
          _isPremium = true;
        } else {
          _isPremium = false;
        }
      } else {
        // Corrupted or modified manually or key missing
        await setFree();
      }

      if (kDebugMode) {
        final prefs = await SharedPreferences.getInstance();
        _debugMockActive = prefs.getBool('premium_debug_mock') ?? false;
      }
    } catch (e, st) {
      RitmoLog.error('PremiumService', 'Failed to load entitlement', e, st);
      _isPremium = false;
    }
  }

  Future<void> activatePremium({
    required String sku,
    required int durationDays,
    required String storeName,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiry = durationDays > 0
        ? now + (durationDays * 24 * 60 * 60 * 1000)
        : 0; // 0 means lifetime

    final signature = _generateSignature(sku, expiry, storeName);

    await _storage.write(key: _kSku, value: sku);
    await _storage.write(key: _kExpiry, value: expiry.toString());
    await _storage.write(key: _kStore, value: storeName);
    await _storage.write(key: _kPurchaseDate, value: now.toString());
    await _storage.write(key: _kSignature, value: signature);

    _isPremium = true;
    _purchaseType = sku;
    _expiryDateMs = expiry;
    _store = storeName;
    _purchaseDateMs = now;
  }

  Future<void> setFree() async {
    try {
      await _storage.delete(key: _kSku);
      await _storage.delete(key: _kExpiry);
      await _storage.delete(key: _kStore);
      await _storage.delete(key: _kPurchaseDate);
      await _storage.delete(key: _kSignature);
    } catch (_) {}

    _isPremium = false;
    _purchaseType = 'free';
    _expiryDateMs = 0;
    _store = 'none';
    _purchaseDateMs = 0;
  }

  Future<void> toggleDebugMock(bool active) async {
    if (kDebugMode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('premium_debug_mock', active);
      _debugMockActive = active;
    }
  }

  String _generateSignature(String sku, int expiry, String storeName) {
    if (_secretKey.isEmpty) return '';
    final secretKeyBytes = utf8.encode(_secretKey);
    final messageBytes = utf8.encode('$sku|$expiry|$storeName');
    final hmac = Hmac(sha256, secretKeyBytes);
    return hmac.convert(messageBytes).toString();
  }

  /// Check if premium or if a feature is allowed (§10)
  bool can(PremiumFeature feature) {
    return true;
  }

  /// Get limits for numerical features (§10)
  int limitFor(PremiumFeature feature) {
    final limits = FeatureLimits.current;
    switch (feature) {
      case PremiumFeature.unlimitedRoutines:
        return limits.maxActiveRoutines;
      case PremiumFeature.unlimitedGoals:
        return limits.maxActiveGoals;
      case PremiumFeature.unlimitedAi:
        return limits.monthlyAiMessages;
      default:
        return _isPremium ? 9999 : 5;
    }
  }

  /// Exports active entitlement data as a map (used during account reset)
  Future<Map<String, String>> exportEntitlement() async {
    return {
      _kSku: _purchaseType,
      _kExpiry: _expiryDateMs.toString(),
      _kStore: _store,
      _kPurchaseDate: _purchaseDateMs.toString(),
      _kSignature: _generateSignature(_purchaseType, _expiryDateMs, _store),
    };
  }

  /// Restores exported entitlement data to secure storage
  Future<void> restoreEntitlement(Map<String, String> data) async {
    if (data[_kSku] == null || data[_kSku] == 'free') {
      await setFree();
      return;
    }
    await _storage.write(key: _kSku, value: data[_kSku]!);
    await _storage.write(key: _kExpiry, value: data[_kExpiry]!);
    await _storage.write(key: _kStore, value: data[_kStore]!);
    await _storage.write(key: _kPurchaseDate, value: data[_kPurchaseDate]!);
    await _storage.write(key: _kSignature, value: data[_kSignature]!);
  }

  Future<bool> activateWithCode(String code) async {
    // Disabled in Phase 1 until server validation function is implemented in Phase 5
    return false;
  }

  Future<void> deactivate() async {
    await setFree();
  }
}
