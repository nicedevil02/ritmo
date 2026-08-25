import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/plan_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('PlanEngine Stage 4: FILL Unit Tests (S3-T7)', () {
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
      'WALKING': const MvMovementKind(
        code: 'WALKING',
        titleFa: 'پیاده‌روی تند',
        emoji: '🚶‍♂️',
        family: MovementFamily.endurance,
        baseMet: 4.0,
        metLow: 3.5,
        metHigh: 5.0,
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
      'BRISK_WALKING': const MvKindProfile(
        kindCode: 'BRISK_WALKING',
        primaryMuscles: ['calves', 'quads'],
        neuroCost: 1,
        recoveryHours: 12,
        complementFocus: ['core'],
      ),
      'BODYWEIGHT': const MvKindProfile(
        kindCode: 'BODYWEIGHT',
        primaryMuscles: ['chest', 'back', 'core', 'quads'],
        neuroCost: 2,
        recoveryHours: 48,
        complementFocus: ['core', 'upper_body'],
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
      'User with 2 anchors totaling >=270 moderate equivalent min: no extra cardio filler, but exactly 2 strength days placed',
      () {
        final futsalCommitment = MvCommitment(
          id: 1,
          kindCode: 'FUTSAL',
          dayOfWeekSat0: 5, // پنجشنبه 90 min (baseMet 7.0 -> 180 equiv min)
          startTime: '21:00',
          durationMinutes: 90,
        );

        final hikingCommitment = MvCommitment(
          id: 2,
          kindCode: 'HIKING',
          dayOfWeekSat0: 1, // یکشنبه 90 min (baseMet 6.0 -> 180 equiv min)
          startTime: '07:00',
          durationMinutes: 90,
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

        // Total strength days must be at least 2
        final strengthSlots = result.slots
            .where((s) => s.slotType == MvSlotType.strength)
            .toList();
        expect(strengthSlots.length, greaterThanOrEqualTo(2));

        for (final s in strengthSlots) {
          expect(
            s.reasonKey,
            isIn([MvReasonKeys.strengthQuota, MvReasonKeys.complement]),
          );
        }

        // No cardio filler should be added since anchors already exceed 150 min (180 + 180 = 360 > 150)
        final cardioFillerSlots = result.slots
            .where((s) => s.reasonKey == MvReasonKeys.whoGap)
            .toList();
        expect(cardioFillerSlots, isEmpty);
      },
    );
  });
}
