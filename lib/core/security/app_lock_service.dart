import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/settings/settings_service.dart';

class AppLockService {
  AppLockService._privateConstructor();
  static final AppLockService instance = AppLockService._privateConstructor();

  final LocalAuthentication _auth = LocalAuthentication();

  // --- Getters ---
  Future<bool> isLockEnabled() async {
    return SettingsService.instance.get<bool>('app_lock_enabled');
  }

  Future<String?> getLockPassword() async {
    return SecureKeyStore.getKey('app_lock_password');
  }

  Future<bool> useDeviceLock() async {
    return SettingsService.instance.get<bool>('app_use_device_lock');
  }

  Future<bool> isBiometricEnabled() async {
    return SettingsService.instance.get<bool>('app_biometric_enabled');
  }

  Future<int> getLockTimeoutSeconds() async {
    return SettingsService.instance.get<int>('app_lock_timeout_seconds');
  }

  // --- Setters ---
  Future<void> setLockEnabled(bool enabled) async {
    await SettingsService.instance.set('app_lock_enabled', enabled);
  }

  Future<void> setLockPassword(String? password) async {
    await SettingsService.instance.set('app_lock_password', password ?? '');
  }

  Future<void> setUseDeviceLock(bool useDeviceLock) async {
    await SettingsService.instance.set('app_use_device_lock', useDeviceLock);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await SettingsService.instance.set('app_biometric_enabled', enabled);
  }

  // --- Auth Capabilities ---
  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در بررسی پشتیبانی دستگاه از احراز هویت', e, st);
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در بررسی امکان سنجش بیومتریک', e, st);
      return false;
    }
  }

  Future<bool> authenticateWithDevice({
    required String reason,
    required bool biometricOnly,
  }) async {
    if (kIsWeb) return false;
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!isSupported && !canCheck) {
        return false;
      }
      
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: true,
      );
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در احراز هویت با دستگاه', e, st);
      return false;
    }
  }
}
