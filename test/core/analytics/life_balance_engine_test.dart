import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/life_balance_engine.dart';

void main() {
  test('life balance with no routines is unknown', () {
    final res = LifeBalanceEngine.calculateLifeBalanceScore(
      routines: [],
      routineCompletions: [],
    );
    expect(res, isNull);
  });

  test('life balance needs ten completions', () {
    final routines = [
      {'id': 'r1', 'category': 'HEALTH', 'isArchived': 0},
      {'id': 'r2', 'category': 'WORK', 'isArchived': 0},
    ];
    final completions = List.generate(
      9,
      (i) => {'routineId': 'r1', 'resultType': 'FULL'},
    );

    final score9 = LifeBalanceEngine.calculateLifeBalanceScore(
      routines: routines,
      routineCompletions: completions,
    );
    expect(score9, isNull);

    final completions10 = List.generate(
      10,
      (i) => {'routineId': 'r1', 'resultType': 'FULL'},
    );
    final score10 = LifeBalanceEngine.calculateLifeBalanceScore(
      routines: routines,
      routineCompletions: completions10,
    );
    expect(score10, isNotNull);
  });

  test('balance trend keys are numeric', () {
    final trends = LifeBalanceEngine.calculateBalanceTrend(
      now: DateTime(2026, 1, 15),
      routines: [],
      routineCompletions: [],
    );
    expect(trends.keys, containsAll([1, 2, 3, 4]));
  });

  test('duration-weighted balance gives lower score when one domain dominates in time', () {
    final routines = [
      {'id': 'r1', 'category': 'RELIGION', 'targetDurationMinutes': 10, 'isArchived': 0},
      {'id': 'r2', 'category': 'WORK', 'targetDurationMinutes': 120, 'isArchived': 0},
    ];
    // 5 completions each (10 total completions)
    // r1: 5 * 10 = 50 mins
    // r2: 5 * 120 = 600 mins
    final completions = [
      ...List.generate(5, (i) => {'routineId': 'r1', 'resultType': 'FULL'}),
      ...List.generate(5, (i) => {'routineId': 'r2', 'resultType': 'FULL'}),
    ];

    final score = LifeBalanceEngine.calculateLifeBalanceScore(
      routines: routines,
      routineCompletions: completions,
    );
    expect(score, isNotNull);
    expect(score, lessThan(80)); // Much lower than 100 because work took 92% of the time!
  });

  test('perfectly balanced time allocation gives score close to 100', () {
    final routines = [
      {'id': 'r1', 'category': 'HEALTH', 'targetDurationMinutes': 30, 'isArchived': 0},
      {'id': 'r2', 'category': 'LEARNING', 'targetDurationMinutes': 30, 'isArchived': 0},
    ];
    final completions = [
      ...List.generate(5, (i) => {'routineId': 'r1', 'resultType': 'FULL'}),
      ...List.generate(5, (i) => {'routineId': 'r2', 'resultType': 'FULL'}),
    ];

    final score = LifeBalanceEngine.calculateLifeBalanceScore(
      routines: routines,
      routineCompletions: completions,
    );
    expect(score, 100);
  });

  test('category distribution accurately reflects duration percentages and domainMinutes', () {
    final routines = [
      {'id': 'r1', 'category': 'HEALTH', 'targetDurationMinutes': 30, 'isArchived': 0},
      {'id': 'r2', 'category': 'WORK', 'targetDurationMinutes': 90, 'isArchived': 0},
    ];
    final completions = [
      {'routineId': 'r1', 'resultType': 'FULL'}, // 30 min
      {'routineId': 'r2', 'resultType': 'FULL'}, // 90 min
    ];

    final dist = LifeBalanceEngine.calculateCategoryDistribution(
      routines: routines,
      routineCompletions: completions,
    );
    expect(dist['HEALTH'], closeTo(25.0, 0.1));
    expect(dist['WORK'], closeTo(75.0, 0.1));

    final domainMinutes = LifeBalanceEngine.calculateDomainMinutes(
      routines: routines,
      routineCompletions: completions,
    );
    expect(domainMinutes['HEALTH'], 30);
    expect(domainMinutes['WORK'], 90);
  });
}
