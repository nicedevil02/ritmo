import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_ids.dart';
import 'package:ritmo/core/notifications/notification_request.dart';

class CycleNotificationService {
  /// Schedule period reminder notifications
  static Future<void> scheduleReminders({
    required DateTime nextPeriodWindowStart,
    required bool consentReminders,
    required bool pregnancyMode,
  }) async {
    await cancelAll();

    if (!consentReminders || pregnancyMode) {
      return;
    }

    final today = DateTime.now();

    // 2 days before nextPeriodWindowStart
    final dayMinus2 = nextPeriodWindowStart.subtract(const Duration(days: 2));
    // 1 day before nextPeriodWindowStart
    final dayMinus1 = nextPeriodWindowStart.subtract(const Duration(days: 1));

    // Schedule 2 days before reminder
    if (dayMinus2.isAfter(today)) {
      final scheduledDateTime = DateTime(dayMinus2.year, dayMinus2.month, dayMinus2.day, 10); // 10:00 AM
      if (scheduledDateTime.isAfter(today)) {
        await NotificationGateway.schedule(
          NotificationRequest(
            id: 'cycle_period_2days_${NotificationIds.cyclePeriod}',
            channel: NotificationChannelId.privateChannel,
            scheduledAt: scheduledDateTime,
            title: 'یادآوری ریتمو 🌸',
            body: 'لوازم شخصیات رو چک کن 💜',
            privacy: NotificationPrivacy.redacted,
            redactedTitle: 'ریتمو: یادآوری روزانه 🌸',
            redactedBody: 'برای مشاهده باز کنید',
            sourceSystem: 'cycle',
            entityId: 'cycle_period',
          ),
        );
      }
    }

    // Schedule 1 day before reminder
    if (dayMinus1.isAfter(today)) {
      final scheduledDateTime = DateTime(dayMinus1.year, dayMinus1.month, dayMinus1.day, 10); // 10:00 AM
      if (scheduledDateTime.isAfter(today)) {
        await NotificationGateway.schedule(
          NotificationRequest(
            id: 'cycle_period_1day_${NotificationIds.cyclePill}',
            channel: NotificationChannelId.privateChannel,
            scheduledAt: scheduledDateTime,
            title: 'ریتمو 🌸',
            body: 'فردا ممکنه شروع بشه، آماده باش 💪',
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

  /// Cancel all cycle-related notifications
  static Future<void> cancelAll() async {
    await NotificationGateway.cancelForEntity('cycle', 'cycle_period');
    await NotificationGateway.cancel('cycle_period_2days_${NotificationIds.cyclePeriod}');
    await NotificationGateway.cancel('cycle_period_1day_${NotificationIds.cyclePill}');
  }

  /// Show an immediate local notification (used for backup warnings etc.)
  static Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await NotificationGateway.schedule(
      NotificationRequest(
        id: 'immediate_backup_$id',
        channel: NotificationChannelId.planning,
        scheduledAt: DateTime.now(),
        title: title,
        body: body,
        sourceSystem: 'backup',
        entityId: 'backup_immediate',
      ),
    );
  }
}
