import 'package:flutter/material.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_color.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';

/// Centralized safe parsers to eliminate unhandled FormatException / RangeError crashes (P-D).
class RitmoParsers {
  RitmoParsers._();

  /// Safely parses an integer with optional [fallback], [min], and [max] bounds.
  static int? tryParseInt(
    dynamic val, {
    int? fallback,
    int? min,
    int? max,
  }) {
    if (val == null) return fallback;
    int? result;
    if (val is int) {
      result = val;
    } else if (val is num) {
      result = val.toInt();
    } else if (val is String) {
      final normalized = toEnglishDigits(val.trim());
      result = int.tryParse(normalized);
    }
    if (result == null) return fallback;
    if (min != null && result < min) result = min;
    if (max != null && result > max) result = max;
    return result;
  }

  /// Safely parses a double with optional [fallback], [min], and [max] bounds.
  static double? tryParseDouble(
    dynamic val, {
    double? fallback,
    double? min,
    double? max,
  }) {
    if (val == null) return fallback;
    double? result;
    if (val is double) {
      result = val;
    } else if (val is num) {
      result = val.toDouble();
    } else if (val is String) {
      final normalized = toEnglishDigits(val.trim());
      result = double.tryParse(normalized);
    }
    if (result == null) return fallback;
    if (min != null && result < min) result = min;
    if (max != null && result > max) result = max;
    return result;
  }

  /// Safely parses a 'HH:mm' time string into [TimeOfDay].
  static TimeOfDay? tryParseHhMm(String? s) {
    return TimeOfDayMinutes.tryParseTimeOfDay(s);
  }

  /// Safely parses a hex color string using [RitmoColor.fromHex].
  static Color colorFromHex(
    String? hex, {
    Color fallback = const Color(0xFF6366F1),
  }) {
    return RitmoColor.fromHex(hex, fallback: fallback);
  }

  /// Safely parses a date string into [DateTime].
  static DateTime? tryParseDateTime(dynamic val, {DateTime? fallback}) {
    if (val == null) return fallback;
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) {
      final parsed = DateTime.tryParse(val.trim());
      return parsed ?? fallback;
    }
    return fallback;
  }
}
