import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/goals/logic/planning_week.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  group('PlanningWeek Tests', () {
    test('PL-08 / F-09: dayKeysOfMonthContaining returns exact Jalali month lengths', () {
      // 1. Farvardin (month 1) has 31 days
      final farvardinDate = Jalali(1405, 1, 15).toDateTime();
      final farvardinDays = PlanningWeek.dayKeysOfMonthContaining(farvardinDate);
      expect(farvardinDays.length, equals(31));
      expect(farvardinDays.first, equals(PlanningWeek.dayKey(Jalali(1405, 1, 1).toDateTime())));
      expect(farvardinDays.last, equals(PlanningWeek.dayKey(Jalali(1405, 1, 31).toDateTime())));

      // 2. Mehr (month 7) has 30 days
      final mehrDate = Jalali(1405, 7, 10).toDateTime();
      final mehrDays = PlanningWeek.dayKeysOfMonthContaining(mehrDate);
      expect(mehrDays.length, equals(30));
      expect(mehrDays.first, equals(PlanningWeek.dayKey(Jalali(1405, 7, 1).toDateTime())));
      expect(mehrDays.last, equals(PlanningWeek.dayKey(Jalali(1405, 7, 30).toDateTime())));

      // 3. Esfand 1404 (non-leap) has 29 days
      final esfandDate = Jalali(1404, 12, 1).toDateTime();
      final esfandDays = PlanningWeek.dayKeysOfMonthContaining(esfandDate);
      expect(esfandDays.length, equals(29));
      expect(esfandDays.first, equals(PlanningWeek.dayKey(Jalali(1404, 12, 1).toDateTime())));
      expect(esfandDays.last, equals(PlanningWeek.dayKey(Jalali(1404, 12, 29).toDateTime())));
    });

    test('dayKeysOfWeekContaining returns 7 consecutive days starting on Saturday', () {
      final now = DateTime.now();
      final weekKeys = PlanningWeek.dayKeysOfWeekContaining(now);
      expect(weekKeys.length, equals(7));

      final firstDay = DateTime.parse(weekKeys.first);
      final jFirst = Jalali.fromDateTime(firstDay);
      expect(jFirst.weekDay, equals(1)); // Shanbeh in shamsi_date is 1
    });
  });
}
