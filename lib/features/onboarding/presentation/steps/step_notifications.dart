import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/onboarding/presentation/ritmo_orb.dart';
import 'package:sqflite/sqflite.dart';

class StepNotifications extends StatefulWidget {

  const StepNotifications({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<StepNotifications> createState() => _StepNotificationsState();
}

class _StepNotificationsState extends State<StepNotifications> {
  bool _isLoading = false;

  Future<void> _requestPermission() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });
    await HapticFeedback.mediumImpact();

    try {
      await _executePermissionFlow().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('Notification permission request timed out (safe fallback).');
        },
      );
    } catch (e) {
      debugPrint('Error requesting notifications permission: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      widget.onFinished();
    }
  }

  Future<void> _executePermissionFlow() async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // 1. Initialize plugin if not already initialized
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      try {
        await flutterLocalNotificationsPlugin
            .initialize(settings: initializationSettings)
            .timeout(const Duration(seconds: 2), onTimeout: () => null);
      } catch (_) {}

      // 2. Request Android notifications permission (Android 13+ / Huawei EMUI)
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation
            .requestNotificationsPermission()
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
      }

      // 3. Request iOS notifications permission
      final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        await iosImplementation
            .requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            )
            .timeout(const Duration(seconds: 3), onTimeout: () => false);
      }

      // 4. Save notification enabled state
      try {
        await SettingsService.instance.set(
          'persistent_status_notification_enabled',
          'true',
        ).timeout(const Duration(seconds: 2));
      } catch (_) {
        final db = await DatabaseHelper.instance.database;
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.insert(
          'app_settings',
          {
            'key': 'persistent_status_notification_enabled',
            'value': 'true',
            'updatedAt': now
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint('Error in _executePermissionFlow: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: RitmoOrb(size: 100)),
        const SizedBox(height: 24),
        Text(
          'اعلان‌های ریتمو',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
            ),
        ),
        const SizedBox(height: 12),
        Text(
          'برای اینکه بتوانیم روتین‌ها و زمان مصرف داروهایتان را دقیق و به‌موقع یادآوری کنیم، به مجوز ارسال اعلان نیاز داریم.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: colors.textSecondary,
            ),
        ),
        const SizedBox(height: 32),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Color(0xff9B89FF)))
        else ...[
          ElevatedButton(
            onPressed: _requestPermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff34C759), // iOS green style
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text(
              'فعال‌سازی اعلان‌ها',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await HapticFeedback.lightImpact();
              try {
                await SettingsService.instance.set(
                  'persistent_status_notification_enabled',
                  'false',
                ).timeout(const Duration(seconds: 2));
              } catch (e) {
                try {
                  final db = await DatabaseHelper.instance.database;
                  final now = DateTime.now().millisecondsSinceEpoch;
                  await db.insert(
                    'app_settings',
                    {
                      'key': 'persistent_status_notification_enabled',
                      'value': 'false',
                      'updatedAt': now
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                } catch (_) {}
              }
              widget.onFinished();
            },
            style: TextButton.styleFrom(
              foregroundColor: colors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text(
              'حالا نه',
              style: TextStyle(
                fontSize: 13,
                ),
            ),
          ),
        ],
      ],
    );
  }
}
