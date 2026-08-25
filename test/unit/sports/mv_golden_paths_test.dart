import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/plan_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('S3-T10 Three Comprehensive Golden Paths End-to-End Tests', () {
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

    test('Golden Path 1 — Weekly Futsal Player (پنجشنبه ۲۱:۰۰ فوتسال ۹۰ دقیقه)', () {
      final futsalCommitment = MvCommitment(
        id: 1,
        kindCode: 'FUTSAL',
        dayOfWeekSat0: 5, // پنجشنبه
        startTime: '21:00',
        durationMinutes: 90,
        titleFa: 'فوتسال هفتگی',
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

      expect(result.slots.length, equals(7));

      // 1. Thursday: locked anchor slot with exact kind and time
      final thuSlot = result.slots.firstWhere((s) => s.dateIso == '2026-08-27');
      expect(thuSlot.isLocked, isTrue);
      expect(thuSlot.kindCode, equals('FUTSAL'));
      expect(thuSlot.plannedTime, equals('21:00'));
      expect(thuSlot.targetMinutes, equals(90));
      expect(thuSlot.reasonKey, equals(MvReasonKeys.anchor));

      // 2. Wednesday: preAnchorTaper mobility <= 20 min
      final wedSlot = result.slots.firstWhere((s) => s.dateIso == '2026-08-26');
      expect(wedSlot.slotType, equals(MvSlotType.mobility));
      expect(wedSlot.targetMinutes, lessThanOrEqualTo(20));
      expect(wedSlot.reasonKey, equals(MvReasonKeys.preAnchorTaper));

      // 3. Friday: postAnchorRecovery activeRest <= 25 min
      final friSlot = result.slots.firstWhere((s) => s.dateIso == '2026-08-28');
      expect(friSlot.slotType, equals(MvSlotType.activeRest));
      expect(friSlot.targetMinutes, lessThanOrEqualTo(25));
      expect(friSlot.reasonKey, equals(MvReasonKeys.postAnchorRecovery));

      // 4. Two strength days with posterior_chain / complement focus
      final strengthSlots = result.slots.where((s) => s.slotType == MvSlotType.strength).toList();
      expect(strengthSlots.length, greaterThanOrEqualTo(2));
      expect(strengthSlots.any((s) => s.focusCodes.contains('posterior_chain')), isTrue);
      expect(strengthSlots.any((s) => s.reasonKey == MvReasonKeys.complement), isTrue);

      // 5. Total moderate equivalent minutes >= 150
      int totalEquivMinutes = 0;
      for (final s in result.slots) {
        final kind = kindsMap[s.kindCode];
        final met = kind?.baseMet ?? (s.slotType == MvSlotType.strength ? 4.5 : 3.0);
        if (met >= 6.0) {
          totalEquivMinutes += s.targetMinutes * 2;
        } else if (met >= 3.0) {
          totalEquivMinutes += s.targetMinutes;
        }
      }
      expect(totalEquivMinutes, greaterThanOrEqualTo(150));

      // 6. Every slot has a valid, non-null reasonKey
      for (final s in result.slots) {
        expect(s.reasonKey, isNotNull);
        expect(s.reasonKey, isNotEmpty);
        expect(MvReasonKeys.all, contains(s.reasonKey));
      }
    });

    test('Golden Path 2 — Friday Hiker (جمعه ۰۶:۰۰ کوه ۲۴۰ دقیقه)', () {
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
        commitments: [hikingCommitment],
        overrides: const [],
        kinds: kindsMap,
        kindProfiles: kindProfilesMap,
        budget: budget,
        load: null,
        readiness: MvReadinessTier.full,
      );

      expect(result.slots.length, equals(7));

      // 1. Friday: locked anchor slot
      final friSlot = result.slots.firstWhere((s) => s.dateIso == '2026-08-28');
      expect(friSlot.isLocked, isTrue);
      expect(friSlot.kindCode, equals('HIKING'));
      expect(friSlot.plannedTime, equals('06:00'));
      expect(friSlot.targetMinutes, equals(240));

      // 2. Thursday: light mobility <= 20 min
      final thuSlot = result.slots.firstWhere((s) => s.dateIso == '2026-08-27');
      expect(thuSlot.slotType, equals(MvSlotType.mobility));
      expect(thuSlot.targetMinutes, lessThanOrEqualTo(20));
      expect(thuSlot.reasonKey, equals(MvReasonKeys.preAnchorTaper));

      // 3. Saturday: postAnchorRecovery activeRest <= 25 min
      final satSlot = result.slots.firstWhere((s) => s.dateIso == '2026-08-22');
      expect(satSlot.slotType, equals(MvSlotType.activeRest));
      expect(satSlot.targetMinutes, lessThanOrEqualTo(25));
      expect(satSlot.reasonKey, equals(MvReasonKeys.postAnchorRecovery));

      // 4. Two strength days with eccentric_quad / complement focus
      final strengthSlots = result.slots.where((s) => s.slotType == MvSlotType.strength).toList();
      expect(strengthSlots.length, greaterThanOrEqualTo(2));
      expect(strengthSlots.any((s) => s.focusCodes.contains('eccentric_quad')), isTrue);

      // 5. No heavy strength on Thursday (ADJ-7)
      expect(thuSlot.slotType, isNot(equals(MvSlotType.strength)));

      // 6. Every slot has a valid reasonKey
      for (final s in result.slots) {
        expect(s.reasonKey, isNotNull);
        expect(s.reasonKey, isNotEmpty);
        expect(MvReasonKeys.all, contains(s.reasonKey));
      }
    });

    test('Golden Path 3 — Consecutive Anchors (پنجشنبه فوتسال + جمعه کوه)', () {
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

      // 1. Conflict banner active
      expect(result.hasConflict, isTrue);
      expect(result.conflictNote, equals('mv_conflict_back_to_back'));

      // 2. Saturday: activeRest
      final satSlot = result.slots.firstWhere((s) => s.dateIso == '2026-08-22');
      expect(satSlot.slotType, equals(MvSlotType.activeRest));
      expect(satSlot.targetMinutes, lessThanOrEqualTo(25));

      // 3. At least 1 full rest day
      expect(result.slots.any((s) => s.slotType == MvSlotType.rest), isTrue);

      // 4. Every slot has valid reasonKey
      for (final s in result.slots) {
        expect(s.reasonKey, isNotNull);
        expect(s.reasonKey, isNotEmpty);
        expect(MvReasonKeys.all, contains(s.reasonKey));
      }
    });
  });
}
