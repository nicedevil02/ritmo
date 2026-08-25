import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/completion/completion_outcome.dart';
import 'package:ritmo/core/domain/completion/completion_request.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';
import 'package:ritmo/features/worship/domain/prayer_log_quality.dart';
import 'package:ritmo/features/worship/logic/worship_repository.dart';

/// Single gateway entry point for all completion and state-change requests across Ritmo.
class CompletionGateway {
  CompletionGateway._();
  static final instance = CompletionGateway._();

  /// Submits any CompletionRequest and returns a standardized CompletionOutcome.
  Future<CompletionOutcome> submit(CompletionRequest request) async {
    try {
      return switch (request) {
        final RoutineCompletion req        => _handleRoutineCompletion(req),
        final RoutineSkip req              => _handleRoutineSkip(req),
        final RoutineReschedule req         => _handleRoutineReschedule(req),
        final RoutineSnooze req             => _handleRoutineSnooze(req),
        final CourseSessionCompletion req   => _handleCourseCompletion(req),
        final KonkurSessionCompletion req   => _handleKonkurCompletion(req),
        final WorshipCompletion req         => _handleWorshipCompletion(req),
        final PrayerCompletion req          => _handlePrayerCompletion(req),
        final WorshipSkip req               => _handleWorshipSkip(req),
        final WorshipDebtProgress req       => _handleWorshipDebtProgress(req),
        final GoalStepCompletion req       => _handleGoalStepCompletion(req),
        final MedicationTake req           => _handleMedicationTake(req),
        final MovementCompletion req       => _handleMovementCompletion(req),
      };
    } catch (e, st) {
      // MED-45: a swallowed write failure is worse than a crash, because the UI
      // shows a checked item that was never persisted. Log with the stack trace
      // and hand the user a readable message instead of a raw exception string.
      RitmoLog.error('CompletionGateway', 'Submission failed for ${request.runtimeType}', e, st);
      debugPrint('CompletionGateway submission error: $e\n$st');
      return CompletionOutcome.failure('ثبت اطلاعات انجام نشد. دوباره تلاش کنید.');
    }
  }

  Future<CompletionOutcome> _handleMovementCompletion(MovementCompletion req) async {
    final event = MovementEvent(
      id: RitmoIdFactory.movementLog(),
      kindCode: req.kindCode,
      durationMinutes: req.durationMinutes,
      intensity: MovementIntensity.fromCode(req.intensity),
      loggedAt: DateTime.tryParse(req.dateStr)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    );
    await MovementRepository.instance.logEvent(event);
    _notifySuccess(domain: 'movement', itemId: event.id, dateStr: req.dateStr, result: 'FULL');
    return CompletionOutcome.success(undoToken: 'movement:${event.id}');
  }

  Future<CompletionOutcome> _handleRoutineCompletion(RoutineCompletion req) async {
    try {
      await RitmoExecutionKernel.instance.execute(
        CompleteOccurrenceCommand(
          routineId: req.routineId,
          dateStr: req.dateStr,
          resultType: req.result.dbValue,
          durationMinutes: req.durationMinutes,
          partialRatio: req.partialRatio,
          resultSource: 'USER',
        ),
      );
      _notifySuccess(domain: 'routine', itemId: req.routineId, dateStr: req.dateStr, result: req.result.dbValue);
      return CompletionOutcome.success(undoToken: 'routine:${req.routineId}|${req.dateStr}');
    } catch (e, st) {
      RitmoLog.error('CompletionGateway', 'Routine completion failed', e, st);
      return CompletionOutcome.failure('ثبت انجام روتین انجام نشد. دوباره تلاش کنید.');
    }
  }

  Future<CompletionOutcome> _handleRoutineSkip(RoutineSkip req) async {
    try {
      await RitmoExecutionKernel.instance.execute(
        SkipOccurrenceCommand(
          routineId: req.routineId,
          dateStr: req.dateStr,
          reason: req.reason,
        ),
      );
      _notifySuccess(domain: 'routine', itemId: req.routineId, dateStr: req.dateStr, result: 'SKIPPED');
      return CompletionOutcome.success(undoToken: 'routine:${req.routineId}|${req.dateStr}');
    } catch (e, st) {
      RitmoLog.error('CompletionGateway', 'Routine skip failed', e, st);
      return CompletionOutcome.failure('ثبت رد روتین انجام نشد. دوباره تلاش کنید.');
    }
  }

