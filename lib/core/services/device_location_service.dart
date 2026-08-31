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

      // 3. Multi-stage location retrieval strategy:
      // Stage A: High accuracy GPS with resilient 20-second timeout
      final LocationSettings highSettings;
      if (Platform.isAndroid) {
        highSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true, // Independent of Google Play Services (HMS, AOSP, all Androids)
          timeLimit: const Duration(seconds: 20),
          intervalDuration: const Duration(seconds: 1),
        );
      } else {
        highSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        );
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: highSettings,
        );
        return position;
      } catch (innerError) {
        debugPrint('High accuracy GPS timed out or failed, falling back to network/last-known: $innerError');
      }

      // Stage B: Fallback to Network Provider / Balanced accuracy (fast indoor & Wi-Fi fix)
      try {
        final LocationSettings fallbackSettings;
        if (Platform.isAndroid) {
          fallbackSettings = AndroidSettings(
            accuracy: LocationAccuracy.medium,
            forceLocationManager: true,
            timeLimit: const Duration(seconds: 8),
          );
        } else {
          fallbackSettings = const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          );
        }

        final networkPosition = await Geolocator.getCurrentPosition(
          locationSettings: fallbackSettings,
        );
        return networkPosition;
      } catch (_) {}

      // Stage C: Fallback to last known position
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
          'دریافت موقعیت مکانی زمان‌بر شد. لطفاً از روشن بودن اینترنت یا GPS اطمینان حاصل فرمایید.',
        );
      }
      return null;
    } on TimeoutException {
      // Stage D: Fast fallback to last known GPS position
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
