// C-02: Single Date Contract for the Cycle module.
// All date calculations, serialization, parsing, and comparisons in the cycle
// module must go through this contract to prevent DST, time zone, and format inconsistencies.

class CycleDateContract {
  const CycleDateContract._();

  /// Converts [d] to canonical `YYYY-MM-DD` day key based on local date.
  /// Does not use UTC or raw ISO string to avoid timezone drift.
  static String toDayKey(DateTime d) {
    final year = d.year.toString().padLeft(4, '0');
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses [s] into a clean `DateTime(y, m, d)` (00:00:00 local time).
  /// Resilient to both `YYYY-MM-DD` and full ISO8601 strings (e.g. `2026-05-12T14:30:00.000Z`).
  /// Returns `null` if [s] is null, empty, or unparseable.
  static DateTime? parseDayKey(String? s) {
    if (s == null) return null;
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;

    // Fast path: YYYY-MM-DD pattern
    final ymdRegex = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');
    final match = ymdRegex.firstMatch(trimmed);
    if (match != null) {
      final y = int.tryParse(match.group(1)!);
      final m = int.tryParse(match.group(2)!);
      final d = int.tryParse(match.group(3)!);
      if (y != null &&
          m != null &&
          d != null &&
          m >= 1 &&
          m <= 12 &&
          d >= 1 &&
          d <= 31) {
        final dt = DateTime(y, m, d);
        if (dt.year == y && dt.month == m && dt.day == d) {
          return dt;
        }
      }
      return null;
    }

    // Fallback: try full DateTime.tryParse
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return null;
  }

  /// Calculates the number of calendar days between [from] and [to] (to - from).
  /// Uses UTC calendar dates to be completely immune to Daylight Saving Time (DST) transitions.
  static int daysBetween(DateTime from, DateTime to) {
    final utcFrom = DateTime.utc(from.year, from.month, from.day);
    final utcTo = DateTime.utc(to.year, to.month, to.day);
    return utcTo.difference(utcFrom).inDays;
  }

  /// Normalizes [d] to a clean local `DateTime(y, m, d)` with 00:00:00.
  static DateTime cleanDate(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Checks if two dates fall on the exact same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Returns `true` if calendar day of [a] is before or the same as calendar day of [b].
  static bool isSameOrBefore(DateTime a, DateTime b) {
    final cleanA = DateTime.utc(a.year, a.month, a.day);
    final cleanB = DateTime.utc(b.year, b.month, b.day);
    return !cleanA.isAfter(cleanB);
  }

  /// Returns `true` if calendar day of [a] is after or the same as calendar day of [b].
  static bool isSameOrAfter(DateTime a, DateTime b) {
    final cleanA = DateTime.utc(a.year, a.month, a.day);
    final cleanB = DateTime.utc(b.year, b.month, b.day);
    return !cleanA.isBefore(cleanB);
  }

  /// Returns `true` if [target] falls within the inclusive calendar window [[start], [end]].
  static bool inWindow(DateTime target, DateTime start, DateTime end) {
    final cleanTarget = DateTime.utc(target.year, target.month, target.day);
    final cleanStart = DateTime.utc(start.year, start.month, start.day);
    final cleanEnd = DateTime.utc(end.year, end.month, end.day);
    return !cleanTarget.isBefore(cleanStart) && !cleanTarget.isAfter(cleanEnd);
  }
}
