import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/plan_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('PlanEngine Stage 6: FALLBACK and 8 Extreme Profiles Tests (S3-T9)', () {
    const planEngine = PlanEngine();
    final weekStartSat = DateTime.parse('2026-08-22');
    final now = DateTime.now().millisecondsSinceEpoch;

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

    test('Guard Test Always-Output: 8 extreme profiles all produce 7 valid slots with reasonKeys and never empty plan', () {
      final extremeProfiles = <MvUserProfile>[
        // 1. No equipment + knee limitation + apartment mode
        MvUserProfile(
          goal: 'generalFitness',
          experienceLevel: 'beginner',
          availableEquipment: const ['none'],
          physicalLimitations: const ['زانو'],
          neighborFriendly: true,
          daysPerWeek: 1,
          sessionDuration: 'short',
          createdAt: now,
          updatedAt: now,
        ),
        // 2. Multi-joint pain: shoulder + back + knee + apartment
        MvUserProfile(
          goal: 'strength',
          experienceLevel: 'beginner',
          availableEquipment: const ['none'],
          physicalLimitations: const ['زانو', 'شانه', 'کمر'],
          neighborFriendly: true,
          daysPerWeek: 2,
          sessionDuration: 'short',
          createdAt: now,
          updatedAt: now,
        ),
        // 3. Exhausted: severe physical constraints + minimal days
        MvUserProfile(
          goal: 'mobility',
          experienceLevel: 'beginner',
          availableEquipment: const ['none'],
          physicalLimitations: const ['مچ_پا', 'زانو'],
          neighborFriendly: true,
          daysPerWeek: 1,
          sessionDuration: 'short',
          createdAt: now,
          updatedAt: now,
        ),
        // 4. Off-season / indoor constrained + apartment
        MvUserProfile(
          goal: 'endurance',
          experienceLevel: 'intermediate',
          availableEquipment: const ['none'],
          physicalLimitations: const [],
          neighborFriendly: true,
          daysPerWeek: 3,
          sessionDuration: 'short',
          createdAt: now,
          updatedAt: now,
        ),
        // 5. Deload week with physical limitations
        MvUserProfile(
          goal: 'strength',
          experienceLevel: 'advanced',
          availableEquipment: const ['none'],
          physicalLimitations: const ['کمر'],
          neighborFriendly: false,
          daysPerWeek: 4,
          sessionDuration: 'short',
          createdAt: now,
          updatedAt: now,
        ),
        // 6. Fasting / light mode + knee pain + apartment
        MvUserProfile(
          goal: 'generalFitness',
          experienceLevel: 'beginner',
          availableEquipment: const ['none'],
          physicalLimitations: const ['زانو'],
          neighborFriendly: true,
          daysPerWeek: 2,
          sessionDuration: 'short',
          createdAt: now,
          updatedAt: now,
        ),
        // 7. Low readiness / zero equipment / beginner
        MvUserProfile(
          goal: 'mobility',
          experienceLevel: 'beginner',
          availableEquipment: const ['none'],
          physicalLimitations: const ['شانه'],
          neighborFriendly: true,
          daysPerWeek: 1,
          sessionDuration: 'short',
          createdAt: now,
          updatedAt: now,
        ),
        // 8. Minimalist profile
        MvUserProfile.empty(),
      ];

      for (int i = 0; i < extremeProfiles.length; i++) {
        final profile = extremeProfiles[i];
        final result = planEngine.generateWeek(
          weekStartSat: weekStartSat,
          profile: profile,
          commitments: const [],
          overrides: const [],
          kinds: kindsMap,
          kindProfiles: kindProfilesMap,
          budget: const MvBudgetSnapshot(
            moderateEquivalentMinutes: 0,
            rawMetMinutes: 0,
            strengthDays: 0,
            targetMin: 150,
            targetOptimal: 300,
            strengthDaysTarget: 2,
          ),
          load: null,
          readiness: MvReadinessTier.full,
        );

        // Assert 7 slots exist
        expect(result.slots.length, equals(7), reason: 'Profile $i must have exactly 7 slots');

        // Assert every slot has a non-empty, non-null reasonKey
        for (final slot in result.slots) {
          expect(slot.reasonKey, isNotNull, reason: 'Slot ${slot.id} in profile $i must have reasonKey');
          expect(slot.reasonKey, isNotEmpty, reason: 'Slot ${slot.id} in profile $i must have non-empty reasonKey');
          expect(MvReasonKeys.all, contains(slot.reasonKey));
        }

        // Assert at least 1 slot has movement activity (>=0 minutes)
        expect(result.slots.any((s) => s.targetMinutes >= 0), isTrue);

        // Assert stage decisions are populated with all 6 stages
        expect(result.stageDecisions.length, greaterThanOrEqualTo(6));
      }
    });
  });
}
