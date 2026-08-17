// C-10 & C-39: CycleNotificationService
// Manages discrete, privacy-preserving notifications for menstrual cycle tracking.
// Never leaks sensitive terms ("پریود", "قاعدگی") in notifications or logs.
// Uses dedicated notification IDs to prevent collisions with other subsystems.
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';

class CycleNotificationService {
  const CycleNotificationService._();

  static const String _idT2 = 'cycle_period_t2';
  static const String _idT1 = 'cycle_period_t1';

  /// Schedules cycle reminder notifications for the upcoming period window.
  /// [nextPeriodWindowStart] must be a valid upcoming date.
  static Future<void> scheduleReminders({
    required DateTime nextPeriodWindowStart,
    required bool consentReminders,
    required bool pregnancyMode,
    DateTime? now,
  }) async {
    if (!consentReminders || pregnancyMode) {
      await cancelAll();
      return;
    }

    final effectiveNow = now ?? DateTime.now();
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    final cleanWindowStart = CycleDateContract.cleanDate(nextPeriodWindowStart);

    try {
      final requests = <NotificationRequest>[];

      // T-2 reminder: 2 days before predicted start
      final dayMinus2 = cleanWindowStart.subtract(const Duration(days: 2));
      if (CycleDateContract.isSameOrAfter(dayMinus2, cleanToday)) {
        final scheduledDateTime = DateTime(dayMinus2.year, dayMinus2.month, dayMinus2.day, 10, 0);
        if (scheduledDateTime.isAfter(effectiveNow)) {
          requests.add(
            NotificationRequest(
              id: _idT2,
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

      // T-1 reminder: 1 day before predicted start
      final dayMinus1 = cleanWindowStart.subtract(const Duration(days: 1));
      if (CycleDateContract.isSameOrAfter(dayMinus1, cleanToday)) {
        final scheduledDateTime = DateTime(dayMinus1.year, dayMinus1.month, dayMinus1.day, 10, 0);
        if (scheduledDateTime.isAfter(effectiveNow)) {
          requests.add(
            NotificationRequest(
              id: _idT1,
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

      // Cancel previous cycle reminders and schedule newly validated ones
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

  /// Cancels all cycle notifications.
  static Future<void> cancelAll() async {
    try {
      await NotificationGateway.cancelForEntity('cycle', 'cycle_period');
      await NotificationGateway.cancel(_idT2);
      await NotificationGateway.cancel(_idT1);
      // Clean legacy IDs
      await NotificationGateway.cancel('cycle_period_2days_${NotificationIds.cyclePeriod}');
      await NotificationGateway.cancel('cycle_period_1day_${NotificationIds.cyclePill}');
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleNotificationService] error cancelling cycle notifications',
        error: e,
        stack: st,
      );
    }
  }
}
