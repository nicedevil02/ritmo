import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/progression_engine.dart';
import 'package:ritmo/core/domain/engines/routine_occurrence_generator.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/reminder_state.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/central_inbox_service.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/simple_tasks/logic/daily_planning_nudge.dart';
import 'package:ritmo/features/simple_tasks/logic/missed_reminder_recovery.dart';
import 'package:sqflite/sqflite.dart';

class AlarmSchedulerService {
  static Future<void> _cancelAlarmSafely(String id) async {
    try {
      if (sl.isRegistered<AlarmPlatform>()) {
        await sl<AlarmPlatform>().cancelAlarm(id);
      }
    } catch (_) {}
  }

  static NotificationChannelId _channelForCategory(String? category) {
    final cat = (category ?? '').toLowerCase();
    if (cat == 'medical' || cat == 'health') {
      return NotificationChannelId.critical;
    }
    if (cat == 'religious' || cat == 'worship') {
      return NotificationChannelId.worship;
    }
    return NotificationChannelId.routine;
  }

  /// Scans all active routine schedules and schedules the next occurrences (next 24h-48h).
  /// Reconciles with AlarmManager via NativeBridge.
  static Future<void> scheduleNextAlarms() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    final settingsList = await db.query('app_settings');
    final settingsMap = {
      for (final s in settingsList) s['key']! as String: s['value']! as String,
    };

    final masterEnabled = settingsMap['notif_master_enabled'] != 'false';
    if (!masterEnabled) {
      // Actively cancel native scheduled alarms
      final scheduledReminders = await db.query(
        'pending_reminders',
        where: 'nativeScheduled = 1',
      );
      for (final r in scheduledReminders) {
        final id = r['id'] as String;
        await _cancelAlarmSafely(id);
      }
      await db.update('pending_reminders', {
        'nativeScheduled': 0,
        'updatedAt': nowMs,
      }, where: 'nativeScheduled = 1');
      await sweepMissedAlarms();
      await SnapshotSyncService.syncAll();
      return;
    }

    final quietEnabled = settingsMap['notif_quiet_enabled'] == 'true';
    final quietStart = settingsMap['notif_quiet_start'] ?? '00:00';
    final quietEnd = settingsMap['notif_quiet_end'] ?? '07:00';

    await sweepMissedAlarms();

    // Load active routines, schedules, and medication clinical profiles
    final routines = await db.query('routines', where: 'isArchived = 0');
    final schedules = await db.query('routine_schedules', orderBy: 'id ASC');
    final profiles = await db.query('medication_profiles');
    final profilesMap = <String, Map<String, dynamic>>{
      for (final p in profiles)
        if (p['routineId'] != null) p['routineId']! as String: p,
    };

    // Fetch calendar exceptions and routines map
    final exceptions = await db.query('calendar_exceptions');
    final exceptionsMap = {
      for (final e in exceptions)
        e['date']! as String: e['behavior']! as String,
    };
    final routinesMap = {for (final r in routines) r['id']! as String: r};

    // Clean up existing alarms that conflict with exceptions
    final pending = await db.query(
      'pending_reminders',
      where: "state = 'unknown' OR state = 'delayed'",
    );

