import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('S4-T6 LoadEngine & ACWR / sRPE Unit Tests (§4.3)', () {
    const engine = LoadEngine();

    test('5-row table test for ACWR load ratio and bandKey resolution', () {
      final testCases = [
        // Case 1: Insufficient history / sessions (< 14 days or < 6 sessions) -> null
        {
          'desc':
              'Insufficient data (10 days, 4 sessions) -> ratio null & bandKey null',
          'acute': 1200,
          'chronicWeekly': 1000.0,
          'days': 10,
          'sessions': 4,
          'expectedRatio': null,
          'expectedBand': null,
        },
        // Case 2: ratio = 0.6 (< 0.8) -> mv_load_band_low
        {
          'desc': 'Ratio 0.6 -> mv_load_band_low',
          'acute': 600,
          'chronicWeekly': 1000.0,
          'days': 28,
          'sessions': 12,
          'expectedRatio': 0.6,
          'expectedBand': 'mv_load_band_low',
        },
        // Case 3: ratio = 1.0 (0.8 .. 1.3) -> mv_load_band_optimal
        {
          'desc': 'Ratio 1.0 -> mv_load_band_optimal',
          'acute': 1000,
          'chronicWeekly': 1000.0,
          'days': 28,
          'sessions': 12,
          'expectedRatio': 1.0,
          'expectedBand': 'mv_load_band_optimal',
        },
        // Case 4: ratio = 1.4 (1.3 .. 1.5) -> mv_load_band_watch
        {
          'desc': 'Ratio 1.4 -> mv_load_band_watch',
          'acute': 1400,
          'chronicWeekly': 1000.0,
          'days': 28,
          'sessions': 12,
          'expectedRatio': 1.4,
          'expectedBand': 'mv_load_band_watch',
        },
        // Case 5: ratio = 1.8 (> 1.5) -> mv_load_band_spike
        {
          'desc': 'Ratio 1.8 -> mv_load_band_spike',
          'acute': 1800,
          'chronicWeekly': 1000.0,
          'days': 28,
          'sessions': 12,
          'expectedRatio': 1.8,
          'expectedBand': 'mv_load_band_spike',
        },
      ];

      for (final tc in testCases) {
        final snapshot = engine.computeFromLoads(
          acuteLoad: tc['acute'] as int,
          chronicWeeklyLoad: tc['chronicWeekly'] as double,
          daysOfHistory: tc['days'] as int,
          completedSessions: tc['sessions'] as int,
        );

        if (tc['expectedRatio'] == null) {
          expect(snapshot.ratio, isNull, reason: tc['desc'] as String);
          expect(snapshot.bandKey, isNull, reason: tc['desc'] as String);
          expect(snapshot.hasEnoughData, isFalse);
        } else {
          expect(
            snapshot.ratio,
            closeTo(tc['expectedRatio'] as double, 0.001),
            reason: tc['desc'] as String,
          );
          expect(
            snapshot.bandKey,
            equals(tc['expectedBand']),
            reason: tc['desc'] as String,
          );
          expect(snapshot.hasEnoughData, isTrue);
        }
      }
    });

    test(
      'Session-based load calculation sums acute (7 days) and chronic (28 days / 4)',
      () {
        final now = DateTime(2026, 8, 25, 12, 0);

        // Create 8 completed sessions over 20 days
        final sessions = <MvSession>[];
        // 2 sessions in the last 7 days (acute)
        sessions.add(
          MvSession(
            id: 's1',
            kindCode: 'FUTSAL',
            status: MvSessionStatus.completed,
            startedAt: now
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch,
            endedAt:
                now.subtract(const Duration(days: 2)).millisecondsSinceEpoch +
                (60 * 60 * 1000), // 60 min
            rpe1To10: 8, // sessionLoad = 480
            createdAt: 100,
            updatedAt: 100,
          ),
        );
        sessions.add(
          MvSession(
            id: 's2',
            kindCode: 'RUNNING',
            status: MvSessionStatus.completed,
            startedAt: now
                .subtract(const Duration(days: 5))
                .millisecondsSinceEpoch,
            endedAt:
                now.subtract(const Duration(days: 5)).millisecondsSinceEpoch +
                (30 * 60 * 1000), // 30 min
            rpe1To10: 6, // sessionLoad = 180
            createdAt: 100,
            updatedAt: 100,
          ),
        );
        // 6 sessions between days 8 and 27
        for (int i = 1; i <= 6; i++) {
          sessions.add(
            MvSession(
              id: 's_older_$i',
              kindCode: 'BODYWEIGHT',
              status: MvSessionStatus.completed,
              startedAt: now
                  .subtract(Duration(days: 8 + (i * 2)))
                  .millisecondsSinceEpoch,
              endedAt:
                  now
                      .subtract(Duration(days: 8 + (i * 2)))
                      .millisecondsSinceEpoch +
                  (40 * 60 * 1000), // 40 min
              rpe1To10: 5, // sessionLoad = 200 each -> total 1200
              createdAt: 100,
              updatedAt: 100,
            ),
          );
        }

        // Total acute load (days 0..7) = 480 + 180 = 660
        // Total 28-day sum = 480 + 180 + 1200 = 1860
        // Chronic weekly load = 1860 / 4.0 = 465.0
        // Ratio = 660 / 465.0 = 1.419... -> band = mv_load_band_watch (1.3..1.5)

        final snapshot = engine.computeLoadSnapshot(
          completedSessions: sessions,
          daysOfHistory: 25,
          referenceDate: now,
        );

        expect(snapshot.acuteLoad, equals(660));
        expect(snapshot.chronicWeeklyLoad, equals(465.0));
        expect(snapshot.ratio, closeTo(1.419, 0.01));
        expect(snapshot.bandKey, equals('mv_load_band_watch'));
        expect(snapshot.completedSessions, equals(8));
        expect(snapshot.hasEnoughData, isTrue);
      },
    );
  });
}
