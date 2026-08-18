import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/date_key.dart';

void main() {
  group('CAL-59: DateKey Comprehensive Invariant Tests', () {
    test('1. DateKey.of works on local and UTC correctly (CAL-01)', () {
      final dtLocal = DateTime(2026, 8, 17, 10, 30);
      expect(DateKey.of(dtLocal), equals('2026-08-17'));

      final dtUtc = DateTime.utc(2026, 8, 17, 10, 30);
      expect(DateKey.of(dtUtc), equals(DateKey.of(dtUtc.toLocal())));
    });

    test('2. DateKey.dayOf returns midnight of the same date', () {
      final dt = DateTime(2026, 8, 17, 23, 45, 12, 500);
      final day = DateKey.dayOf(dt);
      expect(day, equals(DateTime(2026, 8, 17, 0, 0, 0, 0, 0)));
      expect(day.hour, equals(0));
      expect(day.minute, equals(0));
      expect(day.second, equals(0));
    });

    test('3. DateKey.parse handles valid and invalid strings robustly', () {
      expect(DateKey.parse('2026-08-17'), equals(DateTime(2026, 8, 17)));
      expect(DateKey.parse('2026-13-01'), isNull);
      expect(DateKey.parse('2026-02-30'), isNull);
      expect(DateKey.parse('2025-02-29'), isNull); // Non-leap year Feb 29
      expect(DateKey.parse('2026-04-31'), isNull); // April only has 30 days
      expect(DateKey.parse('invalid'), isNull);
      expect(DateKey.parse('2026/08/17'), isNull);
      expect(DateKey.parse(''), isNull);
    });

    test('4. DateKey.addDays adds calendar days correctly across month/year boundaries', () {
      final dt = DateTime(2026, 8, 30);
      expect(DateKey.addDays(dt, 2), equals(DateTime(2026, 9, 1)));
      expect(DateKey.addDays(DateTime(2026, 12, 31), 1), equals(DateTime(2027, 1, 1)));
      expect(DateKey.addDays(DateTime(2026, 1, 1), -1), equals(DateTime(2025, 12, 31)));
    });

    test('5. DateKey.isSameDay identifies same calendar day regardless of time', () {
      final d1 = DateTime(2026, 8, 18, 0, 1);
      final d2 = DateTime(2026, 8, 18, 23, 59);
      final d3 = DateTime(2026, 8, 19, 0, 0);

      expect(DateKey.isSameDay(d1, d2), isTrue);
      expect(DateKey.isSameDay(d1, d3), isFalse);
    });
  });
}
