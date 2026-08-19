// C-12, C-14, C-16: CyclePeriodRepository & Model
// Manages cycle period persistence, prevents invalid date order (endDate < startDate),
// prevents future dates, prevents overlapping periods, and handles automatic stale period closure.
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite/sqflite.dart';

class CyclePeriod {
  static const int maxActivePeriodDays = CycleSettings.forgottenOpenPeriodDays;

  final String id;
  final DateTime startDate;
  final DateTime? endDate;
  final String flowIntensity;
  final bool isPredicted;
  final String? note;
  final int createdAt;
  final int updatedAt;

  const CyclePeriod({
    required this.id,
    required this.startDate,
    this.endDate,
    this.flowIntensity = 'MEDIUM',
    this.isPredicted = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => endDate == null;

  /// طول قاعدگی برحسب روز، فقط برای دورهٔ بسته. دورهٔ باز null می‌دهد.
  int? get durationDays => endDate == null
      ? null
      : CycleDateContract.daysBetween(startDate, endDate!) + 1;

  /// تعداد روزهای سپری‌شده از شروع تا تاریخ مرجع (برای دورهٔ باز).
  int elapsedDaysAt(DateTime reference) =>
      CycleDateContract.daysBetween(startDate, reference) + 1;

  Map<String, dynamic> toMap() {
    return {
      CyclePeriodContract.colId: id,
      CyclePeriodContract.colStartDate: CycleDateContract.toDayKey(startDate),
      CyclePeriodContract.colEndDate:
          endDate != null ? CycleDateContract.toDayKey(endDate!) : null,
      CyclePeriodContract.colFlowIntensity: flowIntensity,
      CyclePeriodContract.colIsPredicted: isPredicted ? 1 : 0,
      CyclePeriodContract.colNote: note,
      CyclePeriodContract.colCreatedAt: createdAt,
      CyclePeriodContract.colUpdatedAt: updatedAt,
    };
  }

  factory CyclePeriod.fromMap(Map<String, dynamic> map) {
    final startRaw =
        map[CyclePeriodContract.colStartDate] ?? map['cycleStartDate'];
    final endRaw = map[CyclePeriodContract.colEndDate] ?? map['cycleEndDate'];
    final rawId = (map[CyclePeriodContract.colId] as String?) ?? '';

    return CyclePeriod(
      id: rawId,
      startDate:
          CycleDateContract.parseDayKey(startRaw?.toString()) ?? CycleClock.now,
      endDate: CycleDateContract.parseDayKey(endRaw?.toString()),
      flowIntensity:
          (map[CyclePeriodContract.colFlowIntensity] as String?) ?? 'MEDIUM',
      isPredicted:
          (map[CyclePeriodContract.colIsPredicted] as int? ?? 0) == 1,
      note: (map[CyclePeriodContract.colNote] ?? map['notes']) as String?,
      createdAt: map[CyclePeriodContract.colCreatedAt] as int? ??
          CycleClock.nowMillisecondsSinceEpoch,
      updatedAt: map[CyclePeriodContract.colUpdatedAt] as int? ??
          CycleClock.nowMillisecondsSinceEpoch,
    );
  }
}

class CyclePeriodRepository {
  CyclePeriodRepository._();
  static final CyclePeriodRepository instance = CyclePeriodRepository._();

  /// Fetches all recorded cycle periods sorted chronologically newest-first.
  Future<List<CyclePeriod>> getAllPeriods(DatabaseExecutor db) async {
    try {
      final rows = await db.query(
        CyclePeriodContract.table,
        orderBy: '${CyclePeriodContract.colStartDate} DESC',
      );
      return rows.map((r) => CyclePeriod.fromMap(r)).toList();
    } catch (e, st) {
      RitmoLogger.error(
        '[CyclePeriodRepository] failed to fetch periods',
        error: e,
        stack: st,
      );
      return [];
    }
  }

  /// Fetches the currently open period (endDate is NULL), or null if none active.
  Future<CyclePeriod?> getOpenPeriod(DatabaseExecutor db) async {
    try {
      final rows = await db.query(
        CyclePeriodContract.table,
        where: '${CyclePeriodContract.colEndDate} IS NULL',
        orderBy: '${CyclePeriodContract.colStartDate} DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return CyclePeriod.fromMap(rows.first);
    } catch (e, st) {
      RitmoLogger.error(
        '[CyclePeriodRepository] failed to fetch active period',
        error: e,
        stack: st,
      );
      return null;
    }
  }

  /// Starts a new cycle period on [startDate].
  /// Enforces R1..R10 rules.
  Future<String> startPeriod({
    required DatabaseExecutor db,
    required DateTime startDate,
    String flowIntensity = 'MEDIUM',
    String? note,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? CycleClock.now;
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    final cleanStart = CycleDateContract.cleanDate(startDate);
    final startKey = CycleDateContract.toDayKey(cleanStart);

    // R4: startDate cannot be in the future
    if (cleanStart.isAfter(cleanToday)) {
      throw ArgumentError('تاریخ شروع دوره نمی‌تواند در آینده باشد.');
    }

    // R6: Check active open period
    final active = await getOpenPeriod(db);
    if (active != null) {
      if (CycleDateContract.isSameDay(active.startDate, cleanStart)) {
        RitmoLogger.warning(
          '[CyclePeriodRepository] Duplicate start on same day: $startKey',
        );
        return active.id;
      }
      final elapsed = active.elapsedDaysAt(cleanToday);
      if (elapsed >= CycleSettings.forgottenOpenPeriodDays) {
        // Auto-close with startDate to avoid faking data
        await db.update(
          CyclePeriodContract.table,
          {
            CyclePeriodContract.colEndDate:
                CycleDateContract.toDayKey(active.startDate),
            CyclePeriodContract.colNote: 'auto_closed_unknown_end',
            CyclePeriodContract.colUpdatedAt:
                effectiveNow.millisecondsSinceEpoch,
          },
          where: '${CyclePeriodContract.colId} = ?',
          whereArgs: [active.id],
        );
      } else {
        throw StateError(
          'دورهٔ باز فعال دیگری وجود دارد. ابتدا دورهٔ قبلی را ببندید.',
        );
      }
    }

    // R5: Check for duplicate on the exact same startDate
    final existingSameDay = await db.query(
      CyclePeriodContract.table,
      where: '${CyclePeriodContract.colStartDate} = ?',
      whereArgs: [startKey],
      limit: 1,
    );
    if (existingSameDay.isNotEmpty) {
      RitmoLogger.warning(
        '[CyclePeriodRepository] Existing period on same start date: $startKey',
      );
      return (existingSameDay.first[CyclePeriodContract.colId] as String?) ?? '';
    }

    // R4: Overlap check with existing periods
    final all = await getAllPeriods(db);
    for (final p in all) {
      final pEnd = p.endDate ?? cleanToday;
      if (CycleDateContract.inWindow(cleanStart, p.startDate, pEnd)) {
        throw ArgumentError(
          'تاریخ شروع با یکی از دوره‌های ثبت‌شده هم‌پوشانی دارد.',
        );
      }
    }

    // R1, R2, R3: Insert new row
    final newId = CyclePeriodContract.newId();
    final nowMs = effectiveNow.millisecondsSinceEpoch;

    await db.insert(CyclePeriodContract.table, {
      CyclePeriodContract.colId: newId,
      CyclePeriodContract.colStartDate: startKey,
      CyclePeriodContract.colEndDate: null,
      CyclePeriodContract.colFlowIntensity: flowIntensity,
      CyclePeriodContract.colIsPredicted: 0,
      CyclePeriodContract.colNote: note,
      CyclePeriodContract.colCreatedAt: nowMs,
      CyclePeriodContract.colUpdatedAt: nowMs,
    });

    // R7: Mandatory invalidate
    CycleEngine().invalidate();
    return newId;
  }

  /// Ends the period [id] on [endDate].
  /// Enforces R1..R10 rules.
  Future<void> endPeriod({
    required DatabaseExecutor db,
    required String id,
    required DateTime endDate,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? CycleClock.now;
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    final cleanEnd = CycleDateContract.cleanDate(endDate);

    final rows = await db.query(
      CyclePeriodContract.table,
      where: '${CyclePeriodContract.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    // R8: No silent return
    if (rows.isEmpty) {
      throw StateError('دوره‌ای با شناسهٔ مشخص‌شده یافت نشد.');
    }

    final period = CyclePeriod.fromMap(rows.first);

    // R4: Validation guards
    if (cleanEnd.isBefore(period.startDate)) {
      throw ArgumentError('تاریخ پایان نمی‌تواند قبل از تاریخ شروع باشد.');
    }
    if (cleanEnd.isAfter(cleanToday)) {
      throw ArgumentError('تاریخ پایان نمی‌تواند در آینده باشد.');
    }

    final duration =
        CycleDateContract.daysBetween(period.startDate, cleanEnd) + 1;
    if (duration > CycleSettings.forgottenOpenPeriodDays) {
      throw ArgumentError(
        'طول دوره نمی‌تواند بیش از ${CycleSettings.forgottenOpenPeriodDays} روز باشد.',
      );
    }

    final nowMs = effectiveNow.millisecondsSinceEpoch;
    await db.update(
      CyclePeriodContract.table,
      {
        CyclePeriodContract.colEndDate: CycleDateContract.toDayKey(cleanEnd),
        CyclePeriodContract.colUpdatedAt: nowMs,
      },
      where: '${CyclePeriodContract.colId} = ?',
      whereArgs: [id],
    );

    // R7: Mandatory invalidate
    CycleEngine().invalidate();
  }

  /// Updates an existing period [id].
  Future<void> updatePeriod({
    required DatabaseExecutor db,
    required String id,
    required DateTime startDate,
    DateTime? endDate,
    String? flowIntensity,
    String? note,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? CycleClock.now;
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    final cleanStart = CycleDateContract.cleanDate(startDate);
    final cleanEnd =
        endDate != null ? CycleDateContract.cleanDate(endDate) : null;

    final rows = await db.query(
      CyclePeriodContract.table,
      where: '${CyclePeriodContract.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('دوره‌ای با شناسهٔ مشخص‌شده برای ویرایش یافت نشد.');
    }

    // R4: Guards
    if (cleanStart.isAfter(cleanToday)) {
      throw ArgumentError('تاریخ شروع دوره نمی‌تواند در آینده باشد.');
    }
    if (cleanEnd != null) {
      if (cleanEnd.isBefore(cleanStart)) {
        throw ArgumentError('تاریخ پایان نمی‌تواند قبل از تاریخ شروع باشد.');
      }
      if (cleanEnd.isAfter(cleanToday)) {
        throw ArgumentError('تاریخ پایان نمی‌تواند در آینده باشد.');
      }
      final duration =
          CycleDateContract.daysBetween(cleanStart, cleanEnd) + 1;
      if (duration > CycleSettings.forgottenOpenPeriodDays) {
        throw ArgumentError(
          'طول دوره نمی‌تواند بیش از ${CycleSettings.forgottenOpenPeriodDays} روز باشد.',
        );
      }
    }

    // Check overlap with OTHER periods
    final all = await getAllPeriods(db);
    for (final p in all) {
      if (p.id == id) continue;
      final pEnd = p.endDate ?? cleanToday;
      if (CycleDateContract.inWindow(cleanStart, p.startDate, pEnd)) {
        throw ArgumentError(
          'تاریخ شروع با یکی از دوره‌های دیگر هم‌پوشانی دارد.',
        );
      }
      if (cleanEnd != null &&
          CycleDateContract.inWindow(cleanEnd, p.startDate, pEnd)) {
        throw ArgumentError(
          'تاریخ پایان با یکی از دوره‌های دیگر هم‌پوشانی دارد.',
        );
      }
    }

    final nowMs = effectiveNow.millisecondsSinceEpoch;
    final updateMap = <String, dynamic>{
      CyclePeriodContract.colStartDate: CycleDateContract.toDayKey(cleanStart),
      CyclePeriodContract.colEndDate:
          cleanEnd != null ? CycleDateContract.toDayKey(cleanEnd) : null,
      CyclePeriodContract.colUpdatedAt: nowMs,
    };
    if (flowIntensity != null) {
      updateMap[CyclePeriodContract.colFlowIntensity] = flowIntensity;
    }
    if (note != null) {
      updateMap[CyclePeriodContract.colNote] = note;
    }

    await db.update(
      CyclePeriodContract.table,
      updateMap,
      where: '${CyclePeriodContract.colId} = ?',
      whereArgs: [id],
    );

    // R7: Mandatory invalidate
    CycleEngine().invalidate();
  }

  /// Deletes a period by [id].
  Future<void> deletePeriod({
    required DatabaseExecutor db,
    required String id,
  }) async {
    final rows = await db.query(
      CyclePeriodContract.table,
      where: '${CyclePeriodContract.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('دوره‌ای با شناسهٔ مشخص‌شده برای حذف یافت نشد.');
    }

    await db.delete(
      CyclePeriodContract.table,
      where: '${CyclePeriodContract.colId} = ?',
      whereArgs: [id],
    );

    // R7: Mandatory invalidate
    CycleEngine().invalidate();
  }

  /// Pre-validation helper for UI sheets.
  static String? validatePeriodRange({
    required List<CyclePeriod> existing,
    required String? editingId,
    required DateTime startDate,
    DateTime? endDate,
    DateTime? now,
  }) {
    final effectiveNow = now ?? CycleClock.now;
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    final cleanStart = CycleDateContract.cleanDate(startDate);
    final cleanEnd =
        endDate != null ? CycleDateContract.cleanDate(endDate) : null;

    if (cleanStart.isAfter(cleanToday)) {
      return 'تاریخ شروع نمی‌تواند در آینده باشد.';
    }
    if (cleanEnd != null) {
      if (cleanEnd.isBefore(cleanStart)) {
        return 'تاریخ پایان نمی‌تواند قبل از شروع باشد.';
      }
      if (cleanEnd.isAfter(cleanToday)) {
        return 'تاریخ پایان نمی‌تواند در آینده باشد.';
      }
      final duration =
          CycleDateContract.daysBetween(cleanStart, cleanEnd) + 1;
      if (duration > CycleSettings.forgottenOpenPeriodDays) {
        return 'طول دوره نمی‌تواند بیش از ${CycleSettings.forgottenOpenPeriodDays} روز باشد.';
      }
    }

    for (final p in existing) {
      if (editingId != null && p.id == editingId) continue;
      final pEnd = p.endDate ?? cleanToday;
      if (CycleDateContract.inWindow(cleanStart, p.startDate, pEnd)) {
        return 'تاریخ شروع با دورهٔ دیگری هم‌پوشانی دارد.';
      }
      if (cleanEnd != null &&
          CycleDateContract.inWindow(cleanEnd, p.startDate, pEnd)) {
        return 'تاریخ پایان با دورهٔ دیگری هم‌پوشانی دارد.';
      }
    }

    return null;
  }
}
