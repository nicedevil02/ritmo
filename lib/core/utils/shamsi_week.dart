/// Single source of truth for Shamsi weekday names and plurals.
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
}
