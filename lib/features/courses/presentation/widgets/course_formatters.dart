import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

/// Helper for duration conversion and formatting (Fixes M10)
abstract final class CourseDurationFormat {
  /// Converts seconds to minutes with standard rounding, clamped to [CourseLimits.maxTimerSeconds] / 60 (480 minutes).
  static int minutesFromSeconds(int seconds) {
    if (seconds <= 0) return 0;
    final clampedSeconds = seconds.clamp(0, CourseLimits.maxTimerSeconds);
    return (clampedSeconds / 60.0).round();
  }
}

/// Legacy helper for Persian digits, wraps [RitmoNumber.toFa].
@Deprecated('Use RitmoNumber.toFa() or RitmoNumber.fa() directly instead.')
String toPersianDigits(dynamic input) {
  return RitmoNumber.toFa(input);
}

/// Formats duration in minutes to Persian representation, wraps [RitmoNumber.formatDuration].
String formatDuration(int minutes) {
  return RitmoNumber.formatDuration(minutes);
}
