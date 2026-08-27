import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Contract for date manipulation and formatting in the Courses module (K-02, K-03).
class CourseDate {
  const CourseDate._();

  /// Converts a [DateTime] to a standard DayKey format: 'YYYY-MM-DD'.
  static String toDayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a DayKey string 'YYYY-MM-DD' into a normalized local DateTime.
  /// Null-safe, returns null on invalid input without throwing.
  static DateTime? parseDayKey(String? key) {
    if (key == null) return null;
    final clean = key.trim();
    if (clean.isEmpty) return null;
    try {
      final datePart = clean.split('T')[0].split(' ')[0];
      final parts = datePart.split('-');
      if (parts.length >= 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
          return DateTime(y, m, d);
        }
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'CourseDate.parseDayKey error on "$key": $e',
        error: e,
        stack: st,
      );
    }
    return null;
  }

  /// DST-safe date addition using UTC coordinates.
  static DateTime addDays(DateTime dt, int days) {
    final utc = DateTime.utc(dt.year, dt.month, dt.day);
    final addedUtc = utc.add(Duration(days: days));
    return DateTime(addedUtc.year, addedUtc.month, addedUtc.day);
  }

  /// Difference in calendar days between two dates, independent of time of day and DST.
  static int daysBetween(DateTime a, DateTime b) {
    final utcA = DateTime.utc(a.year, a.month, a.day);
    final utcB = DateTime.utc(b.year, b.month, b.day);
    return (utcB.difference(utcA).inHours / 24).round();
  }

  /// Finds Saturday (شنبه) as the start of the Persian week for [dt].
  static DateTime startOfFarsiWeek(DateTime dt) {
    final weekday = dt.weekday; // 1 = Mon, ..., 6 = Sat, 7 = Sun
    final daysToSubtract = (weekday == DateTime.saturday) ? 0 : (weekday % 7) + 1;
    return addDays(dt, -daysToSubtract);
  }

  /// Checks if two [DateTime] instances fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Converts a Gregorian [DateTime] to formatted Persian Jalali display: '۱۴۰۵/۰۶/۱۴'.
  static String toJalaliDisplay(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    final y = j.year.toString();
    final m = j.month.toString().padLeft(2, '0');
    final d = j.day.toString().padLeft(2, '0');
    return RitmoNumber.fa('$y/$m/$d');
  }

  /// Converts a DayKey string 'YYYY-MM-DD' to formatted Persian Jalali display.
  static String dayKeyToJalaliDisplay(String key) {
    final dt = parseDayKey(key);
    if (dt == null) return key;
    return toJalaliDisplay(dt);
  }
}
