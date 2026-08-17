import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/health_engine.dart';
import 'package:ritmo/core/domain/engines/medical_engine.dart';
import 'package:ritmo/features/health/models/health_models.dart';

void main() {
  group('Phase 3: Medication Intake, Dosage Safety & Adherence Tests', () {
    test('PRN overdose check flags doses taken under minIntervalHours', () {
      final now = DateTime(2026, 8, 17, 12, 0).millisecondsSinceEpoch;
      // Last taken 2 hours ago
      final twoHoursAgo = DateTime(2026, 8, 17, 10, 0).millisecondsSinceEpoch;

      final res = MedicalEngine.checkOverdoseStatus(
        now: now,
        prnLogs24h: [twoHoursAgo],
        minIntervalHours: 4, // requires 4 hours
        maxDosesPerDay: 4,
      );

      expect(res, OverdoseResult.warningUnderInterval);
    });

    test('PRN overdose check flags doses exceeding maxDosesPerDay in 24h', () {
      final now = DateTime(2026, 8, 17, 20, 0).millisecondsSinceEpoch;
      final logs = [
        DateTime(2026, 8, 17, 8, 0).millisecondsSinceEpoch,
        DateTime(2026, 8, 17, 12, 0).millisecondsSinceEpoch,
        DateTime(2026, 8, 17, 16, 0).millisecondsSinceEpoch,
      ];

      final res = MedicalEngine.checkOverdoseStatus(
        now: now,
        prnLogs24h: logs,
        minIntervalHours: 4,
        maxDosesPerDay: 3, // max 3 doses reached
      );

      expect(res, OverdoseResult.warningMaxLimitExceeded);
    });

    test('PRN overdose check passes when interval and max doses are respected', () {
      final now = DateTime(2026, 8, 17, 22, 0).millisecondsSinceEpoch;
      final logs = [
        DateTime(2026, 8, 17, 8, 0).millisecondsSinceEpoch,
        DateTime(2026, 8, 17, 14, 0).millisecondsSinceEpoch,
      ];

      final res = MedicalEngine.checkOverdoseStatus(
        now: now,
        prnLogs24h: logs,
        minIntervalHours: 4,
        maxDosesPerDay: 4,
      );

      expect(res, OverdoseResult.safe);
    });

    test('Stock deduction and refill threshold calculation', () {
      const initialStock = 30;
      const unitDose = 1;
      const threshold = 5;

      var stock = initialStock;
      for (var i = 0; i < 26; i++) {
        stock -= unitDose;
      }
      expect(stock, 4);
      expect(MedicalEngine.isRefillNeeded(stockCount: stock, warningThreshold: threshold), isTrue);
      expect(MedicalEngine.isOutOfStock(stockCount: stock), isFalse);

      for (var i = 0; i < 4; i++) {
        stock -= unitDose;
      }
      expect(stock, 0);
      expect(MedicalEngine.isOutOfStock(stockCount: stock), isTrue);
    });

    test('Accurate Adherence calculation handles scheduled vs missed correctly', () {
      final today = DateTime(2026, 8, 17);
      final logs = [
        // Day 1: 2 taken
        MedicationLog(
          id: 'log_1',
          routineId: 'med_1',
          scheduledTime: DateTime(2026, 8, 15, 8, 0).millisecondsSinceEpoch,
          status: 'TAKEN',
          createdAt: DateTime(2026, 8, 15, 8, 5).millisecondsSinceEpoch,
        ),
        MedicationLog(
          id: 'log_2',
          routineId: 'med_1',
          scheduledTime: DateTime(2026, 8, 15, 20, 0).millisecondsSinceEpoch,
          status: 'TAKEN',
          createdAt: DateTime(2026, 8, 15, 20, 2).millisecondsSinceEpoch,
        ),
        // Day 2: 1 taken, 1 skipped
        MedicationLog(
          id: 'log_3',
          routineId: 'med_1',
          scheduledTime: DateTime(2026, 8, 16, 8, 0).millisecondsSinceEpoch,
          status: 'TAKEN',
          createdAt: DateTime(2026, 8, 16, 8, 1).millisecondsSinceEpoch,
        ),
        MedicationLog(
          id: 'log_4',
          routineId: 'med_1',
          scheduledTime: DateTime(2026, 8, 16, 20, 0).millisecondsSinceEpoch,
          status: 'SKIPPED',
          createdAt: DateTime(2026, 8, 16, 20, 10).millisecondsSinceEpoch,
        ),
        // Day 3: 1 taken
        MedicationLog(
          id: 'log_5',
          routineId: 'med_1',
          scheduledTime: DateTime(2026, 8, 17, 8, 0).millisecondsSinceEpoch,
          status: 'TAKEN',
          createdAt: DateTime(2026, 8, 17, 8, 0).millisecondsSinceEpoch,
        ),
      ];

      final input = HealthEngineInput(
        today: today,
        windowDays: 7,
        bloodSugarLogs: const [],
        bloodPressureLogs: const [],
        vitalSignLogs: const [],
        medicationLogs: logs,
        prnLogs: const [],
        energyLogs: const [],
        sleepLogs: const [],
        hasDiabetes: false,
        hasHypertension: false,
      );

      final output = HealthEngine.calculateSync(input);

      // Total 5 scheduled doses, 4 taken -> 4/5 = 0.8 (80%)
      expect(output.adherence.adherenceRate, closeTo(0.8, 0.001));
    });
  });
}
