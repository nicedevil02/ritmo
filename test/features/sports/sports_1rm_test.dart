import 'package:flutter_test/flutter_test.dart';

double? calculate1RM(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return null;
  if (reps == 1) return weight;
  if (reps <= 10) {
    return weight * (1 + reps / 30.0);
  } else if (reps <= 30) {
    return weight * (36.0 / (37.0 - reps));
  } else {
    return weight * 2.0;
  }
}

void main() {
  group('SPORTS-04: Composite 1RM Calculation Tests', () {
    test('1 rep @ 100kg => 100kg', () {
      expect(calculate1RM(100.0, 1), equals(100.0));
    });

    test('Epley formula for reps <= 10 (10 reps @ 100kg => 133.33kg)', () {
      final rm = calculate1RM(100.0, 10)!;
      expect(rm, closeTo(133.33, 0.01));
    });

    test('Brzycki formula for 10 < reps <= 30 (15 reps @ 100kg => 163.63kg vs Epley 150kg)', () {
      final rm = calculate1RM(100.0, 15)!;
      expect(rm, closeTo(163.63, 0.01));
    });

    test('Invalid weight or reps return null', () {
      expect(calculate1RM(0, 10), isNull);
      expect(calculate1RM(100, 0), isNull);
      expect(calculate1RM(-50, 5), isNull);
    });
  });
}
