import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/models/health_models.dart';

void main() {
  group('L-29: Physiological Health Log Validation Tests', () {
    test('BloodSugarLog.isPhysiologicallyValid validates physiological glucose range (20 to 1200 mg/dL)', () {
      expect(BloodSugarLog.isPhysiologicallyValid(70), isTrue);
      expect(BloodSugarLog.isPhysiologicallyValid(100), isTrue);
      expect(BloodSugarLog.isPhysiologicallyValid(250), isTrue);
      expect(BloodSugarLog.isPhysiologicallyValid(20), isTrue);
      expect(BloodSugarLog.isPhysiologicallyValid(1200), isTrue);

      // Unphysiological or invalid
      expect(BloodSugarLog.isPhysiologicallyValid(0), isFalse);
      expect(BloodSugarLog.isPhysiologicallyValid(-10), isFalse);
      expect(BloodSugarLog.isPhysiologicallyValid(15), isFalse);
      expect(BloodSugarLog.isPhysiologicallyValid(1500), isFalse);
    });

    test('BloodPressureLog.isPhysiologicallyValid validates systolic, diastolic and pulse bounds', () {
      // Normal reading
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 120,
          diastolic: 80,
          pulse: 72,
        ),
        isTrue,
      );

      // Hypotension and hypertension valid ranges
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 90,
          diastolic: 60,
          pulse: 60,
        ),
        isTrue,
      );
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 190,
          diastolic: 110,
          pulse: 100,
        ),
        isTrue,
      );

      // Systolic <= Diastolic (physiologically impossible)
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 80,
          diastolic: 120,
        ),
        isFalse,
      );
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 90,
          diastolic: 90,
        ),
        isFalse,
      );

      // Out of bounds
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 40,
          diastolic: 30,
        ),
        isFalse,
      );
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 320,
          diastolic: 150,
        ),
        isFalse,
      );
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 120,
          diastolic: 20,
        ),
        isFalse,
      );

      // Pulse out of bounds
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 120,
          diastolic: 80,
          pulse: 20,
        ),
        isFalse,
      );
      expect(
        BloodPressureLog.isPhysiologicallyValid(
          systolic: 120,
          diastolic: 80,
          pulse: 280,
        ),
        isFalse,
      );
    });

    test('VitalSignLog.isPhysiologicallyValid validates weight, temperature, SpO2, and waist bounds', () {
      // Weight
      expect(VitalSignLog.isPhysiologicallyValid('WEIGHT', 70.5), isTrue);
      expect(VitalSignLog.isPhysiologicallyValid('WEIGHT', 1.0), isFalse);
      expect(VitalSignLog.isPhysiologicallyValid('WEIGHT', 600.0), isFalse);

      // Temperature (Celsius)
      expect(VitalSignLog.isPhysiologicallyValid('TEMPERATURE', 37.0), isTrue);
      expect(VitalSignLog.isPhysiologicallyValid('TEMPERATURE', 39.5), isTrue);
      expect(VitalSignLog.isPhysiologicallyValid('TEMPERATURE', 25.0), isFalse);
      expect(VitalSignLog.isPhysiologicallyValid('TEMPERATURE', 46.0), isFalse);

      // SpO2 (%)
      expect(VitalSignLog.isPhysiologicallyValid('SPO2', 98.0), isTrue);
      expect(VitalSignLog.isPhysiologicallyValid('SPO2', 88.0), isTrue);
      expect(VitalSignLog.isPhysiologicallyValid('SPO2', 40.0), isFalse);
      expect(VitalSignLog.isPhysiologicallyValid('SPO2', 105.0), isFalse);

      // Waist (cm)
      expect(VitalSignLog.isPhysiologicallyValid('WAIST', 85.0), isTrue);
      expect(VitalSignLog.isPhysiologicallyValid('WAIST', 10.0), isFalse);
      expect(VitalSignLog.isPhysiologicallyValid('WAIST', 300.0), isFalse);
    });
  });
}
