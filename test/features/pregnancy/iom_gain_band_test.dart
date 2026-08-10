import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';

void main() {
  group('UX-08 IOM Pre-pregnancy Weight Gain Band Tests', () {
    test('returns accurate weight gain bands for all BMI categories', () {
      // Underweight (BMI < 18.5)
      final under = PregnancyHelpers.iomGainBandKg(17.5);
      expect(under['min'], equals(12.5));
      expect(under['max'], equals(18.0));

      // Normal weight (18.5 <= BMI < 25.0)
      final normal = PregnancyHelpers.iomGainBandKg(22.0);
      expect(normal['min'], equals(11.5));
      expect(normal['max'], equals(16.0));

      // Overweight (25.0 <= BMI < 30.0)
      final over = PregnancyHelpers.iomGainBandKg(27.5);
      expect(over['min'], equals(7.0));
      expect(over['max'], equals(11.5));

      // Obese (BMI >= 30.0)
      final obese = PregnancyHelpers.iomGainBandKg(32.0);
      expect(obese['min'], equals(5.0));
      expect(obese['max'], equals(9.0));
    });
  });
}
