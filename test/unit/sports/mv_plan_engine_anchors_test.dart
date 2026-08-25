import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/plan_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('PlanEngine Stage 1: ANCHORS Unit Tests (S3-T4)', () {
    const planEngine = PlanEngine();
    final weekStartSat = DateTime.parse('2026-08-22'); // شنبه
    // Sat=08-22 (0), Sun=08-23 (1), Mon=08-24 (2), Tue=08-25 (3), Wed=08-26 (4), Thu=08-27 (5), Fri=08-28 (6)

    final kindsMap = <String, MvMovementKind>{
      'FUTSAL': const MvMovementKind(
        code: 'FUTSAL',
        titleFa: 'فوتسال',
        emoji: '⚽',
        family: MovementFamily.sport,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
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
      'HIKING': const MvMovementKind(
        code: 'HIKING',
        titleFa: 'کوهنوردی',
        emoji: '🥾',
        family: MovementFamily.outdoor,
        baseMet: 6.0,
        metLow: 4.5,
        metHigh: 8.0,
        primaryMetric: MovementMetric.duration,
        isOutdoor: true,
        isSocial: true,
        needsVenue: false,
        jointImpact: 2,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      ),
    };

    final kindProfilesMap = <String, MvKindProfile>{
      'FUTSAL': const MvKindProfile(
        kindCode: 'FUTSAL',
        primaryMuscles: ['hamstrings', 'quads', 'calves', 'core'],
        neuroCost: 3,
        recoveryHours: 48,
        complementFocus: ['posterior_chain', 'adductors', 'ankle'],
      ),
      'HIKING': const MvKindProfile(
        kindCode: 'HIKING',
        primaryMuscles: ['quads', 'calves', 'glutes', 'core'],
        neuroCost: 2,
        recoveryHours: 36,
        complementFocus: ['eccentric_quad', 'ankle', 'core'],
      ),
    };

    const budget = MvBudgetSnapshot(
      moderateEquivalentMinutes: 0,
      rawMetMinutes: 0,
      strengthDays: 0,
      targetMin: 150,
      targetOptimal: 300,
      strengthDaysTarget: 2,
    );

    test('Two commitments (Thursday futsal, Friday mountain) produce exactly 2 locked slots with exact times and slotTypes', () {
      final futsalCommitment = MvCommitment(
        id: 1,
        kindCode: 'FUTSAL',
        dayOfWeekSat0: 5, // پنجشنبه
        startTime: '21:00',
        durationMinutes: 90,
        titleFa: 'فوتسال پنجشنبه',
      );

      final hikingCommitment = MvCommitment(
        id: 2,
        kindCode: 'HIKING',
        dayOfWeekSat0: 6, // جمعه
        startTime: '06:00',
        durationMinutes: 240,
        titleFa: 'کوهنوردی جمعه',
      );

      final result = planEngine.generateWeek(
        weekStartSat: weekStartSat,
        profile: MvUserProfile.empty(),
        commitments: [futsalCommitment, hikingCommitment],
        overrides: const [],
        kinds: kindsMap,
        kindProfiles: kindProfilesMap,
        budget: budget,
        load: null,
        readiness: MvReadinessTier.full,
      );

      // Total slots should be 7
      expect(result.slots.length, equals(7));

      final lockedSlots = result.slots.where((s) => s.isLocked).toList();
      // Acceptance criterion: exactly 2 locked slots on those two days with those exact times
      expect(lockedSlots.length, equals(2));

      final thursdaySlot = lockedSlots.firstWhere((s) => s.dateIso == '2026-08-27');
      expect(thursdaySlot.kindCode, equals('FUTSAL'));
      expect(thursdaySlot.plannedTime, equals('21:00'));
      expect(thursdaySlot.targetMinutes, equals(90));
      expect(thursdaySlot.slotType, equals(MvSlotType.sport));
      expect(thursdaySlot.reasonKey, equals(MvReasonKeys.anchor));
      expect(thursdaySlot.isLocked, isTrue);

      final fridaySlot = lockedSlots.firstWhere((s) => s.dateIso == '2026-08-28');
      expect(fridaySlot.kindCode, equals('HIKING'));
      expect(fridaySlot.plannedTime, equals('06:00'));
      expect(fridaySlot.targetMinutes, equals(240));
      expect(fridaySlot.slotType, equals(MvSlotType.outdoor));
      expect(fridaySlot.reasonKey, equals(MvReasonKeys.anchor));
      expect(fridaySlot.isLocked, isTrue);
    });

    test('Override with skip action suppresses anchor slot generation for that week', () {
      final futsalCommitment = MvCommitment(
        id: 1,
        kindCode: 'FUTSAL',
        dayOfWeekSat0: 5, // پنجشنبه 2026-08-27
        startTime: '21:00',
        durationMinutes: 90,
      );

      const skipOverride = MvSlotOverride(
        id: 'ovr_1',
        routineId: 'comm_1',
        dateIso: '2026-08-27',
        action: 'SKIP',
        createdAt: 100,
      );

      final result = planEngine.generateWeek(
        weekStartSat: weekStartSat,
        profile: MvUserProfile.empty(),
        commitments: [futsalCommitment],
        overrides: const [skipOverride],
        kinds: kindsMap,
        kindProfiles: kindProfilesMap,
        budget: budget,
        load: null,
        readiness: MvReadinessTier.full,
      );

      final thursdaySlot = result.slots.firstWhere((s) => s.dateIso == '2026-08-27');
      expect(thursdaySlot.isLocked, isFalse);
      expect(thursdaySlot.kindCode, isNot(equals('FUTSAL')));
    });
  });
}
