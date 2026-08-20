import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';

class MissedReminderRecovery {
  static Future<int> recoverMissedReminders({DateTime? nowOverride}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = nowOverride ?? DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      final rows = await db.query(
        'pending_reminders',
        where: 'scheduledTime <= ?',
        whereArgs: [nowMs],
      );

      if (rows.isEmpty) return 0;

      final activeMissedTasks = <(String reminderId, String taskId, String title, String body)>[];
      final rowsToDelete = <String>[];

      for (final r in rows) {
        final reminderId = r['id'] as String;
        final payloadJson = r['payloadJson'] as String?;
        String? taskId;

        if (payloadJson != null && payloadJson.isNotEmpty) {
          try {
            final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
            taskId = payload['taskId'] as String?;
          } catch (_) {}
        }

        if (taskId == null || taskId.isEmpty || taskId == 'nudge') {
          rowsToDelete.add(reminderId);
          continue;
        }

        final task = await SimpleTaskRepository.instance.getById(taskId);
        if (task == null || task.isDone) {
          rowsToDelete.add(reminderId);
          continue;
        }

        activeMissedTasks.add((reminderId, taskId, task.title, task.note ?? ''));
        rowsToDelete.add(reminderId);
      }

      final missedCount = activeMissedTasks.length;

      if (missedCount > 3) {
        // Aggregated notification for more than 3 missed reminders
        await NotificationGateway.schedule(
          NotificationRequest(
            id: 'missed_tasks_summary_${now.millisecondsSinceEpoch}',
            channel: NotificationChannelId.planning,
            scheduledAt: now,
            title: 'یادآور کارهای گذشته',
            body: '${PersianDigits.toPersian(missedCount)} یادآور را ندیدی',
            sourceSystem: 'tasks',
            entityId: 'missed_summary',
          ),
        );
      } else {
        // Dispatch individual instant notifications (up to 3)
        for (final item in activeMissedTasks) {
          await NotificationGateway.schedule(
            NotificationRequest(
              id: 'missed_${item.$1}',
              channel: NotificationChannelId.planning,
              scheduledAt: now,
              title: 'یادآور کار: ${item.$3}',
              body: item.$4,
              sourceSystem: 'tasks',
              entityId: item.$2,
            ),
          );
        }
      }

      // Clean up processed pending reminders
      if (rowsToDelete.isNotEmpty) {
        final placeholders = List.filled(rowsToDelete.length, '?').join(', ');
        await db.delete(
          'pending_reminders',
          where: 'id IN ($placeholders)',
          whereArgs: rowsToDelete,
        );
      }

      RitmoLog.info('MissedReminderRecovery', 'Recovered $missedCount missed task reminders');
      return missedCount;
    } catch (e, st) {
      RitmoLog.error('MissedReminderRecovery', 'Failed to recover missed reminders', e, st);
      return 0;
    }
  }
}
