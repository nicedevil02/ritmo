import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';

class MissedReminderRecovery {
  static Future<int> recoverMissedReminders({DateTime? nowOverride}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = nowOverride ?? DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // RITF-001 & RITF-062: Only recover active pending reminders belonging to the tasks module with safe batch limit
      final rows = await db.query(
        'pending_reminders',
        where: "scheduledTime <= ? AND state IN ('SCHEDULED', 'pending') AND (ownerModule = 'tasks' OR ownerModule IS NULL)",
        whereArgs: [nowMs],
        limit: 50,
      );

      if (rows.isEmpty) return 0;

      // Extract all valid task IDs for batch retrieval (RITF-062)
      final reminderTaskPairs = <(String reminderId, String taskId)>[];
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

        reminderTaskPairs.add((reminderId, taskId));
      }

      final taskIds = reminderTaskPairs.map((p) => p.$2).toSet().toList();
      final tasksMap = <String, SimpleTask>{};

      if (taskIds.isNotEmpty) {
        final placeholders = List.filled(taskIds.length, '?').join(', ');
        final taskRows = await db.query(
          'simple_tasks',
          where: 'id IN ($placeholders)',
          whereArgs: taskIds,
        );
        for (final tr in taskRows) {
          final t = SimpleTask.fromMap(tr);
          tasksMap[t.id] = t;
        }
      }

      final activeMissedTasks = <(String reminderId, String taskId, String title, String body, bool isPrivate)>[];
      final recoveredReminderIds = <String>[];

      for (final pair in reminderTaskPairs) {
        final task = tasksMap[pair.$2];
        if (task == null || task.isDone) {
          skippedReminderIds.add(pair.$1);
          continue;
        }

        final isPrivate = task.isImportant || task.tags.any((t) => t == 'محرمانه' || t == 'شخصی' || t == 'private');
        final bodyText = isPrivate ? 'یک کار شخصی' : (task.note ?? '');

        activeMissedTasks.add((pair.$1, pair.$2, task.title, bodyText, isPrivate));
        recoveredReminderIds.add(pair.$1);
      }

      final missedCount = activeMissedTasks.length;
      final scheduleTarget = now.add(const Duration(seconds: 2));

      if (missedCount > 3) {
        // RITF-060 & RITF-061: Idempotent daily summary notification + slight offset
        final dayKey = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
        await NotificationGateway.schedule(
          NotificationRequest(
            id: 'missed_tasks_summary_$dayKey',
            channel: NotificationChannelId.planning,
            scheduledAt: scheduleTarget,
            title: 'یادآور کارهای گذشته',
            body: '${PersianDigits.toPersian(missedCount)} یادآور را ندیدی',
            sourceSystem: 'tasks',
            entityId: 'missed_summary',
          ),
        );
      } else {
        // RITF-061 & RITF-063: Dispatch individual notifications with privacy protection
        for (final item in activeMissedTasks) {
          await NotificationGateway.schedule(
            NotificationRequest(
              id: 'missed_${item.$1}',
              channel: NotificationChannelId.planning,
              scheduledAt: scheduleTarget,
              title: item.$5 ? 'ریتمو: یادآور کار' : 'یادآور کار: ${item.$3}',
              body: item.$4,
              privacy: item.$5 ? NotificationPrivacy.redacted : NotificationPrivacy.none,
              redactedTitle: 'ریتمو: یادآور کار',
              redactedBody: 'یک یادآور کار داری',
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
