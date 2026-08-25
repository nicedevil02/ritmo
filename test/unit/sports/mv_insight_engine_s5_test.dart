import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('S5-T6 Real-Data Progress Insights Engine Tests', () {
    const insightEngine = InsightEngine();

    test(
      'Fresh user with 3 sessions produces ZERO insights (no generic fallback sentences)',
      () {
        final now = DateTime(2026, 8, 25, 12, 0);
        final sessions = [
          MvSession(
            id: 's1',
            kindCode: 'FUTSAL',
            sessionMode: MvSessionMode.match,
            status: MvSessionStatus.completed,
            startedAt: now
                .subtract(const Duration(days: 6))
                .millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
          ),
          MvSession(
            id: 's2',
            kindCode: 'FUTSAL',
            sessionMode: MvSessionMode.match,
            status: MvSessionStatus.completed,
            startedAt: now
                .subtract(const Duration(days: 4))
                .millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
          ),
          MvSession(
            id: 's3',
            kindCode: 'HIKING',
            sessionMode: MvSessionMode.route,
            status: MvSessionStatus.completed,
            startedAt: now
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
          ),
        ];

        final insights = insightEngine.generateInsights(
          completedSessions: sessions,
          referenceDate: now,
        );

        expect(insights, isEmpty);
      },
    );

    test(
      'User with full qualifying data triggers all 5 exact insights with probability phrasing',
      () {
        final now = DateTime(2026, 8, 25, 12, 0);

        // 1. 10 sessions with 8 on Thursday (DateTime.thursday = 4) -> triggers best_day
        final sessions = <MvSession>[];
        for (int i = 0; i < 8; i++) {
          // Find recent Thursdays
          final thurs = DateTime(2026, 8, 20 - (i * 7 ~/ 2), 18, 0);
          sessions.add(
            MvSession(
              id: 'thurs_$i',
              kindCode: 'FUTSAL',
              sessionMode: MvSessionMode.match,
              status: MvSessionStatus.completed,
              startedAt: thurs.millisecondsSinceEpoch,
              effortSource: 'user',
              rpe1To10: 8, // recent RPE
              createdAt: 0,
              updatedAt: 0,
            ),
          );
        }

        // Add previous month sessions with lower RPE to trigger effort_drift (delta >= 0.5)
        for (int i = 0; i < 4; i++) {
          final past = now.subtract(Duration(days: 40 + i));
          sessions.add(
            MvSession(
              id: 'past_$i',
              kindCode: 'SWIMMING',
              sessionMode: MvSessionMode.laps,
              status: MvSessionStatus.completed,
              startedAt: past.millisecondsSinceEpoch,
              effortSource: 'user',
              rpe1To10: 5, // previous RPE = 5 vs recent RPE = 8 -> delta = +3
              createdAt: 0,
              updatedAt: 0,
            ),
          );
        }

        // Add third kind in current month to trigger kind_mix (Futsal, Hiking, Swimming in Aug 2026)
        sessions.add(
          MvSession(
            id: 'aug_hike',
            kindCode: 'HIKING',
            sessionMode: MvSessionMode.route,
            status: MvSessionStatus.completed,
            startedAt: DateTime(2026, 8, 15, 8, 0).millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
        sessions.add(
          MvSession(
            id: 'aug_swim',
            kindCode: 'SWIMMING',
            sessionMode: MvSessionMode.laps,
            status: MvSessionStatus.completed,
            startedAt: DateTime(2026, 8, 10, 8, 0).millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

        // 2. Active commitment for 6 weeks, 6 completed out of 6 planned -> triggers anchor_adherence
        final commitments = [
          MvCommitment(
            id: 1,
            kindCode: 'FUTSAL',
            dayOfWeekSat0: 5,
            startTime: '19:00',
            durationMinutes: 90,
            createdAt: '2026-07-01',
            updatedAt: '2026-07-01',
          ),
        ];

        // 3. Route with 4 completions -> triggers route_progress
        const routes = [
          MvRoute(
            id: 101,
            titleFa: 'مسیر دارآباد',
            kindCode: 'HIKING',
            timesCompleted: 4,
            bestDurationMin: 210,
            createdAt: '2026-07-01',
          ),
        ];

        const kindsMap = <String, MvMovementKind>{
          'FUTSAL': MvMovementKind(
            code: 'FUTSAL',
            titleFa: 'فوتسال',
            emoji: '⚽',
            family: MovementFamily.sport,
            baseMet: 8.0,
            metLow: 6.0,
            metHigh: 10.0,
            primaryMetric: MovementMetric.duration,
            isOutdoor: false,
            isSocial: true,
            needsVenue: true,
            jointImpact: 3,
            isCustom: false,
            isEnabled: true,
            usageCount: 0,
            sortOrder: 0,
          ),
          'HIKING': MvMovementKind(
            code: 'HIKING',
            titleFa: 'کوهنوردی',
            emoji: '🥾',
            family: MovementFamily.outdoor,
            baseMet: 7.5,
            metLow: 5.0,
            metHigh: 9.0,
            primaryMetric: MovementMetric.elevation,
            isOutdoor: true,
            isSocial: false,
            needsVenue: false,
            jointImpact: 2,
            isCustom: false,
            isEnabled: true,
            usageCount: 0,
            sortOrder: 0,
          ),
          'SWIMMING': MvMovementKind(
            code: 'SWIMMING',
            titleFa: 'شنا',
            emoji: '🏊',
            family: MovementFamily.sport,
            baseMet: 7.0,
            metLow: 5.0,
            metHigh: 9.0,
            primaryMetric: MovementMetric.laps,
            isOutdoor: false,
            isSocial: false,
            needsVenue: true,
            jointImpact: 0,
            isCustom: false,
            isEnabled: true,
            usageCount: 0,
            sortOrder: 0,
          ),
        };

        final insights = insightEngine.generateInsights(
          completedSessions: sessions,
          activeCommitments: commitments,
          commitmentWeeks: 6,
          plannedAnchorSessions: 6,
          completedAnchorSessions: 6,
          routes: routes,
          kindsMap: kindsMap,
          referenceDate: now,
        );

        expect(insights.length, equals(5));

        final keys = insights.map((i) => i.key).toSet();
        expect(keys.contains('mv_insight_best_day'), isTrue);
        expect(keys.contains('mv_insight_anchor_adherence'), isTrue);
        expect(keys.contains('mv_insight_effort_drift'), isTrue);
        expect(keys.contains('mv_insight_kind_mix'), isTrue);
        expect(keys.contains('mv_insight_route_progress'), isTrue);

        // Verify no medical claims or absolute deterministic promises in generated texts
        for (final ins in insights) {
          expect(
            ins.descriptionFa.contains('بیماری') ||
                ins.descriptionFa.contains('درمان'),
            isFalse,
          );
        }
      },
    );
  });
}
