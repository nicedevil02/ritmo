import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';

class TaskScheduleRow extends StatelessWidget {
  const TaskScheduleRow({
    super.key,
    required this.task,
    required this.onTaskChanged,
  });

  final SimpleTask task;
  final ValueChanged<SimpleTask> onTaskChanged;

  Future<void> _setQuickReminder(BuildContext context, DateTime at, String label) async {
    final reminderId = 'rem_${task.id}';

    if (!await sl<AlarmPlatform>().checkExactAlarmPermission()) {
      final granted = await sl<AlarmPlatform>().requestExactAlarmPermission();
      if (!granted) {
        if (context.mounted) {
          RitmoToast.show(context, 'مجوز یادآور داده نشد', icon: CupertinoIcons.exclamationmark_triangle);
        }
        return;
      }
    }

    await NotificationGateway.cancel(reminderId);

    final targetMs = at.millisecondsSinceEpoch;
    await SimpleTaskRepository.instance.addPendingReminder(
      reminderId: reminderId,
      title: 'یادآور کار: ${task.title}',
      body: task.note ?? '',
      scheduledTimeMs: targetMs,
      taskId: task.id,
    );

    final updated = task.copyWith(reminderAtMs: targetMs, reminderId: reminderId);
    await SimpleTaskRepository.instance.updateTask(updated);
    onTaskChanged(updated);

    await NotificationGateway.schedule(
      NotificationRequest(
        id: reminderId,
        channel: NotificationChannelId.planning,
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(targetMs),
        title: task.title,
        sourceSystem: 'tasks',
        entityId: task.id,
      ),
    );
    await AlarmSchedulerService.scheduleNextAlarms();

    if (context.mounted) {
      RitmoToast.show(context, 'یادآور برای $label تنظیم شد', icon: CupertinoIcons.bell);
    }
  }

  Future<void> _pickCustomReminder(BuildContext context) async {
    final now = DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime != null && context.mounted) {
      var target = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
      if (target.isBefore(now)) {
        target = target.add(const Duration(days: 1));
      }
      final hh = pickedTime.hour.toString().padLeft(2, '0');
      final mm = pickedTime.minute.toString().padLeft(2, '0');
      await _setQuickReminder(context, target, 'ساعت $hh:$mm'.toPersianDigits());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'یادآور و زمان‌بندی',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (now.hour < 20)
              ActionChip(
                label: const Text('امشب ۲۰:۰۰', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  final at = DateTime(now.year, now.month, now.day, 20, 0);
                  _setQuickReminder(context, at, 'امشب');
                },
              ),
            ActionChip(
              label: const Text('فردا ۰۹:۰۰', style: TextStyle(fontSize: 11)),
              onPressed: () {
                final at = DateTime(now.year, now.month, now.day + 1, 9, 0);
                _setQuickReminder(context, at, 'فردا صبح');
              },
            ),
            ActionChip(
              label: const Text('زمان دلخواه…', style: TextStyle(fontSize: 11)),
              onPressed: () => _pickCustomReminder(context),
            ),
            if (task.reminderAtMs != null)
              ActionChip(
                avatar: const Icon(CupertinoIcons.clear_circled, size: 14),
                label: const Text('حذف یادآور', style: TextStyle(fontSize: 11)),
                onPressed: () async {
                  if (task.reminderId != null) {
                    await NotificationGateway.cancel(task.reminderId!);
                  }
                  final updated = task.copyWith(reminderAtMs: null, reminderId: null);
                  await SimpleTaskRepository.instance.updateTask(updated);
                  onTaskChanged(updated);
                },
              ),
          ],
        ),
      ],
    );
  }
}
