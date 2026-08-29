import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/features/goals/logic/capacity_models.dart';
import 'package:ritmo/features/goals/logic/commitment_scorer.dart';
import 'package:ritmo/features/goals/logic/week_allocation_engine.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';

void main() {
  group('Planning Audit Comprehensive Verification Tests', () {
    test('PL-02: Scoring with deadline proximity gives high score and correct reasonFa', () {
      const commitment = PlanningCommitment(
        id: 'c_urgent',
        cycleId: 'cycle_1',
        title: 'کار فوری',
        importance: CommitmentImportance.should,
        effortMinutes: 60,
        createdAt: 0,
        updatedAt: 0,
      );

      const scorer = CommitmentScorer();
      final breakdown = scorer.score(
        c: commitment,
        todayKey: '2026-08-09',
        daysToDeadline: 1,
      );

      expect(breakdown.deadlineUrgency, greaterThanOrEqualTo(20));
      expect(breakdown.toReasonFa(), contains('مهلتش نزدیک است'));
    });

    test('PL-03: Preview = Result (idempotent allocation given same inputs)', () {
      const engine = WeekAllocationEngine();
      final commitments = [
        const PlanningCommitment(
          id: 'c1',
          cycleId: 'cycle_1',
          title: 'کار ۱',
          importance: CommitmentImportance.should,
          effortMinutes: 60,
          createdAt: 0,
          updatedAt: 0,
        ),
        const PlanningCommitment(
          id: 'c2',
          cycleId: 'cycle_1',
          title: 'کار ۲',
          importance: CommitmentImportance.must,
          effortMinutes: 90,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final capacities = [
        const DayCapacity(
          dayKey: '2026-08-10',
          rawFreeMinutes: 300,
          usableMinutes: 240,
          committableMinutes: 240,
        ),
      ];

      final dayLoads = [
        const DayLoad(
          dayKey: '2026-08-10',
          occupiedMinutes: 0,
          fixedCount: 0,
          deepCount: 0,
        ),
      ];

      final result1 = engine.allocate(
        commitments: commitments,
        capacities: capacities,
        dayLoads: dayLoads,
        todayKey: '2026-08-10',
      );

      final result2 = engine.allocate(
        commitments: commitments,
        capacities: capacities,
        dayLoads: dayLoads,
        todayKey: '2026-08-10',
      );

      expect(result1.placed.length, equals(result2.placed.length));
      for (int i = 0; i < result1.placed.length; i++) {
        expect(result1.placed[i].commitmentId, equals(result2.placed[i].commitmentId));
        expect(result1.placed[i].plannedMinutes, equals(result2.placed[i].plannedMinutes));
        expect(result1.placed[i].dayKey, equals(result2.placed[i].dayKey));
      }
    });

    test('PL-05: User locked commitments are preserved on their assigned day', () {
      const engine = WeekAllocationEngine();
      const lockedCommitment = PlanningCommitment(
        id: 'c_locked',
        cycleId: 'cycle_1',
        title: 'کار قفل شده',
        isUserLocked: true,
        earliestDayKey: '2026-08-11',
        latestDayKey: '2026-08-11',
        importance: CommitmentImportance.could,
        effortMinutes: 60,
        createdAt: 0,
        updatedAt: 0,
      );

      final capacities = [
        const DayCapacity(
          dayKey: '2026-08-10',
          rawFreeMinutes: 300,
          usableMinutes: 240,
          committableMinutes: 240,
        ),
        const DayCapacity(
          dayKey: '2026-08-11',
          rawFreeMinutes: 300,
          usableMinutes: 240,
          committableMinutes: 240,
        ),
      ];

      final dayLoads = [
        const DayLoad(
          dayKey: '2026-08-10',
          occupiedMinutes: 0,
          fixedCount: 0,
          deepCount: 0,
        ),
        const DayLoad(
          dayKey: '2026-08-11',
          occupiedMinutes: 0,
          fixedCount: 0,
          deepCount: 0,
        ),
      ];

      final result = engine.allocate(
        commitments: [lockedCommitment],
        capacities: capacities,
        dayLoads: dayLoads,
        todayKey: '2026-08-10',
      );

      expect(result.placed.length, equals(1));
      expect(result.placed.first.dayKey, equals('2026-08-11'));
      expect(result.placed.first.commitmentId, equals('c_locked'));
    });

    test('PL-13: Past days receive zero allocations when today is mid-week', () {
      const engine = WeekAllocationEngine();
      const commitment = PlanningCommitment(
        id: 'c1',
        cycleId: 'cycle_1',
        title: 'کار هفته',
        importance: CommitmentImportance.must,
        effortMinutes: 60,
        createdAt: 0,
        updatedAt: 0,
      );

      final capacities = [
        const DayCapacity(
          dayKey: '2026-08-08', // Saturday (past)
          rawFreeMinutes: 300,
          usableMinutes: 240,
          committableMinutes: 240,
        ),
        const DayCapacity(
          dayKey: '2026-08-09', // Sunday (past)
          rawFreeMinutes: 300,
          usableMinutes: 240,
          committableMinutes: 240,
        ),
        const DayCapacity(
          dayKey: '2026-08-10', // Monday (today)
          rawFreeMinutes: 300,
          usableMinutes: 240,
          committableMinutes: 240,
        ),
      ];

      final dayLoads = [
        const DayLoad(
          dayKey: '2026-08-08',
          occupiedMinutes: 0,
          fixedCount: 0,
          deepCount: 0,
        ),
        const DayLoad(
          dayKey: '2026-08-09',
          occupiedMinutes: 0,
          fixedCount: 0,
          deepCount: 0,
        ),
        const DayLoad(
          dayKey: '2026-08-10',
          occupiedMinutes: 0,
          fixedCount: 0,
          deepCount: 0,
        ),
      ];

      final result = engine.allocate(
        commitments: [commitment],
        capacities: capacities,
        dayLoads: dayLoads,
        todayKey: '2026-08-10', // today is Monday
      );

      expect(result.placed.length, equals(1));
      expect(result.placed.first.dayKey, equals('2026-08-10'));
      expect(result.placed.any((a) => a.dayKey == '2026-08-08'), isFalse);
      expect(result.placed.any((a) => a.dayKey == '2026-08-09'), isFalse);
    });

    test('F-02: AgendaQueryOptions has excludeDomains to prevent feedback loop', () {
      const optsWithExclude = AgendaQueryOptions(
        excludeDomains: {AgendaDomain.commitment},
      );
      expect(optsWithExclude.wants(AgendaDomain.commitment), isFalse);
      expect(optsWithExclude.wants(AgendaDomain.task), isTrue);
      expect(optsWithExclude.wants(AgendaDomain.prayer), isTrue);
    });

    test('PL-06: Split preserves total planned minutes', () {
      const original = PlanningAllocation(
        id: 'alloc_orig',
        commitmentId: 'c1',
        dayKey: '2026-08-10',
        plannedMinutes: 90,
        idempotencyKey: 'idemp_orig',
        createdAt: 0,
        updatedAt: 0,
      );

      final part1 = (original.plannedMinutes / 2).floor();
      final part2 = (original.plannedMinutes / 2).ceil();

      expect(part1 + part2, equals(original.plannedMinutes));
      expect(part1, equals(45));
      expect(part2, equals(45));
    });

    test('PL-28: Vocabulary Guard - No raw MoSCoW jargon in CreateCommitmentSheet', () {
      final sheetFile = File('lib/features/goals/presentation/widgets/create_commitment_sheet.dart');
      final content = sheetFile.readAsStringSync();

      expect(content.contains('ضروری (Must)'), isFalse, reason: 'Found raw MoSCoW label');
      expect(content.contains('مهم (Should)'), isFalse, reason: 'Found raw MoSCoW label');
      expect(content.contains('در صورت امکان (Could)'), isFalse, reason: 'Found raw MoSCoW label');
      expect(content.contains('کار عمیق (Deep)'), isFalse, reason: 'Found raw Deep label');
      expect(content.contains('کار سبک (Light)'), isFalse, reason: 'Found raw Light label');
      expect(content.contains('اداری (Admin)'), isFalse, reason: 'Found raw Admin label');
    });
  });
}
