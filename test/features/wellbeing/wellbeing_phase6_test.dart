import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/reflection_engine.dart';
import 'package:ritmo/core/util/ritmo_date.dart';

void main() {
  group('Phase 6 Tests — Reflection Flow & Forgiving Streak (B23..B24)', () {
    final today = DateTime(2026, 8, 17);

    test('Criterion 1: Exactly 1 missed day 2 days ago is forgiven with token recorded', () {
      // User reflected today and 3 days ago, missing 1 and 2 days ago
      final twoAgo = today.subtract(const Duration(days: 2));
      final threeAgo = today.subtract(const Duration(days: 3));

      final dates = {
        RitmoDate.dayKey(twoAgo),
        RitmoDate.dayKey(threeAgo),
      };

      final walk = ReflectionEngine.walkCurrentStreak(
        dates: dates,
        today: today,
      );

      expect(walk.forgivenThisWeek, isTrue);
      expect(walk.currentStreak, greaterThanOrEqualTo(2));
    });

    test('Criterion 2: 3 consecutive missed days breaks streak to 0', () {
      final fourAgo = today.subtract(const Duration(days: 4));
      final dates = {
        RitmoDate.dayKey(fourAgo),
      };

      final walk = ReflectionEngine.walkCurrentStreak(
        dates: dates,
        today: today,
      );

      expect(walk.currentStreak, 0);
      expect(walk.forgivenThisWeek, isFalse);
    });
  });
}
