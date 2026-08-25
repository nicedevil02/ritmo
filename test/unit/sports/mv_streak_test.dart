import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_hub_controller.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('Real Consecutive Active Weeks Streak Calculation (S0-T3)', () {
    // Reference date: a Tuesday
    final referenceDate = DateTime(2026, 8, 25); // 2026-08-25
    final currentWeekSat = MvCalendar.getWeekSaturday(referenceDate);

    MvSession makeSession({
      required String id,
      required DateTime date,
      MvSessionStatus status = MvSessionStatus.completed,
    }) {
      final at = date.millisecondsSinceEpoch;
      return MvSession(
        id: id,
        kindCode: 'BODYWEIGHT',
        status: status,
        startedAt: at,
        endedAt: at + 1800000,
        createdAt: at,
        updatedAt: at,
      );
    }

    test(
      'Scenario 1: No completed sessions returns null (honest insufficient data)',
      () {
        final result = MvHubController.calculateContinuousWeeks(
          [],
          referenceDate: referenceDate,
        );
        expect(result, isNull);
      },
    );

    test(
      'Scenario 2: 3 continuous weeks with 2+ completed sessions returns 3',
      () {
        final sessions = [
          // Current week (week 0): 2 sessions
          makeSession(
            id: 'w0_1',
            date: currentWeekSat.add(const Duration(days: 0, hours: 10)),
          ),
          makeSession(
            id: 'w0_2',
            date: currentWeekSat.add(const Duration(days: 2, hours: 18)),
          ),
          // 1 week ago (week -1): 2 sessions
          makeSession(
            id: 'w1_1',
            date: currentWeekSat.subtract(const Duration(days: 7 - 1)),
          ),
          makeSession(
            id: 'w1_2',
            date: currentWeekSat.subtract(const Duration(days: 7 - 3)),
          ),
          // 2 weeks ago (week -2): 3 sessions
          makeSession(
            id: 'w2_1',
            date: currentWeekSat.subtract(const Duration(days: 14 - 0)),
          ),
          makeSession(
            id: 'w2_2',
            date: currentWeekSat.subtract(const Duration(days: 14 - 2)),
          ),
          makeSession(
            id: 'w2_3',
            date: currentWeekSat.subtract(const Duration(days: 14 - 4)),
          ),
        ];

        final result = MvHubController.calculateContinuousWeeks(
          sessions,
          referenceDate: referenceDate,
        );
        expect(result, equals(3));
      },
    );

    test(
      'Scenario 3: Gap in the second week (1 week ago has only 1 session) returns 1',
      () {
        final sessions = [
          // Current week (week 0): 2 sessions
          makeSession(
            id: 'w0_1',
            date: currentWeekSat.add(const Duration(days: 0, hours: 10)),
          ),
          makeSession(
            id: 'w0_2',
            date: currentWeekSat.add(const Duration(days: 3, hours: 18)),
          ),
          // 1 week ago (week -1): only 1 session (break in streak)
          makeSession(
            id: 'w1_1',
            date: currentWeekSat.subtract(const Duration(days: 7 - 2)),
          ),
          // 2 weeks ago (week -2): 2 sessions
          makeSession(
            id: 'w2_1',
            date: currentWeekSat.subtract(const Duration(days: 14 - 1)),
          ),
          makeSession(
            id: 'w2_2',
            date: currentWeekSat.subtract(const Duration(days: 14 - 3)),
          ),
        ];

        final result = MvHubController.calculateContinuousWeeks(
          sessions,
          referenceDate: referenceDate,
        );
        expect(result, equals(1));
      },
    );

    test(
      'Scenario 4: 1 session per week returns 0 (threshold is >= 2 active sessions)',
      () {
        final sessions = [
          // Current week: 1 session
          makeSession(
            id: 'w0_1',
            date: currentWeekSat.add(const Duration(days: 1)),
          ),
          // 1 week ago: 1 session
          makeSession(
            id: 'w1_1',
            date: currentWeekSat.subtract(const Duration(days: 6)),
          ),
          // 2 weeks ago: 1 session
          makeSession(
            id: 'w2_1',
            date: currentWeekSat.subtract(const Duration(days: 13)),
          ),
        ];

        final result = MvHubController.calculateContinuousWeeks(
          sessions,
          referenceDate: referenceDate,
        );
        expect(result, equals(0));
      },
    );
  });
}
