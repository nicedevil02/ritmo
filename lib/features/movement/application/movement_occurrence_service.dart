import 'dart:async';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_stats.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_summary.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس مدیریت رخدادها و جلسات برنامهٔ حرکتی در لایهٔ Application
class MovementOccurrenceService {
  MovementOccurrenceService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  // کش فعالیت‌ها
  final Map<String, MovementActivityKind> _activityCache = {};

  Future<MovementActivityKind?> getActivityKind(String id) async {
    if (_activityCache.containsKey(id)) {
      return _activityCache[id];
    }
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableActivityKinds,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final kind = MovementActivityKind.fromMap(rows.first);
    _activityCache[id] = kind;
    return kind;
  }

  Future<List<MovementActivityKind>> getAllActivityKinds() async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableActivityKinds,
      where: 'archivedAt IS NULL',
      orderBy: 'isFavorite DESC, nameFa ASC',
    );
    final kinds = rows.map((e) => MovementActivityKind.fromMap(e)).toList();
    for (final k in kinds) {
      _activityCache[k.id] = k;
    }
    return kinds;
  }

  /// ایجاد یک نوع فعالیت سفارشی جدید توسط کاربر
  Future<MovementActivityKind> createCustomActivityKind({
    required String nameFa,
    String? nameEn,
    required String family,
    required String icon,
    required String primaryMetric,
    List<String>? defaultUnits,
  }) async {
    final dbExec = await _database;
    final id = 'kind_custom_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc().toIso8601String();

    final kind = MovementActivityKind(
      id: id,
      nameFa: nameFa,
      nameEn: nameEn,
      family: family,
      icon: icon,
      primaryMetric: primaryMetric,
      isCustom: true,
      createdAt: DateTime.now(),
    );

    await dbExec.insert(MovementTables.tableActivityKinds, {
      'id': id,
      'nameFa': nameFa,
      'nameEn': nameEn,
      'aliasesJson': null,
      'family': family,
      'icon': icon,
      'primaryMetric': primaryMetric,
      'defaultUnitsJson': defaultUnits != null
          ? '[${defaultUnits.map((u) => '"$u"').join(',')}]'
          : null,
      'isCustom': 1,
      'isFavorite': 0,
      'archivedAt': null,
      'createdAt': now,
    });

    _activityCache[id] = kind;
    return kind;
  }

  /// تغییر وضعیت علاقه‌مندی یک فعالیت
  Future<void> toggleFavoriteActivityKind(String id, [bool? isFavorite]) async {
    final dbExec = await _database;
    final current = await getActivityKind(id);
    final target = isFavorite ?? !(current?.isFavorite ?? false);
    await dbExec.update(
      MovementTables.tableActivityKinds,
      {'isFavorite': target ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (_activityCache.containsKey(id)) {
      _activityCache[id] = _activityCache[id]!.copyWith(isFavorite: target);
    }
  }

  /// آرشیو کردن فعالیت سفارشی بدون حذف لاگ‌های قبلی
  Future<void> archiveCustomActivityKind(String id) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableActivityKinds,
      {'archivedAt': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    _activityCache.remove(id);
  }

  /// دریافت رخداد با شناسه همراه با نوع فعالیت
  Future<MovementOccurrence?> getOccurrenceById(String occurrenceId) async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableOccurrences,
      where: 'id = ?',
      whereArgs: [occurrenceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final kindId = row['activityKindId'] as String;
    final kind = await getActivityKind(kindId);
    return MovementOccurrence.fromMap(row, activityKind: kind);
  }

  /// دریافت لاگ‌های ثبت‌شده برای یک Occurrence
  Future<List<MovementWorkoutLog>> getOccurrenceLogs(
    String occurrenceId,
  ) async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableWorkoutLogs,
      where: 'occurrenceId = ?',
      whereArgs: [occurrenceId],
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => MovementWorkoutLog.fromMap(r)).toList();
  }

  /// خواندن Occurrenceهای یک بازهٔ هفتگی
  Future<List<MovementOccurrence>> getOccurrencesForRange(
    String startDateIso,
    String endDateIso,
  ) async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableOccurrences,
      where: 'dateIso >= ? AND dateIso <= ?',
      whereArgs: [startDateIso, endDateIso],
      orderBy: 'dateIso ASC, startTime ASC, createdAt ASC',
    );

    await getAllActivityKinds(); // پر کردن کش

    return rows.map((row) {
      final kindId = row['activityKindId'] as String;
      return MovementOccurrence.fromMap(
        row,
        activityKind: _activityCache[kindId],
      );
    }).toList();
  }

  /// گروهبندی رخدادها بر اساس تاریخ روز (YYYY-MM-DD)
  Future<Map<String, List<MovementOccurrence>>> getWeekOccurrencesGrouped(
    String startDateIso,
    String endDateIso,
  ) async {
    final list = await getOccurrencesForRange(startDateIso, endDateIso);
    final Map<String, List<MovementOccurrence>> map = {};
    for (final occ in list) {
      map.putIfAbsent(occ.dateIso, () => []).add(occ);
    }
    return map;
  }

  /// محاسبه خلاصهٔ ۳ متریکی هفته
  Future<MovementWeekSummary> getWeekSummary(
    String startDateIso,
    String endDateIso,
    List<String> allSevenDaysIso,
  ) async {
    final occurrences = await getOccurrencesForRange(startDateIso, endDateIso);

    int completed = 0;
    final int planned = occurrences.length;
    int activeMinutes = 0;
    final Set<String> daysWithActivity = {};

    for (final occ in occurrences) {
      if (occ.isCompleted) {
        completed++;
        if (occ.goalType == 'duration' && occ.goalValue != null) {
          activeMinutes += occ.goalValue!.round();
        } else {
          activeMinutes += 30; // پیش‌فرض منطقی
        }
      }
      daysWithActivity.add(occ.dateIso);
    }

    // روزهای ریکاوری = روزهایی از هفته که هیچ فعالیتی در آنها برنامه‌ریزی نشده
    var recoveryDays = 0;
    for (final d in allSevenDaysIso) {
      if (!daysWithActivity.contains(d)) {
        recoveryDays++;
      }
    }

    return MovementWeekSummary(
      completedCount: completed,
      plannedCount: planned,
      activeMinutes: activeMinutes,
      recoveryDaysCount: recoveryDays,
    );
  }

  /// محاسبه آمار هفتگی کاربر بر اساس شنبه تا جمعه (P-04)
  Future<MovementWeekStats> weekStats(DateTime anchor) async {
    final sat = DateTime(anchor.year, anchor.month, anchor.day)
        .subtract(Duration(days: (anchor.weekday % 7 + 1) % 7));
    final fri = sat.add(const Duration(days: 6));
    final startIso = sat.toIso8601String().split('T').first;
    final endIso = fri.toIso8601String().split('T').first;

    final occs = await getOccurrencesForRange(startIso, endIso);
    final dbExec = await _database;
    final logRows = await dbExec.query(
      MovementTables.tableWorkoutLogs,
      where: 'dateIso >= ? AND dateIso <= ?',
      whereArgs: [startIso, endIso],
    );

    final planned = occs.length;
    final doneOccCount = occs.where((o) => o.isCompleted).length;
    final retroCount = logRows.where((l) => l['occurrenceId'] == null).length;
    final done = doneOccCount + retroCount;

    final totalSec = logRows.fold<int>(0, (sum, r) => sum + ((r['durationSec'] as int?) ?? 0));
    final totalMinutes = (totalSec / 60).round();

    final activeDays = logRows.map((r) => r['dateIso'] as String).toSet().length;

    MovementMetric<double> adherence;
    if (planned >= 4) {
      final val = (done / planned).clamp(0.0, 1.0);
      adherence = MovementMetric(value: val, sampleSize: planned, reason: MovementMetricReason.ok);
    } else if (planned > 0) {
      adherence = MovementMetric(value: null, sampleSize: planned, reason: MovementMetricReason.partialData);
    } else {
      adherence = const MovementMetric.noData();
    }

    return MovementWeekStats(
      plannedCount: planned,
      doneCount: done,
      activeStreakDays: activeDays,
      totalMinutes: totalMinutes,
      adherence: adherence,
      hasAnyData: planned > 0 || done > 0,
    );
  }

  Future<void> saveOccurrence(MovementOccurrence occurrence) async {
    final dbExec = await _database;
    await dbExec.insert(
      MovementTables.tableOccurrences,
      occurrence.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateOccurrenceStatus(
    String occurrenceId,
    MovementOccurrenceStatus newStatus,
  ) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableOccurrences,
      {
        'status': newStatus.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  Future<void> moveOccurrence(String occurrenceId, String targetDateIso) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableOccurrences,
      {
        'dateIso': targetDateIso,
        'movedToDateIso': targetDateIso,
        'status': MovementOccurrenceStatus.moved.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  Future<void> deleteOccurrence(String occurrenceId) async {
    final dbExec = await _database;
    await dbExec.delete(
      MovementTables.tableOccurrences,
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }
}
