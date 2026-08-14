import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';
import 'package:ritmo/core/notifications/notification_request.dart';

/// یادآور پیش‌خواب (Wind-down).
/// زمان‌بندی از طریق NotificationGateway با کانال planning انجام می‌شود.
class SleepWinddownReminderService {
  static const int _notificationId = NotificationIds.sleepWinddown;
  static const String _tapPayload = 'route:/sleep';

  /// تنظیمات را از `app_settings` می‌خواند و نوتیف روزانه را از طریق Gateway زمان‌بندی یا لغو می‌کند.
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
    await cancel();

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await NotificationGateway.schedule(
      NotificationRequest(
        id: 'sleep_winddown_$_notificationId',
        channel: NotificationChannelId.planning,
        scheduledAt: scheduled,
        title: 'ریتمو 🌙',
        body: '$minutesBefore دقیقه تا خواب هدف ($bedtime). کم‌کم جمع‌ش کن.',
        sourceSystem: 'sleep',
        entityId: 'sleep_winddown',
        payload: const {'route': _tapPayload},
      ),
    );
  }

  static Future<void> cancel() async {
    await NotificationGateway.cancel('sleep_winddown_$_notificationId');
    await NotificationGateway.cancelForEntity('sleep', 'sleep_winddown');
  }
}
