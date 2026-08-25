import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_plan_generator.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_profile_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_program_calendar.dart';
import 'package:sqflite/sqflite.dart';

/// Handles weekly adaptive plan regeneration based on recent progression signals
/// and completion of the current dated prescription cycle.
class SSAdaptiveScheduler {
  static const int _progressionWindowDays = 42;

  /// Ensures upcoming week's plan is generated adaptively.
  static Future<void> ensureUpcomingWeekReady(
    Database db,
    DateTime today,
  ) async {
    final profile = await SSProfileRepository.instance.getProfile();
    if (profile == null) return;

    final programStart =
        DateTime.tryParse(profile.programStartDate ?? '') ??
        DateTime(today.year, today.month, today.day);
    final nextWeekDate = today.add(const Duration(days: 7));
    final nextWk = SsProgramCalendar.cycleWeekFor(
      nextWeekDate,
      programStart: programStart,
    );

    final check = await db.query(
      'ss_workout_plan',
      where: 'id LIKE ?',
      whereArgs: ['plan_w${nextWk}_%'],
      limit: 1,
    );
    if (check.isNotEmpty) return;

    final signals = await _collectProgressionSignals(db, today);
    final currentWk = SsProgramCalendar.cycleWeekFor(
      today,
      programStart: programStart,
    );
    final completionRate = await _calculateWeekCompletionRate(db, currentWk);

    var effectiveProfile = profile;
    if (completionRate < 0.5 && profile.daysPerWeek > 2) {
      effectiveProfile = profile.copyWith(daysPerWeek: profile.daysPerWeek - 1);
    }

    final isDeloadWeek = SsProgramCalendar.isDeloadWeek(
      nextWk,
      deloadEveryNWeeks: profile.deloadEveryNWeeks,
    );

    await db.transaction((txn) async {
      await SSPlanGenerator.generateWeeklyAndMonthlyPlan(
        txn,
        effectiveProfile,
        week: nextWk,
        progressionSignals: signals,
        isDeload: isDeloadWeek,
      );

      await txn.insert('ss_decision_log', {
        'id': RitmoIdFactory.ssDecision(),
        'userId': 'default',
        'decisionType': isDeloadWeek
            ? 'DELOAD_WEEK_APPLIED'
            : 'WEEK_REGENERATED',
        'rejectionReason':
            'cycleWeek=$nextWk; completion=${(completionRate * 100).toStringAsFixed(0)}%; deload=$isDeloadWeek',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  static Future<Map<String, ProgressionSignal>> _collectProgressionSignals(
    Database db,
    DateTime now,
  ) async {
    final since = now
        .subtract(const Duration(days: _progressionWindowDays))
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      '''
      SELECT exerciseId, feeling, loggedAt
      FROM ss_exercise_feeling_log
      WHERE loggedAt >= ?
      ORDER BY exerciseId ASC, loggedAt DESC
    ''',
      [since],
    );

    final byExercise = <String, List<String>>{};
    for (final row in rows) {
      final exerciseId = row['exerciseId']?.toString();
      final feeling = row['feeling']?.toString().toUpperCase();
      if (exerciseId == null || feeling == null) continue;
      byExercise.putIfAbsent(exerciseId, () => []).add(feeling);
    }

    final signals = <String, ProgressionSignal>{};
    byExercise.forEach((exerciseId, feelings) {
      final latest = feelings.take(3).toList(growable: false);
      if (latest.length < 2) {
        signals[exerciseId] = ProgressionSignal.maintain;
        return;
      }

      final latestTwo = latest.take(2).toList(growable: false);
      final hardCount = latestTwo
          .where((f) => f == 'HARD' || f == 'TOO_HARD')
          .length;
      final easyCount = latestTwo.where((f) => f == 'EASY').length;

      if (hardCount >= 1) {
        signals[exerciseId] = ProgressionSignal.decrease;
      } else if (easyCount == 2) {
        signals[exerciseId] = ProgressionSignal.increase;
      } else {
        signals[exerciseId] = ProgressionSignal.maintain;
      }
    });
    return signals;
  }

  static Future<double> _calculateWeekCompletionRate(
    Database db,
    int week,
  ) async {
    final rows = await db.query(
      'ss_session_prescription',
      columns: ['status'],
      where: 'cycleWeek = ? AND slotType != ?',
      whereArgs: [week, 'REST'],
    );

    if (rows.isEmpty) return 1.0;

    var earned = 0.0;
    for (final row in rows) {
      final status = row['status']?.toString().toUpperCase();
      if (status == 'DONE') earned += 1.0;
      if (status == 'PARTIAL') earned += 0.5;
    }
    return (earned / rows.length).clamp(0.0, 1.0);
  }
}
