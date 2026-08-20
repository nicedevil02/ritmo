import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';

enum SnoozePreset {
  tenMinutes,
  oneHour,
  thisEvening,
  tomorrowMorning,
}

Future<void> snoozeTask(
  String taskId,
  SnoozePreset preset, {
  DateTime? nowOverride,
}) async {
  try {
    final task = await SimpleTaskRepository.instance.getById(taskId);
    if (task == null) {
      RitmoLog.warning('TaskSnooze', 'Cannot snooze non-existent task: $taskId');
      return;
    }

    final now = nowOverride ?? DateTime.now();
    final DateTime targetTime;

    switch (preset) {
      case SnoozePreset.tenMinutes:
        targetTime = now.add(const Duration(minutes: 10));
      case SnoozePreset.oneHour:
        targetTime = now.add(const Duration(hours: 1));
      case SnoozePreset.thisEvening:
        if (now.hour >= 20) {
          throw StateError('This evening preset is unavailable after 20:00');
        }
        targetTime = DateTime(now.year, now.month, now.day, 20, 0);
      case SnoozePreset.tomorrowMorning:
        targetTime = DateTime(now.year, now.month, now.day + 1, 9, 0);
    }

    final reminderId = 'rem_${task.id}';
    final targetMs = targetTime.millisecondsSinceEpoch;

    // 1. Cancel previous reminder
    if (task.reminderId != null && task.reminderId!.isNotEmpty) {
      try {
        await NotificationGateway.cancel(task.reminderId!);
      } catch (e, st) {
        RitmoLog.warning('TaskSnooze', 'Failed to cancel previous reminder: ${task.reminderId}', e, st);
      }
    }

    // 2. Schedule new reminder
    await NotificationGateway.schedule(
      NotificationRequest(
        id: reminderId,
        channel: NotificationChannelId.planning,
        scheduledAt: targetTime,
        title: 'یادآور کار: ${task.title}',
        body: task.note ?? '',
        sourceSystem: 'tasks',
        entityId: task.id,
      ),
    );

    // 3. Record pending reminder entry
    await SimpleTaskRepository.instance.addPendingReminder(
      reminderId: reminderId,
      title: 'یادآور کار: ${task.title}',
      body: task.note ?? '',
      scheduledTimeMs: targetMs,
      taskId: task.id,
    );

    // 4. Update task record (dueDate is strictly preserved!)
    final updated = task.copyWith(
      reminderAtMs: targetMs,
      reminderId: reminderId,
    );
    await SimpleTaskRepository.instance.updateTask(updated);

    RitmoLog.info('TaskSnooze', 'Task $taskId snoozed until $targetTime (preset: $preset)');
  } catch (e, st) {
    RitmoLog.error('TaskSnooze', 'Error snoozing task $taskId', e, st);
    rethrow;
  }
}
