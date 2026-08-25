import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/readiness_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

void main() {
  group('Full Readiness Inputs Verification (S0-T6)', () {
    const engine = ReadinessEngine();

    test(
      'Case 1: No check-in returns MvReadinessTier.full with hasEnoughData == false',
      () {
        final decision = engine.evaluateReadiness();

        expect(decision.value, equals(MvReadinessTier.full));
        expect(decision.hasEnoughData, isFalse);
      },
    );

    test(
      'Case 2: Sleep 4 hours (240 minutes) reduces tier below full (light)',
      () {
        final decision = engine.evaluateReadiness(
          sleepMinutes: 240, // 4 hours
        );

        expect(decision.value, isNot(equals(MvReadinessTier.full)));
        expect(decision.value, equals(MvReadinessTier.light));
        expect(decision.sources, contains('sleep'));
        expect(decision.reasonFa, contains('خواب کم'));
        expect(decision.hasEnoughData, isTrue);
      },
    );

    test('Case 3: Energy 1 triggers MvReadinessTier.rest', () {
      final decision = engine.evaluateReadiness(energyLevel: 1);

      expect(decision.value, equals(MvReadinessTier.rest));
      expect(decision.sources, contains('energy'));
      expect(decision.hasEnoughData, isTrue);
    });
  });
}
