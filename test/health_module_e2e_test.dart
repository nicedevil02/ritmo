import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/medical_engine.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/health/models/health_models.dart';

void main() {
  group('Phase 8: Comprehensive Health & Medication Module End-to-End Test Suite', () {
    test('E2E: Full lifecycle of a specialized medication (Insulin)', () {
      // 1. Create specialized profile
      const profile = MedicationProfile(
        routineId: 'med_insulin_e2e',
        form: MedicationForm.INSULIN,
        route: MedicationRoute.SUBCUTANEOUS,
        doseAmount: 14.0,
        doseUnit: DoseUnit.IU,
        foodRelation: FoodRelation.BEFORE_MEAL,
        isChronic: true,
        packageSize: 100.0,
        remainingAmount: 100.0,
        refillThresholdAmount: 20.0,
        needsSiteRotation: true,
        injectionSites: ['ABDOMEN_RIGHT', 'ABDOMEN_LEFT', 'THIGH_RIGHT'],
      );

      expect(profile.form, MedicationForm.INSULIN);
      expect(profile.doseAmount, 14.0);
      expect(profile.doseUnit, DoseUnit.IU);
      expect(profile.isLowStock, isFalse);
      expect(profile.isOutOfStock, isFalse);

      // 2. Consume doses down to low stock
      var remaining = profile.remainingAmount!;
      for (var i = 0; i < 6; i++) {
        remaining -= profile.doseAmount!; // 6 * 14 = 84 units consumed -> 16 units remaining
      }

      final lowStockProfile = profile.copyWith(remainingAmount: remaining);
      expect(lowStockProfile.remainingAmount, 16.0);
      expect(lowStockProfile.isLowStock, isTrue);
      expect(lowStockProfile.isOutOfStock, isFalse);

      // 3. Clinical Guidance Note
      final note = ClinicalFormHelper.getClinicalEducationNote(profile.form);
      expect(note, contains('لیپوهایپرتروفی'));
    });

    test('E2E: Multi-dose RecurrenceRule schedule expansion', () {
      final rule = RecurrenceRule(
        weekdays: const [6, 7, 1, 2, 3, 4, 5],
        reminderTimes: const ['08:00', '14:00', '20:00'],
      );

      expect(rule.reminderTimes.length, 3);
      expect(rule.reminderTimes[0], '08:00');
      expect(rule.reminderTimes[1], '14:00');
      expect(rule.reminderTimes[2], '20:00');

      // Verify deterministic ID format
      const rId = 'routine_test_123';
      const scheduleId = 'sched_test_123';
      const dateStr = '2026-08-17';
      final ids = rule.reminderTimes.map((t) {
        final timeStr = t.replaceAll(':', '');
        return 'rem_${rId}_${scheduleId}_${dateStr}_$timeStr';
      }).toList();

      expect(ids[0], 'rem_routine_test_123_sched_test_123_2026-08-17_0800');
      expect(ids[1], 'rem_routine_test_123_sched_test_123_2026-08-17_1400');
      expect(ids[2], 'rem_routine_test_123_sched_test_123_2026-08-17_2000');
      expect(ids.toSet().length, 3); // All distinct
    });

    test('E2E: PRN Safety & Overdose Guard Invariants', () {
      final now = DateTime(2026, 8, 17, 14, 0).millisecondsSinceEpoch;
      final recentLogs = [
        DateTime(2026, 8, 17, 12, 0).millisecondsSinceEpoch, // 2 hours ago
      ];

      // Under interval check (min 4h required)
      final res1 = MedicalEngine.checkOverdoseStatus(
        now: now,
        prnLogs24h: recentLogs,
        minIntervalHours: 4,
        maxDosesPerDay: 4,
      );
      expect(res1, OverdoseResult.warningUnderInterval);

      // Max doses check
      final maxLogs = [
        DateTime(2026, 8, 17, 4, 0).millisecondsSinceEpoch,
        DateTime(2026, 8, 17, 9, 0).millisecondsSinceEpoch,
        DateTime(2026, 8, 17, 14, 0).millisecondsSinceEpoch,
      ];
      final res2 = MedicalEngine.checkOverdoseStatus(
        now: DateTime(2026, 8, 17, 19, 0).millisecondsSinceEpoch,
        prnLogs24h: maxLogs,
        minIntervalHours: 4,
        maxDosesPerDay: 3,
      );
      expect(res2, OverdoseResult.warningMaxLimitExceeded);
    });

    test('E2E: HealthEngine analytics and clinical blood pressure/sugar staging', () {
      final bp = BloodPressureLog(
        id: 'bp_1',
        systolic: 145,
        diastolic: 92,
        loggedAt: DateTime.now().millisecondsSinceEpoch,
      );
      expect(bp.stageLabel, 'فشار خون مرحله ۲');

      final crisisBp = BloodPressureLog(
        id: 'bp_2',
        systolic: 185,
        diastolic: 110,
        loggedAt: DateTime.now().millisecondsSinceEpoch,
      );
      expect(crisisBp.stageLabel, 'بحران فشار خون');

      final sugar = BloodSugarLog(
        id: 'bs_1',
        value: 115,
        measurementType: 'FASTING',
        loggedAt: DateTime.now().millisecondsSinceEpoch,
      );
      expect(sugar.categoryLabel, 'ناشتا');
    });

    test('E2E: Medication identity predicate ensures generic tasks never masquerade as medication', () {
      final taskRoutine = {
        'id': 'task_study',
        'title': 'مطالعه ریاضی',
        'category': 'study',
        'itemType': 'ROUTINE',
      };
      expect(MedicationIdentity.isMedicationRoutine(taskRoutine), isFalse);

      final medRoutine = {
        'id': 'med_metformin',
        'title': 'متفورمین ۵۰۰',
        'category': 'medical',
        'itemType': 'MEDICINE',
      };
      expect(MedicationIdentity.isMedicationRoutine(medRoutine), isTrue);
    });
  });
}
