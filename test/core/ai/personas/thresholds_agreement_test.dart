import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/assistant_charters.dart';
import 'package:ritmo/core/ai/personas/persona_thresholds.dart';

void main() {
  group('PersonaThresholds Agreement Tests (PSN-42)', () {
    test('Sleep debt warning threshold matches charter (90 min)', () {
      final sleepCharter =
          AssistantCharters.charters['system_prompt_sleep'] ?? '';
      final sportsCharter =
          AssistantCharters.charters['system_prompt_sports'] ?? '';

      expect(PersonaThresholds.sleepDebtSevereMinutes, equals(90));
      expect(PersonaThresholds.sleepDebtWarningMinutes, equals(60));
      expect(
        sleepCharter.contains('۹۰') ||
            sleepCharter.contains('90') ||
            sleepCharter.contains('۶۰'),
        isTrue,
        reason: 'Sleep charter must mention sleep debt threshold',
      );
      expect(
        sportsCharter.contains('۹۰') || sportsCharter.contains('90'),
        isTrue,
        reason: 'Sports charter must mention 90-minute sleep debt threshold',
      );
    });

    test('Dead goal inactive threshold matches charter (14 days)', () {
      final goalsCharter =
          AssistantCharters.charters['system_prompt_goals'] ?? '';
      expect(PersonaThresholds.deadGoalInactiveDays, equals(14));
      expect(
        goalsCharter.contains('۱۴') || goalsCharter.contains('14'),
        isTrue,
        reason: 'Goals charter must mention 14-day inactivity threshold',
      );
    });

    test('Abandoned course inactive threshold matches charter (21 days)', () {
      final coursesCharter =
          AssistantCharters.charters['system_prompt_courses'] ?? '';
      expect(PersonaThresholds.abandonedCourseInactiveDays, equals(21));
      expect(
        coursesCharter.contains('۲۱') || coursesCharter.contains('21'),
        isTrue,
        reason: 'Courses charter must mention 21-day inactivity threshold',
      );
    });

    test('Sports weekly volume increase max matches charter (10%)', () {
      final sportsCharter =
          AssistantCharters.charters['system_prompt_sports'] ?? '';
      expect(PersonaThresholds.sportsWeeklyVolumeMaxIncreasePct, equals(10));
      expect(
        sportsCharter.contains('۱۰٪') || sportsCharter.contains('10%'),
        isTrue,
        reason: 'Sports charter must mention 10% volume increase threshold',
      );
    });
  });
}
