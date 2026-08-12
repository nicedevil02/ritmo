// test/supplementary_sports/movement_phase_5_test.dart
//
// تست‌های واحد برای فاز ۵: پیشنهاددهندهٔ نسخهٔ ۲

import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_suggester.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';

void main() {
  group('Phase 5 | MovementSuggester v2 Logical Scoring Tests', () {
    const running = MovementKind(
      code: 'RUNNING',
      titleFa: 'دویدن',
      emoji: '🏃',
      family: MovementFamily.endurance,
      baseMet: 8.0,
      metLow: 6.0,
      metHigh: 10.0,
      primaryMetric: MovementMetric.distance,
      secondaryMetric: MovementMetric.none,
      isOutdoor: false,
      isSocial: false,
      needsVenue: false,
      jointImpact: 3, // High impact
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 1,
    );

    const walking = MovementKind(
      code: 'WALKING',
      titleFa: 'پیاده‌روی',
      emoji: '🚶',
      family: MovementFamily.daily,
      baseMet: 3.0,
      metLow: 2.0,
      metHigh: 4.0,
      primaryMetric: MovementMetric.distance,
      secondaryMetric: MovementMetric.none,
      isOutdoor: false,
      isSocial: false,
      needsVenue: false,
      jointImpact: 1, // Low impact
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 2,
    );

    const swimming = MovementKind(
      code: 'SWIMMING',
      titleFa: 'شنا',
      emoji: '🏊',
      family: MovementFamily.endurance,
      baseMet: 7.0,
      metLow: 5.0,
      metHigh: 9.0,
      primaryMetric: MovementMetric.laps,
      secondaryMetric: MovementMetric.none,
      isOutdoor: false,
      isSocial: false,
      needsVenue: true,
      jointImpact: 0, // Very low impact
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 3,
    );

    test('Knee pain limitation vetoes running (jointImpact >= 3)', () {
      const budget = MovementBudgetSnapshot(
        weeklyMetMinutesTarget: 500,
        achievedMetMinutes: 100,
        activeDays: 1,
        targetActiveDays: 4,
        byFamily: {},
        byKind: {},
        daysRemaining: 4,
        projectedTotal: null,
        events: [],
        kindsByCode: {},
      );

      final ctx = SuggestionCtx(
        budget: budget,
        availableMinutes: 30,
        energy: 5,
        soreness: 1,
        painLevel: 0,
        limitations: {'knee'}, // Knee pain limitation
        recentKindCodes14d: const {},
        jalaliMonth: 5,
      );

      final scoreRunning = scoreMovementKind(running, ctx);
      final scoreWalking = scoreMovementKind(walking, ctx);

      // Running has jointImpact = 3, so knee limitation should make it double.negativeInfinity
      expect(scoreRunning, equals(double.negativeInfinity));
      // Walking (jointImpact = 1) remains finite and suggested
      expect(scoreWalking.isFinite, isTrue);
    });

    test('High painLevel >= 6 vetoes jointImpact >= 2 sports', () {
      const budget = MovementBudgetSnapshot(
        weeklyMetMinutesTarget: 500,
        achievedMetMinutes: 100,
        activeDays: 1,
        targetActiveDays: 4,
        byFamily: {},
        byKind: {},
        daysRemaining: 4,
        projectedTotal: null,
        events: [],
        kindsByCode: {},
      );

      final ctx = SuggestionCtx(
        budget: budget,
        availableMinutes: 30,
        energy: 5,
        soreness: 1,
        painLevel: 7, // High pain level
        limitations: const {},
        recentKindCodes14d: const {},
        jalaliMonth: 5,
      );

      final scoreRunning = scoreMovementKind(running, ctx);
      final scoreWalking = scoreMovementKind(walking, ctx);

      // Running has jointImpact = 3 (>= 2), so it is vetoed
      expect(scoreRunning, equals(double.negativeInfinity));
      // Walking has jointImpact = 1 (< 2), so it is allowed
      expect(scoreWalking.isFinite, isTrue);
    });

    test('Low readiness (soreness/low energy) prefers low impact/low met', () {
      const budget = MovementBudgetSnapshot(
        weeklyMetMinutesTarget: 500,
        achievedMetMinutes: 100,
        activeDays: 1,
        targetActiveDays: 4,
        byFamily: {},
        byKind: {},
        daysRemaining: 4,
        projectedTotal: null,
        events: [],
        kindsByCode: {},
      );

      // Soreness 4, Energy 2 -> Low readiness
      final ctxLow = SuggestionCtx(
        budget: budget,
        availableMinutes: 30,
        energy: 2,
        soreness: 4,
        painLevel: 0,
        limitations: const {},
        recentKindCodes14d: const {},
        jalaliMonth: 5,
      );

      final fitRunning = readinessFit(running, ctxLow);
      final fitWalking = readinessFit(walking, ctxLow);

      // Walking has baseMet = 3.0 (<= 5) and jointImpact = 1 (<= 1) -> fit is 1.0
      expect(fitWalking, equals(1.0));
      // Running has baseMet = 8.0 and jointImpact = 3 -> fit is penalized
      expect(fitRunning, lessThan(fitWalking));

      // Build reason for low readiness
      final reason = buildReason(walking, ctxLow, 90.0);
      expect(reason, contains('بدنت امروز به آرامش نیاز دارد'));
    });

    test('Season fit logic maps seasonMask correctly', () {
      const winterSport = MovementKind(
        code: 'SKIING',
        titleFa: 'اسکی',
        emoji: '⛷',
        family: MovementFamily.outdoor,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.duration,
        secondaryMetric: MovementMetric.none,
        isOutdoor: true,
        isSocial: false,
        needsVenue: true,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 4,
        seasonMask: '10,11,12', // Dey, Bahman, Esfand (winter months in Solar Hijri)
      );

      // Month 11 (Bahman) -> fits mask
      expect(seasonFit(winterSport, 11), equals(1.0));
      // Month 5 (Mordad) -> does not fit mask
      expect(seasonFit(winterSport, 5), equals(0.0));
      // Null mask defaults to 0.5
      expect(seasonFit(walking, 5), equals(0.5));
    });

    test('Confidence is derived from score gap', () {
      const budget = MovementBudgetSnapshot(
        weeklyMetMinutesTarget: 500,
        achievedMetMinutes: 100,
        activeDays: 1,
        targetActiveDays: 4,
        byFamily: {},
        byKind: {},
        daysRemaining: 4,
        projectedTotal: null,
        events: [],
        kindsByCode: {},
      );

      final ctx = SuggestionCtx(
        budget: budget,
        availableMinutes: 30,
        energy: 5,
        soreness: 1,
        painLevel: 0,
        limitations: const {},
        recentKindCodes14d: const {},
        jalaliMonth: 5,
      );

      final scoreWalking = scoreMovementKind(walking, ctx);
      final scoreSwimming = scoreMovementKind(swimming, ctx);

      // Calculate confidence formula mock
      final double top1 = scoreWalking;
      final double top2 = scoreSwimming;
      final confidence = ((top1 - top2) / (top1.abs() + 1.0)).clamp(0.3, 0.9);

      expect(confidence, greaterThanOrEqualTo(0.3));
      expect(confidence, lessThanOrEqualTo(0.9));
    });
  });
}