    for (final pMap in pending) {
      final id = pMap['id']! as String;
      final routineId = pMap['routineId']! as String;
      final scheduledTimeMs = pMap['scheduledTime']! as int;
      final scheduledDate = DateTime.fromMillisecondsSinceEpoch(
        scheduledTimeMs,
      );
      final dateStr = scheduledDate.toIso8601String().substring(0, 10);

      final behavior = exceptionsMap[dateStr] ?? 'NORMAL';
      final r = routinesMap[routineId];
      final isEssential = r != null && r['isEssential'] == 1;

      if (behavior == 'SILENCE_ALL' ||
          (behavior == 'ESSENTIAL_ONLY' && !isEssential)) {
        // Cancel physical alarm
        await _cancelAlarmSafely(id);
        // Mark as CANCELLED in db
        await db.update(
          'pending_reminders',
          {'state': 'CANCELLED', 'updatedAt': nowMs},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    // Batch prefetch to eliminate N+1 queries across date/routine loops
    final allPendingReminders = await db.query('pending_reminders');
    final pendingRemindersMap = {
      for (final r in allPendingReminders) r['id'] as String: r,
    };
    final allMedicationLogs = await db.query('medication_logs');
    final medicationLogsSet = {
      for (final l in allMedicationLogs)
        '${l['routineId']}_${l['scheduledTime']}',
    };

    // Schedule next reminders for today and tomorrow (supports multi-dose routines)
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dates = [today, tomorrow];

    for (final targetDate in dates) {
      final dateStr = targetDate.toIso8601String().substring(0, 10);
      final year = targetDate.year;
      final month = targetDate.month;
      final day = targetDate.day;
      final targetDateMs = targetDate.millisecondsSinceEpoch;

      for (final r in routines) {
        final rId = r['id']! as String;
        final title = r['title']! as String;
        final isEssential = r['isEssential'] == 1;
        final isPrivate = r['isPrivate'] == 1;
        final categoryStr = r['category'] as String? ?? '';
        final isMedical = categoryStr == 'medical' || categoryStr == 'health';

        // بررسی پایان دوره مصرف برای داروهای غیرمزمن (Fixes #4)
        if (isMedical) {
          final prof = profilesMap[rId];
          if (prof != null) {
            final isChronic = prof['isChronic'] == 1 || prof['isChronic'] == true;
            if (!isChronic) {
              final endDate = (prof['endDate'] as num?)?.toInt();
              if (endDate != null && targetDateMs > endDate) {
                continue;
              }
              final startDate = (prof['startDate'] as num?)?.toInt();
              final durationDays = (prof['durationDays'] as num?)?.toInt();
              if (startDate != null && durationDays != null && durationDays > 0) {
                final courseEndMs = startDate + (durationDays * 24 * 60 * 60 * 1000);
                if (targetDateMs > courseEndMs) {
                  continue;
                }
              }
            }
          }
        }

        final sched = schedules.firstWhere(
          (s) => s['routineId'] == rId,
          orElse: () => <String, dynamic>{},
        );
        if (sched.isEmpty) continue;
        final scheduleId = sched['id']! as String;

        // Parse RecurrenceRule
        RecurrenceRule rule;
        final ruleStr = sched['recurrenceRule'] as String?;
        if (ruleStr != null && ruleStr.isNotEmpty) {
          try {
            rule = RecurrenceRule.fromMap(
              jsonDecode(ruleStr) as Map<String, dynamic>,
            );
          } catch (_) {
            rule = RecurrenceRule(
              weekdays: const [6, 7, 1, 2, 3, 4, 5],
              reminderTimes: sched['timeOfDay'] != null
                  ? [sched['timeOfDay'] as String]
                  : const <String>[],
            );
          }
        } else {
          final daysStr = sched['daysOfWeek'] as String? ?? '6,7,1,2,3,4,5';
          final days = daysStr
              .split(',')
              .map((d) => int.tryParse(d.trim()))
              .whereType<int>()
              .toList();
          rule = RecurrenceRule(
            weekdays: days,
            reminderTimes: sched['timeOfDay'] != null
                ? [sched['timeOfDay'] as String]
                : const <String>[],
          );
        }

        // Check if routine occurs on this date
        if (!RoutineOccurrenceGenerator.shouldOccurOnDate(targetDate, rule)) {
          continue;
        }

        // Extract all reminder times (multi-dose support, no speculative 08:00 times)
        final times = rule.reminderTimes.isNotEmpty
            ? rule.reminderTimes
            : (sched['timeOfDay'] != null
                  ? [sched['timeOfDay'] as String]
                  : const <String>[]);
        if (times.isEmpty) continue;

        for (final rawTime in times) {
          final timeStr = rawTime.trim();
          final timeParts = timeStr.split(':');
          final hour = int.tryParse(timeParts[0]);
          final minute = int.tryParse(timeParts[1]);
          if (hour == null || minute == null) continue;

          final reminderOffset = r['reminderOffsetMinutes'] as int? ?? 0;
          final targetTime = DateTime(year, month, day, hour, minute);
          var scheduledMs = targetTime
              .subtract(Duration(minutes: reminderOffset))
              .millisecondsSinceEpoch;

          final reminderId =
              'rem_${rId}_${scheduleId}_${dateStr}_${timeStr.replaceAll(':', '')}';

          // Check if already completed / logged for this slot
          if (isMedical &&
              medicationLogsSet.contains(
                '${rId}_${targetTime.millisecondsSinceEpoch}',
              )) {
            continue;
          }

          // Check existing reminder in pending_reminders
          final existingReminder = pendingRemindersMap[reminderId];

          if (existingReminder != null) {
            final remState = existingReminder['state']! as String;
            final snoozeTime = existingReminder['snoozeUntil'] as int?;

            if (remState == 'delayed' && snoozeTime != null) {
              if (snoozeTime > nowMs) {
                scheduledMs = snoozeTime;
                final channel = _channelForCategory(categoryStr);
                final ok = await NotificationGateway.schedule(
                  NotificationRequest(
                    id: reminderId,
                    channel: channel,
                    scheduledAt: DateTime.fromMillisecondsSinceEpoch(
                      scheduledMs,
                    ),
                    title: isPrivate ? '🔒 یادآوری محرمانه' : title,
                    privacy: isPrivate
                        ? NotificationPrivacy.locked
                        : (isEssential
                              ? NotificationPrivacy.redacted
                              : NotificationPrivacy.none),
                    redactedTitle: isPrivate
                        ? '🔒 یادآوری محرمانه'
                        : (isEssential
                              ? (isMedical
                                    ? 'ریتمو: زمان مصرف دارو 🌸'
                                    : 'ریتمو: یک یادآوری روتین دارید 🌸')
                              : null),
                    redactedBody: isPrivate
                        ? 'جهت مشاهده جزئیات ضربه بزنید و هویت خود را تأیید کنید.'
                        : null,
                    sourceSystem: 'routines',
                    entityId: rId,
                  ),
                );
                await db.update(
                  'pending_reminders',
                  {'nativeScheduled': ok ? 1 : 0},
                  where: 'id = ?',
                  whereArgs: [reminderId],
                );
              } else {
                await db.update(
                  'pending_reminders',
                  {'state': 'unknown'},
                  where: 'id = ?',
                  whereArgs: [reminderId],
                );
              }
            } else if (remState == 'completed' || remState == 'CANCELLED') {
              continue;
            }
            continue;
          }

          if (scheduledMs <= nowMs) {
            // In the past
            continue;
          }

          // Apply calendar behavior filter
          final behavior = exceptionsMap[dateStr] ?? 'NORMAL';
          if (behavior == 'SILENCE_ALL' ||
              (behavior == 'ESSENTIAL_ONLY' && !isEssential)) {
            continue;
          }

          // Check quiet hours: if routine is not essential and not medical/health, postpone after quiet hours
          if (quietEnabled && !isEssential && !isMedical) {
            final schedDateTime = DateTime.fromMillisecondsSinceEpoch(
              scheduledMs,
            );
            if (isTimeInQuietHours(schedDateTime, quietStart, quietEnd)) {
              final adjustedTime = adjustTimeForQuietHours(
                schedDateTime,
                quietEnd,
              );
              scheduledMs = adjustedTime.millisecondsSinceEpoch;
            }
          }

          // Register physical Alarm with NotificationGateway
          final channel = _channelForCategory(categoryStr);
          final ok = await NotificationGateway.schedule(
            NotificationRequest(
              id: reminderId,
              channel: channel,
              scheduledAt: DateTime.fromMillisecondsSinceEpoch(scheduledMs),
              title: isPrivate ? '🔒 یادآوری محرمانه' : title,
              privacy: isPrivate
                  ? NotificationPrivacy.locked
                  : (isEssential
                        ? NotificationPrivacy.redacted
                        : NotificationPrivacy.none),
              redactedTitle: isPrivate
                  ? '🔒 یادآوری محرمانه'
                  : (isEssential
                        ? (isMedical
                              ? 'ریتمو: زمان مصرف دارو 🌸'
                              : 'ریتمو: یک یادآوری روتین دارید 🌸')
                        : null),
              redactedBody: isPrivate
                  ? 'جهت مشاهده جزئیات ضربه بزنید و هویت خود را تأیید کنید.'
                  : null,
              sourceSystem: 'routines',
              entityId: rId,
            ),
          );

          // Insert new reminder with 'unknown' state
          await db.insert('pending_reminders', {
            'id': reminderId,
            'routineId': rId,
            'scheduleId': scheduleId,
            'originalTime': targetTime.millisecondsSinceEpoch,
            'scheduledTime': scheduledMs,
            'state': 'unknown',
            'deferCount': 0,
            'nativeScheduled': ok ? 1 : 0,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          await DatabaseHelper.instance.logNotificationEvent(
            routineId: rId,
            actionTaken: 'sent',
            notificationType: isMedical ? 'MEDICINE' : 'ROUTINE',
          );
        }
      }
    }

    // Schedule private cycle reminders if gender is FEMALE and consent is granted
    final cycleConsentReminders =
        settingsMap['cycle_consent_reminders'] == 'true';
    final cycleModuleEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_cycle_enabled',
    );
    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);

    if (isFemale && cycleModuleEnabled && cycleConsentReminders) {
      final periods = await db.query(
        'cycle_periods',
        orderBy: 'startDate DESC',
        limit: 1,
      );
      if (periods.isNotEmpty) {
        final latestPeriod = periods.first;
        final start = DateTime.parse(latestPeriod['startDate']! as String);
        final cycleLength = math.max(
          10,
          int.tryParse(settingsMap['cycle_avg_length'] ?? '28') ?? 28,
        );
        final daysSinceStart = now.difference(start).inDays;
        final cyclesElapsed = (daysSinceStart / cycleLength).floor() + 1;
        final nextPeriodStart = start.add(
          Duration(days: cyclesElapsed * cycleLength),
        );

        final offsets = [-7, -3, -1, 0];
        for (final offset in offsets) {
          final reminderTime = DateTime(
            nextPeriodStart.year,
            nextPeriodStart.month,
            nextPeriodStart.day,
            9, // 9:00 AM
          ).add(Duration(days: offset));
          final reminderMs = reminderTime.millisecondsSinceEpoch;

          // Only schedule if in future and within next 48 hours
          if (reminderMs > nowMs && reminderMs < nowMs + 48 * 3600 * 1000) {
            final reminderId =
                'cycle_rem_${nextPeriodStart.toIso8601String().substring(0, 10)}_$offset';

            final existing = await db.query(
              'pending_reminders',
              where: 'id = ?',
              whereArgs: [reminderId],
            );

            if (existing.isEmpty) {
              await db.insert('pending_reminders', {
                'id': reminderId,
                'routineId': 'cycle_private_reminder',
                'scheduleId': 'cycle_schedule',
                'originalTime': reminderMs,
                'scheduledTime': reminderMs,
                'state': 'unknown',
                'deferCount': 0,
                'createdAt': nowMs,
                'updatedAt': nowMs,
              });

              await NotificationGateway.schedule(
                NotificationRequest(
                  id: reminderId,
                  channel: NotificationChannelId.privateChannel,
                  scheduledAt: DateTime.fromMillisecondsSinceEpoch(reminderMs),
                  title: 'یک یادداشت خصوصی برایت آماده است',
                  privacy: NotificationPrivacy.redacted,
                  redactedTitle: 'ریتمو: یادآوری روزانه 🌸',
                  redactedBody: 'برای مشاهده باز کنید',
                  sourceSystem: 'cycle',
                  entityId: 'cycle_private_reminder',
                ),
              );

              await DatabaseHelper.instance.logNotificationEvent(
                routineId: 'cycle_private_reminder',
                actionTaken: 'sent',
                notificationType: 'CYCLE',
              );
            }
          }
        }
      }
    }

    // Simple Tasks: Daily planning nudge & missed reminder recovery
    await DailyPlanningNudge.syncNudgeSchedule();
    await MissedReminderRecovery.recoverMissedReminders();

    // Finally, update shared snapshot
    await SnapshotSyncService.syncAll();
  }

  /// Completes an occurrence, saves to completions, updates occurrence, cancels alarm
  static Future<void> completeOccurrence(
    String routineId,
    String dateStr, {
    String resultType = 'FULL',
    int? durationMinutes,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final alarmsToCancel = <String>[];

    await db.transaction((txn) async {
      // 1. Insert or Update completion (upsert check)
      final scheduleList = await txn.query(
        'routine_schedules',
        where: 'routineId = ?',
        whereArgs: [routineId],
        limit: 1,
      );
      final isInterval =
          scheduleList.isNotEmpty &&
          (scheduleList.first['intervalHours'] as int? ?? 0) > 0;

      var shouldInsert = true;
      if (!isInterval) {
        final existing = await txn.query(
          'routine_completions',
          where: 'routineId = ? AND completionDate = ?',
          whereArgs: [routineId, dateStr],
        );

        if (existing.isNotEmpty) {
          shouldInsert = false;
          await txn.update(
            'routine_completions',
            {
              'completionTime': now,
              'resultType': resultType,
              'durationMinutes': durationMinutes,
              'actual_duration_minutes': durationMinutes,
              'createdAt': now,
            },
            where: 'routineId = ? AND completionDate = ?',
            whereArgs: [routineId, dateStr],
          );
        }
      }

      if (shouldInsert) {
        await txn.insert('routine_completions', {
          'id': 'comp_${routineId}_$now',
          'routineId': routineId,
          'completionDate': dateStr,
          'completionTime': now,
          'resultType': resultType,
          'resultSource': 'USER',
          'durationMinutes': durationMinutes,
          'actual_duration_minutes': durationMinutes,
          'createdAt': now,
        });
      }

      // Invoke progression engine logic on successful completion
      await ProgressionEngine().onCompletion(txn, routineId);

      // 2. Update occurrence status
      await txn.update(
        'routine_occurrences',
        {'status': 'done'},
        where: 'routine_id = ? AND date = ?',
        whereArgs: [routineId, dateStr],
      );

      // 3. Update pending_reminders state to 'opened'
      final dateDateTime = DateTime.parse(dateStr);
      final startOfDay = DateTime(
        dateDateTime.year,
        dateDateTime.month,
        dateDateTime.day,
      ).millisecondsSinceEpoch;
      final endOfDay = DateTime(
        dateDateTime.year,
        dateDateTime.month,
        dateDateTime.day,
        23,
        59,
        59,
      ).millisecondsSinceEpoch;

      final reminders = await txn.query(
        'pending_reminders',
        where:
            'routineId = ? AND (state = ? OR state = ? OR state = ?) AND scheduledTime >= ? AND scheduledTime <= ?',
        whereArgs: [
          routineId,
          'unknown',
          'delayed',
          'sent',
          startOfDay,
          endOfDay,
        ],
      );

      for (final rem in reminders) {
        final remId = rem['id']! as String;
        alarmsToCancel.add(remId);
        await txn.update(
          'pending_reminders',
          {'state': 'opened', 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [remId],
        );
      }

      await DatabaseHelper.instance.logNotificationEvent(
        routineId: routineId,
        actionTaken: 'opened',
        notificationType: 'ROUTINE',
        executor: txn,
      );

      await CentralInboxService.markActionedForEntity(
        'routines',
        routineId,
        executor: txn,
      );
    });

    // Run native cancel alarms outside the transaction
    for (final remId in alarmsToCancel) {
      await _cancelAlarmSafely(remId);
    }

    // Run syncAll outside the transaction
    await SnapshotSyncService.syncAll();

    // Invalidate the agenda cache for the target date so the UI refreshes correctly
    DayAgendaService.instance.invalidateDate(dateStr);
  }

  /// Reverts a routine occurrence completion back to 'pending', deletes completion record, and restores alarms.
  static Future<void> undoCompletion(String routineId, String dateStr) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // 1. Delete completion record
      await txn.delete(
        'routine_completions',
        where: 'routineId = ? AND completionDate = ?',
        whereArgs: [routineId, dateStr],
      );

      // 2. Revert occurrence status to 'pending'
      await txn.update(
        'routine_occurrences',
        {'status': 'pending'},
        where: 'routine_id = ? AND date = ?',
        whereArgs: [routineId, dateStr],
      );

      // 3. Revert reminders today back to 'unknown' if they were 'opened'
      final dateDateTime = DateTime.parse(dateStr);
      final startOfDay = DateTime(
        dateDateTime.year,
        dateDateTime.month,
        dateDateTime.day,
      ).millisecondsSinceEpoch;
      final endOfDay = DateTime(
        dateDateTime.year,
        dateDateTime.month,
        dateDateTime.day,
        23,
        59,
        59,
      ).millisecondsSinceEpoch;

      await txn.update(
        'pending_reminders',
        {'state': 'unknown', 'updatedAt': now},
        where:
            'routineId = ? AND state = ? AND scheduledTime >= ? AND scheduledTime <= ?',
        whereArgs: [routineId, 'opened', startOfDay, endOfDay],
      );
    });

    // Run syncAll and reschedule alarms immediately
    await SnapshotSyncService.syncAll();
    await scheduleNextAlarms();

    // Invalidate the agenda cache for the target date so the UI refreshes correctly
    DayAgendaService.instance.invalidateDate(dateStr);
  }

  /// Skips an occurrence, updates occurrence status to skipped, cancels alarm
  static Future<void> skipOccurrence(String routineId, String dateStr) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final alarmsToCancel = <String>[];

    await db.transaction((txn) async {
      // 1. Insert skip into completions (upsert check)
      final existing = await txn.query(
        'routine_completions',
        where: 'routineId = ? AND completionDate = ?',
        whereArgs: [routineId, dateStr],
      );

      if (existing.isNotEmpty) {
        await txn.update(
          'routine_completions',
          {'completionTime': now, 'resultType': 'SKIPPED', 'createdAt': now},
          where: 'routineId = ? AND completionDate = ?',
          whereArgs: [routineId, dateStr],
        );
      } else {
        await txn.insert('routine_completions', {
          'id': 'comp_${routineId}_$now',
          'routineId': routineId,
          'completionDate': dateStr,
          'completionTime': now,
          'resultType': 'SKIPPED',
          'resultSource': 'USER',
          'createdAt': now,
        });
      }

      // 2. Update occurrence status
      await txn.update(
        'routine_occurrences',
        {'status': 'skipped'},
        where: 'routine_id = ? AND date = ?',
        whereArgs: [routineId, dateStr],
      );

      // 3. Update pending_reminders state to 'opened'
      final dateDateTime = DateTime.parse(dateStr);
      final startOfDay = DateTime(
        dateDateTime.year,
        dateDateTime.month,
        dateDateTime.day,
      ).millisecondsSinceEpoch;
      final endOfDay = DateTime(
        dateDateTime.year,
        dateDateTime.month,
        dateDateTime.day,
        23,
        59,
        59,
      ).millisecondsSinceEpoch;

      final reminders = await txn.query(
        'pending_reminders',
        where:
            'routineId = ? AND (state = ? OR state = ? OR state = ?) AND scheduledTime >= ? AND scheduledTime <= ?',
        whereArgs: [
          routineId,
          'unknown',
          'delayed',
          'sent',
          startOfDay,
          endOfDay,
        ],
      );

      for (final rem in reminders) {
        final remId = rem['id']! as String;
        alarmsToCancel.add(remId);
        await txn.update(
          'pending_reminders',
          {'state': 'skipped', 'updatedAt': now},
          where: 'id = ?',
          whereArgs: [remId],
        );
      }

      await DatabaseHelper.instance.logNotificationEvent(
        routineId: routineId,
        actionTaken: 'skipped',
        notificationType: 'ROUTINE',
        executor: txn,
      );

      await CentralInboxService.markActionedForEntity(
        'routines',
        routineId,
        executor: txn,
      );
    });

    // Run native cancel alarms outside the transaction
    for (final remId in alarmsToCancel) {
      await _cancelAlarmSafely(remId);
    }

    await SnapshotSyncService.syncAll();
  }

