import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/date_key.dart';

void main() {
  group('DateKey Tests (CAL-01 & CAL-59)', () {
    test('DateKey.of works on local and UTC correctly', () {
      final dtLocal = DateTime(2026, 8, 17, 10, 30);
      expect(DateKey.of(dtLocal), '2026-08-17');

      final dtUtc = DateTime.utc(2026, 8, 17, 10, 30);
      expect(DateKey.of(dtUtc), DateKey.of(dtUtc.toLocal()));
    });

    test('DateKey.dayOf returns midnight of same date', () {
      final dt = DateTime(2026, 8, 17, 23, 45, 12);
      final day = DateKey.dayOf(dt);
      expect(day, DateTime(2026, 8, 17));
    });

    test('DateKey.parse handles valid and invalid strings', () {
      expect(DateKey.parse('2026-08-17'), DateTime(2026, 8, 17));
      expect(DateKey.parse('2026-13-01'), isNull);
      expect(DateKey.parse('2026-02-30'), isNull);
      expect(DateKey.parse('invalid'), isNull);
      expect(DateKey.parse(''), isNull);
    });

    test('DateKey.addDays adds calendar days correctly across month/year boundaries', () {
      final dt = DateTime(2026, 8, 30);
      expect(DateKey.addDays(dt, 2), DateTime(2026, 9, 1));
      expect(DateKey.addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
    });
  });
}
