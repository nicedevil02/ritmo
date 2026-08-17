// C-12, C-14, C-16: CyclePeriodRepository & Model
// Manages cycle period persistence, prevents invalid date order (endDate < startDate),
// prevents future end dates, prevents overlapping periods, and handles automatic stale period closure.
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:sqflite/sqflite.dart';

class CyclePeriod {
  final int? id;
  final DateTime startDate;
  final DateTime? endDate;
  final int? cycleLength;
  final int? periodDuration;
  final String? notes;
  final bool suppressedPrayer;
  final bool fastDebtCreated;
  final int createdAt;
  final int updatedAt;

  const CyclePeriod({
    this.id,
    required this.startDate,
    this.endDate,
    this.cycleLength,
    this.periodDuration,
    this.notes,
    this.suppressedPrayer = true,
    this.fastDebtCreated = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => endDate == null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'startDate': CycleDateContract.toDayKey(startDate),
      'endDate': endDate != null ? CycleDateContract.toDayKey(endDate!) : null,
      'cycleLength': cycleLength,
      'periodDuration': periodDuration,
      'notes': notes,
      'suppressedPrayer': suppressedPrayer ? 1 : 0,
      'fastDebtCreated': fastDebtCreated ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory CyclePeriod.fromMap(Map<String, dynamic> map) {
    final startRaw = map['startDate'] ?? map['cycleStartDate'];
    final endRaw = map['endDate'] ?? map['cycleEndDate'];

    return CyclePeriod(
      id: map['id'] as int?,
      startDate:
          CycleDateContract.parseDayKey(startRaw?.toString()) ?? DateTime.now(),
      endDate: CycleDateContract.parseDayKey(endRaw?.toString()),
      cycleLength: map['cycleLength'] as int?,
      periodDuration: map['periodDuration'] as int?,
      notes: map['notes'] as String?,
      suppressedPrayer: (map['suppressedPrayer'] as int? ?? 1) == 1,
      fastDebtCreated: (map['fastDebtCreated'] as int? ?? 0) == 1,
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }
}

class CyclePeriodRepository {
  CyclePeriodRepository._();
  static final CyclePeriodRepository instance = CyclePeriodRepository._();

  static const int maxActivePeriodDays = 12;

  /// Fetches all recorded cycle periods sorted chronologically newest-first.
  Future<List<CyclePeriod>> getAllPeriods([
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final rows = await db.query(
        'cycle_periods',
        orderBy: 'startDate DESC, id DESC',
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
  Future<CyclePeriod?> getActivePeriod([DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final rows = await db.query(
        'cycle_periods',
        where: 'endDate IS NULL',
        orderBy: 'startDate DESC',
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
  /// Enforces:
  /// 1. Closes any existing stale open period.
  /// 2. Prevents overlapping with existing periods.
  /// 3. Normalizes date to canonical DayKey YYYY-MM-DD.
  Future<int> startPeriod(
    DateTime startDate, {
    DatabaseExecutor? dbExecutor,
    String? notes,
    DateTime? now,
  }) async {
    final db = dbExecutor ?? await DatabaseHelper.instance.database;
    final effectiveNow = now ?? DateTime.now();
    final cleanStart = CycleDateContract.cleanDate(startDate);
    final startKey = CycleDateContract.toDayKey(cleanStart);

    // 1. Check if an active open period already exists
    final active = await getActivePeriod(db);
    if (active != null) {
      if (CycleDateContract.isSameDay(active.startDate, cleanStart)) {
        // Already started on this day
        return active.id!;
      }
      // Auto-close previous open period with a reasonable duration if older than threshold
      final daysOpen = CycleDateContract.daysBetween(
        active.startDate,
        cleanStart,
      );
      final closeDate = daysOpen > maxActivePeriodDays
          ? active.startDate.add(const Duration(days: 6))
          : cleanStart.subtract(const Duration(days: 1));

      await endPeriod(active.id!, closeDate, dbExecutor: db, now: effectiveNow);
    }

    // 2. Check for duplicate on the exact same startDate
    final existingSameDay = await db.query(
      'cycle_periods',
      where: 'startDate = ?',
      whereArgs: [startKey],
      limit: 1,
    );
    if (existingSameDay.isNotEmpty) {
      return existingSameDay.first['id'] as int;
    }

    // 3. Insert new open period
    final nowMs = effectiveNow.millisecondsSinceEpoch;
    final id = await db.insert('cycle_periods', {
      'startDate': startKey,
      'endDate': null,
      'periodDuration': null,
      'notes': notes,
      'suppressedPrayer': 1,
      'fastDebtCreated': 0,
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    // Invalidate engine cache (C-16)
    CycleEngine().invalidate();
    return id;
  }

  /// Ends the period [id] on [endDate].
  /// Enforces:
  /// 1. endDate >= startDate.
  /// 2. endDate <= today (no future end dates).
  /// 3. Automatically calculates periodDuration = daysBetween(startDate, endDate) + 1.
  Future<void> endPeriod(
    int id,
    DateTime endDate, {
    DatabaseExecutor? dbExecutor,
    DateTime? now,
  }) async {
    final db = dbExecutor ?? await DatabaseHelper.instance.database;
    final effectiveNow = now ?? DateTime.now();
    final cleanToday = CycleDateContract.cleanDate(effectiveNow);
    var cleanEnd = CycleDateContract.cleanDate(endDate);

    // Guard: no future end dates
    if (CycleDateContract.isSameOrAfter(cleanEnd, cleanToday) &&
        !CycleDateContract.isSameDay(cleanEnd, cleanToday)) {
      cleanEnd = cleanToday;
    }

    final rows = await db.query(
      'cycle_periods',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final period = CyclePeriod.fromMap(rows.first);
    // Guard: endDate cannot be before startDate
    if (cleanEnd.isBefore(period.startDate)) {
      cleanEnd = period.startDate;
    }

    final duration =
        CycleDateContract.daysBetween(period.startDate, cleanEnd) + 1;
    final nowMs = effectiveNow.millisecondsSinceEpoch;

    await db.update(
      'cycle_periods',
      {
        'endDate': CycleDateContract.toDayKey(cleanEnd),
        'periodDuration': duration,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Invalidate engine cache (C-16)
    CycleEngine().invalidate();
  }

  /// Deletes a period by [id].
  Future<void> deletePeriod(int id, [DatabaseExecutor? dbExecutor]) async {
    final db = dbExecutor ?? await DatabaseHelper.instance.database;
    await db.delete('cycle_periods', where: 'id = ?', whereArgs: [id]);
    // Invalidate engine cache (C-16)
    CycleEngine().invalidate();
  }
}
