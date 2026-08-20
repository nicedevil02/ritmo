import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/presentation/task_strings.dart';

class DailyPlanningNudge {
  static const String reminderId = 'daily_planning_nudge';

  static Future<void> syncNudgeSchedule() async {
    try {
      final enabled = await TaskPreferences.isDailyNudgeEnabled();
      final timeStr = await TaskPreferences.getDailyNudgeTime();

      // Always cancel existing alarm first via unified NotificationGateway
      try {
        await NotificationGateway.cancel(reminderId);
      } catch (e, st) {
        RitmoLog.warning('DailyPlanningNudge', 'Failed to cancel existing nudge alarm', e, st);
      }

      if (!enabled) return;

      final parts = timeStr.split(':');
      if (parts.length != 2) return;
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 30;

      final now = DateTime.now();
      var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      const title = TaskStrings.dailyPlanningNudgeTitle;
      const message = TaskStrings.dailyPlanningNudgeBody;

      // 1. Schedule via NotificationGateway
      await NotificationGateway.schedule(
        NotificationRequest(
          id: reminderId,
          channel: NotificationChannelId.planning,
          scheduledAt: scheduledTime,
          title: title,
          body: message,
          sourceSystem: 'tasks',
          entityId: 'nudge',
        ),
      );

      // 2. Record pending reminder entry
      await SimpleTaskRepository.instance.addPendingReminder(
        reminderId: reminderId,
        title: title,
        body: message,
        scheduledTimeMs: scheduledTime.millisecondsSinceEpoch,
        taskId: 'nudge',
      );
    } catch (e, st) {
      RitmoLog.error('DailyPlanningNudge', 'Error syncing schedule', e, st);
    }
  }
}

