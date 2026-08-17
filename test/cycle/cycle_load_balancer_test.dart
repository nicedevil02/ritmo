import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_load_balancer.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

void main() {
  group('CycleLoadBalancer Tests (C-31)', () {
    test('C-31: In menstrual phase, loadMode is NEVER higher-focus even with LOW burden', () {
      const lowBurden = BodyBurdenScore(
        score: 10.0,
        level: 'LOW',
        reasonsFa: [],
      );

      final advice = CycleLoadBalancer.generateAdvice(
        lowBurden,
        phase: CyclePhase.menstrual,
      );

      expect(advice.mode, equals(CycleLoadMode.balanced));
      expect(advice.loadMode, equals('balanced'));
      expect(advice.loadMode, isNot(equals('higher-focus')));
      expect(advice.mode, isNot(equals(CycleLoadMode.higherFocus)));
    });

    test('C-31: In follicular phase with LOW burden, higher-focus is recommended', () {
      const lowBurden = BodyBurdenScore(
        score: 10.0,
        level: 'LOW',
        reasonsFa: [],
      );

      final advice = CycleLoadBalancer.generateAdvice(
        lowBurden,
        phase: CyclePhase.follicular,
      );

      expect(advice.mode, equals(CycleLoadMode.higherFocus));
      expect(advice.loadMode, equals('higher-focus'));
      expect(advice.energyDelta, equals(0));
      expect(advice.sessionLengthMultiplier, equals(1.0));
      expect(advice.extraBreakMinutesEveryHour, equals(0));
    });

    test('C-31: HIGH burden triggers lighter mode with standard reductions', () {
      const highBurden = BodyBurdenScore(
        score: 80.0,
        level: 'HIGH',
        reasonsFa: ['خونریزی شدید'],
      );

      final advice = CycleLoadBalancer.generateAdvice(
        highBurden,
        phase: CyclePhase.menstrual,
      );

      expect(advice.mode, equals(CycleLoadMode.lighter));
      expect(advice.loadMode, equals('lighter'));
      expect(advice.energyDelta, equals(CycleLoadBalanceConstants.highBurdenEnergyDelta));
      expect(advice.sessionLengthMultiplier, equals(CycleLoadBalanceConstants.highBurdenMultiplier));
      expect(advice.extraBreakMinutesEveryHour, equals(CycleLoadBalanceConstants.highBurdenExtraBreaks));
    });
  });
}
