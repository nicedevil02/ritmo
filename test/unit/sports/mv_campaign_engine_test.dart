import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/campaign_engine.dart';

void main() {
  group('S5-T2 CampaignEngine Outdoor/Hiking Progression Tests', () {
    const engine = CampaignEngine();

    test(
      '12-week goal with 80kg bodyweight matches exact periodization schedule',
      () {
        final plan = engine.buildOutdoorPlan(
          totalWeeks: 12,
          bodyWeightKg: 80.0,
        );

        expect(plan.totalWeeks, equals(12));
        expect(plan.isTooShort, isFalse);
        expect(plan.warningKey, isNull);
        expect(plan.weeks.length, equals(12));

        // Phase 1 (Weeks 1..4): Base building -> 0 pack weight
        for (int w = 1; w <= 4; w++) {
          final wp = plan.getWeekPlan(w)!;
          expect(wp.phase, equals(MvCampaignPhase.base));
          expect(wp.packWeightKg, equals(0.0));
          expect(wp.packWeightPercent, equals(0.0));
          expect(wp.volumeRatio, equals(1.0));
          expect(wp.isTaper, isFalse);
        }

        // Phase 2 (Weeks 5..11): Progressive pack load (5% -> 10% -> 15% -> 20%)
        // Week 5 & 6: 5% of 80kg = 4.0kg
        expect(plan.getWeekPlan(5)!.packWeightPercent, equals(0.05));
        expect(plan.getWeekPlan(5)!.packWeightKg, equals(4.0));
        expect(plan.getWeekPlan(6)!.packWeightPercent, equals(0.05));
        expect(plan.getWeekPlan(6)!.packWeightKg, equals(4.0));

        // Week 7 & 8: 10% of 80kg = 8.0kg
        expect(plan.getWeekPlan(7)!.packWeightPercent, equals(0.10));
        expect(plan.getWeekPlan(7)!.packWeightKg, equals(8.0));
        expect(plan.getWeekPlan(8)!.packWeightPercent, equals(0.10));
        expect(plan.getWeekPlan(8)!.packWeightKg, equals(8.0));

        // Week 9 & 10: 15% of 80kg = 12.0kg (Acceptance requirement: Week 9 is 12kg)
        expect(
          plan.getWeekPlan(9)!.phase,
          equals(MvCampaignPhase.progressiveLoad),
        );
        expect(plan.getWeekPlan(9)!.packWeightPercent, equals(0.15));
        expect(plan.getWeekPlan(9)!.packWeightKg, equals(12.0));
        expect(plan.getWeekPlan(10)!.packWeightPercent, equals(0.15));
        expect(plan.getWeekPlan(10)!.packWeightKg, equals(12.0));

        // Week 11: 20% of 80kg = 16.0kg
        expect(plan.getWeekPlan(11)!.packWeightPercent, equals(0.20));
        expect(plan.getWeekPlan(11)!.packWeightKg, equals(16.0));

        // Phase 3 (Week 12): Taper (60% volume, 0 pack weight)
        final week12 = plan.getWeekPlan(12)!;
        expect(week12.phase, equals(MvCampaignPhase.taper));
        expect(week12.packWeightKg, equals(0.0));
        expect(week12.volumeRatio, equals(0.6));
        expect(week12.isTaper, isTrue);
      },
    );

    test(
      'Campaign with less than 4 weeks flags mv_campaign_too_short and restricts to base + taper',
      () {
        final plan3 = engine.buildOutdoorPlan(
          totalWeeks: 3,
          bodyWeightKg: 75.0,
        );

        expect(plan3.isTooShort, isTrue);
        expect(plan3.warningKey, equals('mv_campaign_too_short'));
        expect(plan3.weeks.length, equals(3));

        // Week 1 & 2: Base (0 pack weight)
        expect(plan3.getWeekPlan(1)!.phase, equals(MvCampaignPhase.base));
        expect(plan3.getWeekPlan(1)!.packWeightKg, equals(0.0));
        expect(plan3.getWeekPlan(2)!.phase, equals(MvCampaignPhase.base));

        // Week 3: Taper (0.6 volume, 0 pack weight)
        expect(plan3.getWeekPlan(3)!.phase, equals(MvCampaignPhase.taper));
        expect(plan3.getWeekPlan(3)!.volumeRatio, equals(0.6));
        expect(plan3.getWeekPlan(3)!.isTaper, isTrue);
      },
    );

    test('Campaign with 1 week is pure taper with too_short warning', () {
      final plan1 = engine.buildOutdoorPlan(totalWeeks: 1, bodyWeightKg: 70.0);

      expect(plan1.isTooShort, isTrue);
      expect(plan1.warningKey, equals('mv_campaign_too_short'));
      expect(plan1.weeks.length, equals(1));
      expect(plan1.getWeekPlan(1)!.phase, equals(MvCampaignPhase.taper));
      expect(plan1.getWeekPlan(1)!.volumeRatio, equals(0.6));
    });
  });
}
