import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/budget_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('Week-bounded Budget Progress Tests (S0-T5)', () {
    const budgetEngine = BudgetEngine();

    test('25 scattered sessions across 3 weeks -> only current week sessions count toward budget', () {
      final now = DateTime(2026, 8, 25); // Tuesday of current week
      final currentWeekSat = MvCalendar.getWeekSaturday(now);
      final weekStart = DateTime(currentWeekSat.year, currentWeekSat.month, currentWeekSat.day, 0, 0, 0);
      final weekEnd = DateTime(currentWeekSat.year, currentWeekSat.month, currentWeekSat.day + 6, 23, 59, 59, 999);

      final allSessions = <MvSession>[];

      // 10 sessions in previous week (-1)
      for (int i = 0; i < 10; i++) {
        final dt = currentWeekSat.subtract(Duration(days: 7 - (i % 7)));
        final ms = dt.millisecondsSinceEpoch;
        allSessions.add(
          MvSession(
            id: 'prev_$i',
            kindCode: 'WALKING',
            status: MvSessionStatus.completed,
            startedAt: ms,
            endedAt: ms + 1800000, // 30 min
            createdAt: ms,
            updatedAt: ms,
          ),
        );
      }

      // 5 sessions in current week (2 completed, 2 partial, 1 active)
      for (int i = 0; i < 5; i++) {
        final dt = currentWeekSat.add(Duration(days: i, hours: 10));
        final ms = dt.millisecondsSinceEpoch;
        final status = i == 4 ? MvSessionStatus.active : (i % 2 == 0 ? MvSessionStatus.completed : MvSessionStatus.partial);
        allSessions.add(
          MvSession(
            id: 'curr_$i',
            kindCode: 'WALKING',
            status: status,
            startedAt: ms,
            endedAt: ms + 1800000, // 30 min
            createdAt: ms,
            updatedAt: ms,
          ),
        );
      }

      // 10 sessions in next week (+1)
      for (int i = 0; i < 10; i++) {
        final dt = currentWeekSat.add(Duration(days: 7 + (i % 7)));
        final ms = dt.millisecondsSinceEpoch;
        allSessions.add(
          MvSession(
            id: 'next_$i',
            kindCode: 'WALKING',
            status: MvSessionStatus.completed,
            startedAt: ms,
            endedAt: ms + 1800000,
            createdAt: ms,
            updatedAt: ms,
          ),
        );
      }

      expect(allSessions.length, equals(25));

      // Filter to current week completed / partial sessions
      final fromMs = weekStart.millisecondsSinceEpoch;
      final toMs = weekEnd.millisecondsSinceEpoch;
      final weekSessions = allSessions.where(
        (s) => s.startedAt >= fromMs && s.startedAt <= toMs && (s.status == MvSessionStatus.completed || s.status == MvSessionStatus.partial),
      ).toList();

      expect(weekSessions.length, equals(4)); // 4 finished sessions in current week

      final decision = budgetEngine.calculateWeeklyProgress(
        weekCompletedSessions: weekSessions,
        currentDayOfWeekSat0: 3,
      );

      // 4 sessions of 30 min = 120 moderate-equivalent minutes
      expect(decision.value.moderateEquivalentMinutes, equals(120));
      expect(decision.value.currentActiveDays, equals(4));
    });

    test('Guard Test: getRecentSessions is NOT called in mv_hub_controller.dart on budget path', () {
      final file = File('lib/features/supplementary_sports/application/mv_hub_controller.dart');
      final content = file.readAsStringSync();

      expect(content.contains('getRecentSessions'), isFalse,
          reason: 'mv_hub_controller must not call getRecentSessions for budget');
    });
  });
}
