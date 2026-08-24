import 'dart:math';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';

/// Helper utilities for snapping minutes and duration calculations.
class TimelineSnappingHelper {
  const TimelineSnappingHelper._();

  static const int defaultSnapIntervalMinutes =
      CalendarDefaults.snapIntervalMinutes;
  static const int minDurationMinutes = CalendarDefaults.minDurationMinutes;

  /// Snaps [rawMinutes] to the nearest [intervalMinutes] (default 15 mins)
  /// and clamps within valid day minutes `[0, 1440 - duration]`.
  static int snapStartMinutes(
    int rawMinutes, {
    int intervalMinutes = defaultSnapIntervalMinutes,
    int durationMinutes = CalendarDefaults.fallbackDurationMinutes,
  }) {
    final sanitizedDuration = DurationBounds.sanitize(durationMinutes);
    final interval = intervalMinutes > 0
        ? intervalMinutes
        : CalendarDefaults.snapIntervalMinutes;
    final snapped = (rawMinutes / interval).round() * interval;
    final maxAllowed = (1440 - sanitizedDuration).clamp(0, 1440);
    return snapped.clamp(0, maxAllowed);
  }

  /// Snaps [rawDurationMinutes] to the nearest [intervalMinutes]
  /// enforcing a minimum duration of [minDurationMinutes] (default 15 mins).
  /// null یعنی در این نقطهٔ شروع، حتی حداقل مدت هم جا نمی‌شود.
  static int? snapDurationMinutes(
    int rawDurationMinutes, {
    int startMinutes = 0,
    int intervalMinutes = defaultSnapIntervalMinutes,
  }) {
    final interval = intervalMinutes > 0
        ? intervalMinutes
        : CalendarDefaults.snapIntervalMinutes;
    final untilEndOfDay = 1440 - startMinutes;
    if (untilEndOfDay < minDurationMinutes) return null;
    final hardMax = min(untilEndOfDay, DurationBounds.maxMinutes);
    final snapped = (rawDurationMinutes / interval).round() * interval;
    return snapped.clamp(minDurationMinutes, hardMax);
  }
}
