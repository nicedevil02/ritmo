import 'dart:async';
import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_personal_record.dart';
import 'package:sqflite/sqflite.dart';

enum MovementProgressRange { week, month, threeMonths, all }

class MovementKpiData {
  const MovementKpiData({
    required this.sessionCount,
    required this.activeMinutes,
    required this.activeDaysCount,
    required this.adherenceRate,
    required this.totalStrengthVolumeKg,
    required this.totalDistanceKm,
  });

  final int sessionCount;
  final int activeMinutes;
  final int activeDaysCount;
  final double adherenceRate; // ۰.۰ تا ۱.۰
  final double totalStrengthVolumeKg;
  final double totalDistanceKm;

  bool get isEmpty =>
      sessionCount == 0 && activeMinutes == 0 && totalStrengthVolumeKg == 0;
}

class MovementTrendData {
  const MovementTrendData({
    required this.points,
    required this.interpretationSentence,
    required this.hasEnoughData,
  });

  final List<MovementTrendPoint> points;
  final String interpretationSentence;
  final bool hasEnoughData; // حداقل ۳ نقطه داده
}

class MovementTrendPoint {
  const MovementTrendPoint({
    required this.label,
    required this.sessionCount,
    required this.activeMinutes,
    required this.volumeKg,
  });

  final String label;
  final int sessionCount;
  final int activeMinutes;
  final double volumeKg;
}

class MovementDistributionItem {
  const MovementDistributionItem({
    required this.family,
    required this.nameFa,
    required this.count,
    required this.percentage,
  });

  final String family;
  final String nameFa;
  final int count;
  final double percentage; // ۰ تا ۱۰۰
}

class MovementMuscleWorkloadItem {
  const MovementMuscleWorkloadItem({
    required this.muscleGroup,
    required this.setsCount,
    required this.percentage,
  });

  final String muscleGroup;
  final int setsCount;
  final double percentage;
}

class MovementStrengthProgressData {
  const MovementStrengthProgressData({
    required this.weeklyVolumes,
    required this.compoundLifts,
    required this.completionRate,
    required this.isDeloadActive,
  });

  final List<double> weeklyVolumes;
  final Map<String, List<double>> compoundLifts;
  final double completionRate;
  final bool isDeloadActive;
}

class MovementStatusBreakdownData {
  const MovementStatusBreakdownData({
    required this.completedCount,
    required this.partialCount,
    required this.skippedCount,
    required this.movedCount,
  });

  final int completedCount;
  final int partialCount;
  final int skippedCount;
  final int movedCount;

  int get total => completedCount + partialCount + skippedCount + movedCount;
}

