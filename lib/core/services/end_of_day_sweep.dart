import 'dart:convert';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:ritmo/core/domain/models/reminder_state.dart';
import 'package:ritmo/core/services/central_inbox_service.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/ritmo_date.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/logic/worship_repository.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
// TODO(arch): Core layer dependency on supplementary_sports feature. Decouple in future via DatabaseHelper.warmupHooks or an event listener pattern.
import 'package:ritmo/features/supplementary_sports/domain/ss_session_completion_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// EndOfDaySweep sweeps stale pending/snoozed occurrences past midnight and converts them to 'missed'.
class EndOfDaySweep {
  EndOfDaySweep._();

  static Future<int> runSweep(Database db, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayStr = RitmoDate(today).value;
    final yesterdayStr = RitmoDate(
      today.subtract(const Duration(days: 1)),
    ).value;

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

      // Pre-fetch worship context before transaction to avoid SQLite deadlock (BOOT-DEADLOCK)
      final suspended = await CycleConsentBridge.isWorshipSuspended();
      final yesterdayDate =
          DateTime.tryParse(yesterdayStr) ??
          DateTime.now().subtract(const Duration(days: 1));
      final dayCtx = await WorshipEngine.instance.dayContext(yesterdayDate);

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

        // Worship Sweep with pre-fetched contexts
        await _sweepWorship(
          txn,
          yesterdayStr,
          todayStr,
          dayCtx: dayCtx,
          suspended: suspended,
          yesterdayDate: yesterdayDate,
        );

        // Sports Sweep
        await _sweepSports(txn);
      });

      WorshipRepository.instance.invalidateCache();
      DayAgendaService.instance.invalidateDate(yesterdayStr);
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

      await db.execute(
        "INSERT OR REPLACE INTO app_settings (key, value, updatedAt) VALUES ('last_worship_sweep_date', ?, ?)",
        [todayStr, DateTime.now().millisecondsSinceEpoch],
      );
    } catch (e, st) {
      RitmoLog.error('EndOfDaySweep', 'EndOfDaySweep error', e, st);
    }

    return sweptCount;
  }

  static Future<void> _sweepWorship(
    DatabaseExecutor txn,
    String yesterdayStr,
    String todayStr, {
    required WorshipDayContext dayCtx,
    required bool suspended,
    required DateTime yesterdayDate,
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
        if (parsedAppStart != null && yesterdayDate.isBefore(parsedAppStart)) {
          return;
        }
      }
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Calculate end-of-yesterday cutoff: practices created AFTER this point
    // were not active yesterday and should NOT be swept (prevents false qada on fresh install).
    final yesterdayEnd = (yesterdayDate.add(
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
      [yesterdayEnd, yesterdayStr],
    );

    for (final row in uncompletedRows) {
      final practice = WorshipPractice.fromMap(row);
      final recordId = 'wc_missed_${practice.id}_$yesterdayStr';

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
        await txn.insert('worship_completions', {
          'id': recordId,
          'practiceId': practice.id,
          'dateStr': yesterdayStr,
          'practiceType': practice.practiceType,
          'resultType': resultType,
          'countDone': 0,
          'countTarget': practice.dailyTarget,
          'loggedAt': nowMs,
          'createdAt': nowMs,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        if (addQada) {
          final debtId = 'debt_${practice.practiceType}_${practice.id}';
          final debtType = practice.practiceType == 'FASTING'
              ? 'FAST'
              : 'PRAYER';
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

    // Reset dailyDone for active practices
    await txn.update('worship_practices', {
      'dailyDone': 0,
      'dailyDoneDate': todayStr,
      'updatedAt': nowMs,
    }, where: 'isActive = 1');
  }

  static Future<void> _sweepSports(DatabaseExecutor txn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeSessionId = prefs.getString('ss_active_session_id');
      final startedAt = prefs.getInt('ss_active_session_started_at');
      final activePlanId = prefs.getString('ss_active_plan_id');

      if (activeSessionId != null &&
          startedAt != null &&
          activePlanId != null) {
        final today = DateTime.now();
        final startOfToday = DateTime(
          today.year,
          today.month,
          today.day,
        ).millisecondsSinceEpoch;

        // If the session was started before today, it's a stale/unfinished session from a previous day.
        if (startedAt < startOfToday) {
          final rawState = prefs.getString('ss_exercises_state');
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

          final durationSec = ((startOfToday - 1000) - startedAt) ~/ 1000;
          final finishedAt =
              startOfToday - 1000; // Fake finish time at 23:59:59 yesterday

          await txn.insert('ss_workout_session_log', {
            'id': activeSessionId,
            'planId': activePlanId,
            'prescriptionId': activePlanId,
            'startedAt': startedAt,
            'finishedAt': finishedAt,
            'durationSeconds': durationSec > 0 ? durationSec : 0,
            'completedExercisesCount': completedCount,
            'totalExercisesCount': totalCount,
            'note': 'مختومه به دلیل پایان روز',
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          await SsSessionCompletionGateway.completeDetailedSessionInTransaction(
            txn,
            prescriptionId: activePlanId,
            sessionId: activeSessionId,
            actualMinutes: durationSec ~/ 60,
            actualRpe: 5,
            isPartial: true,
          );

          // Clear preferences so it doesn't get swept again and dashboard doesn't show it as resumable
          await prefs.remove('ss_active_session_id');
          await prefs.remove('ss_active_plan_id');
          await prefs.remove('ss_exercises_state');
          await prefs.remove('ss_active_session_index');
          await prefs.remove('ss_active_session_started_at');
          await prefs.remove('ss_active_session_status');
          await prefs.remove('ss_active_session_target_timestamp');
          await prefs.remove('ss_active_session_elapsed');
          await prefs.remove('ss_active_session_paused');
        }
      }
    } catch (e, st) {
      RitmoLog.error('EndOfDaySweep', 'Sports sweep error', e, st);
    }
  }
}
