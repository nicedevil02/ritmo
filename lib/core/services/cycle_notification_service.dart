// C-10 & C-39 & Lifecycle Prompt Phase 6: CycleNotificationService
// Schedules discrete, privacy-preserving notifications for upcoming menstrual cycle windows.
// Supports multi-cycle lookahead (3 cycles), ensures transactional scheduling (no early wipeouts),
// and guarantees discrete Persian titles/bodies via CyclePrivacyText and NotificationIds.
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_privacy_text.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';

class CycleNotificationService {
  const CycleNotificationService._();

  static const int upcomingCyclesLookahead = 3;

  /// Schedules multi-cycle reminder notifications for the provided forecast cycles (up to 3).
  static Future<void> scheduleForecastReminders({
    required List<PredictedCycle> forecastCycles,
    required bool consentReminders,
    required bool pregnancyMode,
    List<int> leadDays = const [3, 1],
    int reminderHour = 10,
    DateTime? now,
  }) async {
    if (!consentReminders || pregnancyMode || forecastCycles.isEmpty) {
      await cancelAll();
      return;
    }

    final effectiveNow = now ?? CycleClock.now;
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);

    try {
      final requests = <NotificationRequest>[];
      final targetCycles =
          forecastCycles.take(upcomingCyclesLookahead).toList();

      for (var c = 0; c < targetCycles.length; c++) {
        final cycle = targetCycles[c];
        final cleanTargetStart = CycleDateContract.cleanDate(
          cycle.predictedStart,
        );

        for (final days in leadDays) {
          final reminderDate = cleanTargetStart.subtract(
            Duration(days: days),
          );
          if (CycleDateContract.isSameOrAfter(reminderDate, cleanToday)) {
            final scheduledDateTime = DateTime(
              reminderDate.year,
              reminderDate.month,
              reminderDate.day,
              reminderHour,
              0,
            );
            if (scheduledDateTime.isAfter(effectiveNow)) {
              final idStr = NotificationIds.leadReminder(c, days).toString();
              requests.add(
                NotificationRequest(
                  id: idStr,
                  channel: NotificationChannelId.privateChannel,
                  scheduledAt: scheduledDateTime,
                  title: CyclePrivacyText.leadReminderTitle,
                  body: CyclePrivacyText.leadReminderBody(days),
                  privacy: NotificationPrivacy.redacted,
                  redactedTitle: CyclePrivacyText.osRedactedTitle,
                  redactedBody: CyclePrivacyText.osRedactedBody,
                  sourceSystem: 'cycle',
                  entityId: 'cycle_period',
                ),
              );
            }
          }
        }
      }

      await cancelAll();
      for (final req in requests) {
        await NotificationGateway.schedule(req);
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleNotificationService] error scheduling forecast reminders',
        error: e,
        stack: st,
      );
    }
  }

  /// Schedules multi-cycle reminder notifications for the upcoming period windows.
  static Future<void> scheduleReminders({
    required DateTime? nextPeriodWindowStart,
    int cycleLength = 28,
    required bool consentReminders,
    required bool pregnancyMode,
    List<int> leadDays = const [3, 1],
    int reminderHour = 10,
    DateTime? now,
  }) async {
    if (!consentReminders || pregnancyMode || nextPeriodWindowStart == null) {
      await cancelAll();
      return;
    }

    final effectiveNow = now ?? CycleClock.now;
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    final cleanWindowStart = CycleDateContract.cleanDate(nextPeriodWindowStart);
    final safeCycleLength = cycleLength > 0 ? cycleLength : 28;

    try {
      final requests = <NotificationRequest>[];

      for (var c = 0; c < upcomingCyclesLookahead; c++) {
        final cycleTargetStart = cleanWindowStart.add(
          Duration(days: c * safeCycleLength),
        );

        for (final days in leadDays) {
          final reminderDate = cycleTargetStart.subtract(
            Duration(days: days),
          );
          if (CycleDateContract.isSameOrAfter(reminderDate, cleanToday)) {
            final scheduledDateTime = DateTime(
              reminderDate.year,
              reminderDate.month,
              reminderDate.day,
              reminderHour,
              0,
            );
            if (scheduledDateTime.isAfter(effectiveNow)) {
              final idStr = NotificationIds.leadReminder(c, days).toString();
              requests.add(
                NotificationRequest(
                  id: idStr,
                  channel: NotificationChannelId.privateChannel,
                  scheduledAt: scheduledDateTime,
                  title: CyclePrivacyText.leadReminderTitle,
                  body: CyclePrivacyText.leadReminderBody(days),
                  privacy: NotificationPrivacy.redacted,
                  redactedTitle: CyclePrivacyText.osRedactedTitle,
                  redactedBody: CyclePrivacyText.osRedactedBody,
                  sourceSystem: 'cycle',
                  entityId: 'cycle_period',
                ),
              );
            }
          }
        }
      }

      // Atomically cancel and reschedule now that requests are successfully constructed
      await cancelAll();
      for (final req in requests) {
        await NotificationGateway.schedule(req);
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleNotificationService] error scheduling reminders',
        error: e,
        stack: st,
      );
    }
  }

  /// Cancels all cycle notifications across all lookahead cycles and legacy IDs.
  static Future<void> cancelAll() async {
    try {
      await NotificationGateway.cancelForEntity('cycle', 'cycle_period');
      // Cancel lead reminder IDs and confirmation IDs across all lookahead cycles
      for (var c = 0; c < 15; c++) {
        for (final d in [1, 2, 3, 5, 7, 10, 14]) {
          await NotificationGateway.cancel('cycle_lead_c${c}_d$d');
          await NotificationGateway.cancel(
            NotificationIds.leadReminder(c, d).toString(),
          );
        }
        await NotificationGateway.cancel('cycle_start_confirm_c$c');
        await NotificationGateway.cancel(
          NotificationIds.startConfirm(c).toString(),
        );
        await NotificationGateway.cancel('cycle_end_confirm_c$c');
        await NotificationGateway.cancel('cycle_period_t2_c$c');
        await NotificationGateway.cancel('cycle_period_t1_c$c');
      }
      await NotificationGateway.cancel('cycle_end_confirm');
      await NotificationGateway.cancel(
        NotificationIds.endConfirm().toString(),
      );
      await NotificationGateway.cancel('cycle_prolonged');
      await NotificationGateway.cancel(
        NotificationIds.prolongedBleeding().toString(),
      );

      // Clean legacy IDs
      await NotificationGateway.cancel('cycle_period_t2');
      await NotificationGateway.cancel('cycle_period_t1');
      await NotificationGateway.cancel('cycle_period');
      await NotificationGateway.cancel(NotificationIds.cyclePeriod.toString());
      await NotificationGateway.cancel(NotificationIds.cyclePeriodT1.toString());
      await NotificationGateway.cancel(
        'cycle_period_2days_${NotificationIds.cyclePeriod}',
      );
      await NotificationGateway.cancel(
        'cycle_period_1day_${NotificationIds.cyclePill}',
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleNotificationService] error cancelling cycle notifications',
        error: e,
        stack: st,
      );
    }
  }
}
