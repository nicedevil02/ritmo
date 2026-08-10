import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';

void main() {
  group('UX-06 Checkup Window Status Tests', () {
    test('returns correct status for upcoming, open, done, and overdue states', () {
      // Completed state
      expect(
        PregnancyHelpers.checkupWindowStatus(
          currentWeek: 12,
          windowStartWeek: 11,
          windowEndWeek: 13,
          isCompleted: true,
        ),
        contains('انجام شد'),
      );

      // Upcoming state
      expect(
        PregnancyHelpers.checkupWindowStatus(
          currentWeek: 8,
          windowStartWeek: 11,
          windowEndWeek: 13,
          isCompleted: false,
        ),
        equals('هنوز باز نشده'),
      );

      // Open state
      expect(
        PregnancyHelpers.checkupWindowStatus(
          currentWeek: 12,
          windowStartWeek: 11,
          windowEndWeek: 13,
          isCompleted: false,
        ),
        contains('باز است'),
      );

      // Overdue state
      expect(
        PregnancyHelpers.checkupWindowStatus(
          currentWeek: 15,
          windowStartWeek: 11,
          windowEndWeek: 13,
          isCompleted: false,
        ),
        contains('پنجره بسته شد'),
      );
    });
  });
}
