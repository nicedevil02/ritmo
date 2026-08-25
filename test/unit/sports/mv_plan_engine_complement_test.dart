import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/plan_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('PlanEngine Stage 5: COMPLEMENT Unit Tests (S3-T8)', () {
    const planEngine = PlanEngine();
    final weekStartSat = DateTime.parse('2026-08-22');
    // Sat=08-22 (0), Sun=08-23 (1), Mon=08-24 (2), Tue=08-25 (3), Wed=08-26 (4), Thu=08-27 (5), Fri=08-28 (6)

    final kindsMap = <String, MvMovementKind>{
      'FOOTBALL': const MvMovementKind(
        code: 'FOOTBALL',
        titleFa: 'فوتبال',
        emoji: '⚽',
        family: MovementFamily.sport,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.duration,
        isOutdoor: true,
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
      'ROCK_CLIMBING': const MvMovementKind(
        code: 'ROCK_CLIMBING',
        titleFa: 'سنگ‌نوردی / صخره‌نوردی',
        emoji: '🧗‍♂️',
        family: MovementFamily.outdoor,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.duration,
        isOutdoor: true,
        isSocial: false,
        needsVenue: true,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      ),
      'BODYWEIGHT': const MvMovementKind(
        code: 'BODYWEIGHT',
        titleFa: 'تمرین با وزن بدن',
        emoji: '🤸‍♂️',
        family: MovementFamily.strength,
        baseMet: 5.0,
        metLow: 3.5,
        metHigh: 6.5,
        primaryMetric: MovementMetric.duration,
        isOutdoor: false,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      ),
      'WALKING': const MvMovementKind(
        code: 'WALKING',
        titleFa: 'پیاده‌روی',
        emoji: '🚶‍♂️',
        family: MovementFamily.endurance,
        baseMet: 3.5,
        metLow: 2.5,
        metHigh: 4.5,
        primaryMetric: MovementMetric.duration,
        isOutdoor: true,
        isSocial: false,
        needsVenue: false,
        jointImpact: 1,
        isCustom: false,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 0,
      ),
    };

    final kindProfilesMap = <String, MvKindProfile>{
      'FOOTBALL': const MvKindProfile(
        kindCode: 'FOOTBALL',
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
      'ROCK_CLIMBING': const MvKindProfile(
        kindCode: 'ROCK_CLIMBING',
        primaryMuscles: ['forearms', 'lats', 'core', 'fingers'],
        neuroCost: 3,
        recoveryHours: 48,
        complementFocus: ['antagonist_push', 'shoulder_external_rotators'],
      ),
      'BODYWEIGHT': const MvKindProfile(
        kindCode: 'BODYWEIGHT',
        primaryMuscles: ['chest', 'back', 'core', 'quads'],
        neuroCost: 2,
        recoveryHours: 48,
        complementFocus: ['core', 'upper_body'],
      ),
      'WALKING': const MvKindProfile(
        kindCode: 'WALKING',
        primaryMuscles: ['calves', 'quads'],
        neuroCost: 1,
        recoveryHours: 12,
        complementFocus: ['core'],
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
      'FOOTBALL anchor -> strength day must have posterior_chain in focus with complement reasonKey',
      () {
        final footballCommitment = MvCommitment(
          id: 1,
          kindCode: 'FOOTBALL',
          dayOfWeekSat0: 5, // پنجشنبه
          startTime: '20:00',
          durationMinutes: 90,
        );

        final result = planEngine.generateWeek(
          weekStartSat: weekStartSat,
          profile: MvUserProfile.empty(),
          commitments: [footballCommitment],
          overrides: const [],
          kinds: kindsMap,
          kindProfiles: kindProfilesMap,
          budget: budget,
          load: null,
          readiness: MvReadinessTier.full,
        );

        final complementStrengthSlot = result.slots.firstWhere(
          (s) =>
              s.slotType == MvSlotType.strength &&
              s.reasonKey == MvReasonKeys.complement,
        );
        expect(complementStrengthSlot.focusCodes, contains('posterior_chain'));
        expect(complementStrengthSlot.reasonParams?['kind'], equals('فوتبال'));
      },
    );

    test('HIKING anchor -> strength day must have eccentric_quad in focus', () {
      final hikingCommitment = MvCommitment(
        id: 1,
        kindCode: 'HIKING',
        dayOfWeekSat0: 6, // جمعه
        startTime: '06:00',
        durationMinutes: 240,
      );

      final result = planEngine.generateWeek(
        weekStartSat: weekStartSat,
        profile: MvUserProfile.empty(),
        commitments: [hikingCommitment],
        overrides: const [],
        kinds: kindsMap,
        kindProfiles: kindProfilesMap,
        budget: budget,
        load: null,
        readiness: MvReadinessTier.full,
      );

      final complementStrengthSlot = result.slots.firstWhere(
        (s) =>
            s.slotType == MvSlotType.strength &&
            s.reasonKey == MvReasonKeys.complement,
      );
      expect(complementStrengthSlot.focusCodes, contains('eccentric_quad'));
      expect(complementStrengthSlot.reasonParams?['kind'], equals('کوهنوردی'));
    });

    test(
      'ROCK_CLIMBING anchor -> strength day must have antagonist_push in focus',
      () {
        final climbingCommitment = MvCommitment(
          id: 1,
          kindCode: 'ROCK_CLIMBING',
          dayOfWeekSat0: 3, // سه‌شنبه
          startTime: '18:00',
          durationMinutes: 90,
        );

        final result = planEngine.generateWeek(
          weekStartSat: weekStartSat,
          profile: MvUserProfile.empty(),
          commitments: [climbingCommitment],
          overrides: const [],
          kinds: kindsMap,
          kindProfiles: kindProfilesMap,
          budget: budget,
          load: null,
          readiness: MvReadinessTier.full,
        );

        final complementStrengthSlot = result.slots.firstWhere(
          (s) =>
              s.slotType == MvSlotType.strength &&
              s.reasonKey == MvReasonKeys.complement,
        );
        expect(complementStrengthSlot.focusCodes, contains('antagonist_push'));
        expect(
          complementStrengthSlot.reasonParams?['kind'],
          equals('سنگ‌نوردی / صخره‌نوردی'),
        );
      },
    );
  });
}
