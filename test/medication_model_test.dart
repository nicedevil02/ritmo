import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/models/medication_models.dart';

void main() {
  group('MedicationForm and Enums Tests', () {
    test('MedicationForm parses correctly and maps defaults', () {
      expect(MedicationForm.fromString('TABLET'), MedicationForm.TABLET);
      expect(MedicationForm.fromString('insulin'), MedicationForm.INSULIN);
      expect(MedicationForm.fromString('UNKNOWN_XYZ'), MedicationForm.TABLET);

      expect(MedicationForm.INSULIN.defaultUnit, DoseUnit.IU);
      expect(MedicationForm.INSULIN.defaultRoute, MedicationRoute.SUBCUTANEOUS);

      expect(MedicationForm.DROPS.defaultUnit, DoseUnit.DROP);
      expect(MedicationForm.DROPS.defaultRoute, MedicationRoute.OPHTHALMIC);

      expect(MedicationForm.SYRUP.defaultUnit, DoseUnit.ML);
      expect(MedicationForm.SYRUP.defaultRoute, MedicationRoute.ORAL);

      expect(MedicationForm.INHALER.defaultUnit, DoseUnit.PUFF);
      expect(MedicationForm.INHALER.defaultRoute, MedicationRoute.INHALED);

      expect(MedicationForm.SPRAY.defaultUnit, DoseUnit.PUFF);
      expect(MedicationForm.SPRAY.defaultRoute, MedicationRoute.NASAL);
    });

    test('DoseUnit parses and formats labels', () {
      expect(DoseUnit.fromString('IU'), DoseUnit.IU);
      expect(DoseUnit.fromString('mg'), DoseUnit.MG);
      expect(DoseUnit.fromString('ML'), DoseUnit.ML);
      expect(DoseUnit.fromString('PUFF'), DoseUnit.PUFF);
      expect(DoseUnit.fromString('DROP'), DoseUnit.DROP);

      expect(DoseUnit.IU.shortLabelFa, 'واحد');
      expect(DoseUnit.MG.shortLabelFa, 'mg');
      expect(DoseUnit.ML.shortLabelFa, 'ml');
    });

    test('MedicationRoute and FoodRelation parse correctly', () {
      expect(MedicationRoute.fromString('SUBCUTANEOUS'), MedicationRoute.SUBCUTANEOUS);
      expect(MedicationRoute.fromString('ORAL'), MedicationRoute.ORAL);
      expect(MedicationRoute.fromString('OPHTHALMIC'), MedicationRoute.OPHTHALMIC);
      expect(MedicationRoute.fromString(null), isNull);

      expect(FoodRelation.fromString('BEFORE_MEAL'), FoodRelation.BEFORE_MEAL);
      expect(FoodRelation.fromString('WITH_FOOD'), FoodRelation.WITH_FOOD);
      expect(FoodRelation.fromString(null), FoodRelation.NONE);
    });
  });

  group('MedicationProfile toMap and fromMap Tests', () {
    test('roundtrip serialization of full medication profile', () {
      const profile = MedicationProfile(
        routineId: 'routine_med_123',
        form: MedicationForm.INSULIN,
        route: MedicationRoute.SUBCUTANEOUS,
        doseAmount: 10.0,
        doseUnit: DoseUnit.IU,
        strength: '100 IU/ml',
        activeIngredient: 'Insulin Glargine',
        foodRelation: FoodRelation.BEFORE_MEAL,
        startDate: 1700000000000,
        endDate: 1710000000000,
        isChronic: true,
        durationDays: 90,
        prescriberName: 'دکتر علوی',
        instructions: 'هر شب ۱۰ واحد قبل خواب تزریق شود',
        criticality: MedicationCriticality.LIFE_CRITICAL,
        packageSize: 300.0,
        packageUnit: 'واحد',
        remainingAmount: 180.0,
        refillThresholdAmount: 50.0,
        injectionSites: ['شکم راست', 'شکم چپ', 'بازو'],
        lastInjectionSite: 'شکم راست',
        needsSiteRotation: true,
      );

      final map = profile.toMap();
      expect(map['routineId'], 'routine_med_123');
      expect(map['form'], 'INSULIN');
      expect(map['route'], 'SUBCUTANEOUS');
      expect(map['doseAmount'], 10.0);
      expect(map['doseUnit'], 'IU');
      expect(map['strength'], '100 IU/ml');
      expect(map['activeIngredient'], 'Insulin Glargine');
      expect(map['criticality'], 'LIFE_CRITICAL');
      expect(map['needsSiteRotation'], 1);

      final reconstructed = MedicationProfile.fromMap(map);
      expect(reconstructed.routineId, profile.routineId);
      expect(reconstructed.form, MedicationForm.INSULIN);
      expect(reconstructed.route, MedicationRoute.SUBCUTANEOUS);
      expect(reconstructed.doseAmount, 10.0);
      expect(reconstructed.doseUnit, DoseUnit.IU);
      expect(reconstructed.strength, '100 IU/ml');
      expect(reconstructed.activeIngredient, 'Insulin Glargine');
      expect(reconstructed.criticality, MedicationCriticality.LIFE_CRITICAL);
      expect(reconstructed.injectionSites, contains('شکم راست'));
      expect(reconstructed.needsSiteRotation, isTrue);
    });

    test('stock tracking getters work accurately', () {
      const inStock = MedicationProfile(
        routineId: 'med_1',
        packageSize: 30.0,
        remainingAmount: 15.0,
        refillThresholdAmount: 5.0,
      );
      expect(inStock.hasStockTracking, isTrue);
      expect(inStock.isLowStock, isFalse);
      expect(inStock.isOutOfStock, isFalse);

      final lowStock = inStock.copyWith(remainingAmount: 4.0);
      expect(lowStock.isLowStock, isTrue);
      expect(lowStock.isOutOfStock, isFalse);

      final outOfStock = inStock.copyWith(remainingAmount: 0.0);
      expect(outOfStock.isLowStock, isTrue);
      expect(outOfStock.isOutOfStock, isTrue);

      const noTracking = MedicationProfile(routineId: 'med_2');
      expect(noTracking.hasStockTracking, isFalse);
      expect(noTracking.isLowStock, isFalse);
      expect(noTracking.isOutOfStock, isFalse);
    });
  });

  group('Clinical Medication Entity Scenarios', () {
    test('10 IU Insulin profile formatting', () {
      const med = Medication(
        id: 'med_insulin',
        name: 'انسولین لانتوس',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        profile: MedicationProfile(
          routineId: 'med_insulin',
          form: MedicationForm.INSULIN,
          route: MedicationRoute.SUBCUTANEOUS,
          doseAmount: 10.0,
          doseUnit: DoseUnit.IU,
          strength: '100 IU/ml',
          needsSiteRotation: true,
        ),
      );

      expect(med.displayDose, '10 واحد');
      expect(med.fullDoseDescription, contains('10 واحد'));
      expect(med.fullDoseDescription, contains('100 IU/ml'));
      expect(med.fullDoseDescription, contains('زیرجلدی'));
    });

    test('Eye Drops profile formatting', () {
      const med = Medication(
        id: 'med_drops',
        name: 'قطره بتازون',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        profile: MedicationProfile(
          routineId: 'med_drops',
          form: MedicationForm.DROPS,
          route: MedicationRoute.OPHTHALMIC,
          doseAmount: 2.0,
          doseUnit: DoseUnit.DROP,
        ),
      );

      expect(med.displayDose, '2 قطره');
      expect(med.fullDoseDescription, contains('2 قطره'));
      expect(med.fullDoseDescription, contains('چشمی'));
    });

    test('5ml Syrup profile formatting', () {
      const med = Medication(
        id: 'med_syrup',
        name: 'شربت دیفن هیدرامین',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        profile: MedicationProfile(
          routineId: 'med_syrup',
          form: MedicationForm.SYRUP,
          route: MedicationRoute.ORAL,
          doseAmount: 5.0,
          doseUnit: DoseUnit.ML,
        ),
      );

      expect(med.displayDose, '5 ml');
      expect(med.fullDoseDescription, contains('5 ml'));
      expect(med.fullDoseDescription, contains('خوراکی'));
    });

    test('2-puff Inhaler spray profile formatting', () {
      const med = Medication(
        id: 'med_inhaler',
        name: 'اسپری سالبوتامول',
        createdAt: 1700000000000,
        updatedAt: 1700000000000,
        profile: MedicationProfile(
          routineId: 'med_inhaler',
          form: MedicationForm.INHALER,
          route: MedicationRoute.INHALED,
          doseAmount: 2.0,
          doseUnit: DoseUnit.PUFF,
          packageSize: 200.0,
          packageUnit: 'پاف',
          remainingAmount: 150.0,
          refillThresholdAmount: 20.0,
        ),
      );

      expect(med.displayDose, '2 پاف');
      expect(med.displayStock, '150 پاف');
      expect(med.fullDoseDescription, contains('2 پاف'));
      expect(med.fullDoseDescription, contains('تنفسی'));
    });
  });
}
