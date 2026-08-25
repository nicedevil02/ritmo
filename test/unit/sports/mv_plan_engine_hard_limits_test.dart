import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/plan_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('PlanEngine Stage 2: HARD_LIMITS Unit Tests (S3-T5)', () {
    const planEngine = PlanEngine();
    final weekStartSat = DateTime.parse(
      '2026-08-22',
    ); // تابستان (Mordad / Shahrivar 1405 -> Season bit 2)

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
      'SKIING': const MvMovementKind(
        code: 'SKIING',
        titleFa: 'اسکی',
        emoji: '⛷️',
        family: MovementFamily.outdoor,
        baseMet: 7.0,
        metLow: 5.0,
        metHigh: 9.0,
        primaryMetric: MovementMetric.duration,
        seasonMask: '10,11,12', // زمستان فقط
        isOutdoor: true,
        isSocial: false,
        needsVenue: true,
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
      'SWIMMING': const MvKindProfile(
        kindCode: 'SWIMMING',
        primaryMuscles: ['lats', 'shoulders', 'core'],
        neuroCost: 1,
        recoveryHours: 24,
        complementFocus: ['core', 'scapular_stability'],
      ),
      'SKIING': const MvKindProfile(
        kindCode: 'SKIING',
        primaryMuscles: ['quads', 'glutes', 'calves'],
        neuroCost: 2,
        recoveryHours: 36,
        complementFocus: ['eccentric_quad', 'ankle'],
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
      'User with knee pain limitation: high joint impact filler kinds excluded, but anchor futsal preserved with constraint note',
      () {
        const kneeProfile = MvUserProfile(
          physicalLimitations: ['knee'],
          createdAt: 100,
          updatedAt: 100,
        );

        final futsalCommitment = MvCommitment(
          id: 1,
          kindCode: 'FUTSAL',
          dayOfWeekSat0: 5, // پنجشنبه
          startTime: '21:00',
          durationMinutes: 90,
          titleFa: 'فوتسال پنجشنبه',
        );

        final result = planEngine.generateWeek(
          weekStartSat: weekStartSat,
          profile: kneeProfile,
          commitments: [futsalCommitment],
          overrides: const [],
          kinds: kindsMap,
          kindProfiles: kindProfilesMap,
          budget: budget,
          load: null,
          readiness: MvReadinessTier.full,
        );

        // High-impact kinds (FUTSAL with jointImpact=3) must be excluded from allowedKinds for filling
        expect(result.allowedKinds.containsKey('FUTSAL'), isFalse);
        // Low-impact kinds (SWIMMING with jointImpact=1) must be preserved
        expect(result.allowedKinds.containsKey('SWIMMING'), isTrue);

        // Out-of-season kind (SKIING seasonMask=8 vs summer=2) must be excluded
        expect(result.allowedKinds.containsKey('SKIING'), isFalse);

        // Fixed anchor slot FUTSAL must stay locked on Thursday
        final thursdaySlot = result.slots.firstWhere(
          (s) => s.dateIso == '2026-08-27',
        );
        expect(thursdaySlot.isLocked, isTrue);
        expect(thursdaySlot.kindCode, equals('FUTSAL'));

        // Anchor must have constraint warning attached
        expect(thursdaySlot.coachNoteFa, contains('زانو'));
        expect(
          thursdaySlot.reasonParams?['constraintNote'],
          equals('mv_anchor_constraint_note'),
        );
        expect(result.notes, contains('mv_anchor_constraint_note'));
      },
    );
  });
}
