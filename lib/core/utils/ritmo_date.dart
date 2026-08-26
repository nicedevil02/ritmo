import 'package:flutter/foundation.dart';
import 'package:shamsi_date/shamsi_date.dart';

@immutable
class RitmoDate {
  RitmoDate(DateTime dt)
    : dateTime = DateTime(dt.year, dt.month, dt.day),
      value =
          '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  final DateTime dateTime;
  final String value; // Format: 'YYYY-MM-DD'

  static RitmoDate now() => RitmoDate(DateTime.now());

  static RitmoDate? parse(String raw) {
    try {
      final clean = raw.trim();
      final parts = clean.split('-');
      if (parts.length >= 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final dayStr = parts[2].split('T')[0].split(' ')[0];
        final day = int.parse(dayStr);
        return RitmoDate(DateTime(year, month, day));
      }
    } catch (_) {}
    return null;
  }

  // --- Static Date Helpers (T-0.1) ---
  static String dayKey(DateTime instant) {
    final local = instant.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String dayKeyFromMillis(int millis) =>
      dayKey(DateTime.fromMillisecondsSinceEpoch(millis));

  static DateTime startOfDay(DateTime instant) {
    final l = instant.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  static int startOfDayMillis(DateTime instant) =>
      startOfDay(instant).millisecondsSinceEpoch;

  static List<String> lastNDayKeys(DateTime now, int days) {
    final base = startOfDay(now);
    return List<String>.generate(
      days,
      (i) => dayKey(base.subtract(Duration(days: days - 1 - i))),
    );
  }

  static DateTime? tryParseDayKey(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final clean = value.trim();
      final parts = clean.split('-');
      if (parts.length >= 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2].split('T')[0].split(' ')[0]);
        if (year < 1800) {
          final jalali = Jalali(year, month, day);
          return jalali.toDateTime();
        } else {
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return DateTime.tryParse(value);
  }

  RitmoDate addDays(int days) => RitmoDate(dateTime.add(Duration(days: days)));
  RitmoDate subtractDays(int days) =>
      RitmoDate(dateTime.subtract(Duration(days: days)));

  bool isSameDay(RitmoDate other) => value == other.value;
  bool isBefore(RitmoDate other) => dateTime.isBefore(other.dateTime);
  bool isAfter(RitmoDate other) => dateTime.isAfter(other.dateTime);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitmoDate &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
