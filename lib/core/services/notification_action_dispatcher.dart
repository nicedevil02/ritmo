import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/completion/snooze_policy.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/services/foreground_notification_updater.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/logic/task_snooze.dart';
import 'package:sqflite/sqflite.dart';

@pragma('vm:entry-point')
void notificationActionDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  const channel = MethodChannel('com.ritmo.app/notif_action_bg');

  channel.setMethodCallHandler((call) async {
    if (call.method == 'handleAction') {
      final args = call.arguments as Map?;
      if (args != null) {
        final action = args['action'] as String?;
        final reminderId = args['reminderId'] as String?;
        if (action != null && reminderId != null) {
          await NotificationActionHandler.handle(action, reminderId);
        }
      }
      return true;
    } else if (call.method == 'completeRoutineDirect') {
      final args = call.arguments as Map?;
      if (args != null) {
        final routineId = args['routineId'] as String?;
        final dateStr = args['dateStr'] as String?;
        if (routineId != null && dateStr != null) {
          await RitmoExecutionKernel.instance.execute(
            CompleteOccurrenceCommand(
              routineId: routineId,
              dateStr: dateStr,
              resultType: 'FULL',
              durationMinutes: 0,
            ),
          );
          await ForegroundNotificationUpdater.update();
        }
      }
      return true;
    } else if (call.method == 'snoozeRoutineDirect') {
      final args = call.arguments as Map?;
      if (args != null) {
        final routineId = args['routineId'] as String?;
        if (routineId != null && routineId.isNotEmpty) {
          final now = DateTime.now();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          await RitmoExecutionKernel.instance.execute(
            CompleteOccurrenceCommand(
              routineId: routineId,
              dateStr: dateStr,
              resultType: 'SNOOZED',
              durationMinutes: 0,
            ),
          );
          await ForegroundNotificationUpdater.update();
        }
      }
      return true;
    } else if (call.method == 'setTaskDoneDirect') {
      final args = call.arguments as Map?;
      if (args != null) {
        final taskId = args['taskId'] as String?;
        final done = args['done'] as bool? ?? true;
        if (taskId != null && taskId.isNotEmpty) {
          await SimpleTaskRepository.instance.setDone(taskId, done: done);
        }
      }
      return true;
    } else if (call.method == 'changeZoneDirect') {
      final args = call.arguments as Map?;
      if (args != null) {
        final zoneId = args['zoneId'] as String?;
        if (zoneId != null) {
          final db = await DatabaseHelper.instance.database;
          final nowMs = DateTime.now().millisecondsSinceEpoch;

          if (zoneId.isEmpty || zoneId == 'default_zone') {
            await db.insert('app_settings', {
              'key': 'realm_override_id',
              'value': '',
              'updatedAt': nowMs,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            await db.insert('app_settings', {
              'key': 'realm_override_until_ms',
              'value': '0',
              'updatedAt': nowMs,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            final untilMs = nowMs + 60 * 60 * 1000;
            await db.insert('app_settings', {
              'key': 'realm_override_id',
              'value': zoneId,
              'updatedAt': nowMs,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            await db.insert('app_settings', {
              'key': 'realm_override_until_ms',
              'value': untilMs.toString(),
              'updatedAt': nowMs,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }

          RitmoEventBus().fire(
            RitmoEvent(
              type: 'ZoneChanged',
              timestamp: DateTime.now(),
              payload: {},
            ),
          );
          RitmoEvents.notifyRoutineChanged();
          await ForegroundNotificationUpdater.update();
        }
      }
      return true;
    } else if (call.method == 'changeEnergyDirect') {
      final args = call.arguments as Map?;
      if (args != null) {
        final energy = args['energy'] as String?;
        if (energy != null) {
          final db = await DatabaseHelper.instance.database;
          final nowMs = DateTime.now().millisecondsSinceEpoch;

          await db.insert('app_settings', {
            'key': 'default_energy_level',
            'value': energy.toUpperCase(),
            'updatedAt': nowMs,
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          RitmoEventBus().fire(
            RitmoEvent(
              type: 'EnergyLogged',
              timestamp: DateTime.now(),
              payload: {},
            ),
          );
          RitmoEvents.notifyRoutineChanged();
          await ForegroundNotificationUpdater.update();
        }
      }
      return true;
    } else if (call.method == 'updatePersistentStatus') {
      await ForegroundNotificationUpdater.update();
      return true;
    }
    return false;
  });

  // Signal Kotlin side that dispatcher is registered and ready to receive calls
  channel.invokeMethod('dispatcherReady');
}

class NotificationActionHandler {
  static Future<void> handle(String action, String reminderId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch the reminder record
      final List<Map<String, dynamic>> reminders = await db.query(
        'pending_reminders',
        where: 'id = ?',
        whereArgs: [reminderId],
      );

      if (reminders.isEmpty) {
        RitmoLog.warning('NOTIF', 'Reminder not found: $reminderId');
        return;
      }

      final reminder = reminders.first;
      final routineId = reminder['routineId'] as String;
      final originalTime = reminder['originalTime'] as int;

      // Formulate dateStr from originalTime (YYYY-MM-DD)
      final date = DateTime.fromMillisecondsSinceEpoch(originalTime);
      final dateStr = date.toIso8601String().substring(0, 10);

      RitmoLog.info(
        'NOTIF',
        'Processing action $action for reminder $reminderId (routine: $routineId, date: $dateStr)',
      );

      // Check if this reminder belongs to a simple task
      final payloadJson = reminder['payloadJson'] as String?;
      String? taskId;
      if (payloadJson != null && payloadJson.isNotEmpty) {
        try {
          final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
          taskId = payload['taskId'] as String?;
        } catch (_) {}
      }

      if (taskId != null && taskId.isNotEmpty && taskId != 'nudge') {
        if (action == 'DONE') {
          await SimpleTaskRepository.instance.setDone(taskId, done: true);
          await db.delete('pending_reminders', where: 'id = ?', whereArgs: [reminderId]);
          return;
        } else if (action == 'SNOOZE' || action == 'SNOOZE_1H') {
          await snoozeTask(taskId, SnoozePreset.oneHour);
          return;
        } else if (action == 'SNOOZE_10M') {
          await snoozeTask(taskId, SnoozePreset.tenMinutes);
          return;
        } else if (action == 'SNOOZE_EVENING') {
          try {
            await snoozeTask(taskId, SnoozePreset.thisEvening);
          } catch (_) {
            await snoozeTask(taskId, SnoozePreset.tomorrowMorning);
          }
          return;
        } else if (action == 'SNOOZE_TOMORROW') {
          await snoozeTask(taskId, SnoozePreset.tomorrowMorning);
          return;
        }
      }

      // 2. Perform database actions based on action type
      switch (action) {
        case 'DONE':
          // Check if this is a real routine in routines table
          final List<Map<String, dynamic>> routines = await db.query(
            'routines',
            where: 'id = ?',
            whereArgs: [routineId],
          );

          if (routines.isNotEmpty) {
            await RitmoExecutionKernel.instance.execute(
              CompleteOccurrenceCommand(
                routineId: routineId,
                dateStr: dateStr,
                resultType: 'FULL',
                durationMinutes: 0,
              ),
            );
          } else {
            // Unregistered routine or special reminder (e.g. cycle privacy reminder)
            await db.update(
              'pending_reminders',
              {
                'state': 'opened',
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [reminderId],
            );
          }

        case 'SNOOZE':
          final deferCount = (reminder['deferCount'] as int?) ?? 0;
          final settingsRows = await db.query(
            'app_settings',
            where: "key IN ('snooze_minutes', 'snooze_max_defer_count')",
          );
          final settings = {
            for (final r in settingsRows)
              r['key'] as String: r['value'] as String,
          };
          final snoozeMins =
              int.tryParse(settings['snooze_minutes'] ?? '10') ?? 10;
          final maxDefer =
              int.tryParse(settings['snooze_max_defer_count'] ?? '0') ?? 0;
          final quotaEnabled = maxDefer > 0;

          final decision = SnoozePolicy.evaluate(
            itemId: routineId,
            now: DateTime.now(),
            requestedMinutes: snoozeMins,
            currentDeferCount: deferCount,
            configuredMax: maxDefer > 0 ? maxDefer : 3,
            quotaEnabled: quotaEnabled,
          );
          switch (decision.verdict) {
            case SnoozeVerdict.allowed:
            case SnoozeVerdict.lastCall:
              await RitmoExecutionKernel.instance.execute(
                SnoozeReminderCommand(
                  reminderId: reminderId,
                  snoozeMinutes: decision.allowedMinutes > 0
                      ? decision.allowedMinutes
                      : snoozeMins,
                  dateStr: dateStr,
                ),
              );
            case SnoozeVerdict.exhausted:
            case SnoozeVerdict.blockedMidnight:
              await _postBlockedSnoozeNotification(reminderId, decision);
          }

        case 'DISMISS':
          // Check if this is a real routine
          final List<Map<String, dynamic>> routines = await db.query(
            'routines',
            where: 'id = ?',
            whereArgs: [routineId],
          );

          if (routines.isNotEmpty) {
            await RitmoExecutionKernel.instance.execute(
              SkipOccurrenceCommand(
                routineId: routineId,
                dateStr: dateStr,
                reason: 'Dismissed from notification',
              ),
            );
          } else {
            await db.update(
              'pending_reminders',
              {
                'state': 'opened',
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ?',
              whereArgs: [reminderId],
            );
          }

        default:
          RitmoLog.warning('NOTIF', 'Unknown action: $action');
      }

      // Re-trigger alarm synchronization to dismiss or reschedule alarms
      await AlarmSchedulerService.scheduleNextAlarms();
    } catch (e, stacktrace) {
      RitmoLog.error('NOTIF', 'Error handling action $action', e, stacktrace);
    }
  }

  static Future<void> _postBlockedSnoozeNotification(
    String reminderId,
    SnoozeDecision decision,
  ) async {
    RitmoLog.warning(
      'NOTIF',
      'Snooze blocked for $reminderId: ${decision.verdict.name} (${decision.userMessage})',
    );
  }
}