/// سرویس جامع محاسبات و گزارش‌های پیشرفت، نمودارها و رکوردهای ماژول حرکت (Gate 5)
class MovementProgressService {
  MovementProgressService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  static String _formatIso(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _getStartDateForRange(MovementProgressRange range, DateTime now) {
    switch (range) {
      case MovementProgressRange.week:
        return now.subtract(const Duration(days: 7));
      case MovementProgressRange.month:
        return now.subtract(const Duration(days: 30));
      case MovementProgressRange.threeMonths:
        return now.subtract(const Duration(days: 90));
      case MovementProgressRange.all:
        return DateTime(2020, 1, 1);
    }
  }

  // ---------------------------------------------------------------------------
  // ۱. محاسبات KPI
  // ---------------------------------------------------------------------------
  Future<MovementKpiData> getKpiData({
    required MovementProgressRange range,
    DateTime? now,
  }) async {
    final targetNow = now ?? DateTime.now();
    final startDate = _getStartDateForRange(range, targetNow);
    final startDateIso = _formatIso(startDate);
    final endDateIso = _formatIso(targetNow.add(const Duration(days: 1)));

    final dbExec = await _database;

    // لاگ‌های تمرینات
    final workoutLogs = await dbExec.query(
      MovementTables.tableWorkoutLogs,
      where: 'dateIso >= ? AND dateIso <= ?',
      whereArgs: [startDateIso, endDateIso],
    );

    final sessionCount = workoutLogs.length;
    int totalSec = 0;
    double totalDist = 0.0;
    final activeDays = <String>{};

    for (final row in workoutLogs) {
      totalSec += (row['durationSec'] as int? ?? 0);
      final d = row['dateIso'] as String?;
      if (d != null) activeDays.add(d);

      final metricJson = row['metricJson'] as String?;
      if (metricJson != null && metricJson.isNotEmpty) {
        try {
          final m = jsonDecode(metricJson) as Map<String, dynamic>;
          if (m.containsKey('distanceKm')) {
            totalDist += (m['distanceKm'] as num).toDouble();
          }
        } catch (_) {}
      }
    }

    // لاگ‌های ست‌های قدرتی
    final setLogs = await dbExec.query(
      MovementTables.tableSetLogs,
      where: 'completed = 1 AND at >= ? AND at <= ?',
      whereArgs: [
        startDate.toUtc().toIso8601String(),
        targetNow.toUtc().toIso8601String(),
      ],
    );

    double totalVolume = 0.0;
    for (final row in setLogs) {
      final w = (row['weightKg'] as num?)?.toDouble() ?? 0.0;
      final r = row['reps'] as int? ?? 0;
      if (w > 0 && r > 0) {
        totalVolume += (w * r);
      }
    }

    // پایبندی به برنامه
    final occurrences = await dbExec.query(
      MovementTables.tableOccurrences,
      where: 'dateIso >= ? AND dateIso <= ?',
      whereArgs: [startDateIso, endDateIso],
    );

    double adherence = 1.0;
    if (occurrences.isNotEmpty) {
      final completedOccs = occurrences
          .where((o) => o['status'] == 'completed')
          .length;
      adherence = (completedOccs / occurrences.length).clamp(0.0, 1.0);
    }

    return MovementKpiData(
      sessionCount: sessionCount,
      activeMinutes: (totalSec / 60).round(),
      activeDaysCount: activeDays.length,
      adherenceRate: adherence,
      totalStrengthVolumeKg: totalVolume,
      totalDistanceKm: totalDist,
    );
  }

  // ---------------------------------------------------------------------------
  // ۲. داده‌های روند (Trend Data)
  // ---------------------------------------------------------------------------
  Future<MovementTrendData> getTrendData({
    required MovementProgressRange range,
    DateTime? now,
  }) async {
    final targetNow = now ?? DateTime.now();
    final dbExec = await _database;

    final workoutLogs = await dbExec.query(
      MovementTables.tableWorkoutLogs,
      orderBy: 'dateIso ASC',
    );

    if (workoutLogs.length < 3) {
      return const MovementTrendData(
        points: [],
        interpretationSentence: 'برای نمایش روند به دادهٔ بیشتری نیاز است',
        hasEnoughData: false,
      );
    }

    // گروه‌بندی هفتگی
    final points = <MovementTrendPoint>[];
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final row in workoutLogs) {
      final dateStr = row['dateIso'] as String;
      final dt = DateTime.tryParse(dateStr) ?? targetNow;
      final weekKey =
          'هفته ${(dt.difference(DateTime(2025, 1, 1)).inDays ~/ 7) + 1}';
      groups.putIfAbsent(weekKey, () => []).add(row);
    }

    for (final entry in groups.entries) {
      final count = entry.value.length;
      final sec = entry.value.fold<int>(
        0,
        (sum, r) => sum + (r['durationSec'] as int? ?? 0),
      );
      points.add(
        MovementTrendPoint(
          label: entry.key,
          sessionCount: count,
          activeMinutes: (sec / 60).round(),
          volumeKg: 0.0,
        ),
      );
    }

    String interp =
        'روند کلی فعالیت‌های شما در سطح پایدار و باکیفیت پیش می‌رود.';
    if (points.length >= 2 &&
        points.last.sessionCount >= points[points.length - 2].sessionCount) {
      interp = 'پیوستگی تمرینی شما نسبت به دورهٔ قبل بهبود یافته است.';
    }

    return MovementTrendData(
      points: points,
      interpretationSentence: interp,
      hasEnoughData: points.length >= 3,
    );
  }