  /// Triggered when a routine completion is logged.
  /// Handles interval-based schedules by setting the next alarm.
  static Future<void> onRoutineCompleted(
    String routineId,
    DateTime completionTime,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    // Load active routine schedules
    final schedules = await db.query(
      'routine_schedules',
      where: 'routineId = ? AND scheduleType = ?',
      whereArgs: [routineId, 'INTERVAL'],
    );

    if (schedules.isNotEmpty) {
      final sMap = schedules.first;
      final scheduleId = sMap['id']! as String;
      final intervalHours = sMap['intervalHours'] as int? ?? 4;

      final nextAlarmTime = completionTime.add(Duration(hours: intervalHours));
      final nextAlarmMs = nextAlarmTime.millisecondsSinceEpoch;

      final routineRes = await db.query(
        'routines',
        where: 'id = ?',
        whereArgs: [routineId],
        limit: 1,
      );
      if (routineRes.isNotEmpty) {
        final title = routineRes.first['title']! as String;
        final isEssential = routineRes.first['isEssential'] == 1;

        final reminderId = 'rem_${routineId}_${scheduleId}_$nextAlarmMs';

        await db.insert('pending_reminders', {
          'id': reminderId,
          'routineId': routineId,
          'scheduleId': scheduleId,
          'originalTime': nextAlarmMs,
          'scheduledTime': nextAlarmMs,
          'state': 'unknown',
          'deferCount': 0,
          'createdAt': nowMs,
          'updatedAt': nowMs,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        // Register exact alarm via NotificationGateway
        final channel = _channelForCategory(
          routineRes.first['category'] as String?,
        );
        await NotificationGateway.schedule(
          NotificationRequest(
            id: reminderId,
            channel: channel,
            scheduledAt: DateTime.fromMillisecondsSinceEpoch(nextAlarmMs),
            title: title,
            privacy: isEssential
                ? NotificationPrivacy.redacted
                : NotificationPrivacy.none,
            redactedTitle: isEssential
                ? 'ریتمو: یک یادآوری روتین دارید 🌸'
                : null,
            sourceSystem: 'routines',
            entityId: routineId,
          ),
        );
        await DatabaseHelper.instance.logNotificationEvent(
          routineId: routineId,
          actionTaken: 'sent',
          notificationType: 'ROUTINE',
        );
      }
    }

    // Schedule persistent status notification update alarms for midnight and zone changes
    await _scheduleStatusUpdateAlarms(db, DateTime.now());

    // Sync state
    await SnapshotSyncService.syncAll();
  }

  static Future<void> _scheduleStatusUpdateAlarms(
    Database db,
    DateTime now,
  ) async {
    // 1. Midnight update silent tick
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    await sl<AlarmPlatform>().scheduleSilentTick(
      id: 'status_update_midnight',
      timeMsUTC: nextMidnight.millisecondsSinceEpoch,
    );

    // 2. Zone schedules transitions silent tick
    try {
      final zoneSchedules = await db.query('zone_schedules');
      final todayStr = now.toIso8601String().substring(0, 10);
      final tomorrowStr = now
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);

      final transitionTimesMs = <int>{};

      for (final sched in zoneSchedules) {
        final start = sched['startTime'] as String? ?? '09:00';
        final end = sched['endTime'] as String? ?? '17:00';

        for (final dateStr in [todayStr, tomorrowStr]) {
          for (final timeStr in [start, end]) {
            final parts = timeStr.split(':');
            if (parts.length == 2) {
              final h = int.tryParse(parts[0]) ?? 0;
              final m = int.tryParse(parts[1]) ?? 0;
              final dateParts = dateStr.split('-');
              final dt = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
                h,
                m,
              );
              if (dt.isAfter(now)) {
                transitionTimesMs.add(dt.millisecondsSinceEpoch);
              }
            }
          }
        }
      }

      final sortedTimes = transitionTimesMs.toList()..sort();
      final timesToSchedule = sortedTimes.take(5);

      var idx = 0;
      for (final timeMs in timesToSchedule) {
        await sl<AlarmPlatform>().scheduleSilentTick(
          id: 'status_update_zone_${idx++}',
          timeMsUTC: timeMs,
        );
      }
    } catch (e) {
      debugPrint('Error scheduling zone transition status updates: $e');
    }
  }

