import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_reminder_scheduler.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';
import 'package:sqflite/sqflite.dart';

class CycleConfirmationService {
  CycleConfirmationService._();
  static final CycleConfirmationService instance =
      CycleConfirmationService._();

  static const int maxAutoAsksPerCycle = 3;

  /// ارزیابی این‌که آیا تأییدی در انتظار است یا خیر
  Future<CycleConfirmationRequest?> evaluatePendingRequest({
    DatabaseExecutor? dbExecutor,
    required CycleEngineOutput engineOutput,
    required Map<String, dynamic> settings,
    DateTime? now,
  }) async {
    try {
      final effectiveNow = now ?? CycleClock.now;
      final cleanNow = CycleDateContract.cleanDate(effectiveNow);
      final db = dbExecutor ?? await DatabaseHelper.instance.database;

      // بررسی تعویق (Snooze)
      final snoozeUntilStr =
          settings[CycleSettings.keyConfirmSnoozeUntil]?.toString();
      if (snoozeUntilStr != null && snoozeUntilStr.isNotEmpty) {
        final snoozeDate = CycleDateContract.parseDayKey(snoozeUntilStr);
        if (snoozeDate != null &&
            CycleDateContract.isSameOrBefore(cleanNow, snoozeDate)) {
          return null;
        }
      }

      // ۱. بررسی تأیید شروع
      if (CycleSettings.isConfirmStartEnabled(settings) &&
          !engineOutput.isBleedingConfirmed &&
          (engineOutput.isStartDueToday ||
              engineOutput.awaitingStartConfirmation)) {
        final kind =
            engineOutput.isStartDueToday
                ? CycleConfirmationKind.startDue
                : CycleConfirmationKind.startOverdue;

        final targetDate =
            engineOutput.nextPeriodPrediction ??
            (engineOutput.forecast.isNotEmpty
                ? engineOutput.forecast.first.predictedStart
                : cleanNow);

        final reqId = CycleConfirmationRequest.buildId(kind, targetDate);
        final existing = await _getRequestById(db, reqId);

        if (existing != null) {
          if (existing.isAnswered) return null;
          if (existing.askCount >= maxAutoAsksPerCycle) return null;
          return existing;
        }

        return CycleConfirmationRequest(
          id: reqId,
          kind: kind,
          targetDate: targetDate,
          askCount: 0,
        );
      }

      // ۲. بررسی تأیید پایان
      if (CycleSettings.isConfirmEndEnabled(settings) &&
          (engineOutput.awaitingEndConfirmation ||
              engineOutput.isOpenPeriodBeyondAverage)) {
        final kind =
            engineOutput.isOpenPeriodBeyondAverage
                ? CycleConfirmationKind.bleedingProlonged
                : CycleConfirmationKind.endDue;

        final targetDate = engineOutput.actualPeriodStart ?? cleanNow;
        final reqId = CycleConfirmationRequest.buildId(kind, targetDate);
        final existing = await _getRequestById(db, reqId);

        if (existing != null) {
          if (existing.isAnswered) return null;
          if (existing.askCount >= maxAutoAsksPerCycle) return null;
          return existing;
        }

        return CycleConfirmationRequest(
          id: reqId,
          kind: kind,
          targetDate: targetDate,
          askCount: 0,
        );
      }

      return null;
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleConfirmationService] Error evaluating pending request',
        error: e,
        stack: st,
      );
      return null;
    }
  }

  Future<CycleConfirmationRequest?> _getRequestById(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      'cycle_confirmations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CycleConfirmationRequest.fromMap(rows.first);
  }

  /// ثبت پاسخ کاربر
  Future<void> recordAnswer({
    DatabaseExecutor? dbExecutor,
    required String requestId,
    required CycleConfirmationAnswer answer,
    DateTime? resolvedDate,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? CycleClock.now;
    final cleanNow = CycleDateContract.cleanDate(effectiveNow);
    final nowMs = effectiveNow.millisecondsSinceEpoch;
    final db = dbExecutor ?? await DatabaseHelper.instance.database;

    final existing = await _getRequestById(db, requestId);
    final newAskCount = (existing?.askCount ?? 0) + 1;

    await db.insert('cycle_confirmations', {
      'id': requestId,
      'kind':
          existing?.kind.name ??
          (requestId.startsWith('endDue') ||
                  requestId.startsWith('bleedingProlonged')
              ? 'endDue'
              : 'startDue'),
      'targetDate':
          existing != null
              ? CycleDateContract.toDayKey(existing.targetDate)
              : CycleDateContract.toDayKey(cleanNow),
      'answer': answer.name,
      'answeredAt': nowMs,
      'askCount': newAskCount,
      'lastAskedAt': nowMs,
      'createdAt': existing?.targetDate.millisecondsSinceEpoch ?? nowMs,
      'updatedAt': nowMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // اعمال اثر روی رکوردهای دوره
    switch (answer) {
      case CycleConfirmationAnswer.startedToday:
        await CyclePeriodRepository.instance.startPeriod(
          cleanNow,
          dbExecutor: db,
          now: effectiveNow,
        );
        break;

      case CycleConfirmationAnswer.startedOnOtherDate:
        final dateToStart = resolvedDate ?? cleanNow;
        await CyclePeriodRepository.instance.startPeriod(
          CycleDateContract.cleanDate(dateToStart),
          dbExecutor: db,
          now: effectiveNow,
        );
        break;

      case CycleConfirmationAnswer.endedToday:
        final active = await CyclePeriodRepository.instance.getActivePeriod(db);
        if (active != null && active.id != null) {
          await CyclePeriodRepository.instance.endPeriod(
            active.id!,
            cleanNow,
            dbExecutor: db,
            now: effectiveNow,
          );
        }
        break;

      case CycleConfirmationAnswer.endedOnOtherDate:
        final active = await CyclePeriodRepository.instance.getActivePeriod(db);
        if (active != null && active.id != null) {
          final dateToEnd = resolvedDate ?? cleanNow;
          await CyclePeriodRepository.instance.endPeriod(
            active.id!,
            CycleDateContract.cleanDate(dateToEnd),
            dbExecutor: db,
            now: effectiveNow,
          );
        }
        break;

      case CycleConfirmationAnswer.snoozed:
        final snoozeDate = cleanNow.add(const Duration(days: 1));
        await db.insert('app_settings', {
          'key': CycleSettings.keyConfirmSnoozeUntil,
          'value': CycleDateContract.toDayKey(snoozeDate),
          'updatedAt': nowMs,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        break;

      case CycleConfirmationAnswer.notStartedYet:
      case CycleConfirmationAnswer.stillOngoing:
      case CycleConfirmationAnswer.dismissed:
        // فقط ثبت پاسخ و رد کردن اعلان
        break;
    }

    CycleEngine().invalidate();
    if (db is Database) {
      await CycleReminderScheduler.rescheduleAll(
        dbExecutor: db,
        now: effectiveNow,
      );
    }

    RitmoEventBus().fire(
      RitmoEvent(
        type: 'CycleConfirmationAnswered',
        payload: {'requestId': requestId, 'answer': answer.name},
      ),
    );
  }

  /// ریست شمارنده برای چرخهٔ جدید پس از شروع واقعی
  Future<void> onActualCycleStarted({
    DatabaseExecutor? dbExecutor,
    required DateTime startDate,
  }) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final startKey = CycleDateContract.toDayKey(
        CycleDateContract.cleanDate(startDate),
      );
      await db.delete(
        'cycle_confirmations',
        where: 'targetDate < ?',
        whereArgs: [startKey],
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleConfirmationService] Error resetting cycle confirmations',
        error: e,
        stack: st,
      );
    }
  }

  /// پاک‌کردن تاریخچهٔ قدیمی
  Future<void> pruneOldRequests([DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final cutoffDate = CycleClock.now.subtract(const Duration(days: 90));
      final cutoffKey = CycleDateContract.toDayKey(cutoffDate);
      await db.delete(
        'cycle_confirmations',
        where: 'targetDate < ?',
        whereArgs: [cutoffKey],
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleConfirmationService] Error pruning old requests',
        error: e,
        stack: st,
      );
    }
  }
}
