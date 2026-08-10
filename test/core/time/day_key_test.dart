import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';

void main() {
  group('DayKey TIME-01 & TIME-02 Tests', () {
    test('DayKey round-trips through local time in Tehran', () {
      final local = DateTime(2026, 8, 10, 0, 30); // 00:30 AM local
      final key = DayKey.from(local);
      expect(key.toLocalDateTime().day, 10);
      expect(key.toLocalDateTime().month, 8);
      expect(key.toLocalDateTime().year, 2026);
      expect(DayKey.from(key.toLocalDateTime()), key);
    });

    test('DayKey.tryParse handles valid and ISO dirty strings safely', () {
      expect(DayKey.tryParse('2026-08-10'), equals(DayKey.parse('2026-08-10')));
      expect(DayKey.tryParse('2026-08-10T00:00:00.000Z')?.value, '2026-08-10');
      expect(DayKey.tryParse(null), isNull);
      expect(DayKey.tryParse('invalid'), isNull);
      expect(DayKey.tryParse('2026-13-45'), isNull);
    });
  });

  group('RitmoClock & FakeClock TIME-03 Tests', () {
    test('FakeClock allows deterministic time advancement and today() calculation', () {
      final fakeClock = FakeClock(DateTime(2026, 8, 10, 23, 59));
      expect(fakeClock.today().value, '2026-08-10');

      // Advance by 2 minutes to cross midnight
      fakeClock.advanceBy(const Duration(minutes: 2));
      expect(fakeClock.today().value, '2026-08-11');
    });

    test('23:59 previous day calculation via FakeClock', () {
      final fakeClock = FakeClock(DateTime(2026, 8, 10, 23, 59, 59));
      final todayKey = fakeClock.today();
      final yesterdayKey = todayKey.addDays(-1);

      expect(todayKey.value, '2026-08-10');
      expect(yesterdayKey.value, '2026-08-09');
    });

    test('Digest reset counter logic at day boundary', () {
      final clock = FakeClock(DateTime(2026, 8, 10, 23, 50));
      String? lastDigestDate = clock.today().value;
      int digestCount = 3;

      // Same day check
      if (clock.today().value != lastDigestDate) {
        digestCount = 0;
      }
      expect(digestCount, 3);

      // Advance clock past midnight
      clock.advanceBy(const Duration(minutes: 15));
      if (clock.today().value != lastDigestDate) {
        digestCount = 0;
        lastDigestDate = clock.today().value;
      }
      expect(digestCount, 0);
      expect(lastDigestDate, '2026-08-11');
    });
  });
}