  Future<CompletionOutcome> _handleRoutineReschedule(RoutineReschedule req) async {
    try {
      await RitmoExecutionKernel.instance.execute(
        RescheduleOccurrenceCommand(
          routineId: req.routineId,
          fromDateStr: req.fromDateStr,
          toDateStr: req.toDateStr,
          reason: req.reason,
        ),
      );
      _notifySuccess(domain: 'routine', itemId: req.routineId, dateStr: req.fromDateStr, result: 'RESCHEDULED');
      _notifySuccess(domain: 'routine', itemId: req.routineId, dateStr: req.toDateStr, result: 'RESCHEDULED');
      return CompletionOutcome.success(
        undoToken: 'reschedule:${req.routineId}|${req.fromDateStr}|${req.toDateStr}',
        userMessage: 'به فردای همین ساعت منتقل شد',
      );
    } catch (e, st) {
      RitmoLog.error('CompletionGateway', 'Routine reschedule failed', e, st);
      return CompletionOutcome.failure('انتقال زمان روتین انجام نشد. دوباره تلاش کنید.');
    }
  }

  Future<CompletionOutcome> _handleRoutineSnooze(RoutineSnooze req) async {
    await RitmoExecutionKernel.instance.execute(
      SnoozeReminderCommand(
        reminderId: req.reminderId,
        snoozeMinutes: req.snoozeMinutes,
        dateStr: req.dateStr,
      ),
    );

    _notifySuccess(domain: 'routine', itemId: req.reminderId, dateStr: req.dateStr, result: 'SNOOZED');
    return CompletionOutcome.success();
  }

  Future<CompletionOutcome> _handleCourseCompletion(CourseSessionCompletion req) async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'course_sessions',
      {
        'completionStatus': 'COMPLETED',
        'isCompleted': 1,
        'completedAt': nowMs,
        'actualDurationMinutes': req.durationMinutes,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [req.sessionId],
    );

