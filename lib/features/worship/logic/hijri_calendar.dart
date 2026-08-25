import 'package:ritmo/features/worship/models/worship_models.dart';

/// Offline Tabular Islamic (Hijri) calendar calculator.
/// Uses 30-year cycle algorithm (leap years: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29).
class HijriCalendarCalculator {
  const HijriCalendarCalculator._();

  static const List<int> _leapYears = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29];

  static bool isLeapYear(int year) {
    final mod = year % 30;
    return _leapYears.contains(mod);
  }

  static int daysInMonth(int year, int month) {
    if (month < 1 || month > 12) return 29;
    if (month % 2 != 0) return 30; // Odd months have 30 days
    if (month == 12 && isLeapYear(year)) return 30; // 12th month in leap year
    return 29; // Even months have 29 days
  }

  static int _gregorianToJdn(int year, int month, int day) {
    final a = ((14 - month) / 12).floor();
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor() - (y / 100).floor() + (y / 400).floor() - 32045;
  }

  static DateTime _jdnToGregorian(int jdn) {
    final l0 = jdn + 68569;
    final n = ((4 * l0) / 146097).floor();
    final l1 = l0 - ((146097 * n + 3) / 4).floor();
    final i = ((4000 * (l1 + 1)) / 1464001).floor();
    final l2 = l1 - ((1461 * i) / 4).floor() + 31;
    final j = ((80 * l2) / 2447).floor();
    final day = l2 - ((2447 * j) / 80).floor();
    final l3 = (j / 11).floor();
    final month = j + 2 - 12 * l3;
    final year = 100 * (n - 49) + i + l3;
    return DateTime(year, month, day);
  }

  /// Converts Gregorian DateTime to HijriDate using exact 30-year tabular algorithm
  static HijriDate hijriFromGregorian(DateTime date, {int offsetDays = 0}) {
    final effectiveDate = DateTime(date.year, date.month, date.day + offsetDays);
    final jdn = _gregorianToJdn(effectiveDate.year, effectiveDate.month, effectiveDate.day);

    // Tabular Islamic Calendar conversion
    final daysSinceEpoch = jdn - 1948439;
    final cycle = (daysSinceEpoch / 10631).floor();
    final dayInCycle = daysSinceEpoch - (cycle * 10631);

    var yearInCycle = 1;
    while (yearInCycle <= 30) {
      final daysToEndOfYear = ((11 * yearInCycle + 3) / 30).floor() + 354 * yearInCycle;
      if (daysToEndOfYear >= dayInCycle) {
        break;
      }
      yearInCycle++;
    }
    yearInCycle = yearInCycle.clamp(1, 30);

    final hYear = cycle * 30 + yearInCycle;
    final startOfYearDays = ((11 * (yearInCycle - 1) + 3) / 30).floor() + 354 * (yearInCycle - 1);
    var dayInYear = dayInCycle - startOfYearDays;
    if (dayInYear <= 0) dayInYear = 1;

    var hMonth = 1;
    while (hMonth <= 12) {
      final daysInM = daysInMonth(hYear, hMonth);
      if (dayInYear <= daysInM) {
        break;
      }
      dayInYear -= daysInM;
      hMonth++;
    }
    if (hMonth > 12) hMonth = 12;
    final hDay = dayInYear.clamp(1, daysInMonth(hYear, hMonth));

    final mName = hijriMonthsFa[hMonth] ?? 'محرم';
    final formatted = '${toPersianDigits(hDay.toString())} $mName ${toPersianDigits(hYear.toString())}';

    return HijriDate(
      day: hDay,
      month: hMonth,
      year: hYear,
      monthName: mName,
      formatted: formatted,
    );
  }

  /// Converts Hijri to Gregorian DateTime using exact 30-year tabular algorithm
  static DateTime gregorianFromHijri(int hy, int hm, int hd, {int offsetDays = 0}) {
    final cycle = ((hy - 1) / 30).floor();
    final yearInCycle = hy - cycle * 30;

    final daysToYear = ((11 * (yearInCycle - 1) + 3) / 30).floor() + 354 * (yearInCycle - 1);
    var daysToMonth = 0;
    for (var m = 1; m < hm; m++) {
      daysToMonth += daysInMonth(hy, m);
    }

    final daysSinceEpoch = cycle * 10631 + daysToYear + daysToMonth + hd;
    final jdn = 1948439 + daysSinceEpoch;
    final rawG = _jdnToGregorian(jdn);

    return DateTime(rawG.year, rawG.month, rawG.day - offsetDays);
  }
}
