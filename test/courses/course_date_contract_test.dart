import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/courses/logic/course_date_contract.dart';

void main() {
  group('CourseDate Contract Tests (K-02, K-03)', () {
    test('toDayKey formats date as YYYY-MM-DD with zero-padding', () {
      final dt = DateTime(2026, 3, 5, 14, 30);
      expect(CourseDate.toDayKey(dt), equals('2026-03-05'));
    });

    test('parseDayKey safely parses valid day keys and handles edge cases', () {
      expect(CourseDate.parseDayKey('2026-03-05'), equals(DateTime(2026, 3, 5)));
      expect(CourseDate.parseDayKey('2026-03-05T12:00:00Z'), equals(DateTime(2026, 3, 5)));
      expect(CourseDate.parseDayKey('2026-03-05 14:20:00'), equals(DateTime(2026, 3, 5)));
      expect(CourseDate.parseDayKey(null), isNull);
      expect(CourseDate.parseDayKey(''), isNull);
      expect(CourseDate.parseDayKey('invalid-date'), isNull);
      expect(CourseDate.parseDayKey('2026-99-99'), isNull);
    });

    test('addDays correctly advances and decrements dates across month boundaries', () {
      final start = DateTime(2026, 2, 28);
      final nextDay = CourseDate.addDays(start, 1);
      expect(nextDay, equals(DateTime(2026, 3, 1)));

      final prevDay = CourseDate.addDays(nextDay, -1);
      expect(prevDay, equals(DateTime(2026, 2, 28)));
    });

    test('daysBetween computes calendar day difference', () {
      final a = DateTime(2026, 6, 1, 23, 59);
      final b = DateTime(2026, 6, 5, 0, 1);
      expect(CourseDate.daysBetween(a, b), equals(4));
      expect(CourseDate.daysBetween(b, a), equals(-4));
    });

    test('startOfFarsiWeek always returns Saturday', () {
      // 2026-06-20 is a Saturday
      final sat = DateTime(2026, 6, 20);
      expect(CourseDate.startOfFarsiWeek(sat), equals(DateTime(2026, 6, 20)));

      // 2026-06-21 is a Sunday -> previous Saturday is 2026-06-20
      final sun = DateTime(2026, 6, 21);
      expect(CourseDate.startOfFarsiWeek(sun), equals(DateTime(2026, 6, 20)));

      // 2026-06-26 is a Friday -> previous Saturday is 2026-06-20
      final fri = DateTime(2026, 6, 26);
      expect(CourseDate.startOfFarsiWeek(fri), equals(DateTime(2026, 6, 20)));
    });

    test('isSameDay accurately compares calendar dates ignoring time', () {
      final a = DateTime(2026, 6, 20, 8, 30);
      final b = DateTime(2026, 6, 20, 22, 15);
      final c = DateTime(2026, 6, 21, 8, 30);

      expect(CourseDate.isSameDay(a, b), isTrue);
      expect(CourseDate.isSameDay(a, c), isFalse);
    });

    test('toJalaliDisplay and dayKeyToJalaliDisplay format to Persian Shamsi strings', () {
      // 2026-03-21 is 1405-01-01 (Nowruz)
      final dt = DateTime(2026, 3, 21);
      final display = CourseDate.toJalaliDisplay(dt);
      expect(display, contains('۱۴۰۵'));
      expect(display, contains('۰۱'));

      final fromKey = CourseDate.dayKeyToJalaliDisplay('2026-03-21');
      expect(fromKey, equals(display));
    });
  });
}
