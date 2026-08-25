import 'package:ritmo/core/utils/date_key.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Single source of truth for Shamsi weekday names, plurals, and week boundaries.
abstract final class ShamsiWeek {
  static const weekdayNames = [
    'شنبه',
    'یک‌شنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنج‌شنبه',
    'جمعه',
  ];

  static const weekdayPlurals = [
    'شنبه‌ها',
    'یک‌شنبه‌ها',
    'دوشنبه‌ها',
    'سه‌شنبه‌ها',
    'چهارشنبه‌ها',
    'پنج‌شنبه‌ها',
    'جمعه‌ها',
  ];

  /// Returns Persian weekday name for Jalali weekday (1=Saturday .. 7=Friday).
  static String nameOf(int jalaliWeekDay) =>
      weekdayNames[(jalaliWeekDay - 1).clamp(0, 6)];

  /// Returns Persian weekday plural for Jalali weekday (1=Saturday .. 7=Friday).
  static String pluralOf(int jalaliWeekDay) =>
      weekdayPlurals[(jalaliWeekDay - 1).clamp(0, 6)];

  /// Returns the Saturday (start) of the Jalali week containing [date] (local midnight).
  static DateTime saturdayOf(DateTime date) {
    final d = DateKey.dayOf(date);
    final j = Jalali.fromDateTime(d);
    return DateKey.addDays(d, -(j.weekDay - 1)); // Jalali weekDay: 1=Saturday .. 7=Friday
  }

  /// Returns the Friday (end) of the Jalali week containing [date] (local midnight).
  static DateTime fridayOf(DateTime date) => DateKey.addDays(saturdayOf(date), 6);

  /// Adds [months] to [j] while clamping the day to the destination month's length.
  /// Prevents DateException when moving from 31st of Farvardin-Shahrivar to Mehr-Esfand.
  static Jalali addMonthsClamped(Jalali j, int months) {
    var targetYear = j.year;
    var targetMonth = j.month + months;
    while (targetMonth > 12) {
      targetYear++;
      targetMonth -= 12;
    }
    while (targetMonth < 1) {
      targetYear--;
      targetMonth += 12;
    }
    final maxDay = Jalali(targetYear, targetMonth, 1).monthLength;
    return Jalali(targetYear, targetMonth, j.day.clamp(1, maxDay));
  }

  /// Adds [years] to [j] while clamping the day to the destination month's length (e.g. leap year Esfand).
  static Jalali addYearsClamped(Jalali j, int years) {
    final targetYear = j.year + years;
    final maxDay = Jalali(targetYear, j.month, 1).monthLength;
    return Jalali(targetYear, j.month, j.day.clamp(1, maxDay));
  }
}
