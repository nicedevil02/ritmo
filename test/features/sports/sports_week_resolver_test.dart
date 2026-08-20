import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_week_resolver.dart';

void main() {
  group('SsWeekResolver unit tests', () {
    test('activeWeek calculates correct week index', () {
      final startDate = DateTime(2026, 8, 1);

      // Day 0 to Day 6 -> Week 1
      expect(
        SsWeekResolver.activeWeek(
          programStartDate: startDate,
          date: DateTime(2026, 8, 1),
          totalWeeks: 4,
        ),
        1,
      );
      expect(
        SsWeekResolver.activeWeek(
          programStartDate: startDate,
          date: DateTime(2026, 8, 7),
          totalWeeks: 4,
        ),
        1,
      );

      // Day 7 to Day 13 -> Week 2
      expect(
        SsWeekResolver.activeWeek(
          programStartDate: startDate,
          date: DateTime(2026, 8, 8),
          totalWeeks: 4,
        ),
        2,
      );

      // Day 21 to Day 27 -> Week 4
      expect(
        SsWeekResolver.activeWeek(
          programStartDate: startDate,
          date: DateTime(2026, 8, 22),
          totalWeeks: 4,
        ),
        4,
      );

      // Day 28+ cycles back to Week 1 (4-week mesocycle wrap)
      expect(
        SsWeekResolver.activeWeek(
          programStartDate: startDate,
          date: DateTime(2026, 8, 29),
          totalWeeks: 4,
        ),
        1,
      );
    });

    test('formatSportTitle correctly parses raw json and plain strings', () {
      expect(
        SsWeekResolver.formatSportTitle({
          'muscleGroups': '["سینه","سرشانه","پشت‌بازو"]',
        }),
        'تمرین سینه و سرشانه و پشت‌بازو',
      );

      expect(
        SsWeekResolver.formatSportTitle({
          'muscleGroups': 'پا و شکم',
        }),
        'تمرین پا و شکم',
      );

      expect(
        SsWeekResolver.formatSportTitle({}),
        'تمرین ورزشی',
      );
    });
  });
}
