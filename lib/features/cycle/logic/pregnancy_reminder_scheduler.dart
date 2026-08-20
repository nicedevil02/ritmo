// PRG-35: PregnancyReminderScheduler
// Orchestrator that computes and schedules pregnancy-specific notifications
// (midwife visits, daily supplements, and third-trimester kick counts)
// with discrete privacy masking support.

import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:sqflite/sqflite.dart';

class PregnancyReminderScheduler {
  const PregnancyReminderScheduler._();

  static const String maskedTitle = 'یادآوری ریتمو';
  static const String maskedBody = 'یادآوری ریتمو';
  static const String redactedTitle = 'یادآوری ریتمو';
  static const String redactedBody = 'یک یادآوری جدید دارید';

  /// Re-evaluates pregnancy parameters and reschedules all active reminders.
  static Future<void> rescheduleAll({
    Database? dbExecutor,
    Map<String, String>? appSettings,
    DateTime? now,
  }) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;

      late final Map<String, String> settings;
      if (appSettings != null) {
        settings = appSettings;
      } else {
        final list = await db.query('app_settings');
        settings = {
          for (final s in list)
            if (s['key'] != null)
              s['key'].toString(): s['value']?.toString() ?? '',
        };
      }

      final isPregnant = CycleSettings.isPregnancyMode(settings);
      if (!isPregnant) {
        await cancelAll();
        return;
      }

      final effectiveNow = now ?? CycleClock.now;
      final cleanToday = CycleDateContract.cleanDate(effectiveNow);

      final isMasked = settings['preg_mask_notifications'] == 'true';
      final leadDays = int.tryParse(settings['preg_visit_reminder_lead_days'] ?? '3') ?? 3;
      final reminderHour = int.tryParse(settings['preg_reminder_hour'] ?? '9') ?? 9;
      final supplementEnabled = settings['preg_supplement_reminder'] == 'true';
      final kickEnabled = settings['preg_kick_reminder'] == 'true';

      final lmpStr = settings['preg_start_date'] ?? settings['cycle_pregnancy_start_date'];
      final lmp = CycleDateContract.parseDayKey(lmpStr) ?? cleanToday;
      final ga = PregnancyDateEngine.calculateCurrentGestation(
        lmp: lmp,
        now: effectiveNow,
      );

      final requests = <NotificationRequest>[];

      // 1. Visit Reminders (from pregnancy_checkups & doctor_visits)
      try {
        final checkupTables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='pregnancy_checkups'",
        );
        if (checkupTables.isNotEmpty) {
          final checkups = await db.query(
            'pregnancy_checkups',
            where: 'isDone != 1 AND isCompleted != 1',
            orderBy: 'scheduledDate ASC',
          );

          for (var i = 0; i < checkups.length; i++) {
            final chk = checkups[i];
            final scheduledMs = chk['scheduledDate'] as int?;
            if (scheduledMs != null && scheduledMs > 0) {
              final scheduledDate = DateTime.fromMillisecondsSinceEpoch(scheduledMs);
              final reminderDate = CycleDateContract.cleanDate(scheduledDate).subtract(
                Duration(days: leadDays),
              );

              if (CycleDateContract.isSameOrAfter(reminderDate, cleanToday)) {
                final scheduledTime = DateTime(
                  reminderDate.year,
                  reminderDate.month,
                  reminderDate.day,
                  reminderHour,
                  0,
                );

                if (scheduledTime.isAfter(effectiveNow)) {
                  final title = isMasked ? maskedTitle : 'یادآوری ویزیت مامایی';
                  final body = isMasked
                      ? maskedBody
                      : (chk['title']?.toString() ?? 'ویزیت مامایی در پیش است.');

                  requests.add(
                    NotificationRequest(
                      id: NotificationIds.pregnancyVisit(i).toString(),
                      channel: NotificationChannelId.privateChannel,
                      scheduledAt: scheduledTime,
                      title: title,
                      body: body,
                      privacy: isMasked ? NotificationPrivacy.redacted : NotificationPrivacy.none,
                      redactedTitle: redactedTitle,
                      redactedBody: redactedBody,
                      sourceSystem: 'pregnancy',
                      entityId: 'pregnancy_visit',
                    ),
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        RitmoLogger.warning('[PregnancyReminderScheduler] Error loading checkups: $e');
      }

      // 2. Daily Supplement Reminder
      if (supplementEnabled) {
        var reminderTime = DateTime(
          cleanToday.year,
          cleanToday.month,
          cleanToday.day,
          reminderHour,
          0,
        );
        if (!reminderTime.isAfter(effectiveNow)) {
          reminderTime = reminderTime.add(const Duration(days: 1));
        }

        final title = isMasked ? maskedTitle : 'یادآوری مکمل بارداری';
        final body = isMasked ? maskedBody : 'زمان مصرف مکمل‌ها و ویتامین‌های روزانه است.';

        requests.add(
          NotificationRequest(
            id: NotificationIds.pregnancySupplement.toString(),
            channel: NotificationChannelId.privateChannel,
            scheduledAt: reminderTime,
            title: title,
            body: body,
            privacy: isMasked ? NotificationPrivacy.redacted : NotificationPrivacy.none,
            redactedTitle: redactedTitle,
            redactedBody: redactedBody,
            sourceSystem: 'pregnancy',
            entityId: 'pregnancy_supplement',
          ),
        );
      }

      // 3. Kick Counting Reminder (Week 28+)
      if (kickEnabled && ga.weeks >= 28) {
        var reminderTime = DateTime(
          cleanToday.year,
          cleanToday.month,
          cleanToday.day,
          reminderHour,
          0,
        );
        if (!reminderTime.isAfter(effectiveNow)) {
          reminderTime = reminderTime.add(const Duration(days: 1));
        }

        final title = isMasked ? maskedTitle : 'یادآوری لگدشماری';
        final body = isMasked ? maskedBody : 'زمان ثبت و بررسی حرکات جنین است.';

        requests.add(
          NotificationRequest(
            id: NotificationIds.pregnancyKick.toString(),
            channel: NotificationChannelId.privateChannel,
            scheduledAt: reminderTime,
            title: title,
            body: body,
            privacy: isMasked ? NotificationPrivacy.redacted : NotificationPrivacy.none,
            redactedTitle: redactedTitle,
            redactedBody: redactedBody,
            sourceSystem: 'pregnancy',
            entityId: 'pregnancy_kick',
          ),
        );
      }

      // Transactional wipe & schedule
      await cancelAll();
      for (final req in requests) {
        await NotificationGateway.schedule(req);
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancyReminderScheduler] error during rescheduleAll',
        error: e,
        stack: st,
      );
    }
  }

  /// Cancels all active pregnancy notifications.
  static Future<void> cancelAll() async {
    try {
      await NotificationGateway.cancelForEntity('pregnancy', 'pregnancy_visit');
      await NotificationGateway.cancelForEntity('pregnancy', 'pregnancy_supplement');
      await NotificationGateway.cancelForEntity('pregnancy', 'pregnancy_kick');

      for (var i = 0; i < 10; i++) {
        await NotificationGateway.cancel(NotificationIds.pregnancyVisit(i).toString());
      }
      await NotificationGateway.cancel(NotificationIds.pregnancySupplement.toString());
      await NotificationGateway.cancel(NotificationIds.pregnancyKick.toString());
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancyReminderScheduler] error during cancelAll',
        error: e,
        stack: st,
      );
    }
  }
}
