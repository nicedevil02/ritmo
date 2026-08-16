import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovementAnalyticsService Tests (Gate 5 - 13 Events)', () {
    setUp(() {
      MovementAnalyticsService.clearEvents();
    });

    test('records all 13 events accurately with sanitized parameters', () {
      final service = MovementAnalyticsService.instance;

      // 1. movement_center_opened
      service.logCenterOpened(source: 'home', hasPlan: true, heroState: 'scheduledToday');
      // 2. movement_add_intent_selected
      service.logAddIntentSelected(intentType: 'start_now');
      // 3. movement_plan_previewed
      service.logPlanPreviewed(family: 'running', daysCount: 3, hasConflict: false);
      // 4. movement_plan_saved
      service.logPlanSaved(occurrencesCount: 12, recurrenceType: 'weekly');
      // 5. movement_occurrence_moved
      service.logOccurrenceMoved(scope: 'thisOnly', dayOffset: 1, actionSource: 'sheet');
      // 6. movement_plan_b_selected
      service.logPlanBSelected(versionType: 'short', trigger: 'readiness');
      // 7. movement_session_started
      service.logSessionStarted(mode: 'time', startSource: 'occurrence', hasOccurrence: true);
      // 8. movement_session_resumed
      service.logSessionResumed(mode: 'time', pauseDurationSec: 60);
      // 9. movement_session_completed
      service.logSessionCompleted(mode: 'time', durationSec: 1800, goalAchieved: true);
      // 10. movement_session_partial
      service.logSessionPartial(mode: 'time', progressPct: 50.0, reason: 'tired');
      // 11. movement_readiness_submitted
      service.logReadinessSubmitted(filledFieldsCount: 4, trigger: 'manual');
      // 12. strength_onboarding_completed
      service.logStrengthOnboardingCompleted(goal: 'hypertrophy', daysPerWeek: 3, equipmentCount: 2);
      // 13. strength_program_activated
      service.logStrengthProgramActivated(totalWeeks: 8, sessionsPerWeek: 3);

      final events = MovementAnalyticsService.recordedEvents;
      expect(events.length, equals(13));

      final names = events.map((e) => e['name'] as String).toList();
      expect(names, equals([
        'movement_center_opened',
        'movement_add_intent_selected',
        'movement_plan_previewed',
        'movement_plan_saved',
        'movement_occurrence_moved',
        'movement_plan_b_selected',
        'movement_session_started',
        'movement_session_resumed',
        'movement_session_completed',
        'movement_session_partial',
        'movement_readiness_submitted',
        'strength_onboarding_completed',
        'strength_program_activated',
      ]));
    });

    test('sanitizes health notes and coordinates from event payload', () {
      final service = MovementAnalyticsService.instance;
      service.logReadinessSubmitted(filledFieldsCount: 3, trigger: 'manual');

      final event = MovementAnalyticsService.recordedEvents.first;
      final params = event['params'] as Map<String, dynamic>;

      expect(params.containsKey('note'), isFalse);
      expect(params.containsKey('health'), isFalse);
      expect(params.containsKey('location'), isFalse);
      expect(params['filled_fields_count'], equals(3));
    });
  });
}
