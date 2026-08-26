import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';

/// Single unified scheduler for daily obligatory prayer notifications & pre-reminders.
class PrayerReminderScheduler {
  PrayerReminderScheduler._();
  static final PrayerReminderScheduler instance = PrayerReminderScheduler._();

  static const _activePrayerKeys = ['fajr', 'dhuhr', 'maghrib'];

  /// Reads current worship settings and schedules exact & pre-reminders for [daysAhead] days.
  Future<void> schedulePrayerReminders({
    DateTime? fromDate,
    int daysAhead = 2,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: "key LIKE 'worship_%'",
      );
      final settings = {
        for (final r in rows) r['key']! as String: r['value']! as String,
      };

      final isEnabled = settings['worship_adhan_enabled'] != 'false' &&
          settings['worship_prayer_reminders_enabled'] != 'false';

      if (!isEnabled) {
        await cancelAll();
        return;
      }

      final adhanFajr = settings['worship_adhan_fajr'] != 'false';
      final adhanDhuhr = settings['worship_adhan_dhuhr'] != 'false';
      final adhanMaghrib = settings['worship_adhan_maghrib'] != 'false';
      final preReminderMinutes =
          int.tryParse(settings['worship_pre_reminder_minutes'] ?? '0') ?? 0;

      final enabledMap = {
        'fajr': adhanFajr,
        'dhuhr': adhanDhuhr,
        'maghrib': adhanMaghrib,
      };

      final prayerLabels = {
        'fajr': 'نماز صبح',
        'dhuhr': 'نماز ظهر',
        'maghrib': 'نماز مغرب',
      };

      final prayerEmojis = {
        'fajr': '🌅',
        'dhuhr': '☀️',
        'maghrib': '🌇',
      };

      final now = DateTime.now();
      final baseDate = fromDate ?? now;

      for (int i = 0; i < daysAhead; i++) {
        final targetDate = DateTime(baseDate.year, baseDate.month, baseDate.day + i);
        final dateStr =
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

        final times = await WorshipEngine.instance.prayerTimes(targetDate);
        final timesMap = {
          'fajr': times.fajr,
          'dhuhr': times.dhuhr,
          'maghrib': times.maghrib,
        };

        for (final key in _activePrayerKeys) {
          final isPrayerActive = enabledMap[key] ?? true;
          final prayerTime = timesMap[key];
          if (!isPrayerActive || prayerTime == null) continue;

          final label = prayerLabels[key] ?? 'نماز';
          final emoji = prayerEmojis[key] ?? '🕌';

          // 1. Exact Prayer Time Notification
          if (prayerTime.isAfter(now)) {
            final exactId = 'prayer_exact_${key}_$dateStr';
            await NotificationGateway.schedule(
              NotificationRequest(
                id: exactId,
                channel: NotificationChannelId.worship,
                scheduledAt: prayerTime,
                title: 'وقت $label $emoji',
                body: 'هنگام اقامهٔ $label فرا رسیده است. التماس دعا 🤲',
                sourceSystem: 'worship',
                entityId: 'prayer_$key',
              ),
              now: now,
            );
          }

          // 2. Pre-Adhan Preparation Reminder
          if (preReminderMinutes > 0) {
            final preTime = prayerTime.subtract(Duration(minutes: preReminderMinutes));
            if (preTime.isAfter(now)) {
              final preId = 'prayer_pre_${key}_$dateStr';
              final minsFa = PersianDigits.convert(preReminderMinutes.toString());
              await NotificationGateway.schedule(
                NotificationRequest(
                  id: preId,
                  channel: NotificationChannelId.worship,
                  scheduledAt: preTime,
                  title: 'آمادگی برای $label $emoji',
                  body: '$minsFa دقیقه تا اذان و اقامهٔ $label باقی مانده است. التماس دعا 🌸',
                  sourceSystem: 'worship',
                  entityId: 'prayer_$key',
                ),
                now: now,
              );
            }
          }
        }
      }

      RitmoLog.info(
        'PrayerReminderScheduler',
        'Successfully scheduled prayer reminders for $daysAhead days (pre-reminder: $preReminderMinutes min).',
      );
    } catch (e, st) {
      RitmoLog.error('PrayerReminderScheduler', 'Failed to schedule prayer reminders', e, st);
    }
  }

  /// Cancels all scheduled prayer reminders.
  Future<void> cancelAll() async {
    try {
      final now = DateTime.now();
      for (int i = 0; i < 7; i++) {
        final targetDate = DateTime(now.year, now.month, now.day + i);
        final dateStr =
            '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
        for (final key in _activePrayerKeys) {
          await NotificationGateway.cancel('prayer_exact_${key}_$dateStr');
          await NotificationGateway.cancel('prayer_pre_${key}_$dateStr');
        }
      }
    } catch (e) {
      debugPrint('PrayerReminderScheduler: Error canceling prayer alarms: $e');
    }
  }
}
