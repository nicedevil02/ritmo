import 'package:shamsi_date/shamsi_date.dart';

class PlanningWeek {
  static DateTime startOfWeek(DateTime day) {
    final j = Jalali.fromDateTime(day);
    final d = DateTime(day.year, day.month, day.day);
    return d.subtract(Duration(days: j.weekDay - 1));
  }

  static List<String> dayKeysOfWeekContaining(DateTime day) {
    final start = startOfWeek(day);
    return List.generate(7, (i) => dayKey(start.add(Duration(days: i))));
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String jalaliMonthKeyOf(DateTime day) {
    final j = Jalali.fromDateTime(day);
    return '${j.year}-${j.month.toString().padLeft(2, '0')}';
  }

  static (String start, String end) dayRangeOfJalaliMonth(int jy, int jm) {
    final first = Jalali(jy, jm, 1).toDateTime();
    final last = Jalali(jy, jm, Jalali(jy, jm).monthLength).toDateTime();
    return (dayKey(first), dayKey(last));
  }
}
