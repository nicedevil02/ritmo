import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_burden_engine.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';

void main() {
  group('CycleBurdenEngine Tests (C-30)', () {
    test(
      'C-30: Moderate flow day without symptoms or energy/sleep logs yields MODERATE level, not HIGH',
      () {
        final burden = CycleBurdenEngine.calculateBurden(
          phase: CyclePhase.menstrual,
          dayOfPeriod: 2,
          flowIntensity: CycleFlowLevel.medium,
          loggedSymptoms: [],
          energyTag: null,
          sleepHours: null,
        );

        // Base (5) + Menstrual (25) + Medium flow (10) = 40.0
        expect(burden.score, equals(40.0));
        expect(burden.level, equals('MODERATE'));
        expect(burden.confidence, equals('LOW')); // No context data provided
        expect(burden.factors.any((f) => f.code == 'flow_medium'), isTrue);
      },
    );

    test(
      'C-30: Heavy flow with multiple symptoms and low energy yields HIGH level',
      () {
        final burden = CycleBurdenEngine.calculateBurden(
          phase: CyclePhase.menstrual,
          dayOfPeriod: 1,
          flowIntensity: CycleFlowLevel.heavy,
          loggedSymptoms: ['cramps', 'headache', 'bloating'],
          energyTag: 'LOW',
          sleepHours: 5.0, // Sleep deficit
        );

        // Base (5) + Menstrual (25) + Heavy (20) + 3 symptoms (15) + Low energy (15) + Sleep deficit (15) = 95.0
        expect(burden.score, equals(95.0));
        expect(burden.level, equals('HIGH'));
        expect(burden.confidence, equals('HIGH'));
        expect(burden.factors.length, equals(5));
      },
    );

    test(
      'C-30: Follicular phase day with no symptoms and good sleep yields LOW burden',
      () {
        final burden = CycleBurdenEngine.calculateBurden(
          phase: CyclePhase.follicular,
          dayOfPeriod: 0,
          flowIntensity: CycleFlowLevel.none,
          loggedSymptoms: [],
          energyTag: 'HIGH',
          sleepHours: 8.0,
        );

        // Base (5)
        expect(burden.score, equals(5.0));
        expect(burden.level, equals('LOW'));
        expect(burden.confidence, equals('HIGH'));
      },
    );
  });
}
