// test/features/supplementary_sports/week_planner_phase2_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_suggester.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_slot_resolver.dart';

void main() {
  group('Weekday Conversion Tests (Sat0 <-> Dart Weekday)', () {
    test('sat0ToDartWeekday and dartWeekdayToSat0 round-trip for all 7 days', () {
      final expectedDartWeekdays = [6, 7, 1, 2, 3, 4, 5];

      for (int sat0 = 0; sat0 < 7; sat0++) {
        final dartDay = sat0ToDartWeekday(sat0);
        expect(dartDay, expectedDartWeekdays[sat0],
            reason: 'Sat0 index $sat0 should map to Dart weekday ${expectedDartWeekdays[sat0]}');

        final backToSat0 = dartWeekdayToSat0(dartDay);
        expect(backToSat0, sat0,
            reason: 'Dart weekday $dartDay should convert back to Sat0 index $sat0');
      }
    });
  });

  group('Movement Suggester Safety Veto Tests', () {
    const safeWalking = MovementKind(
      code: 'WALKING',
      titleFa: 'پیاده‌روی',
      emoji: '🚶',
      family: MovementFamily.endurance,
      baseMet: 3.5,
      metLow: 2.5,
      metHigh: 4.5,
      primaryMetric: MovementMetric.duration,
      secondaryMetric: MovementMetric.none,
      isOutdoor: true,
      isSocial: false,
      needsVenue: false,
      jointImpact: 1,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 0,
    );

    const highImpactRunning = MovementKind(
      code: 'RUNNING',
      titleFa: 'دویدن',
      emoji: '🏃',
      family: MovementFamily.endurance,
      baseMet: 8.0,
      metLow: 6.0,
      metHigh: 10.0,
      primaryMetric: MovementMetric.distance,
      secondaryMetric: MovementMetric.duration,
      isOutdoor: true,
      isSocial: false,
      needsVenue: false,
      jointImpact: 3,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 0,
    );

    const jumpingRope = MovementKind(
      code: 'JUMP_ROPE',
      titleFa: 'طناب زدن',
      emoji: '🪢',
      family: MovementFamily.endurance,
      baseMet: 9.0,
      metLow: 7.0,
      metHigh: 11.0,
      primaryMetric: MovementMetric.duration,
      secondaryMetric: MovementMetric.none,
      isOutdoor: false,
      isSocial: false,
      needsVenue: false,
      jointImpact: 2,
      isCustom: false,
      isEnabled: true,
      usageCount: 0,
      sortOrder: 0,
    );

    const baseBudget = MovementBudgetSnapshot(
      weeklyMetMinutesTarget: 500,
      achievedMetMinutes: 200,
      activeDays: 2,
      targetActiveDays: 4,
      byFamily: {},
      byKind: {},
      daysRemaining: 5,
      projectedTotal: 450,
      events: [],
      kindsByCode: {},
    );

    test('Knee limitation vetos jointImpact >= 3 to negative infinity', () {
      const kneeCtx = SuggestionCtx(
        budget: baseBudget,
        availableMinutes: 30,
        energy: 3,
        soreness: 1,
        painLevel: 0,
        limitations: {'knee'},
        recentKindCodes14d: {},
        jalaliMonth: 5,
      );

      final runningScore = scoreMovementKind(highImpactRunning, kneeCtx);
      expect(runningScore, double.negativeInfinity,
          reason: 'Knee limitation must veto jointImpact >= 3');

      final walkingScore = scoreMovementKind(safeWalking, kneeCtx);
      expect(walkingScore.isFinite, isTrue,
          reason: 'Knee limitation should allow safe walking with jointImpact 1');
    });

    test('High pain (>= 6) vetos jointImpact >= 2 to negative infinity', () {
      const highPainCtx = SuggestionCtx(
        budget: baseBudget,
        availableMinutes: 30,
        energy: 3,
        soreness: 1,
        painLevel: 6,
        limitations: {},
        recentKindCodes14d: {},
        jalaliMonth: 5,
      );

      final ropeScore = scoreMovementKind(jumpingRope, highPainCtx);
      expect(ropeScore, double.negativeInfinity,
          reason: 'Pain level >= 6 must veto jointImpact >= 2');

      final walkingScore = scoreMovementKind(safeWalking, highPainCtx);
      expect(walkingScore.isFinite, isTrue,
          reason: 'Walking (jointImpact 1) should be allowed even with pain level 6');
    });
  });

  group('Planned Slot Tests', () {
    test('PlannedSlot copyWith preserves properties correctly', () {
      const slot = PlannedSlot(
        routineId: 'r1',
        weekdaySat0: 0,
        dateIso: '2026-08-15',
        time: '07:00',
        title: 'دویدن',
        emoji: '🏃',
        reminderMinutes: 30,
      );

      final updated = slot.copyWith(isLight: true, time: '08:00');
      expect(updated.routineId, 'r1');
      expect(updated.time, '08:00');
      expect(updated.isLight, isTrue);
      expect(updated.emoji, '🏃');
    });
  });
}
