import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ritmo/core/ux/ritmo_snackbar.dart';

class DeviceLocationService {
  DeviceLocationService._();
  static final DeviceLocationService instance = DeviceLocationService._();

  /// Determines the current position of the device completely independent of Google Play Services.
  /// Uses native Android LocationManager (forceLocationManager: true) and provides clean Persian error messages.
  Future<Position?> getCurrentPosition(BuildContext context) async {
    try {
      // 1. Check if device location service (GPS hardware) is enabled
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isEnabled) {
        if (context.mounted) {
          RitmoSnackbar.warning(
            context,
            'موقعیت‌یاب (GPS) گوشی خاموش است. لطفاً آن را روشن نمایید.',
          );
        }
        return null;
      }

      // 2. Check and request runtime location permissions
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            RitmoSnackbar.warning(
              context,
              'دسترسی به موقعیت مکانی توسط شما تایید نشد.',
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          RitmoSnackbar.error(
            context,
            'دسترسی به موقعیت مکانی مسدود است. لطفاً از بخش تنظیمات گوشی به ریتمو مجوز دهید.',
          );
        }
        return null;
      }

      // 3. Location settings configured for direct hardware GPS without Google Play Services
      final LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true, // Independent of Google Play Services (HMS, AOSP, all Androids)
          timeLimit: const Duration(seconds: 12),
          intervalDuration: const Duration(seconds: 1),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        );
      }

      // Try fetching current GPS position directly
      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      return position;
    } on TimeoutException {
      // Fast fallback to last known GPS position
      try {
        final lastKnown = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (lastKnown != null) {
          return lastKnown;
        }
      } catch (_) {}

      if (context.mounted) {
        RitmoSnackbar.error(
          context,
          'دریافت سیگنال GPS زمان‌بر شد. لطفاً در فضای باز امتحان نمایید.',
        );
      }
      return null;
    } on LocationServiceDisabledException {
      if (context.mounted) {
        RitmoSnackbar.warning(
          context,
          'موقعیت‌یاب (GPS) گوشی خاموش است. لطفاً GPS را روشن کنید.',
        );
      }
      return null;
    } on PermissionDeniedException {
      if (context.mounted) {
        RitmoSnackbar.warning(
          context,
          'دسترسی به موقعیت مکانی رد شد.',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error getting GPS position: $e');

      // Fast fallback to last known GPS position
      try {
        final lastKnown = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (lastKnown != null) {
          return lastKnown;
        }
      } catch (_) {}

      if (context.mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('disabled') || errStr.contains('location service')) {
          RitmoSnackbar.warning(
            context,
            'موقعیت‌یاب (GPS) گوشی خاموش است. لطفاً آن را روشن نمایید.',
          );
        } else if (errStr.contains('denied') || errStr.contains('permission')) {
          RitmoSnackbar.warning(
            context,
            'دسترسی به موقعیت مکانی داده نشد.',
          );
        } else {
          RitmoSnackbar.error(
            context,
            'خطا در ارتباط با GPS. لطفاً از روشن بودن موقعیت مکانی اطمینان حاصل فرمایید.',
          );
        }
      }
      return null;
    }
  }
}
