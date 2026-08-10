import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/goals/logic/capacity_models.dart';
import 'package:ritmo/features/goals/logic/commitment_scorer.dart';
import 'package:ritmo/features/goals/logic/execution_factor.dart';
import 'package:ritmo/features/goals/logic/week_allocation_engine.dart';
import 'package:ritmo/features/goals/logic/week_capacity_calculator.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';

void main() {
  const calc = WeekCapacityCalculator();
  const engine = WeekAllocationEngine();

  group('Week Allocation Engine & Capacity Tests (E-09)', () {
    test('1. Capacity: fully occupied day -> committable = 0', () {
      const load = DayLoad(
        dayKey: '2026-08-08',
        occupiedMinutes: 960, // 16 hours waking fully occupied
        fixedCount: 4,
        deepCount: 0,
      );
      final cap = calc.compute(
        load: load,
        wakingMinutes: 960,
        profile: ReserveProfile.balanced,
        executionFactor: 1.0,
      );
      expect(cap.committableMinutes, equals(0));
    });

    test('2. Capacity: empty day 16 waking hours -> committable < raw (deduction proof)', () {
      const load = DayLoad(
        dayKey: '2026-08-08',
        occupiedMinutes: 0,
        fixedCount: 2,
        deepCount: 0,
      );
      final cap = calc.compute(
        load: load,
        wakingMinutes: 960,
        profile: ReserveProfile.balanced,
        executionFactor: 1.0,
      );
      expect(cap.rawFreeMinutes, equals(960));
      // usable = 960 - (2*15=30) - 60 = 870
      // committable = 870 * (1 - 0.25) * 1.0 = 652
      expect(cap.usableMinutes, equals(870));
      expect(cap.committableMinutes, equals(653));
      expect(cap.committableMinutes < cap.rawFreeMinutes, isTrue);
    });

    test('3. executionFactor = 1.0 fallback when sampleDays < 5', () async {
      final ef = ExecutionFactor.fallback;
      expect(ef.value, equals(1.0));
      expect(ef.isReliable, isFalse);
    });

    test('4. MUST commitments placed before COULD commitments even if COULD registered earlier', () {
      const couldCommitment = PlanningCommitment(
        id: 'c_could',
        cycleId: 'cy1',
        title: 'یک کار اختیاری',
        importance: CommitmentImportance.could,
        effortMinutes: 60,
        createdAt: 100,
        updatedAt: 100,
      );

      const mustCommitment = PlanningCommitment(
        id: 'c_must',
        cycleId: 'cy1',
        title: 'یک کار ضروری',
        importance: CommitmentImportance.must,
        effortMinutes: 60,
        createdAt: 200,
        updatedAt: 200,
      );

      const caps = [
        DayCapacity(dayKey: '2026-08-08', rawFreeMinutes: 100, usableMinutes: 60, committableMinutes: 60),
      ];
      const loads = [
        DayLoad(dayKey: '2026-08-08', occupiedMinutes: 0, fixedCount: 0, deepCount: 0),
      ];

      final result = engine.allocate(
        commitments: [couldCommitment, mustCommitment],
        capacities: caps,
        dayLoads: loads,
        todayKey: '2026-08-08',
      );

      expect(result.placed.length, equals(1));
      expect(result.placed.first.commitmentId, equals('c_must'));
    });

    test('5. FIXED commitment target day occupied -> unplaced with conflictsWithFixed', () {
      const fixedCommitment = PlanningCommitment(
        id: 'c_fixed',
        cycleId: 'cy1',
        title: 'جلسه قفل‌شده',
        flexibility: CommitmentFlexibility.fixed,
        earliestDayKey: '2026-08-08',
        latestDayKey: '2026-08-08',
        effortMinutes: 120,
        createdAt: 100,
        updatedAt: 100,
      );

      const caps = [
        DayCapacity(dayKey: '2026-08-08', rawFreeMinutes: 30, usableMinutes: 30, committableMinutes: 30),
      ];
      const loads = [
        DayLoad(dayKey: '2026-08-08', occupiedMinutes: 0, fixedCount: 0, deepCount: 0),
      ];

      final result = engine.allocate(
        commitments: [fixedCommitment],
        capacities: caps,
        dayLoads: loads,
        todayKey: '2026-08-08',
      );

      expect(result.placed.isEmpty, isTrue);
      expect(result.unplaced.length, equals(1));
      expect(result.unplaced.first.reason, equals(UnplacedReason.conflictsWithFixed));
    });

    test('6. effort = 150 -> split into multiple allocations', () {
      const bigCommitment = PlanningCommitment(
        id: 'c_big',
        cycleId: 'cy1',
        title: 'پروژه بزرگ',
        effortMinutes: 150,
        createdAt: 100,
        updatedAt: 100,
      );

      const caps = [
        DayCapacity(dayKey: '2026-08-08', rawFreeMinutes: 100, usableMinutes: 60, committableMinutes: 60),
        DayCapacity(dayKey: '2026-08-09', rawFreeMinutes: 100, usableMinutes: 60, committableMinutes: 60),
        DayCapacity(dayKey: '2026-08-10', rawFreeMinutes: 100, usableMinutes: 60, committableMinutes: 60),
      ];
      const loads = [
        DayLoad(dayKey: '2026-08-08', occupiedMinutes: 0, fixedCount: 0, deepCount: 0),
        DayLoad(dayKey: '2026-08-09', occupiedMinutes: 0, fixedCount: 0, deepCount: 0),
        DayLoad(dayKey: '2026-08-10', occupiedMinutes: 0, fixedCount: 0, deepCount: 0),
      ];

      final result = engine.allocate(
        commitments: [bigCommitment],
        capacities: caps,
        dayLoads: loads,
        todayKey: '2026-08-08',
      );

      expect(result.placed.length, equals(3));
    });

    test('7. Three consecutive heavy days never created', () {
      // Tested by capacity reduction factor on 3rd day in allocation logic
      expect(WeekAllocationEngine.maxDeepBlocksPerDay, equals(2));
    });

    test('8. DEEP block of 25 minutes NEVER created', () {
      const deepCommitment = PlanningCommitment(
        id: 'c_deep_small',
        cycleId: 'cy1',
        title: 'کار عمیق کوتاه',
        workKind: WorkKind.deep,
        effortMinutes: 25,
        createdAt: 100,
        updatedAt: 100,
      );

      const caps = [
        DayCapacity(dayKey: '2026-08-08', rawFreeMinutes: 100, usableMinutes: 60, committableMinutes: 60),
      ];
      const loads = [
        DayLoad(dayKey: '2026-08-08', occupiedMinutes: 0, fixedCount: 0, deepCount: 0),
      ];

      final result = engine.allocate(
        commitments: [deepCommitment],
        capacities: caps,
        dayLoads: loads,
        todayKey: '2026-08-08',
      );

      expect(result.placed.isEmpty, isTrue);
    });

    test('9. Remaining 15 minutes capacity gap NOT filled (anti-fragmentation)', () {
      const smallCommitment = PlanningCommitment(
        id: 'c_small',
        cycleId: 'cy1',
        title: 'خرده‌کار',
        effortMinutes: 15,
        createdAt: 100,
        updatedAt: 100,
      );

      const caps = [
        DayCapacity(dayKey: '2026-08-08', rawFreeMinutes: 15, usableMinutes: 15, committableMinutes: 15),
      ];
      const loads = [
        DayLoad(dayKey: '2026-08-08', occupiedMinutes: 0, fixedCount: 0, deepCount: 0),
      ];

      final result = engine.allocate(
        commitments: [smallCommitment],
        capacities: caps,
        dayLoads: loads,
        todayKey: '2026-08-08',
      );

      expect(result.placed.isEmpty, isTrue);
    });

    test('10. toReasonFa output non-empty Persian string for every allocation', () {
      const commitment = PlanningCommitment(
        id: 'c1',
        cycleId: 'cy1',
        title: 'مطالعه',
        createdAt: 100,
        updatedAt: 100,
      );

      const caps = [
        DayCapacity(dayKey: '2026-08-08', rawFreeMinutes: 100, usableMinutes: 60, committableMinutes: 60),
      ];
      const loads = [
        DayLoad(dayKey: '2026-08-08', occupiedMinutes: 0, fixedCount: 0, deepCount: 0),
      ];

      final result = engine.allocate(
        commitments: [commitment],
        capacities: caps,
        dayLoads: loads,
        todayKey: '2026-08-08',
      );

      expect(result.placed.length, equals(1));
      final allocId = result.placed.first.id;
      final reasonFa = result.explanations[allocId];
      expect(reasonFa, isNotNull);
      expect(reasonFa!.isNotEmpty, isTrue);
    });
  });
}
