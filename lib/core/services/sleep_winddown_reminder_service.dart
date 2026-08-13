import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// قدم صفر — یادآور پیش‌خواب (Wind-down).
///
/// کلیدهای `sleep_winddown_reminder` و `sleep_winddown_minutes` مدت‌ها در
/// `app_settings` نوشته می‌شدند ولی هیچ‌جا خوانده و زمان‌بندی نمی‌شدند.
/// این سرویس تنها نقطهٔ ورود است: پس از ذخیرهٔ اهداف خواب و در شروع اپ،
/// [syncFromSettings] را صدا بزنید.
class SleepWinddownReminderService {
  static const int _notificationId = 3001;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
    _initialized = true;
  }

  /// تنظیمات را از `app_settings` می‌خواند و نوتیف روزانه را زمان‌بندی یا لغو می‌کند.
  static Future<void> syncFromSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        columns: ['key', 'value'],
        where: 'key IN (?, ?, ?)',
        whereArgs: [
          'sleep_winddown_reminder',
          'sleep_winddown_minutes',
          'sleep_target_bedtime',
        ],
      );

      final values = <String, String>{
        for (final row in rows)
          row['key'] as String: (row['value'] as String?) ?? '',
      };

      final enabled = values['sleep_winddown_reminder'] == 'true';
      final minutesBefore =
          int.tryParse(values['sleep_winddown_minutes'] ?? '') ?? 30;
      final bedtime = values['sleep_target_bedtime']; // قالب «HH:mm»

      if (!enabled || bedtime == null || bedtime.isEmpty) {
        await cancel();
        return;
      }

      final parts = bedtime.split(':');
      final hour = int.tryParse(parts.first);
      final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
      if (hour == null || minute == null) {
        await cancel();
        return;
      }

      // امن در برابر عبور از نیمه‌شب: مثلاً پلهٔ ۰۰:۳۰ با ۶۰ دقیقه ⇒ ۲۳:۳۰ همان شب.
      // اپراتور ٪ در Dart برای مقسوم‌علیه مثبت همیشه نامنفی برمی‌گرداند.
      final reminderMinOfDay = ((hour * 60 + minute) - minutesBefore) % 1440;

      await _scheduleDaily(
        hour: reminderMinOfDay ~/ 60,
        minute: reminderMinOfDay % 60,
        minutesBefore: minutesBefore,
        bedtime: bedtime,
      );
    } catch (e) {
      debugPrint('SleepWinddownReminderService.syncFromSettings failed: $e');
    }
  }

  static Future<void> _scheduleDaily({
    required int hour,
    required int minute,
    required int minutesBefore,
    required String bedtime,
  }) async {
    await _ensureInitialized();
    await cancel();

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'sleep_winddown',
      'یادآور پیش‌خواب',
      channelDescription: 'اعلان ملایم برای آماده‌شدن جهت خواب',
      color: Color(0xff8B5CF6),
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tzDateTime = tz.TZDateTime.from(scheduled, tz.local);

    Future<void> schedule(AndroidScheduleMode mode) =>
        _notificationsPlugin.zonedSchedule(
          id: _notificationId,
          title: 'ریتمو 🌙',
          body: '$minutesBefore دقیقه تا خواب هدف ($bedtime). کم‌کم جمع‌ش کن.',
          scheduledDate: tzDateTime,
          notificationDetails: details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.time,
        );

    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      try {
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (e) {
        debugPrint(
            'SleepWinddownReminderService: fallback scheduling also failed: $e');
      }
    }
  }

  static Future<void> cancel() async {
    await _ensureInitialized();
    await _notificationsPlugin.cancel(id: _notificationId);
  }
}
