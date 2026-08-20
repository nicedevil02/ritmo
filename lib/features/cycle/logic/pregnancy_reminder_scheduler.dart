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
      final resumeMsStr = settings['preg_cycle_resume_reminder'];
      final hasResumeReminder = resumeMsStr != null && resumeMsStr.isNotEmpty;

      if (!isPregnant && !hasResumeReminder) {
        await cancelAll();
        return;
      }

      final effectiveNow = now ?? CycleClock.now;
      final cleanToday = CycleDateContract.cleanDate(effectiveNow);

      final isMasked =
          settings['preg_mask_notifications'] == 'true' ||
          settings['preg_lock_enabled'] == 'true' ||
          settings['cycle_inbox_mask_enabled'] == 'true';
      final leadDays =
          int.tryParse(settings['preg_visit_reminder_lead_days'] ?? '3') ?? 3;
      final reminderHour =
          int.tryParse(settings['preg_reminder_hour'] ?? '9') ?? 9;
      final supplementEnabled = settings['preg_supplement_reminder'] == 'true';
      final kickEnabled = settings['preg_kick_reminder'] == 'true';

      final requests = <NotificationRequest>[];

      if (isPregnant) {
        final lmpStr =
            settings['preg_start_date'] ??
            settings['cycle_pregnancy_start_date'];
        final lmp = CycleDateContract.parseDayKey(lmpStr) ?? cleanToday;
        final ga = PregnancyDateEngine.calculateCurrentGestation(
          lmp: lmp,
          now: effectiveNow,
        );

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
                final scheduledDate = DateTime.fromMillisecondsSinceEpoch(
                  scheduledMs,
                );
                final reminderDate = CycleDateContract.cleanDate(
                  scheduledDate,
                ).subtract(Duration(days: leadDays));

                if (CycleDateContract.isSameOrAfter(reminderDate, cleanToday)) {
                  final scheduledTime = DateTime(
                    reminderDate.year,
                    reminderDate.month,
                    reminderDate.day,
                    reminderHour,
                    0,
                  );

                  if (scheduledTime.isAfter(effectiveNow)) {
                    final title = isMasked
                        ? maskedTitle
                        : 'یادآوری نوبت مراقبت بارداری';
                    final body = isMasked
                        ? maskedBody
                        : 'شما در تاریخ ${CycleDateContract.toDayKey(scheduledDate)} نوبت ویزیت یا آزمایش دارید.';

                    requests.add(
                      NotificationRequest(
                        id: NotificationIds.pregnancyVisit(i).toString(),
                        channel: NotificationChannelId.privateChannel,
                        scheduledAt: scheduledTime,
                        title: title,
                        body: body,
                        privacy: isMasked
                            ? NotificationPrivacy.redacted
                            : NotificationPrivacy.none,
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
        } catch (e, st) {
          RitmoLogger.error(
            '[PregnancyReminderScheduler] error querying checkups: $e',
            error: e,
            stack: st,
          );
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

          final title = isMasked
              ? maskedTitle
              : 'یادآوری مکمل و ویتامین بارداری';
          final body = isMasked
              ? maskedBody
              : 'زمان مصرف مکمل‌ها و اسیدفولیک/ویتامین روزانه است.';

          requests.add(
            NotificationRequest(
              id: NotificationIds.pregnancySupplement.toString(),
              channel: NotificationChannelId.privateChannel,
              scheduledAt: reminderTime,
              title: title,
              body: body,
              privacy: isMasked
                  ? NotificationPrivacy.redacted
                  : NotificationPrivacy.none,
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
          final body = isMasked
              ? maskedBody
              : 'زمان ثبت و بررسی حرکات جنین است.';

          requests.add(
            NotificationRequest(
              id: NotificationIds.pregnancyKick.toString(),
              channel: NotificationChannelId.privateChannel,
              scheduledAt: reminderTime,
              title: title,
              body: body,
              privacy: isMasked
                  ? NotificationPrivacy.redacted
                  : NotificationPrivacy.none,
              redactedTitle: redactedTitle,
              redactedBody: redactedBody,
              sourceSystem: 'pregnancy',
              entityId: 'pregnancy_kick',
            ),
          );
        }
      }

      // 4. Postpartum Cycle Resume Reminder
      if (hasResumeReminder) {
        final resumeMs = int.tryParse(resumeMsStr);
        if (resumeMs != null && resumeMs > 0) {
          final resumeTime = DateTime.fromMillisecondsSinceEpoch(resumeMs);
          if (resumeTime.isAfter(effectiveNow)) {
            final title = isMasked ? maskedTitle : 'پیگیری سلامت و چرخه قاعدگی';
            final body = isMasked
                ? maskedBody
                : 'امیدواریم حال شما و نوزادتان خوب باشد. در صورت تمایل می‌توانید ثبت چرخهٔ قاعدگی را از سر بگیرید.';

            requests.add(
              NotificationRequest(
                id: NotificationIds.pregnancyCycleResume.toString(),
                channel: NotificationChannelId.privateChannel,
                scheduledAt: resumeTime,
                title: title,
                body: body,
                privacy: isMasked
                    ? NotificationPrivacy.redacted
                    : NotificationPrivacy.none,
                redactedTitle: redactedTitle,
                redactedBody: redactedBody,
                sourceSystem: 'pregnancy',
                entityId: 'pregnancy_cycle_resume',
              ),
            );
          }
        }
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
      await NotificationGateway.cancelForEntity(
        'pregnancy',
        'pregnancy_supplement',
      );
      await NotificationGateway.cancelForEntity('pregnancy', 'pregnancy_kick');
      await NotificationGateway.cancelForEntity(
        'pregnancy',
        'pregnancy_cycle_resume',
      );

      for (var i = 0; i < 10; i++) {
        await NotificationGateway.cancel(
          NotificationIds.pregnancyVisit(i).toString(),
        );
      }
      await NotificationGateway.cancel(
        NotificationIds.pregnancySupplement.toString(),
      );
      await NotificationGateway.cancel(
        NotificationIds.pregnancyKick.toString(),
      );
      await NotificationGateway.cancel(
        NotificationIds.pregnancyCycleResume.toString(),
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancyReminderScheduler] error during cancelAll',
        error: e,
        stack: st,
      );
    }
  }

  /// Schedules a 40-day postpartum cycle resume reminder and stores it in app_settings.
  static Future<void> scheduleCycleResume({
    required DateTime reminderDate,
    Database? dbExecutor,
    Map<String, String>? appSettings,
  }) async {
    final db = dbExecutor ?? await DatabaseHelper.instance.database;
    await db.insert('app_settings', {
      'key': 'preg_cycle_resume_reminder',
      'value': reminderDate.millisecondsSinceEpoch.toString(),
      'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await rescheduleAll(dbExecutor: db, appSettings: appSettings);
  }
}
