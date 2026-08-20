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
  static final CycleConfirmationService instance = CycleConfirmationService._();

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
      final snoozeUntilStr = settings[CycleSettings.keyConfirmSnoozeUntil]
          ?.toString();
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
        final kind = engineOutput.isStartDueToday
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
        final kind = engineOutput.isOpenPeriodBeyondAverage
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
      'targetDate': existing != null
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
          db: db,
          startDate: cleanNow,
          now: effectiveNow,
        );
        break;

      case CycleConfirmationAnswer.startedOnOtherDate:
        final dateToStart = resolvedDate ?? cleanNow;
        await CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: CycleDateContract.cleanDate(dateToStart),
          now: effectiveNow,
        );
        break;

      case CycleConfirmationAnswer.endedToday:
        final active = await CyclePeriodRepository.instance.getOpenPeriod(db);
        if (active != null && active.id.isNotEmpty) {
          await CyclePeriodRepository.instance.endPeriod(
            db: db,
            id: active.id,
            endDate: cleanNow,
            now: effectiveNow,
          );
        }
        break;

      case CycleConfirmationAnswer.endedOnOtherDate:
        final active = await CyclePeriodRepository.instance.getOpenPeriod(db);
        if (active != null && active.id.isNotEmpty) {
          final dateToEnd = resolvedDate ?? cleanNow;
          await CyclePeriodRepository.instance.endPeriod(
            db: db,
            id: active.id,
            endDate: CycleDateContract.cleanDate(dateToEnd),
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

  /// هنگامی که دورهٔ واقعی شروع شد (startPeriod)، درخواست‌های startDue باز حذف/بسته می‌شوند
  /// و cycle_confirm_snooze_until نیز پاک می‌شود.
  Future<void> onActualCycleStarted({
    DatabaseExecutor? dbExecutor,
    required DateTime startDate,
  }) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final cleanStart = CycleDateContract.cleanDate(startDate);
      final maxTargetDate = cleanStart.add(const Duration(days: 7));

      await db.delete(
        'cycle_confirmations',
        where: "kind = 'startDue' AND targetDate <= ?",
        whereArgs: [CycleDateContract.toDayKey(maxTargetDate)],
      );

      await db.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: [CycleSettings.keyConfirmSnoozeUntil],
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleConfirmationService] Error resetting cycle confirmations on start',
        error: e,
        stack: st,
      );
    }
  }

  /// هنگامی که دورهٔ واقعی پایان یافت (endPeriod)، درخواست‌های endDue و bleedingProlonged باز حذف می‌شوند.
  Future<void> onActualCycleEnded({
    DatabaseExecutor? dbExecutor,
    required DateTime endDate,
  }) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final cleanEnd = CycleDateContract.cleanDate(endDate);
      final maxTargetDate = cleanEnd.add(const Duration(days: 7));

      await db.delete(
        'cycle_confirmations',
        where:
            "(kind = 'endDue' OR kind = 'bleedingProlonged') AND targetDate <= ?",
        whereArgs: [CycleDateContract.toDayKey(maxTargetDate)],
      );
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleConfirmationService] Error resetting cycle confirmations on end',
        error: e,
        stack: st,
      );
    }
  }

  /// پاک‌کردن تاریخچهٔ قدیمی (بیش از ۹۰ روز)
  Future<void> pruneOldRequests({
    DatabaseExecutor? dbExecutor,
    DateTime? now,
  }) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final effectiveNow = now ?? CycleClock.now;
      final cutoffDate = effectiveNow.subtract(const Duration(days: 90));
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
