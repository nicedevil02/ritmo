import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/plan_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('PlanEngine Stage 3: ADJACENCY Unit Tests (S3-T6 / ADJ-1..ADJ-7)', () {
    const planEngine = PlanEngine();
    final weekStartSat = DateTime.parse('2026-08-22');
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
      'TABLE_TENNIS': const MvMovementKind(
        code: 'TABLE_TENNIS',
        titleFa: 'تنیس روی میز',
        emoji: '🏓',
        family: MovementFamily.sport,
        baseMet: 4.0,
        metLow: 3.0,
        metHigh: 5.0,
        primaryMetric: MovementMetric.duration,
        isOutdoor: false,
        isSocial: true,
        needsVenue: true,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      ),
      'SWIMMING': const MvMovementKind(
        code: 'SWIMMING',
        titleFa: 'شنا',
        emoji: '🏊',
        family: MovementFamily.endurance,
        baseMet: 6.0,
        metLow: 4.0,
        metHigh: 8.0,
        primaryMetric: MovementMetric.duration,
        isOutdoor: false,
        isSocial: false,
        needsVenue: true,
        jointImpact: 1,
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
      'TABLE_TENNIS': const MvKindProfile(
        kindCode: 'TABLE_TENNIS',
        primaryMuscles: ['calves', 'shoulders'],
        neuroCost: 1,
        recoveryHours: 24,
        complementFocus: ['core', 'shoulder'],
      ),
      'SWIMMING': const MvKindProfile(
        kindCode: 'SWIMMING',
        primaryMuscles: ['lats', 'shoulders', 'core'],
        neuroCost: 1,
        recoveryHours: 24,
        complementFocus: ['core', 'scapular_stability'],
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

    test(
      'Case 1: Single Thursday futsal 90m -> Wednesday mobility <=20m and Friday activeRest <=25m',
      () {
        final futsalCommitment = MvCommitment(
          id: 1,
          kindCode: 'FUTSAL',
          dayOfWeekSat0: 5, // پنجشنبه 2026-08-27
          startTime: '21:00',
          durationMinutes: 90,
          titleFa: 'فوتسال پنجشنبه',
        );

        final result = planEngine.generateWeek(
          weekStartSat: weekStartSat,
          profile: MvUserProfile.empty(),
          commitments: [futsalCommitment],
          overrides: const [],
          kinds: kindsMap,
          kindProfiles: kindProfilesMap,
          budget: budget,
          load: null,
          readiness: MvReadinessTier.full,
        );

        // Wednesday (2026-08-26, day 4) -> mobility <= 20 min with preAnchorTaper reasonKey
        final wednesdaySlot = result.slots.firstWhere(
          (s) => s.dateIso == '2026-08-26',
        );
        expect(wednesdaySlot.slotType, equals(MvSlotType.mobility));
        expect(wednesdaySlot.targetMinutes, lessThanOrEqualTo(20));
        expect(wednesdaySlot.reasonKey, equals(MvReasonKeys.preAnchorTaper));
        expect(wednesdaySlot.reasonParams?['kind'], equals('فوتسال'));

        // Friday (2026-08-28, day 6) -> activeRest <= 25 min with postAnchorRecovery reasonKey
        final fridaySlot = result.slots.firstWhere(
          (s) => s.dateIso == '2026-08-28',
        );
        expect(fridaySlot.slotType, equals(MvSlotType.activeRest));
        expect(fridaySlot.targetMinutes, lessThanOrEqualTo(25));
        expect(fridaySlot.reasonKey, equals(MvReasonKeys.postAnchorRecovery));
        expect(fridaySlot.reasonParams?['kind'], equals('فوتسال'));
      },
    );

    test(
      'Case 2: Thursday futsal + Friday mountain hiking -> both locked, Saturday activeRest (ADJ-6), conflict banner active',
      () {
        final futsalCommitment = MvCommitment(
          id: 1,
          kindCode: 'FUTSAL',
          dayOfWeekSat0: 5, // پنجشنبه
          startTime: '21:00',
          durationMinutes: 90,
        );

        final hikingCommitment = MvCommitment(
          id: 2,
          kindCode: 'HIKING',
          dayOfWeekSat0: 6, // جمعه
          startTime: '06:00',
          durationMinutes: 240,
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

        // Thursday & Friday are locked
        expect(
          result.slots.firstWhere((s) => s.dateIso == '2026-08-27').isLocked,
          isTrue,
        );
        expect(
          result.slots.firstWhere((s) => s.dateIso == '2026-08-28').isLocked,
          isTrue,
        );

        // Conflict warning active (ADJ-6)
        expect(result.hasConflict, isTrue);
        expect(result.conflictNote, equals('mv_conflict_back_to_back'));

        // Saturday (day index 0 in week) is set to activeRest
        final satSlot = result.slots.firstWhere(
          (s) => s.dateIso == '2026-08-22',
        );
        expect(satSlot.slotType, equals(MvSlotType.activeRest));
        expect(satSlot.targetMinutes, lessThanOrEqualTo(25));
      },
    );

    test(
      'Case 3: 3 anchors in a week -> at least 1 full rest day guaranteed (ADJ-5)',
      () {
        final comm1 = MvCommitment(
          id: 1,
          kindCode: 'SWIMMING',
          dayOfWeekSat0: 1,
          startTime: '08:00',
          durationMinutes: 45,
        ); // یکشنبه
        final comm2 = MvCommitment(
          id: 2,
          kindCode: 'SWIMMING',
          dayOfWeekSat0: 3,
          startTime: '08:00',
          durationMinutes: 45,
        ); // سه‌شنبه
        final comm3 = MvCommitment(
          id: 3,
          kindCode: 'FUTSAL',
          dayOfWeekSat0: 5,
          startTime: '21:00',
          durationMinutes: 90,
        ); // پنجشنبه

        final result = planEngine.generateWeek(
          weekStartSat: weekStartSat,
          profile: MvUserProfile.empty(),
          commitments: [comm1, comm2, comm3],
          overrides: const [],
          kinds: kindsMap,
          kindProfiles: kindProfilesMap,
          budget: budget,
          load: null,
          readiness: MvReadinessTier.full,
        );

        final restSlots = result.slots
            .where((s) => s.slotType == MvSlotType.rest)
            .toList();
        expect(restSlots, isNotEmpty);
        expect(
          restSlots.any((s) => s.reasonKey == MvReasonKeys.restGuaranteed),
          isTrue,
        );
      },
    );

    test(
      'Case 5: Table tennis 45 min anchor (jointImpact=1) -> day after is NOT restricted to activeRest',
      () {
        final pingPongCommitment = MvCommitment(
          id: 1,
          kindCode: 'TABLE_TENNIS',
          dayOfWeekSat0: 1, // یکشنبه 2026-08-23
          startTime: '18:00',
          durationMinutes: 45,
        );

        final result = planEngine.generateWeek(
          weekStartSat: weekStartSat,
          profile: MvUserProfile.empty(),
          commitments: [pingPongCommitment],
          overrides: const [],
          kinds: kindsMap,
          kindProfiles: kindProfilesMap,
          budget: budget,
          load: null,
          readiness: MvReadinessTier.full,
        );

        // Monday (2026-08-24, day 2) should NOT be forced to postAnchorRecovery because Table Tennis jointImpact is 1 (< 2)
        final mondaySlot = result.slots.firstWhere(
          (s) => s.dateIso == '2026-08-24',
        );
        expect(
          mondaySlot.reasonKey,
          isNot(equals(MvReasonKeys.postAnchorRecovery)),
        );
      },
    );
  });
}
