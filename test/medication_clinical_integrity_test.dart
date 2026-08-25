import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/medical_engine.dart';
import 'package:ritmo/features/health/data/medication_repository.dart';
import 'package:ritmo/features/health/models/medication_models.dart';

void main() {
  group('Clinical Grade Medication Integrity Tests', () {
    test('C-01: calculateDeductionUnits prevents mg to tablet count mismatch', () {
      // 1. Tablet with 500mg dose and 500mg strength -> 1.0 tablet deducted
      const tablet500 = MedicationProfile(
        routineId: 'med_1',
        form: MedicationForm.TABLET,
        doseAmount: 500.0,
        doseUnit: DoseUnit.MG,
        strength: '500 mg',
      );
      expect(
        MedicationRepository.calculateDeductionUnits(profile: tablet500),
        1.0,
      );

      // 2. Tablet with 1000mg dose and 500mg strength -> 2.0 tablets deducted
      expect(
        MedicationRepository.calculateDeductionUnits(
          profile: tablet500,
          doseAmount: 1000.0,
          doseUnit: 'MG',
        ),
        2.0,
      );

      // 3. Tablet with 500mg dose without strength -> safe fallback to 1.0 tablet (NOT 500 tablets!)
      const tabletNoStrength = MedicationProfile(
        routineId: 'med_2',
        form: MedicationForm.TABLET,
        doseAmount: 500.0,
        doseUnit: DoseUnit.MG,
      );
      expect(
        MedicationRepository.calculateDeductionUnits(profile: tabletNoStrength),
        1.0,
      );

      // 4. Syrup with 5ml dose -> 5.0 ml deducted
      const syrup = MedicationProfile(
        routineId: 'med_3',
        form: MedicationForm.SYRUP,
        doseAmount: 5.0,
        doseUnit: DoseUnit.ML,
      );
      expect(
        MedicationRepository.calculateDeductionUnits(profile: syrup),
        5.0,
      );

      // 5. Insulin with 15 IU dose -> 15.0 IU deducted
      const insulin = MedicationProfile(
        routineId: 'med_4',
        form: MedicationForm.INSULIN,
        doseAmount: 15.0,
        doseUnit: DoseUnit.IU,
      );
      expect(
        MedicationRepository.calculateDeductionUnits(profile: insulin),
        15.0,
      );
    });

    test('C-02: hasStockTracking works when packageSize is null but remainingAmount is set', () {
      // Legacy backfilled profile where packageSize is null
      const legacyProfile = MedicationProfile(
        routineId: 'med_legacy',
        packageSize: null,
        remainingAmount: 20.0,
        refillThresholdAmount: 5.0,
      );

      expect(legacyProfile.hasStockTracking, isTrue);
      expect(legacyProfile.isLowStock, isFalse);
      expect(legacyProfile.isOutOfStock, isFalse);

      // When remainingAmount <= refillThresholdAmount
      final lowStockProfile = legacyProfile.copyWith(remainingAmount: 4.0);
      expect(lowStockProfile.isLowStock, isTrue);

      // When remainingAmount <= 0
      final outOfStockProfile = legacyProfile.copyWith(remainingAmount: 0.0);
      expect(outOfStockProfile.isOutOfStock, isTrue);
    });

    test('H-06: Sentinel copyWith allows clearing nullable fields explicitly', () {
      const profile = MedicationProfile(
        routineId: 'med_sentinel',
        endDate: 1710000000000,
        prescriberName: 'دکتر محمدی',
        instructions: 'قبل از غذا',
        strength: '250mg',
        activeIngredient: 'Amoxicillin',
      );

      // Explicitly pass null to clear
      final cleared = profile.copyWith(
        endDate: null,
        prescriberName: null,
        instructions: null,
        strength: null,
        activeIngredient: null,
      );

      expect(cleared.endDate, isNull);
      expect(cleared.prescriberName, isNull);
      expect(cleared.instructions, isNull);
      expect(cleared.strength, isNull);
      expect(cleared.activeIngredient, isNull);

      // Calling copyWith without parameters preserves existing values
      final preserved = profile.copyWith(routineId: 'med_new_id');
      expect(preserved.endDate, 1710000000000);
      expect(preserved.prescriberName, 'دکتر محمدی');
    });

    test('H-10: OverdoseResult.warningBoth is reported when interval and max doses are violated', () {
      final now = DateTime(2026, 8, 25, 12, 0).millisecondsSinceEpoch;
      // 3 doses taken already, last taken 1 hour ago
      final logs = [
        DateTime(2026, 8, 25, 6, 0).millisecondsSinceEpoch,
        DateTime(2026, 8, 25, 9, 0).millisecondsSinceEpoch,
        DateTime(2026, 8, 25, 11, 0).millisecondsSinceEpoch,
      ];

      final res = MedicalEngine.checkOverdoseStatus(
        now: now,
        prnLogs24h: logs,
        minIntervalHours: 4, // requires 4 hours, only 1 hour passed -> violated!
        maxDosesPerDay: 3,   // max 3 doses allowed, already 3 taken -> violated!
      );

      expect(res, OverdoseResult.warningBoth);
    });

    test('H-07: Refill and out-of-stock evaluation supports decimal amounts', () {
      expect(MedicalEngine.isRefillNeeded(stockCount: 0.5, warningThreshold: 1.0), isTrue);
      expect(MedicalEngine.isRefillNeeded(stockCount: 1.5, warningThreshold: 1.0), isFalse);
      expect(MedicalEngine.isOutOfStock(stockCount: 0.0), isTrue);
      expect(MedicalEngine.isOutOfStock(stockCount: 0.5), isFalse);
    });

    test('M-14: Medication preserves and maps isPrivate correctly', () {
      final routine = {
        'id': 'med_private_1',
        'title': 'داروی محرمانه',
        'isPrivate': 1,
        'category': 'medical',
        'itemType': 'MEDICINE',
      };
      final med = Medication.fromRoutineAndProfile(routine, null);
      expect(med.isPrivate, isTrue);

      final publicRoutine = {
        'id': 'med_public_1',
        'title': 'داروی عمومی',
        'isPrivate': 0,
        'category': 'medical',
        'itemType': 'MEDICINE',
      };
      final publicMed = Medication.fromRoutineAndProfile(publicRoutine, null);
      expect(publicMed.isPrivate, isFalse);
    });

    test('M-18: ClinicalFormHelper gives distinct advice for eye, ear, and nose routes', () {
      // 1. Ear drops
      final earAdvice = ClinicalFormHelper.getClinicalEducationNote(
        MedicationForm.DROPS,
        route: MedicationRoute.OTIC,
      );
      expect(earAdvice, contains('گوش'));
      expect(earAdvice, isNot(contains('مجرای اشکی')));

      // 2. Eye drops
      final eyeAdvice = ClinicalFormHelper.getClinicalEducationNote(
        MedicationForm.DROPS,
        route: MedicationRoute.OPHTHALMIC,
      );
      expect(eyeAdvice, contains('مجرای اشکی'));

      // 3. Nose drops
      final noseAdvice = ClinicalFormHelper.getClinicalEducationNote(
        MedicationForm.DROPS,
        route: MedicationRoute.NASAL,
      );
      expect(noseAdvice, contains('بینی'));

      // 4. Nasal spray vs Inhaler spray
      final nasalSprayAdvice = ClinicalFormHelper.getClinicalEducationNote(
        MedicationForm.SPRAY,
        route: MedicationRoute.NASAL,
      );
      expect(nasalSprayAdvice, contains('بینی'));

      final inhaledSprayAdvice = ClinicalFormHelper.getClinicalEducationNote(
        MedicationForm.SPRAY,
        route: MedicationRoute.INHALED,
      );
      expect(inhaledSprayAdvice, contains('برفک دهانی'));
    });

    test('M-19: fromStringOrNull safely returns null for unrecognized enum strings', () {
      expect(MedicationForm.fromStringOrNull('TABLET'), MedicationForm.TABLET);
      expect(MedicationForm.fromStringOrNull('INSULIN'), MedicationForm.INSULIN);
      expect(MedicationForm.fromStringOrNull('NON_EXISTENT_FORM'), isNull);
      expect(MedicationForm.fromStringOrNull(''), isNull);
      expect(MedicationForm.fromStringOrNull(null), isNull);

      expect(DoseUnit.fromStringOrNull('MG'), DoseUnit.MG);
      expect(DoseUnit.fromStringOrNull('IU'), DoseUnit.IU);
      expect(DoseUnit.fromStringOrNull('INVALID_UNIT'), isNull);
      expect(DoseUnit.fromStringOrNull(null), isNull);
    });
  });
}