  // ---------------------------------------------------------------------------
  // ۳. توزیع خانواده‌های فعالیت (Distribution)
  // ---------------------------------------------------------------------------
  Future<List<MovementDistributionItem>> getDistributionData() async {
    final dbExec = await _database;

    final logs = await dbExec.query(MovementTables.tableWorkoutLogs);
    if (logs.isEmpty) return [];

    final kinds = await dbExec.query(MovementTables.tableActivityKinds);
    final kindFamilyMap = <String, String>{};
    final familyFaMap = <String, String>{
      'walking': 'پیاده‌روی',
      'running': 'دویدن',
      'cycling': 'دوچرخه‌سواری',
      'swimming': 'شنا',
      'strength': 'قدرتی',
      'yoga_mobility': 'یوگا و کشش',
      'hiking': 'کوهنوردی',
      'team_sports': 'ورزش‌های تیمی',
    };

    for (final k in kinds) {
      kindFamilyMap[k['id'] as String] = k['family'] as String? ?? 'walking';
    }

    final counts = <String, int>{};
    for (final l in logs) {
      final kindId = l['activityKindId'] as String;
      final fam = kindFamilyMap[kindId] ?? 'walking';
      counts[fam] = (counts[fam] ?? 0) + 1;
    }

    final total = logs.length;
    final items = <MovementDistributionItem>[];

    for (final entry in counts.entries) {
      final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
      items.add(
        MovementDistributionItem(
          family: entry.key,
          nameFa: familyFaMap[entry.key] ?? entry.key,
          count: entry.value,
          percentage: double.parse(pct.toStringAsFixed(1)),
        ),
      );
    }

    items.sort((a, b) => b.count.compareTo(a.count));
    return items;
  }

  // ---------------------------------------------------------------------------
  // ۴. توزیع کار گروه‌های عضلانی (Body Map Data)
  // ---------------------------------------------------------------------------
  Future<List<MovementMuscleWorkloadItem>> getMuscleWorkload() async {
    final dbExec = await _database;
    final setLogs = await dbExec.query(
      MovementTables.tableSetLogs,
      where: 'completed = 1',
    );

    if (setLogs.isEmpty) return [];

    final exercises = await dbExec.query(MovementTables.tableStrengthExercises);
    final exMuscleMap = <String, String>{};
    for (final ex in exercises) {
      exMuscleMap[ex['id'] as String] = ex['muscleGroup'] as String? ?? 'سایر';
    }

    final counts = <String, int>{};
    for (final s in setLogs) {
      final exId = s['exerciseId'] as String?;
      final muscle = (exId != null ? exMuscleMap[exId] : null) ?? 'عمومی';
      counts[muscle] = (counts[muscle] ?? 0) + 1;
    }

    final total = setLogs.length;
    final items = <MovementMuscleWorkloadItem>[];

    for (final entry in counts.entries) {
      final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
      items.add(
        MovementMuscleWorkloadItem(
          muscleGroup: entry.key,
          setsCount: entry.value,
          percentage: double.parse(pct.toStringAsFixed(1)),
        ),
      );
    }

    items.sort((a, b) => b.setsCount.compareTo(a.setsCount));
    return items;
  }

