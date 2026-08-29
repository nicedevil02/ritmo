import 'dart:async';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';

/// Single unified scheduler for daily obligatory prayer notifications & pre-reminders.
class PrayerReminderScheduler {
  PrayerReminderScheduler._();
  static final PrayerReminderScheduler instance = PrayerReminderScheduler._();

  static const int kPrayerScheduleHorizonDays = 7;
  static const _allPrayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  static bool _parseBool(String? val, {bool defaultValue = true}) {
    if (val == null || val.isEmpty) return defaultValue;
    final lower = val.toLowerCase().trim();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
    return defaultValue;
  }

  /// Reads current worship settings and schedules exact & pre-reminders for [daysAhead] days.
  Future<void> schedulePrayerReminders({
    DateTime? fromDate,
    int daysAhead = kPrayerScheduleHorizonDays,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: "key LIKE 'worship_%' OR key = 'module_religion_enabled'",
      );
      final settings = <String, String>{};
      for (final r in rows) {
        final k = r['key']?.toString();
        final v = r['value']?.toString();
        if (k != null && v != null) {
          settings[k] = v;
        }
      }

      final isReligionEnabled = _parseBool(settings['module_religion_enabled'], defaultValue: false);
      final isAdhanEnabled = _parseBool(settings['worship_adhan_enabled'], defaultValue: false);
      final isRemindersEnabled = _parseBool(settings['worship_prayer_reminders_enabled'], defaultValue: false);
      final isEnabled = isReligionEnabled && isAdhanEnabled && isRemindersEnabled;

      // Always clear previous schedules in horizon to prevent stale alarms
      await cancelAll(horizonDays: daysAhead);

      if (!isEnabled) {
        return;
      }

      final separatePrayers = _parseBool(settings['worship_separate_prayers'], defaultValue: false);
      final adhanFajr = _parseBool(settings['worship_adhan_fajr']);
      final adhanDhuhr = _parseBool(settings['worship_adhan_dhuhr']);
      final adhanAsr = _parseBool(settings['worship_adhan_asr'], defaultValue: separatePrayers);
      final adhanMaghrib = _parseBool(settings['worship_adhan_maghrib']);
      final adhanIsha = _parseBool(settings['worship_adhan_isha'], defaultValue: separatePrayers);
      final preReminderMinutes =
          int.tryParse(settings['worship_pre_reminder_minutes'] ?? '0') ?? 0;

      final enabledMap = {
        'fajr': adhanFajr,
        'dhuhr': adhanDhuhr,
        'asr': separatePrayers ? adhanAsr : false,
        'maghrib': adhanMaghrib,
        'isha': separatePrayers ? adhanIsha : false,
      };

      final prayerLabels = {
        'fajr': 'نماز صبح',
        'dhuhr': 'نماز ظهر',
        'asr': 'نماز عصر',
        'maghrib': 'نماز مغرب',
        'isha': 'نماز عشا',
      };

      final prayerEmojis = {
        'fajr': '🌅',
        'dhuhr': '☀️',
        'asr': '🌤️',
        'maghrib': '🌇',
        'isha': '🌙',
      };

      final now = DateTime.now();
      final baseDate = fromDate ?? now;

      for (int i = 0; i < daysAhead; i++) {
        final targetDate = DateTime(baseDate.year, baseDate.month, baseDate.day + i);
        final dateStr = DateKey.of(targetDate);

        final times = await WorshipEngine.instance.prayerTimes(targetDate);
        final timesMap = {
          'fajr': times.fajr,
          'dhuhr': times.dhuhr,
          'asr': times.asr,
          'maghrib': times.maghrib,
          'isha': times.isha,
        };

        for (final key in _allPrayerKeys) {
          final isPrayerActive = enabledMap[key] ?? false;
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

  /// Cancels all scheduled prayer reminders for [horizonDays] days.
  Future<void> cancelAll({int horizonDays = kPrayerScheduleHorizonDays}) async {
    try {
      final now = DateTime.now();
      for (int i = 0; i < horizonDays; i++) {
        final targetDate = DateTime(now.year, now.month, now.day + i);
        final dateStr = DateKey.of(targetDate);
        for (final key in _allPrayerKeys) {
          await NotificationGateway.cancel('prayer_exact_${key}_$dateStr');
          await NotificationGateway.cancel('prayer_pre_${key}_$dateStr');
        }
      }
    } catch (e, st) {
      RitmoLog.error('PrayerReminderScheduler', 'Error canceling prayer alarms', e, st);
    }
  }
}
