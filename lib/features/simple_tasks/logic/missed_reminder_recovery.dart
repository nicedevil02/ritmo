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

      // RITF-001: Only recover active pending reminders belonging to the tasks module
      final rows = await db.query(
        'pending_reminders',
        where: "scheduledTime <= ? AND state IN ('SCHEDULED', 'pending') AND (ownerModule = 'tasks' OR ownerModule IS NULL)",
        whereArgs: [nowMs],
      );

      if (rows.isEmpty) return 0;

      final activeMissedTasks = <(String reminderId, String taskId, String title, String body)>[];
      final recoveredReminderIds = <String>[];
      final skippedReminderIds = <String>[];

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
          skippedReminderIds.add(reminderId);
          continue;
        }

        final task = await SimpleTaskRepository.instance.getById(taskId);
        if (task == null || task.isDone) {
          skippedReminderIds.add(reminderId);
          continue;
        }

        activeMissedTasks.add((reminderId, taskId, task.title, task.note ?? ''));
        recoveredReminderIds.add(reminderId);
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

      // RITF-001: Logically archive reminders instead of deleting shared table records
      if (recoveredReminderIds.isNotEmpty) {
        final placeholders = List.filled(recoveredReminderIds.length, '?').join(', ');
        await db.update(
          'pending_reminders',
          {
            'state': 'RECOVERED',
            'updatedAt': nowMs,
          },
          where: 'id IN ($placeholders)',
          whereArgs: recoveredReminderIds,
        );
      }

      if (skippedReminderIds.isNotEmpty) {
        final placeholders = List.filled(skippedReminderIds.length, '?').join(', ');
        await db.update(
          'pending_reminders',
          {
            'state': 'SKIPPED',
            'updatedAt': nowMs,
          },
          where: 'id IN ($placeholders)',
          whereArgs: skippedReminderIds,
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