    _notifySuccess(domain: 'course', itemId: req.sessionId, dateStr: req.dateStr, result: 'FULL');
    return CompletionOutcome.success(undoToken: 'course:${req.sessionId}');
  }

  Future<CompletionOutcome> _handleKonkurCompletion(KonkurSessionCompletion req) async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final logId = RitmoIdFactory.konkurLog();

    await db.insert('konkur_study_logs', {
      'id': logId,
      'topicId': req.topicId,
      'subjectId': req.subjectId,
      'dateStr': req.dateStr,
      'durationMinutes': req.durationMinutes,
      'questionsCount': req.questionsCount,
      'createdAt': nowMs,
    });

    _notifySuccess(domain: 'konkur', itemId: req.topicId, dateStr: req.dateStr, result: 'FULL');
    return CompletionOutcome.success(undoToken: 'konkur:$logId');
  }

  Future<CompletionOutcome> _handleWorshipCompletion(WorshipCompletion req) async {
    final recordId = await WorshipCompletionRepository.instance.logDone(
      practiceId: req.practiceId,
      dateStr: req.dateStr,
      practiceType: req.practiceType,
      countDone: req.countDone,
      countTarget: req.countTarget,
    );

    _notifySuccess(domain: 'worship', itemId: req.practiceId, dateStr: req.dateStr, result: 'FULL');
    return CompletionOutcome.success(undoToken: 'worship:$recordId');
  }

  Future<CompletionOutcome> _handlePrayerCompletion(PrayerCompletion req) async {
    final quality = PrayerLogQuality.fromCode(req.mode);
    final resultType = quality == PrayerLogQuality.qada ? 'QADA_ADDED' : 'DONE';
    final recordId = await WorshipCompletionRepository.instance.logDone(
      practiceId: req.prayerKey,
      dateStr: req.dateStr,
      practiceType: 'PRAYER',
      quality: quality,
      countDone: 1,
      countTarget: 1,
    );

    _notifySuccess(domain: 'prayer', itemId: req.prayerKey, dateStr: req.dateStr, result: resultType);
    return CompletionOutcome.success(undoToken: 'prayer:$recordId');
  }

  Future<CompletionOutcome> _handleWorshipSkip(WorshipSkip req) async {
    final recordId = await WorshipCompletionRepository.instance.logSkip(
      practiceId: req.practiceId,
      dateStr: req.dateStr,
      practiceType: req.practiceType,
      reason: req.reason,
    );

    _notifySuccess(domain: 'worship', itemId: req.practiceId, dateStr: req.dateStr, result: 'SKIPPED');
    return CompletionOutcome.success(undoToken: 'worship:$recordId');
  }

  Future<CompletionOutcome> _handleWorshipDebtProgress(WorshipDebtProgress req) async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      'worship_debts',
      where: 'id = ? AND isArchived = 0',
      whereArgs: [req.debtId],
    );

    if (rows.isEmpty) {
      return CompletionOutcome.failure('این بدهی عبادی یافت نشد یا قبلاً بایگانی شده است');
    }

    final row = rows.first;
    final currentRemaining = row['remainingCount'] as int? ?? 0;
    final newRemaining = (currentRemaining - req.delta).clamp(0, 999999);
    final isArchived = newRemaining <= 0 ? 1 : 0;

    await db.update(
      'worship_debts',
      {
        'remainingCount': newRemaining,
        'isArchived': isArchived,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [req.debtId],
    );

    final todayStr = DateTime.now().toIso8601String().split('T').first;
    DayAgendaService.instance.invalidateDate(todayStr);
    WorshipRepository.instance.invalidateCache();
    RitmoEventBus().fire(RitmoEvent(type: 'WorshipUpdated', timestamp: DateTime.now(), payload: {'date': todayStr, 'debtId': req.debtId}));

    _notifySuccess(domain: 'worshipDebt', itemId: req.debtId, dateStr: todayStr, result: 'FULL');
    return CompletionOutcome.success(undoToken: 'worshipDebt:${req.debtId}|${req.delta}');
  }

  Future<CompletionOutcome> _handleGoalStepCompletion(GoalStepCompletion req) async {
    final db = await DatabaseHelper.instance.database;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'goal_steps',
      {
        'isCompleted': req.isCompleted ? 1 : 0,
        'completedAt': req.isCompleted ? nowMs : null,
        'updatedAt': nowMs,
      },
      where: 'id = ? AND goalId = ?',
      whereArgs: [req.stepId, req.goalId],
    );

    _notifySuccess(domain: 'goalStep', itemId: req.stepId, dateStr: req.dateStr, result: req.isCompleted ? 'FULL' : 'SKIPPED');
    return CompletionOutcome.success(undoToken: 'goalStep:${req.goalId}|${req.stepId}');
  }

  /// MED-02: an agenda item can carry either a `routines.id` or the id of an
  /// existing `medication_logs` / `prn_logs` row, because MedicineAgendaSource
  /// publishes a row id as `sourceId`. Resolve whatever we are handed back to the
  /// owning routine, and report the scheduled log row when the identifier points
  /// at one, so the caller can complete that dose in place instead of creating a
  /// duplicate.
  Future<({String routineId, String? logId})?> _resolveMedicationTarget(String rawId) async {
    if (rawId.isEmpty) return null;
    final db = await DatabaseHelper.instance.database;

    final routineRows = await db.query('routines', columns: ['id'], where: 'id = ?', whereArgs: [rawId], limit: 1);
    if (routineRows.isNotEmpty) {
      final rid = routineRows.first['id'] as String?;
      if (rid != null) return (routineId: rid, logId: null);
    }

    final logRows = await db.query('medication_logs', columns: ['routineId'], where: 'id = ?', whereArgs: [rawId], limit: 1);
    if (logRows.isNotEmpty) {
      final rid = logRows.first['routineId'] as String?;
      if (rid != null) return (routineId: rid, logId: rawId);
    }

    final prnRows = await db.query('prn_logs', columns: ['routineId'], where: 'id = ?', whereArgs: [rawId], limit: 1);
    if (prnRows.isNotEmpty) {
      final rid = prnRows.first['routineId'] as String?;
      if (rid != null) return (routineId: rid, logId: null);
    }

    return null;
  }

  /// Builds the epoch-ms timestamp a dose was scheduled for, from the agenda's
  /// `yyyy-MM-dd` date and an optional `HH:mm` slot. Falls back to midnight when
  /// no slot is supplied, and to `null` when the date itself is unparsable.
  int? _resolveScheduledMs(String dateStr, String? doseTime) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return null;

    final slot = doseTime?.trim() ?? '';
    if (slot.isEmpty) {
      return DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    }

    final parts = slot.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute).millisecondsSinceEpoch;
  }

  Future<CompletionOutcome> _handleMedicationTake(MedicationTake req) async {
    try {
      final target = await _resolveMedicationTarget(req.medicationId);
      if (target == null) {
        debugPrint('CompletionGateway: no medication routine resolves from id=${req.medicationId}');
        return CompletionOutcome.failure('این دارو یافت نشد. ثبت مصرف انجام نشد.');
      }

      final routineId = target.routineId;
      final scheduledLogId = target.logId;
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final logId = scheduledLogId ?? RitmoIdFactory.medicationLog();
      final scheduledMs = _resolveScheduledMs(req.dateStr, req.doseTime) ?? nowMs;

      await db.transaction((txn) async {
        if (scheduledLogId != null) {
          // MED-03: the agenda row for this slot already exists. Completing it in
          // place keeps the original scheduledTime and stops one dose from being
          // counted twice in the adherence maths.
          await txn.update(
            'medication_logs',
            {'takenTime': nowMs, 'status': 'TAKEN'},
            where: 'id = ?',
            whereArgs: [scheduledLogId],
          );
        } else {
          // MED-01: these are the real medication_logs columns. The previous
          // payload (medicationId / date / doseTime / takenAt) matches no column
          // in the schema, so sqflite threw on every insert and submit()
          // swallowed it: each dose logged from the agenda, calendar or a
          // notification was lost.
          await txn.insert('medication_logs', {
            'id': logId,
            'routineId': routineId,
            'scheduledTime': scheduledMs,
            'takenTime': nowMs,
            'status': 'TAKEN',
            'createdAt': nowMs,
          });
        }

        // MED-14: decrement stock in the same transaction as the log write so two
        // quick taps cannot lose an update, and never fall below zero.
        await txn.rawUpdate(
          'UPDATE routines SET medStockCount = medStockCount - 1, updatedAt = ? '
          'WHERE id = ? AND medStockCount IS NOT NULL AND medStockCount > 0',
          [nowMs, routineId],
        );
        await txn.rawUpdate(
          'UPDATE medication_profiles SET remainingAmount = MAX(0.0, remainingAmount - 1.0) '
          'WHERE routineId = ? AND remainingAmount IS NOT NULL',
          [routineId],
        );
      });

      _notifySuccess(domain: 'medicine', itemId: routineId, dateStr: req.dateStr, result: 'FULL');
      return CompletionOutcome.success(
        undoToken: 'medicine:$logId|${scheduledLogId != null ? 'UPDATED' : 'CREATED'}',
      );
    } catch (e, st) {
      RitmoLog.error('CompletionGateway', 'Medication take failed', e, st);
      return CompletionOutcome.failure('ثبت مصرف دارو انجام نشد. دوباره تلاش کنید.');
    }
  }

  /// Reverts a completion given an undo token.
  Future<CompletionOutcome> undo(String undoToken) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final parts = undoToken.split(':');

      if (parts.length < 2) {
        final rows = await db.query('routine_completions', where: 'id = ?', whereArgs: [undoToken]);
        if (rows.isNotEmpty) {
          final comp = rows.first;
          final rId = comp['routineId']! as String;
          final dateStr = comp['completionDate']! as String;

          await db.transaction((txn) async {
            await txn.delete('routine_completions', where: 'id = ?', whereArgs: [undoToken]);
            await txn.delete('skip_reasons', where: 'itemId = ? AND dateStr = ?', whereArgs: [rId, dateStr]);
            await txn.rawUpdate('''
              UPDATE routine_occurrences 
              SET status = 'pending'
              WHERE routine_id = ? AND date = ?
            ''', [rId, dateStr]);
          });

          DayAgendaService.instance.invalidateDate(dateStr);
          return CompletionOutcome.success();
        }
        return CompletionOutcome.failure('توکن لغو یافت نشد');
      }

      final domain = parts[0];
      final idPayload = parts.sublist(1).join(':');

      switch (domain) {
        case 'reschedule':
          final resParts = idPayload.split('|');
          if (resParts.length >= 2) {
            final rId = resParts[0];
            final fromDateStr = resParts[1];
            final toDateStr = resParts.length >= 3 ? resParts[2] : null;

            await db.transaction((txn) async {
              await txn.delete('routine_completions', where: 'routineId = ? AND completionDate = ? AND resultType = ?', whereArgs: [rId, fromDateStr, 'RESCHEDULED']);
              await txn.delete('skip_reasons', where: 'itemId = ? AND dateStr = ?', whereArgs: [rId, fromDateStr]);
              await txn.rawUpdate('''
                UPDATE routine_occurrences 
                SET status = 'pending'
                WHERE routine_id = ? AND date = ?
              ''', [rId, fromDateStr]);

              if (toDateStr != null) {
                await txn.delete(
                  'routine_occurrences',
                  where: 'routine_id = ? AND date = ? AND status = ?',
                  whereArgs: [rId, toDateStr, 'pending'],
                );
              }
            });

            DayAgendaService.instance.invalidateDate(fromDateStr);
            if (toDateStr != null) DayAgendaService.instance.invalidateDate(toDateStr);
            return CompletionOutcome.success(userMessage: 'انتقال روتین لغو شد');
          }
          return CompletionOutcome.failure('توکن لغو جابه‌جایی نامعتبر است');

        case 'routine':
          final rParts = idPayload.split('|');
          final rId = rParts[0];
          final dateStr = rParts.length >= 2 ? rParts[1] : '';
          final compId = rParts.length >= 3 ? rParts[2] : rId;

          final rows = await db.query('routine_completions', where: 'id = ? OR (routineId = ? AND completionDate = ?)', whereArgs: [compId, rId, dateStr]);
          if (rows.isNotEmpty) {
            final comp = rows.first;
            final actualRoutineId = comp['routineId']! as String;
            final actualDateStr = comp['completionDate']! as String;

            await db.transaction((txn) async {
              await txn.delete('routine_completions', where: 'id = ?', whereArgs: [comp['id']]);
              await txn.delete('skip_reasons', where: 'itemId = ? AND dateStr = ?', whereArgs: [actualRoutineId, actualDateStr]);
              await txn.rawUpdate('''
                UPDATE routine_occurrences 
                SET status = 'pending'
                WHERE routine_id = ? AND date = ?
              ''', [actualRoutineId, actualDateStr]);

              if (rParts.length >= 5) {
                final prevCurr = int.tryParse(rParts[3]);
                final prevDone = int.tryParse(rParts[4]);
                if (prevCurr != null && prevDone != null) {
                  await txn.update(
                    'routines',
                    {
                      'progressionCurrent': prevCurr,
                      'progressionDoneSinceAdvance': prevDone,
                      'updatedAt': DateTime.now().millisecondsSinceEpoch,
                    },
                    where: 'id = ?',
                    whereArgs: [actualRoutineId],
                  );
                }
              }
            });

            DayAgendaService.instance.invalidateDate(actualDateStr);
            return CompletionOutcome.success(userMessage: 'انجام روتین لغو شد');
          }
          return CompletionOutcome.failure('توکن لغو روتین یافت نشد');

        case 'movement':
          await MovementRepository.instance.deleteEvent(idPayload);
          return CompletionOutcome.success();

        case 'course':
          await db.update(
            'course_sessions',
            {
              'completionStatus': 'PENDING',
              'isCompleted': 0,
              'completedAt': null,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [idPayload],
          );
          return CompletionOutcome.success();

        case 'konkur':
          await db.delete('konkur_study_logs', where: 'id = ?', whereArgs: [idPayload]);
          return CompletionOutcome.success();

        case 'prayer':
        case 'worship':
          final success = await WorshipCompletionRepository.instance.undo(idPayload);
          return success ? CompletionOutcome.success() : CompletionOutcome.failure('توکن لغو عبادت یافت نشد');

        case 'worshipDebt':
          final debtParts = idPayload.split('|');
          if (debtParts.length == 2) {
            final debtId = debtParts[0];
            final delta = int.tryParse(debtParts[1]) ?? 1;
            await db.rawUpdate(
              'UPDATE worship_debts SET remainingCount = remainingCount + ?, isArchived = 0, updatedAt = ? WHERE id = ?',
              [delta, DateTime.now().millisecondsSinceEpoch, debtId],
            );
            final todayStr = DateTime.now().toIso8601String().split('T').first;
            DayAgendaService.instance.invalidateDate(todayStr);
            WorshipRepository.instance.invalidateCache();
            return CompletionOutcome.success();
          }
          return CompletionOutcome.failure('شناسه توکن بدهی عبادی غیرمجاز است');

        case 'medicine':
          // MED-14: undoing a dose has to hand the pill back to the stock counter,
          // otherwise every mistaken tap permanently burns one unit of inventory.
          // MED-03: a scheduled dose is reverted to pending; only an ad-hoc take
          // (token suffix CREATED, or a legacy token with no suffix) is deleted.
          final medParts = idPayload.split('|');
          final medLogId = medParts.first;
          final wasScheduled = medParts.length > 1 && medParts[1] == 'UPDATED';

          final medLogRows = await db.query('medication_logs', columns: ['routineId'], where: 'id = ?', whereArgs: [medLogId], limit: 1);
          final medRoutineId = medLogRows.isNotEmpty ? medLogRows.first['routineId'] as String? : null;

          await db.transaction((txn) async {
            if (wasScheduled) {
              await txn.update(
                'medication_logs',
                {'takenTime': null, 'status': 'PENDING'},
                where: 'id = ?',
                whereArgs: [medLogId],
              );
            } else {
              await txn.delete('medication_logs', where: 'id = ?', whereArgs: [medLogId]);
            }

            if (medRoutineId != null) {
              await txn.rawUpdate(
                'UPDATE routines SET medStockCount = medStockCount + 1, updatedAt = ? '
                'WHERE id = ? AND medStockCount IS NOT NULL',
                [DateTime.now().millisecondsSinceEpoch, medRoutineId],
              );
              await txn.rawUpdate(
                'UPDATE medication_profiles SET remainingAmount = remainingAmount + 1.0 '
                'WHERE routineId = ? AND remainingAmount IS NOT NULL',
                [medRoutineId],
              );
            }
          });

          if (medRoutineId != null) {
            RitmoEventBus().fire(
              RitmoEvent(
                type: RitmoEventType.completionRecorded.code,
                timestamp: DateTime.now(),
                payload: {'domain': 'medicine', 'itemId': medRoutineId, 'result': 'UNDONE', 'didWrite': true},
              ),
            );
          }
          return CompletionOutcome.success();

        case 'goalStep':
          final stepParts = idPayload.split('|');
          if (stepParts.length == 2) {
            final goalId = stepParts[0];
            final stepId = stepParts[1];
            await db.update(
              'goal_steps',
              {
                'isCompleted': 0,
                'completedAt': null,
                'updatedAt': DateTime.now().millisecondsSinceEpoch,
              },
              where: 'id = ? AND goalId = ?',
              whereArgs: [stepId, goalId],
            );
            return CompletionOutcome.success();
          }
          return CompletionOutcome.failure('شناسه گام هدف غیرمجاز است');

        default:
          return CompletionOutcome.failure('دامنه بازگردانی پشتیبانی نمی‌شود');
      }
    } catch (e, st) {
      RitmoLog.error('CompletionGateway', 'Undo failed for token $undoToken', e, st);
      return CompletionOutcome.failure('بازگردانی انجام نشد. دوباره تلاش کنید.');
    }
  }

  void _notifySuccess({
    required String domain,
    required String itemId,
    required String dateStr,
    required String result,
  }) {
    DayAgendaService.instance.invalidateDate(dateStr);
    RitmoEventBus().fire(
      RitmoEvent(
        type: RitmoEventType.completionRecorded.code,
        timestamp: DateTime.now(),
        payload: {
          'domain': domain,
          'itemId': itemId,
          'dateStr': dateStr,
          'result': result,
          'didWrite': true,
        },
      ),
    );
  }
}
