// C-02: Tests for CycleDateContract
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';

void main() {
  group('CycleDateContract', () {
    test('toDayKey formats DateTime to YYYY-MM-DD with zero-padding', () {
      final dt = DateTime(2026, 4, 9, 15, 30, 45);
      expect(CycleDateContract.toDayKey(dt), equals('2026-04-09'));

      final dt2 = DateTime(2026, 12, 31);
      expect(CycleDateContract.toDayKey(dt2), equals('2026-12-31'));
    });

    test('parseDayKey handles clean YYYY-MM-DD string', () {
      final result = CycleDateContract.parseDayKey('2026-06-15');
      expect(result, isNotNull);
      expect(result!.year, equals(2026));
      expect(result.month, equals(6));
      expect(result.day, equals(15));
      expect(result.hour, equals(0));
      expect(result.minute, equals(0));
    });

    test(
      'parseDayKey handles full ISO8601 string with timestamp and timezone',
      () {
        final result = CycleDateContract.parseDayKey(
          '2026-06-15T18:45:30.123Z',
        );
        expect(result, isNotNull);
        expect(result!.year, equals(2026));
        expect(result.month, equals(6));
        expect(result.day, equals(15));
      },
    );

    test(
      'parseDayKey handles edge strings with whitespace and time suffixes',
      () {
        final result1 = CycleDateContract.parseDayKey('  2026-01-05   ');
        expect(result1, equals(DateTime(2026, 1, 5)));

        final result2 = CycleDateContract.parseDayKey('2026-01-05T23:59:59');
        expect(result2, equals(DateTime(2026, 1, 5)));
      },
    );

    test('parseDayKey returns null on invalid or empty input', () {
      expect(CycleDateContract.parseDayKey(null), isNull);
      expect(CycleDateContract.parseDayKey(''), isNull);
      expect(CycleDateContract.parseDayKey('   '), isNull);
      expect(CycleDateContract.parseDayKey('invalid-date'), isNull);
      expect(CycleDateContract.parseDayKey('2026-99-99'), isNull);
    });

    test('daysBetween computes exact calendar day difference', () {
      final d1 = DateTime(2026, 3, 10);
      final d2 = DateTime(2026, 3, 15);
      expect(CycleDateContract.daysBetween(d1, d2), equals(5));
      expect(CycleDateContract.daysBetween(d2, d1), equals(-5));
      expect(CycleDateContract.daysBetween(d1, d1), equals(0));
    });

    test('daysBetween is DST-resilient across daylight saving transitions', () {
      // In local time with hours set to different times of day, calendar difference remains exact
      final morning = DateTime(2026, 3, 21, 1, 0, 0);
      final nextEvening = DateTime(2026, 3, 22, 23, 0, 0);
      expect(CycleDateContract.daysBetween(morning, nextEvening), equals(1));

      // Test across month boundaries
      final endOfMonth = DateTime(2026, 3, 31, 23, 59);
      final startOfNext = DateTime(2026, 4, 1, 0, 1);
      expect(CycleDateContract.daysBetween(endOfMonth, startOfNext), equals(1));
    });

    test('cleanDate normalizes DateTime to midnight 00:00:00', () {
      final dt = DateTime(2026, 7, 20, 18, 45, 12, 500);
      final cleaned = CycleDateContract.cleanDate(dt);
      expect(cleaned, equals(DateTime(2026, 7, 20)));
      expect(cleaned.hour, equals(0));
      expect(cleaned.minute, equals(0));
      expect(cleaned.second, equals(0));
    });

    test('isSameDay correctly identifies same or different calendar days', () {
      final a = DateTime(2026, 5, 10, 8, 0);
      final b = DateTime(2026, 5, 10, 22, 30);
      final c = DateTime(2026, 5, 11, 8, 0);

      expect(CycleDateContract.isSameDay(a, b), isTrue);
      expect(CycleDateContract.isSameDay(a, c), isFalse);
    });

    test('isSameOrBefore and isSameOrAfter evaluate correctly', () {
      final d1 = DateTime(2026, 5, 10, 23, 0);
      final d2 = DateTime(2026, 5, 10, 1, 0);
      final d3 = DateTime(2026, 5, 12, 10, 0);

      expect(CycleDateContract.isSameOrBefore(d1, d2), isTrue);
      expect(CycleDateContract.isSameOrBefore(d1, d3), isTrue);
      expect(CycleDateContract.isSameOrBefore(d3, d1), isFalse);

      expect(CycleDateContract.isSameOrAfter(d1, d2), isTrue);
      expect(CycleDateContract.isSameOrAfter(d3, d1), isTrue);
      expect(CycleDateContract.isSameOrAfter(d1, d3), isFalse);
    });

    test('inWindow validates inclusive date range', () {
      final start = DateTime(2026, 5, 10);
      final end = DateTime(2026, 5, 20);

      expect(
        CycleDateContract.inWindow(DateTime(2026, 5, 10), start, end),
        isTrue,
      );
      expect(
        CycleDateContract.inWindow(DateTime(2026, 5, 15), start, end),
        isTrue,
      );
      expect(
        CycleDateContract.inWindow(DateTime(2026, 5, 20), start, end),
        isTrue,
      );
      expect(
        CycleDateContract.inWindow(DateTime(2026, 5, 9), start, end),
        isFalse,
      );
      expect(
        CycleDateContract.inWindow(DateTime(2026, 5, 21), start, end),
        isFalse,
      );
    });
  });
}
