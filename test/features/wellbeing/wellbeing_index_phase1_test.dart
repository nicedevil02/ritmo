import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/wellbeing_engine.dart';

void main() {
  group('Wellbeing Phase 1 Tests — Index Restoration (B1..B6)', () {
    final now = DateTime(2026, 8, 17, 12, 0);

    test('Criterion 1: 7 nights of sleep and 0 other logs yields hasValue == true with sleep contribution', () {
      const engine = WellbeingEngine();
      final index = engine.compute(
        WellbeingEngineInput(
          now: now,
          horizonDays: 14,
          sleepNights: 7,
          avgSleepHours: 7.5,
          targetSleepHours: 7.5,
          avgSleepQuality: 4.0,
          sleepConsistency: 85.0,
          energySamples: 0,
          moodSamples: 0,
          reflectionEntries: 0,
        ),
      );

      expect(index.hasValue, isTrue);
      expect(index.contributions.any((c) => c.signal == WellbeingSignal.sleep), isTrue);
      expect(index.value, isNotNull);
      expect(index.value, greaterThan(0));
    });

    test('Criterion 2: 1 unique day of energy logs yields 0 confidence (below minEnergySamples = 3)', () {
      const engine = WellbeingEngine();
      // Even with 20 logs in a single day, unique day count is 1.
      final index = engine.compute(
        WellbeingEngineInput(
          now: now,
          horizonDays: 14,
          sleepNights: 0,
          energySamples: 1, // 1 unique day
          avgEnergyLevel: 3.0,
          moodSamples: 0,
          reflectionEntries: 0,
        ),
      );

      final energyContrib = index.contributions.where((c) => c.signal == WellbeingSignal.energy).firstOrNull;
      expect(energyContrib, isNull);
      expect(index.missing.any((m) => m.signal == WellbeingSignal.energy), isTrue);
    });

    test('Criterion 3: Confidence scale smoothly scales from 0.5 at min to 1.0 at full', () {
      expect(WellbeingEngine.confidenceFor(2, 3, 14), 0.0);
      expect(WellbeingEngine.confidenceFor(3, 3, 14), 0.5);
      expect(WellbeingEngine.confidenceFor(14, 3, 14), 1.0);
      expect(WellbeingEngine.confidenceFor(20, 3, 14), 1.0);
    });
  });
}
