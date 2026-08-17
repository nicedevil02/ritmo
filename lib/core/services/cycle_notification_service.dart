// C-10 & C-39: CycleNotificationService
// Schedules discrete, privacy-preserving notifications for upcoming menstrual cycle windows.
// Supports multi-cycle lookahead (3 cycles), ensures transactional scheduling (no early wipeouts),
// and guarantees discrete Persian titles/bodies.
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';

class CycleNotificationService {
  const CycleNotificationService._();

  static const int upcomingCyclesLookahead = 3;

  /// Schedules multi-cycle reminder notifications for the upcoming period windows.
  /// If [nextPeriodWindowStart] is null, or [pregnancyMode] is active, or [consentReminders] is false,
  /// all cycle reminders are cancelled.
  static Future<void> scheduleReminders({
    required DateTime? nextPeriodWindowStart,
    int cycleLength = 28,
    required bool consentReminders,
    required bool pregnancyMode,
    DateTime? now,
  }) async {
    if (!consentReminders || pregnancyMode || nextPeriodWindowStart == null) {
      await cancelAll();
      return;
    }

    final effectiveNow = now ?? DateTime.now();
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    final cleanWindowStart = CycleDateContract.cleanDate(nextPeriodWindowStart);
    final safeCycleLength = cycleLength > 0 ? cycleLength : 28;

    try {
      final requests = <NotificationRequest>[];

      for (var c = 0; c < upcomingCyclesLookahead; c++) {
        final cycleTargetStart = cleanWindowStart.add(
          Duration(days: c * safeCycleLength),
        );

        // T-2 reminder: 2 days before predicted start at 10:00 AM
        final dayMinus2 = cycleTargetStart.subtract(const Duration(days: 2));
        if (CycleDateContract.isSameOrAfter(dayMinus2, cleanToday)) {
          final scheduledDateTime = DateTime(
            dayMinus2.year,
            dayMinus2.month,
            dayMinus2.day,
            10,
            0,
          );
          if (scheduledDateTime.isAfter(effectiveNow)) {
            requests.add(
              NotificationRequest(
                id: 'cycle_period_t2_c$c',
                channel: NotificationChannelId.privateChannel,
                scheduledAt: scheduledDateTime,
                title: 'ریتم طبیعی بدن 🌸',
                body: 'بررسی لوازم و آمادگی روزهای پیش رو',
                privacy: NotificationPrivacy.redacted,
                redactedTitle: 'ریتمو: یادآوری روزانه 🌸',
                redactedBody: 'برای مشاهده باز کنید',
                sourceSystem: 'cycle',
                entityId: 'cycle_period',
              ),
            );
          }
        }

        // T-1 reminder: 1 day before predicted start at 10:00 AM
        final dayMinus1 = cycleTargetStart.subtract(const Duration(days: 1));
        if (CycleDateContract.isSameOrAfter(dayMinus1, cleanToday)) {
          final scheduledDateTime = DateTime(
            dayMinus1.year,
            dayMinus1.month,
            dayMinus1.day,
            10,
            0,
          );
          if (scheduledDateTime.isAfter(effectiveNow)) {
            requests.add(
              NotificationRequest(
                id: 'cycle_period_t1_c$c',
                channel: NotificationChannelId.privateChannel,
                scheduledAt: scheduledDateTime,
                title: 'ریتم طبیعی بدن 🌸',
                body: 'فردا احتمال آغاز چرخه جدید است؛ روز آرامی داشته باشید',
                privacy: NotificationPrivacy.redacted,
                redactedTitle: 'ریتمو: یادآوری روزانه 🌸',
                redactedBody: 'برای مشاهده باز کنید',
                sourceSystem: 'cycle',
                entityId: 'cycle_period',
              ),
            );
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
      // Note: Do NOT wipe existing reminders if computation fails
    }
  }

  /// Cancels all cycle notifications across all lookahead cycles.
  static Future<void> cancelAll() async {
    try {
      await NotificationGateway.cancelForEntity('cycle', 'cycle_period');
      for (var c = 0; c < 5; c++) {
        await NotificationGateway.cancel('cycle_period_t2_c$c');
        await NotificationGateway.cancel('cycle_period_t1_c$c');
      }
      await NotificationGateway.cancel('cycle_period_t2');
      await NotificationGateway.cancel('cycle_period_t1');
      // Clean legacy IDs
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