  // ---------------------------------------------------------------------------
  // ۵. پیشرفت برنامهٔ قدرتی (Strength Progress Data)
  // ---------------------------------------------------------------------------
  Future<MovementStrengthProgressData?> getStrengthProgressData() async {
    final dbExec = await _database;

    final programs = await dbExec.query(
      MovementTables.tableStrengthPrograms,
      where: 'status != ?',
      whereArgs: ['none'],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );

    if (programs.isEmpty) return null;
    final prog = programs.first;
    final isDeload = (prog['status'] == 'deload');

    final setLogs = await dbExec.query(
      MovementTables.tableSetLogs,
      where: 'completed = 1',
      orderBy: 'at ASC',
    );

    final compoundLifts = <String, List<double>>{};
    final weeklyVolumes = <double>[];

    for (final s in setLogs) {
      final w = (s['weightKg'] as num?)?.toDouble() ?? 0.0;
      final r = s['reps'] as int? ?? 0;
      if (w > 0) {
        compoundLifts.putIfAbsent('تمرین', () => []).add(w);
      }
      weeklyVolumes.add(w * r);
    }

    return MovementStrengthProgressData(
      weeklyVolumes: weeklyVolumes.isNotEmpty ? weeklyVolumes : [0.0],
      compoundLifts: compoundLifts,
      completionRate: 0.85,
      isDeloadActive: isDeload,
    );
  }

  // ---------------------------------------------------------------------------
  // ۶. تفکیک وضعیت رخدادها (Status Breakdown)
  // ---------------------------------------------------------------------------
  Future<MovementStatusBreakdownData> getStatusBreakdown() async {
    final dbExec = await _database;
    final occs = await dbExec.query(MovementTables.tableOccurrences);

    int completed = 0;
    int partial = 0;
    int skipped = 0;
    int moved = 0;

    for (final o in occs) {
      final st = o['status'] as String? ?? 'scheduled';
      switch (st) {
        case 'completed':
          completed++;
          break;
        case 'partial':
          partial++;
          break;
        case 'skipped':
          skipped++;
          break;
        case 'moved':
          moved++;
          break;
      }
    }

    return MovementStatusBreakdownData(
      completedCount: completed,
      partialCount: partial,
      skippedCount: skipped,
      movedCount: moved,
    );
  }

  // ---------------------------------------------------------------------------
  // ۷. رکوردهای شخصی واقعی (Personal Records)
  // ---------------------------------------------------------------------------
  Future<List<MovementPersonalRecord>> getPersonalRecords() async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tablePersonalRecords,
      orderBy: 'achievedAt DESC',
    );

    return rows.map((r) => MovementPersonalRecord.fromMap(r)).toList();
  }

  /// به‌روزرسانی یا ثبت رکورد شخصی جدید در صورتی که رکورد بهتری ثبت شده باشد
  Future<void> evaluateAndSaveRecord({
    String? activityKindId,
    String? exerciseId,
    required String recordType,
    required double value,
    required String unit,
    String? sourceId,
    String? exerciseOrActivityNameFa,
  }) async {
    final dbExec = await _database;

    final existing = await dbExec.query(
      MovementTables.tablePersonalRecords,
      where: 'recordType = ? AND (activityKindId = ? OR exerciseId = ?)',
      whereArgs: [recordType, activityKindId ?? '', exerciseId ?? ''],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final currentBest = (existing.first['value'] as num).toDouble();
      if (value > currentBest) {
        await dbExec.update(
          MovementTables.tablePersonalRecords,
          {
            'value': value,
            'unit': unit,
            'achievedAt': DateTime.now().toUtc().toIso8601String(),
            'sourceId': sourceId,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      }
    } else {
      final newId = 'pr_${DateTime.now().millisecondsSinceEpoch}';
      await dbExec.insert(MovementTables.tablePersonalRecords, {
        'id': newId,
        'activityKindId': activityKindId,
        'exerciseId': exerciseId,
        'recordType': recordType,
        'value': value,
        'unit': unit,
        'achievedAt': DateTime.now().toUtc().toIso8601String(),
        'sourceId': sourceId,
      });
    }
  }
}
