import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/goals/logic/goal_planning_quick_parser.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';

void main() {
  group('GoalPlanningQuickParser Tests', () {
    const parser = GoalPlanningQuickParser();
    final now = DateTime(2026, 8, 29); // شنبه یا تاریخ مشخص

    test('parses title with numbers without corrupting chapter number', () {
      final res = parser.parse('مطالعه فصل ۲ ریاضی فردا ۱ ساعت', now: now);
      expect(res.cleanTitle, equals('مطالعه فصل 2 ریاضی'));
      expect(res.durationMinutes, equals(60));
      expect(res.matchedDayLabel, equals('فردا'));
    });

    test('parses importance and weekday correctly', () {
      final res = parser.parse('تمرین بدنسازی دوشنبه ۴۵ دقیقه فوری', now: now);
      expect(res.cleanTitle, equals('تمرین بدنسازی'));
      expect(res.durationMinutes, equals(45));
      expect(res.importance, equals(CommitmentImportance.must));
      expect(res.matchedDayLabel, equals('دوشنبه'));
    });

    test('parses half-hour and quarter-hour phrases', () {
      final res1 = parser.parse('جلسه کاری نیم ساعت', now: now);
      expect(res1.durationMinutes, equals(30));

      final res2 = parser.parse('پیاده‌روی یک ربع امروز', now: now);
      expect(res2.durationMinutes, equals(15));
      expect(res2.matchedDayLabel, equals('امروز'));
    });
  });
}
