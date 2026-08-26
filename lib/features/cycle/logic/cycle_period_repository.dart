// C-12, C-14, C-16: CyclePeriodRepository & Model
// Manages cycle period persistence, prevents invalid date order (endDate < startDate),
// prevents future dates, prevents overlapping periods, and handles automatic stale period closure.
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_confirmation_service.dart';
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
  final bool autoClosed;
  final int createdAt;
  final int updatedAt;

  const CyclePeriod({
    required this.id,
    required this.startDate,
    this.endDate,
    this.flowIntensity = 'MEDIUM',
    this.isPredicted = false,
    this.note,
    this.autoClosed = false,
    this.createdAt = 0,
    this.updatedAt = 0,
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
      CyclePeriodContract.colEndDate: endDate != null
          ? CycleDateContract.toDayKey(endDate!)
          : null,
      CyclePeriodContract.colFlowIntensity: flowIntensity,
      CyclePeriodContract.colIsPredicted: isPredicted ? 1 : 0,
      CyclePeriodContract.colNote: note,
      CyclePeriodContract.colAutoClosed: autoClosed ? 1 : 0,
      CyclePeriodContract.colCreatedAt: createdAt,
      CyclePeriodContract.colUpdatedAt: updatedAt,
    };
  }

  static CyclePeriod? tryFromMap(Map<String, dynamic> map) {
    final startRaw =
        map[CyclePeriodContract.colStartDate] ?? map['cycleStartDate'];
    final endRaw = map[CyclePeriodContract.colEndDate] ?? map['cycleEndDate'];
    final start = CycleDateContract.parseDayKey(startRaw?.toString());
    if (start == null) {
      RitmoLogger.error('[CyclePeriod] Corrupt or missing startDate: $startRaw');
      return null;
    }
    final rawId = (map[CyclePeriodContract.colId] as String?) ?? '';

    return CyclePeriod(
      id: rawId,
      startDate: start,
      endDate: CycleDateContract.parseDayKey(endRaw?.toString()),
      flowIntensity:
          (map[CyclePeriodContract.colFlowIntensity] as String?) ?? 'MEDIUM',
      isPredicted: (map[CyclePeriodContract.colIsPredicted] as int? ?? 0) == 1,
      note: (map[CyclePeriodContract.colNote] ?? map['notes']) as String?,
      autoClosed: (map[CyclePeriodContract.colAutoClosed] as int? ?? 0) == 1,
      createdAt:
          map[CyclePeriodContract.colCreatedAt] as int? ??
          CycleClock.nowMillisecondsSinceEpoch,
      updatedAt:
          map[CyclePeriodContract.colUpdatedAt] as int? ??
          CycleClock.nowMillisecondsSinceEpoch,
    );
  }

  factory CyclePeriod.fromMap(Map<String, dynamic> map) {
    return tryFromMap(map) ?? CyclePeriod(id: '', startDate: CycleClock.now);
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
      return rows
          .map((r) => CyclePeriod.tryFromMap(r))
          .whereType<CyclePeriod>()
          .toList();
    } catch (e, st) {
      RitmoLogger.error(
        '[CyclePeriodRepository] getAllPeriods failed: $e',
        error: e,
        stack: st,
      );
      return const [];
    }
  }

  /// Fetches the current open cycle period (where endDate is null), if any.
  Future<CyclePeriod?> getOpenPeriod(DatabaseExecutor db) async {
    try {
      final rows = await db.query(
        CyclePeriodContract.table,
        where: '${CyclePeriodContract.colEndDate} IS NULL',
        orderBy: '${CyclePeriodContract.colStartDate} DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return CyclePeriod.tryFromMap(rows.first);
    } catch (e, st) {
      RitmoLogger.error(
        '[CyclePeriodRepository] getOpenPeriod failed: $e',
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
      throw ArgumentError('startDate cannot be in the future');
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
        // Auto-close with user-configured period duration (fallback 6 days) or before cleanStart with autoClosed = 1
        int estimatedDurationDays = 6;
        try {
          final settingsList = await db.query(
            'app_settings',
            where:
                "key = 'period_duration_days' OR key = 'user_period_duration_days'",
          );
          for (final s in settingsList) {
            final val = int.tryParse(s['value']?.toString() ?? '');
            if (val != null && val >= 3 && val <= 10) {
              estimatedDurationDays = val;
              break;
            }
          }
        } catch (e, st) {
          RitmoLogger.warning(
            '[CyclePeriodRepository] Failed to read period_duration_days: $e',
            error: e,
            stack: st,
          );
        }

        final estimatedEnd = active.startDate.add(
          Duration(days: estimatedDurationDays - 1),
        );
        final safeEnd = estimatedEnd.isBefore(cleanStart)
            ? estimatedEnd
            : cleanStart.subtract(const Duration(days: 1));
        final finalEnd = safeEnd.isBefore(active.startDate)
            ? active.startDate
            : safeEnd;
        final existingNote = active.note ?? '';
        final noteToSave = existingNote.isNotEmpty
            ? '$existingNote [auto-closed]'
            : '[auto-closed]';
        await db.update(
          CyclePeriodContract.table,
          {
            CyclePeriodContract.colEndDate: CycleDateContract.toDayKey(
              finalEnd,
            ),
            CyclePeriodContract.colAutoClosed: 1,
            CyclePeriodContract.colNote: noteToSave,
            CyclePeriodContract.colUpdatedAt:
                effectiveNow.millisecondsSinceEpoch,
          },
          where: '${CyclePeriodContract.colId} = ?',
          whereArgs: [active.id],
        );
      } else {
        throw StateError(
          'Another active open period already exists. Close it first.',
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
      return (existingSameDay.first[CyclePeriodContract.colId] as String?) ??
          '';
    }

    // R4: Overlap check with existing periods using contract overlaps & effectiveEnd
    final all = await getAllPeriods(db);
    final newEffectiveEnd = CycleDateContract.effectiveEnd(
      start: cleanStart,
      end: null,
      today: cleanToday,
      maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
    );
    for (final p in all) {
      final pEnd = CycleDateContract.effectiveEnd(
        start: p.startDate,
        end: p.endDate,
        today: cleanToday,
        maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
      );
      if (CycleDateContract.overlaps(
        cleanStart,
        newEffectiveEnd,
        p.startDate,
        pEnd,
      )) {
        throw ArgumentError(
          'startDate overlaps with an existing recorded period.',
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
      CyclePeriodContract.colAutoClosed: 0,
      CyclePeriodContract.colCreatedAt: nowMs,
      CyclePeriodContract.colUpdatedAt: nowMs,
    });

    // Phase 10: Sync confirmation requests
    await CycleConfirmationService.instance.onActualCycleStarted(
      dbExecutor: db,
      startDate: cleanStart,
    );

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
      throw StateError('Period with specified id not found.');
    }

    final period = CyclePeriod.tryFromMap(rows.first);
    if (period == null) {
      throw StateError('Period with specified id has corrupt or invalid data.');
    }
    if (!period.isOpen) {
      throw StateError('Period is already closed.');
    }

    // R4: Validation guards
    if (cleanEnd.isBefore(period.startDate)) {
      throw ArgumentError('endDate cannot be before startDate.');
    }
    if (cleanEnd.isAfter(cleanToday)) {
      throw ArgumentError('endDate cannot be in the future.');
    }

    final duration =
        CycleDateContract.daysBetween(period.startDate, cleanEnd) + 1;
    if (duration > CycleSettings.maxPeriodDuration) {
      throw ArgumentError(
        'Period duration cannot exceed ${CycleSettings.maxPeriodDuration} days.',
      );
    }

    // Overlap check with other periods
    final all = await getAllPeriods(db);
    for (final p in all) {
      if (p.id == id) continue;
      final pEnd = CycleDateContract.effectiveEnd(
        start: p.startDate,
        end: p.endDate,
        today: cleanToday,
        maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
      );
      if (CycleDateContract.overlaps(
        period.startDate,
        cleanEnd,
        p.startDate,
        pEnd,
      )) {
        throw ArgumentError('endDate overlaps with a subsequent period.');
      }
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

    // Phase 10: Sync confirmation requests
    await CycleConfirmationService.instance.onActualCycleEnded(
      dbExecutor: db,
      endDate: cleanEnd,
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
    bool clearEndDate = false,
    String? flowIntensity,
    String? note,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? CycleClock.now;
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    final cleanStart = CycleDateContract.cleanDate(startDate);
    final cleanEnd = endDate != null
        ? CycleDateContract.cleanDate(endDate)
        : null;

    final rows = await db.query(
      CyclePeriodContract.table,
      where: '${CyclePeriodContract.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Period with specified id for update not found.');
    }

    final period = CyclePeriod.tryFromMap(rows.first);
    if (period == null) {
      throw StateError('Period with specified id for update has corrupt or invalid data.');
    }

    // R4: Guards
    if (cleanStart.isAfter(cleanToday)) {
      throw ArgumentError('startDate cannot be in the future.');
    }
    if (cleanEnd != null) {
      if (cleanEnd.isBefore(cleanStart)) {
        throw ArgumentError('endDate cannot be before startDate.');
      }
      if (cleanEnd.isAfter(cleanToday)) {
        throw ArgumentError('endDate cannot be in the future.');
      }
      final duration = CycleDateContract.daysBetween(cleanStart, cleanEnd) + 1;
      if (duration > CycleSettings.maxPeriodDuration) {
        throw ArgumentError(
          'Period duration cannot exceed ${CycleSettings.maxPeriodDuration} days.',
        );
      }
    }

    // Check overlap with OTHER periods
    final targetEnd = clearEndDate
        ? CycleDateContract.effectiveEnd(
            start: cleanStart,
            end: null,
            today: cleanToday,
            maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
          )
        : (cleanEnd ??
            (period.endDate != null
                ? CycleDateContract.cleanDate(period.endDate!)
                : CycleDateContract.effectiveEnd(
                    start: cleanStart,
                    end: null,
                    today: cleanToday,
                    maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
                  )));

    final all = await getAllPeriods(db);
    for (final p in all) {
      if (p.id == id) continue;
      final pEnd = CycleDateContract.effectiveEnd(
        start: p.startDate,
        end: p.endDate,
        today: cleanToday,
        maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
      );
      if (CycleDateContract.overlaps(
        cleanStart,
        targetEnd,
        p.startDate,
        pEnd,
      )) {
        throw ArgumentError(
          'Updated period range overlaps with another period.',
        );
      }
    }

    final nowMs = effectiveNow.millisecondsSinceEpoch;
    final updateMap = <String, dynamic>{
      CyclePeriodContract.colStartDate: CycleDateContract.toDayKey(cleanStart),
      CyclePeriodContract.colUpdatedAt: nowMs,
    };
    if (clearEndDate) {
      updateMap[CyclePeriodContract.colEndDate] = null;
    } else if (cleanEnd != null) {
      updateMap[CyclePeriodContract.colEndDate] = CycleDateContract.toDayKey(
        cleanEnd,
      );
    }
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
      throw StateError('Period with specified id for deletion not found.');
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
    final cleanEnd = endDate != null
        ? CycleDateContract.cleanDate(endDate)
        : null;

    if (cleanStart.isAfter(cleanToday)) {
      return 'startDate cannot be in the future.';
    }
    if (cleanEnd != null) {
      if (cleanEnd.isBefore(cleanStart)) {
        return 'endDate cannot be before startDate.';
      }
      if (cleanEnd.isAfter(cleanToday)) {
        return 'endDate cannot be in the future.';
      }
      final duration = CycleDateContract.daysBetween(cleanStart, cleanEnd) + 1;
      if (duration > CycleSettings.maxPeriodDuration) {
        return 'Period duration cannot exceed ${CycleSettings.maxPeriodDuration} days.';
      }
    }

    final targetEnd = cleanEnd ?? cleanToday;
    for (final p in existing) {
      if (editingId != null && p.id == editingId) continue;
      final pEnd = CycleDateContract.effectiveEnd(
        start: p.startDate,
        end: p.endDate,
        today: cleanToday,
        maxPlausibleDays: CycleSettings.maxPlausiblePeriodDays,
      );
      if (CycleDateContract.overlaps(
        cleanStart,
        targetEnd,
        p.startDate,
        pEnd,
      )) {
        return 'Period date range overlaps with another period.';
      }
    }

    return null;
  }
}
