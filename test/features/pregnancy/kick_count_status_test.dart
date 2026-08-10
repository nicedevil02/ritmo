import 'package:flutter_test/flutter_test.dart';

enum KickStatus { green, neutral, warning, info }

KickStatus evaluateKickSession(int count, int durationMins) {
  if (count >= 10 && durationMins <= 120) {
    return KickStatus.green;
  } else if (count >= 10 && durationMins > 120) {
    return KickStatus.neutral;
  } else if (count < 10 && durationMins >= 120) {
    return KickStatus.warning;
  } else {
    return KickStatus.info;
  }
}

void main() {
  group('PREG-11: Kick Count Status Evaluation Tests', () {
    test('State 1: >= 10 kicks in <= 120 mins => Green', () {
      expect(evaluateKickSession(10, 60), equals(KickStatus.green));
      expect(evaluateKickSession(12, 120), equals(KickStatus.green));
    });

    test('State 2: >= 10 kicks in > 120 mins => Neutral', () {
      expect(evaluateKickSession(10, 150), equals(KickStatus.neutral));
    });

    test('State 3: < 10 kicks in >= 120 mins => Warning', () {
      expect(evaluateKickSession(8, 120), equals(KickStatus.warning));
    });

    test('State 4: < 10 kicks in < 120 mins => Info (No warning for short session)', () {
      expect(evaluateKickSession(3, 30), equals(KickStatus.info));
      expect(evaluateKickSession(8, 60), equals(KickStatus.info));
    });
  });
}
