import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';

void main() {
  group('PREG-03: GestationalAge Tests', () {
    test('Day 0 => 0+0 and Trimester 1', () {
      final ga = GestationalAge.fromDays(0);
      expect(ga.weeks, equals(0));
      expect(ga.days, equals(0));
      expect(ga.trimester, equals(1));
      expect(ga.label, equals('هفته ۰ و ۰ روز'));
    });

    test('Day 97 => 13+6 and Trimester 1', () {
      final ga = GestationalAge.fromDays(97);
      expect(ga.weeks, equals(13));
      expect(ga.days, equals(6));
      expect(ga.trimester, equals(1));
    });

    test('Day 98 => 14+0 and Trimester 2', () {
      final ga = GestationalAge.fromDays(98);
      expect(ga.weeks, equals(14));
      expect(ga.days, equals(0));
      expect(ga.trimester, equals(2));
    });

    test('Day 196 => 28+0 and Trimester 3', () {
      final ga = GestationalAge.fromDays(196);
      expect(ga.weeks, equals(28));
      expect(ga.days, equals(0));
      expect(ga.trimester, equals(3));
    });

    test('Day 280 => 40+0 (EDD day)', () {
      final ga = GestationalAge.fromDays(280);
      expect(ga.weeks, equals(40));
      expect(ga.days, equals(0));
      expect(ga.trimester, equals(3));
    });
  });
}
