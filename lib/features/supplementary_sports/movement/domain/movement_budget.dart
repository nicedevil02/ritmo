import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:shamsi_date/shamsi_date.dart';

class MovementBudgetSnapshot {
  const MovementBudgetSnapshot({
    required this.weeklyMetMinutesTarget,
    required this.achievedMetMinutes,
    required this.activeDays,
    required this.targetActiveDays,
    required this.byFamily,
    required this.byKind,
    required this.daysRemaining,
    required this.projectedTotal,
    required this.events,
    required this.kindsByCode,
  });

  final double weeklyMetMinutesTarget;
  final double achievedMetMinutes;
  final int activeDays;
  final int targetActiveDays;
  final Map<MovementFamily, double> byFamily;
  final Map<String, double> byKind;
  final int daysRemaining;
  final double? projectedTotal;
  final List<MovementEvent> events;
  final Map<String, MovementKind> kindsByCode;

  double get progressRatio => weeklyMetMinutesTarget > 0
      ? (achievedMetMinutes / weeklyMetMinutesTarget).clamp(0.0, 2.0)
      : 0.0;

  bool get isGoalMet => achievedMetMinutes >= weeklyMetMinutesTarget;
}

class MovementBudgetService {
  MovementBudgetService._();
  static final instance = MovementBudgetService._();

  /// Calculate the current week's movement budget snapshot (Persian week starting Saturday).
  Future<MovementBudgetSnapshot> getCurrentWeekSnapshot() async {
    final db = await DatabaseHelper.instance.database;

    // Load budget target configuration (default 500 MET-min, 4 active days)
    double targetMetMinutes = 500.0;
    int targetActiveDays = 4;

    try {
      bool hasExp = false;
      bool hasDays = false;
      try {
        final info = await db.rawQuery('PRAGMA table_info(ss_user_profile)');
        hasExp = info.any((row) => row['name'] == 'experienceLevel');
        hasDays = info.any((row) => row['name'] == 'daysPerWeek');
      } catch (_) {}

      if (hasExp && hasDays) {
        final profRows = await db.query('ss_user_profile', where: "id = 'default'", limit: 1);
        if (profRows.isNotEmpty) {
          final prof = profRows.first;
          final exp = prof['experienceLevel']?.toString().toUpperCase() ?? 'BEGINNER';
          final days = (prof['daysPerWeek'] as num? ?? 3).toInt();
          
          targetActiveDays = days;
          if (exp == 'ADVANCED' || days >= 5) {
            targetMetMinutes = 800.0;
          } else if (exp == 'INTERMEDIATE' || exp == 'MODERATE' || days == 4) {
            targetMetMinutes = 500.0;
          } else {
            targetMetMinutes = 300.0;
          }
        }
      } else {
        // Fallback to movement_budget table
        final bRows = await db.query('movement_budget', where: "id = 'default'", limit: 1);
        if (bRows.isNotEmpty) {
          targetMetMinutes = (bRows.first['weeklyMetMinutesTarget'] as num? ?? 500.0).toDouble();
          targetActiveDays = (bRows.first['weeklyActiveDaysTarget'] as num? ?? 4).toInt();
        }
      }
    } catch (e) {
      debugPrint('[MovementBudget] budget config read failed, using defaults: $e');
    }

    // Calculate Persian week start (Saturday)
    final now = DateTime.now();
    final jalali = Jalali.fromDateTime(now);
    final dayOfWeekIndex = jalali.weekDay - 1; // Jalali weekDay: 1=Shanbe (0 offset) to 7=Jomeh (6 offset)

    final startOfWeekDate = now.subtract(Duration(days: dayOfWeekIndex));
    final startOfWeek = DateTime(startOfWeekDate.year, startOfWeekDate.month, startOfWeekDate.day);
    final endOfWeekExclusive = startOfWeek.add(const Duration(days: 7)); // شنبهٔ هفتهٔ بعد، ناشمول
    final events = await MovementRepository.instance.eventsInRangeMs(
      startOfWeek.millisecondsSinceEpoch,
      endOfWeekExclusive.millisecondsSinceEpoch,
    );

    final kindRows = await db.query('movement_kinds');
    final kindsByCode = <String, MovementKind>{
      for (final r in kindRows) r['code'] as String: MovementKind.fromMap(r),
    };

    double totalMetMins = 0.0;
    final byFamily = <MovementFamily, double>{};
    final byKind = <String, double>{};
    final activeDates = <String>{};

    for (final e in events) {
      totalMetMins += e.metMinutes;
      byKind[e.kindCode] = (byKind[e.kindCode] ?? 0.0) + e.metMinutes;

      final kind = kindsByCode[e.kindCode];
      final family = kind?.family ?? MovementFamily.endurance;
      byFamily[family] = (byFamily[family] ?? 0.0) + e.metMinutes;

      final dt = DateTime.fromMillisecondsSinceEpoch(e.loggedAt);
      activeDates.add('${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}');
    }

    final daysPassed = (dayOfWeekIndex + 1).clamp(1, 7);
    final daysRemaining = (7 - daysPassed).clamp(0, 6);

    double? projectedTotal;
    if (daysPassed >= 3 && totalMetMins > 0) {
      final dailyPace = totalMetMins / daysPassed;
      projectedTotal =
          (totalMetMins + dailyPace * daysRemaining).clamp(0.0, targetMetMinutes * 1.5);
    }

    return MovementBudgetSnapshot(
      weeklyMetMinutesTarget: targetMetMinutes,
      achievedMetMinutes: totalMetMins,
      activeDays: activeDates.length,
      targetActiveDays: targetActiveDays,
      byFamily: byFamily,
      byKind: byKind,
      daysRemaining: daysRemaining,
      projectedTotal: projectedTotal,
      events: events,
      kindsByCode: kindsByCode,
    );
  }
}
