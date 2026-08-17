import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/models/medication_models.dart';

void main() {
  group('Phase 4: Specialized Clinical Logic for Insulin & Non-Pill Medications', () {
    test('InsulinType enums parse correctly and provide accurate clinical timing instructions', () {
      expect(InsulinType.fromString('RAPID_ACTING'), InsulinType.RAPID_ACTING);
      expect(InsulinType.fromString('long_acting'), InsulinType.LONG_ACTING);
      expect(InsulinType.fromString('invalid'), isNull);

      // Verify timing instructions
      const rapid = InsulinType.RAPID_ACTING;
      expect(rapid.timingInstructionFa, contains('درست قبل از شروع وعده غذایی'));

      const basal = InsulinType.LONG_ACTING;
      expect(basal.timingInstructionFa, contains('یک‌بار در روز در زمان کاملاً ثابت'));
    });

    test('InjectionSite enums cover all 8 standard subcutaneous rotation sites', () {
      const sites = InjectionSite.values;
      expect(sites.length, 8);
      expect(InjectionSite.ABDOMEN_RIGHT.labelFa, contains('شکم'));
      expect(InjectionSite.ARM_LEFT.labelFa, contains('بازوی چپ'));
      expect(InjectionSite.THIGH_RIGHT.labelFa, contains('ران راست'));
      expect(InjectionSite.BUTTOCK_LEFT.labelFa, contains('باسن چپ'));
    });

    test('DropApplicationSite enums cover eyes, ears, and nose targets', () {
      expect(DropApplicationSite.fromString('EYES_BOTH'), DropApplicationSite.EYES_BOTH);
      expect(DropApplicationSite.EYES_BOTH.labelFa, 'هر دو چشم');
      expect(DropApplicationSite.EAR_LEFT.labelFa, 'گوش چپ');
      expect(DropApplicationSite.NOSE_RIGHT.labelFa, 'سوراخ راست بینی');
    });

    test('ClinicalFormHelper provides evidence-based safety guidance for non-pill forms', () {
      final insulinNote = ClinicalFormHelper.getClinicalEducationNote(MedicationForm.INSULIN);
      expect(insulinNote, isNotNull);
      expect(insulinNote, contains('لیپوهایپرتروفی'));

      final inhalerNote = ClinicalFormHelper.getClinicalEducationNote(MedicationForm.INHALER);
      expect(inhalerNote, isNotNull);
      expect(inhalerNote, contains('برفک دهانی'));

      final patchNote = ClinicalFormHelper.getClinicalEducationNote(MedicationForm.PATCH);
      expect(patchNote, isNotNull);
      expect(patchNote, contains('۷ روز'));

      final dropNote = ClinicalFormHelper.getClinicalEducationNote(MedicationForm.DROPS);
      expect(dropNote, isNotNull);
      expect(dropNote, contains('مجرای اشکی'));

      // Standard tablet has no special non-pill note
      expect(ClinicalFormHelper.getClinicalEducationNote(MedicationForm.TABLET), isNull);
    });

    test('MedicationForm mapped default dose units and routes for non-pill medications', () {
      expect(MedicationForm.INSULIN.defaultUnit, DoseUnit.IU);
      expect(MedicationForm.INSULIN.defaultRoute, MedicationRoute.SUBCUTANEOUS);

      expect(MedicationForm.INHALER.defaultUnit, DoseUnit.PUFF);
      expect(MedicationForm.INHALER.defaultRoute, MedicationRoute.INHALED);

      expect(MedicationForm.DROPS.defaultUnit, DoseUnit.DROP);
      expect(MedicationForm.DROPS.defaultRoute, MedicationRoute.OPHTHALMIC);

      expect(MedicationForm.PATCH.defaultUnit, DoseUnit.PATCH);
      expect(MedicationForm.PATCH.defaultRoute, MedicationRoute.TOPICAL);

      expect(MedicationForm.SYRUP.defaultUnit, DoseUnit.ML);
      expect(MedicationForm.SYRUP.defaultRoute, MedicationRoute.ORAL);
    });

    test('Subcutaneous site rotation history prevents repeat injection at same site', () {
      final siteHistory = <InjectionSite>[];

      // Day 1
      siteHistory.add(InjectionSite.ABDOMEN_RIGHT);
      // Day 2
      siteHistory.add(InjectionSite.ABDOMEN_LEFT);
      // Day 3
      siteHistory.add(InjectionSite.THIGH_RIGHT);

      final lastSite = siteHistory.last;
      final nextRecommendedSites = InjectionSite.values.where((s) => s != lastSite).toList();

      expect(nextRecommendedSites.contains(InjectionSite.THIGH_RIGHT), isFalse);
      expect(nextRecommendedSites.contains(InjectionSite.THIGH_LEFT), isTrue);
      expect(nextRecommendedSites.contains(InjectionSite.ARM_RIGHT), isTrue);
    });
  });
}
