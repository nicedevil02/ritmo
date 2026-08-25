import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/presentation/widgets/course_formatters.dart';

void main() {
  group('Task 5 (M10) - Course Duration Formatting & Clamping', () {
    test('minutesFromSeconds returns 0 for zero or negative values', () {
      expect(CourseDurationFormat.minutesFromSeconds(0), equals(0));
      expect(CourseDurationFormat.minutesFromSeconds(-10), equals(0));
    });

    test('minutesFromSeconds rounds correctly', () {
      expect(CourseDurationFormat.minutesFromSeconds(29), equals(0));
      expect(CourseDurationFormat.minutesFromSeconds(30), equals(1));
      expect(CourseDurationFormat.minutesFromSeconds(59), equals(1));
      expect(CourseDurationFormat.minutesFromSeconds(60), equals(1));
      expect(CourseDurationFormat.minutesFromSeconds(89), equals(1));
      expect(CourseDurationFormat.minutesFromSeconds(90), equals(2));
      expect(CourseDurationFormat.minutesFromSeconds(300), equals(5));
    });

    test('minutesFromSeconds clamps to CourseLimits.maxTimerSeconds (480 mins)', () {
      // 100 hours in seconds
      const hugeSeconds = 100 * 3600;
      const maxMinutes = CourseLimits.maxTimerSeconds ~/ 60; // 480
      expect(CourseDurationFormat.minutesFromSeconds(hugeSeconds), equals(maxMinutes));
    });
  });
}
