import 'dart:convert';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:ritmo/core/domain/models/reminder_state.dart';
import 'package:ritmo/core/services/central_inbox_service.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/ritmo_date.dart';
import 'package:ritmo/features/worship/logic/prayer_reminder_scheduler.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/logic/worship_repository.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// EndOfDaySweep sweeps stale pending/snoozed occurrences past midnight and converts them to 'missed'.
class EndOfDaySweep {
  EndOfDaySweep._();

  static Future<int> runSweep(Database db, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayStr = RitmoDate(today).value;
    final yesterdayDate = today.subtract(const Duration(days: 1));

    var sweptCount = 0;

    try {
      final staleRows = await db.rawQuery(
        '''
        SELECT o.routine_id, o.date, r.isEssential, r.category
        FROM routine_occurrences o
        LEFT JOIN routines r ON o.routine_id = r.id
        WHERE o.status IN ('pending', 'snoozed') AND o.date < ?
      ''',
        [todayStr],
      );

      // Determine multi-day worship sweep range (RIT-014)
      final lastSweepRows = await db.query(
        'app_settings',
        where: "key = 'last_worship_sweep_date'",
      );
      final lastSweepStr =
          lastSweepRows.isNotEmpty ? lastSweepRows.first['value'] as String? : null;

      DateTime startDateToSweep;
      if (lastSweepStr != null && lastSweepStr.isNotEmpty) {
        final parsed = DateKey.parse(lastSweepStr);
        if (parsed != null) {
          startDateToSweep = parsed.add(const Duration(days: 1));
        } else {
          startDateToSweep = yesterdayDate;
        }
      } else {
        startDateToSweep = yesterdayDate;
      }

      // Cap back-sweep window to at most 60 days
      final earliestAllowed = today.subtract(const Duration(days: 60));
      if (startDateToSweep.isBefore(earliestAllowed)) {
        startDateToSweep = earliestAllowed;
      }

      final sweepDates = <DateTime>[];
      var curDate = DateTime(
        startDateToSweep.year,
        startDateToSweep.month,
        startDateToSweep.day,
      );
      final endTarget = DateTime(
        yesterdayDate.year,
        yesterdayDate.month,
        yesterdayDate.day,
      );

      while (!curDate.isAfter(endTarget)) {
        sweepDates.add(curDate);
        curDate = curDate.add(const Duration(days: 1));
      }

      // Pre-fetch worship context for each sweep date outside transaction (BOOT-DEADLOCK, RIT-016)
      final suspended = await CycleConsentBridge.isWorshipSuspended();
      final dayContexts = <String, WorshipDayContext>{};
      for (final d in sweepDates) {
        final dStr = RitmoDate(d).value;
        dayContexts[dStr] = await WorshipEngine.instance.dayContext(d);
      }

      // Pre-fetch sports session state from SharedPreferences outside transaction (RIT-016)
      SharedPreferences? prefs;
      Map<String, dynamic>? sportsState;
      try {
        prefs = await SharedPreferences.getInstance();
        final activeSessionId = prefs.getString('ss_active_session_id');
        final startedAt = prefs.getInt('ss_active_session_started_at');
        final activePlanId = prefs.getString('ss_active_plan_id');
        final rawState = prefs.getString('ss_exercises_state');

        if (activeSessionId != null &&
            startedAt != null &&
            activePlanId != null) {
          final startOfToday = DateTime(
            today.year,
            today.month,
            today.day,
          ).millisecondsSinceEpoch;

          if (startedAt < startOfToday) {
            sportsState = {
              'activeSessionId': activeSessionId,
              'startedAt': startedAt,
              'activePlanId': activePlanId,
              'rawState': rawState,
            };
          }
        }
      } catch (e, st) {
        RitmoLog.warning('EndOfDaySweep', 'Failed to read sports prefs: $e', e, st);
      }

      await db.transaction((txn) async {
        for (final row in staleRows) {
          final routineId = row['routine_id'] as String;
          final occDate = row['date'] as String;
          final occId = '${routineId}_$occDate';
          final isEssential = row['isEssential'] == 1;
          final category = row['category'] as String?;

          await txn.update(
            'routine_occurrences',
            {'status': 'missed'},
            where: 'routine_id = ? AND date = ?',
            whereArgs: [routineId, occDate],
          );
          sweptCount++;

          if (isEssential || category == 'medical') {
            await CentralInboxService.push(
              category: InboxCategory.ALERT,
              sourceSystem: 'end_of_day_sweep',
              entityId: occId,
              eventType: 'missed_essential',
              priority: 2,
              title: 'آیتم ضروری فراموش‌شده',
              body: 'یکی از آیتم‌های مهم یا داروی شما دیروز انجام نشد.',
              payload: {'routineId': routineId, 'occurrenceId': occId},
              executor: txn,
            );
          }

          await txn.update(
            'pending_reminders',
            {'state': ReminderState.expired.dbValue},
            where: 'routineId = ? AND state IN (?, ?, ?, ?)',
            whereArgs: [
              routineId,
              ReminderState.active.dbValue,
              ReminderState.delayed.dbValue,
              ReminderState.unknown.dbValue,
              ReminderState.cancelled.dbValue,
            ],
          );
        }

        // Multi-day Worship Sweep (RIT-013, RIT-014)
        for (final targetDate in sweepDates) {
          final targetDateStr = RitmoDate(targetDate).value;
          final dayCtx = dayContexts[targetDateStr] ??
              await WorshipEngine.instance.dayContext(targetDate);

          await _sweepWorshipForDate(
            txn,
            targetDateStr: targetDateStr,
            targetDate: targetDate,
            dayCtx: dayCtx,
            suspended: suspended,
          );
        }
        // Reset dailyDone for active practices for today if not already reset today (Item 9)
        await txn.update(
          'worship_practices',
          {
            'dailyDone': 0,
            'dailyDoneDate': todayStr,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'isActive = 1 AND (dailyDoneDate IS NULL OR dailyDoneDate < ?)',
          whereArgs: [todayStr],
        );

        // Sports Sweep with pre-fetched state (RIT-015, RIT-016)
        if (sportsState != null) {
          await _sweepSports(txn, sportsState);
        }

        // Update last_worship_sweep_date to last swept date (yesterdayDate) (REG-01, RIT-013)
        await txn.insert('app_settings', {
          'key': 'last_worship_sweep_date',
          'value': RitmoDate(yesterdayDate).value,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });

      // Clear sports preferences after transaction committed (RIT-016)
      if (prefs != null && sportsState != null) {
        try {
          await prefs.remove('ss_active_session_id');
          await prefs.remove('ss_active_plan_id');
          await prefs.remove('ss_exercises_state');
          await prefs.remove('ss_active_session_index');
          await prefs.remove('ss_active_session_started_at');
          await prefs.remove('ss_active_session_status');
          await prefs.remove('ss_active_session_target_timestamp');
          await prefs.remove('ss_active_session_elapsed');
          await prefs.remove('ss_active_session_paused');
        } catch (_) {}
      }

      WorshipRepository.instance.invalidateCache();
      for (final d in sweepDates) {
        DayAgendaService.instance.invalidateDate(RitmoDate(d).value);
      }
      DayAgendaService.instance.invalidateDate(todayStr);

      // Cleanup notification_history older than 90 days (DB-07)
      final ninetyDaysAgoMs = today
          .subtract(const Duration(days: 90))
          .millisecondsSinceEpoch;
      await db.delete(
        'notification_history',
        where: 'sentAt < ?',
        whereArgs: [ninetyDaysAgoMs],
      );

      // Refresh prayer reminders for today & tomorrow
      try {
        await PrayerReminderScheduler.instance.schedulePrayerReminders();
      } catch (e, st) {
        RitmoLog.error('EndOfDaySweep', 'Failed to refresh prayer reminders in sweep', e, st);
      }

    } catch (e, st) {
      RitmoLog.error('EndOfDaySweep', 'EndOfDaySweep error', e, st);
    }

    return sweptCount;
  }

  static Future<void> _sweepWorshipForDate(
    DatabaseExecutor txn, {
    required String targetDateStr,
    required DateTime targetDate,
    required WorshipDayContext dayCtx,
    required bool suspended,
  }) async {
    final religionRows = await txn.query(
      'app_settings',
      where: "key = 'module_religion_enabled'",
    );
    final religionEnabled = religionRows.isNotEmpty &&
        religionRows.first['value'] == 'true';
    if (!religionEnabled) return;

    final appStartRows = await txn.query(
      'app_settings',
      where: "key = 'app_start_date'",
    );
    if (appStartRows.isNotEmpty) {
      final appStartStr = appStartRows.first['value'] as String?;
      if (appStartStr != null && appStartStr.isNotEmpty) {
        final parsedAppStart = DateKey.parse(appStartStr);
        if (parsedAppStart != null && targetDate.isBefore(parsedAppStart)) {
          return;
        }
      }
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Calculate end-of-target cutoff: practices created AFTER this point
    // were not active on targetDate and should NOT be swept.
    final targetEnd = (targetDate.add(
      const Duration(days: 1),
    )).millisecondsSinceEpoch;

    final uncompletedRows = await txn.rawQuery(
      '''
      SELECT p.*
      FROM worship_practices p
      WHERE p.isActive = 1
      AND p.userDisabledAt IS NULL
      AND p.practiceType IN ('PRAYER', 'MUSTAHAB', 'FASTING')
      AND p.createdAt < ?
      AND NOT EXISTS (
        SELECT 1 FROM worship_completions c
        WHERE c.practiceId = p.id AND c.dateStr = ?
      )
    ''',
      [targetEnd, targetDateStr],
    );

    for (final row in uncompletedRows) {
      final practice = WorshipPractice.fromMap(row);
      final recordId = 'wc_${practice.id}_$targetDateStr';

      final resultType = WorshipEngine.resolveMissResult(
        practice: practice,
        ctx: dayCtx,
        suspended: suspended,
      );

      final addQada = WorshipEngine.shouldAddQada(
        practice: practice,
        ctx: dayCtx,
        suspended: suspended,
      );

      try {
        final insertedRowId = await txn.insert('worship_completions', {
          'id': recordId,
          'practiceId': practice.id,
          'dateStr': targetDateStr,
          'practiceType': practice.practiceType,
          'resultType': resultType,
          'countDone': 0,
          'countTarget': practice.dailyTarget,
          'loggedAt': nowMs,
          'createdAt': nowMs,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        // Idempotent: only increment debt if worship_completions row was genuinely newly inserted (RIT-013)
        if (insertedRowId > 0 && addQada) {
          final debtType = practice.practiceType == 'FASTING'
              ? 'FASTING'
              : (practice.practiceType == 'MUSTAHAB' ? 'MUSTAHAB' : 'PRAYER');
          final debtId = 'debt_${debtType}_${practice.id}';
          final debtTitle = practice.practiceType == 'FASTING'
              ? 'روزه قضا'
              : practice.title;

          final existingDebt = await txn.query(
            'worship_debts',
            where: 'id = ?',
            whereArgs: [debtId],
          );
          if (existingDebt.isNotEmpty) {
            await txn.rawUpdate(
              '''
              UPDATE worship_debts
              SET totalCount = totalCount + 1,
                  remainingCount = remainingCount + 1,
                  isArchived = 0,
                  updatedAt = ?
              WHERE id = ?
            ''',
              [nowMs, debtId],
            );
          } else {
            await txn.insert('worship_debts', {
              'id': debtId,
              'debtType': debtType,
              'sourcePracticeId': practice.id,
              'title': debtTitle,
              'totalCount': 1,
              'remainingCount': 1,
              'dailyTarget': 1,
              'autoCreated': 1,
              'isArchived': 0,
              'createdAt': nowMs,
              'updatedAt': nowMs,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      } catch (e, st) {
        RitmoLog.error('EndOfDaySweep', 'Worship sweep error for ${practice.id}', e, st);
      }
    }
  }

  static Future<void> _sweepSports(
    DatabaseExecutor txn,
    Map<String, dynamic> sportsState,
  ) async {
    try {
      final activeSessionId = sportsState['activeSessionId'] as String;
      final startedAt = sportsState['startedAt'] as int;
      final activePlanId = sportsState['activePlanId'] as String;
      final rawState = sportsState['rawState'] as String?;

      int completedCount = 0;
      int totalCount = 1;
      if (rawState != null) {
        try {
          final list = jsonDecode(rawState) as List;
          totalCount = list.length;
          for (final item in list) {
            if (item['status'] == 'ExerciseStatus.done') {
              completedCount++;
            }
          }
        } catch (_) {}
      }

      // Calculate end of start day and clip duration to max 4 hours (14400 seconds) (RIT-015)
      final startDate = DateTime.fromMillisecondsSinceEpoch(startedAt);
      final endOfStartDay = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        23,
        59,
        59,
      ).millisecondsSinceEpoch;

      final rawDuration = ((endOfStartDay - startedAt) ~/ 1000);
      final durationSec = rawDuration > 0
          ? (rawDuration > 14400 ? 14400 : rawDuration)
          : 0;
      final finishedAt = endOfStartDay;

      // Lookup real workoutPlanId if activePlanId is a prescription ID (Item 8)
      String? realPlanId = activePlanId;
      String? realPrescriptionId = activePlanId;
      try {
        final prescRows = await txn.query(
          'ss_session_prescription',
          where: 'id = ?',
          whereArgs: [activePlanId],
          limit: 1,
        );
        if (prescRows.isNotEmpty) {
          final workoutPlanId = prescRows.first['workoutPlanId'] as String?;
          if (workoutPlanId != null && workoutPlanId.isNotEmpty) {
            realPlanId = workoutPlanId;
          }
          realPrescriptionId = prescRows.first['id'] as String?;
        }
      } catch (_) {}

      await txn.insert('ss_workout_session_log', {
        'id': activeSessionId,
        'planId': realPlanId,
        'prescriptionId': realPrescriptionId,
        'startedAt': startedAt,
        'finishedAt': finishedAt,
        'durationSeconds': durationSec,
        'completedExercisesCount': completedCount,
        'totalExercisesCount': totalCount,
        'note': 'مختومه به دلیل پایان روز (خودکار)',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.update(
        'ss_session_prescription',
        {'status': 'DONE', 'updatedAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [activePlanId],
      );
      await txn.update(
        'movement_sessions',
        {
          'status': 'COMPLETED',
          'endedAt': finishedAt,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [activeSessionId],
      );
    } catch (e, st) {
      RitmoLog.error('EndOfDaySweep', 'Sports sweep error', e, st);
    }
  }
}