  /// Cancels all alarms for a given routine.
  static Future<void> cancelAllAlarmsForRoutine(String routineId) async {
    await NotificationGateway.cancelForEntity('routines', routineId);
    await SnapshotSyncService.syncAll();
  }

  static Future<void> cancel(String id) async {
    await NotificationGateway.cancel(id);
  }

  /// Sweeps reminders whose scheduledTime has passed but were never fired.
  static Future<List<Map<String, Object?>>> sweepMissedAlarms() async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final pending = await db.query(
      'pending_reminders',
      where:
          "scheduledTime < ? AND state IN ('unknown', 'delayed', 'SCHEDULED', 'active', 'scheduled')",
      whereArgs: [nowMs],
    );

    final missedReminders = <Map<String, Object?>>[];

    for (final row in pending) {
      final remId = row['id']! as String;
      final routineId = row['routineId'] as String?;
      final originalTime = row['originalTime'] as int?;
      final scheduledTime = row['scheduledTime']! as int;

      if (routineId != null && originalTime != null) {
        final dateStr = DateTime.fromMillisecondsSinceEpoch(
          originalTime,
        ).toIso8601String().substring(0, 10);
        final occurrences = await db.query(
          'routine_occurrences',
          where: 'routine_id = ? AND date = ?',
          whereArgs: [routineId, dateStr],
        );
        if (occurrences.isNotEmpty) {
          final occStatus = occurrences.first['status'] as String?;
          if (occStatus == 'done' || occStatus == 'skipped') {
            // Occurrence is completed/skipped, not missed
            continue;
          }
        }
      }

      missedReminders.add(row);

      final logId = 'missed_$remId';
      await db.insert('alarm_delivery_log', {
        'id': logId,
        'reminderId': remId,
        'routineId': routineId,
        'expectedAt': scheduledTime,
        'firedAt': null,
        'outcome': 'missed',
        'createdAt': nowMs,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      await db.update(
        'pending_reminders',
        {'state': ReminderState.missed.dbValue, 'updatedAt': nowMs},
        where: 'id = ?',
        whereArgs: [remId],
      );
    }

    return missedReminders;
  }

  static bool isTimeInQuietHours(
    DateTime time,
    String startStr,
    String endStr,
  ) {
    final startParts = startStr.split(':');
    final endParts = endStr.split(':');
    final startH = int.tryParse(startParts[0]) ?? 0;
    final startM = int.tryParse(startParts[1]) ?? 0;
    final endH = int.tryParse(endParts[0]) ?? 7;
    final endM = int.tryParse(endParts[1]) ?? 0;

    final timeMin = time.hour * 60 + time.minute;
    final startMin = startH * 60 + startM;
    final endMin = endH * 60 + endM;

    if (startMin == endMin) {
      return false;
    }

    if (startMin < endMin) {
      // Daytime quiet hours e.g. 13:00 to 15:00
      return timeMin >= startMin && timeMin < endMin;
    } else {
      // Overnight quiet hours e.g. 23:00 to 07:00
      return timeMin >= startMin || timeMin < endMin;
    }
  }

  static DateTime adjustTimeForQuietHours(DateTime time, String endStr) {
    final endParts = endStr.split(':');
    final endH = int.tryParse(endParts[0]) ?? 7;
    final endM = int.tryParse(endParts[1]) ?? 0;

    var adjusted = DateTime(time.year, time.month, time.day, endH, endM);
    if (!adjusted.isAfter(time)) {
      adjusted = adjusted.add(const Duration(days: 1));
    }
    return adjusted;
  }
}
