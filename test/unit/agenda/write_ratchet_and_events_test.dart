import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase M3-B: Write Ratchet & Invalidation Events (P11 / M3-2..M3-3)', () {
    test('M3-2: Direct db.insert count on core work tables does not exceed baseline ceiling (Write Ratchet)', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final workTables = {
        'routines',
        'simple_tasks',
        'temporary_events',
        'worship_practices',
        'course_sessions',
        'goal_steps',
        'planning_allocations',
      };

      // Files permitted to do direct database persistence (dedicated repositories / handlers / migration / test seams)
      final permittedPaths = [
        'lib/core/database/',
        'lib/core/domain/execution/handlers/',
        'lib/features/routines/data/',
        'lib/features/simple_tasks/data/',
        'lib/features/worship/data/',
        'lib/features/courses/data/',
        'lib/features/goals/data/',
        'lib/features/routines/domain/strategies/',
      ];

      final violations = <String>[];

      for (final file in libDir.listSync(recursive: true)) {
        if (file is File && file.path.endsWith('.dart')) {
          final normalizedPath = file.path.replaceAll(r'\', '/');
          final isPermitted = permittedPaths.any((p) => normalizedPath.contains(p));
          if (isPermitted) continue;

          final content = file.readAsStringSync();
          for (final table in workTables) {
            // Pattern for db.insert('table_name', ...) or insert("table_name", ...)
            final pattern = RegExp("insert\\s*\\(\\s*['\"]$table['\"]");
            if (pattern.hasMatch(content)) {
              violations.add('${file.path}: direct insert into $table');
            }
          }
        }
      }

      // Baseline ceiling established in Wave 3 (M3-2):
      // Exact catalogue of 16 baseline direct insert sites with reason codes:
      // [RATCHET-01] planning_commands.dart: simple_tasks (Planning allocation materialization)
      // [RATCHET-02] planning_commands.dart: planning_allocations (Direct planning allocation creation)
      // [RATCHET-03] worship_commands.dart: worship_practices (Worship practice command handler)
      // [RATCHET-04] assistant_action_registry.dart: routines (Assistant creating routine)
      // [RATCHET-05] assistant_action_registry.dart: simple_tasks (Assistant creating task)
      // [RATCHET-06] assistant_action_registry.dart: worship_practices (Assistant creating practice)
      // [RATCHET-07] courses_repository.dart: course_sessions (Courses repository session persistence)
      // [RATCHET-08] goals_repository.dart: goal_steps (Goals repository step persistence)
      // [RATCHET-09] planning_repository.dart: planning_allocations (Planning repository allocation persistence)
      // [RATCHET-10] onboarding_controller.dart: routines (Onboarding starter routines seed)
      // [RATCHET-11] assistant_suggestions_service.dart: routines (Assistant suggestion routine acceptance)
      // [RATCHET-12] dashboard_controller.dart: routines (Quick add routine from dashboard)
      // [RATCHET-13] temporary_event_create_sheet.dart: temporary_events (Temporary event quick-sheet)
      // [RATCHET-14] worship_engine.dart: worship_practices (Worship engine practice initialization)
      // [RATCHET-15] mustahab_section.dart: worship_practices (Mustahab custom add sheet)
      // [RATCHET-16] quran_dhikr_section.dart: worship_practices (Dhikr custom add sheet)
      const maxAllowedViolations = 16;
      expect(
        violations.length,
        lessThanOrEqualTo(maxAllowedViolations),
        reason: 'Direct db.insert violations (${violations.length}) exceeded baseline ceiling ($maxAllowedViolations):\n${violations.join('\n')}',
      );
    });

    test('M3-3: Known creation and mutation events are strictly registered in DayAgendaService invalidation list', () {
      // Creation & mutation events from known creation points:
      // - Event sheet / creation: EventCreated
      // - Universal planner / TaskStrategy: task_created / TaskCreated
      // - Universal planner / GenericStrategy: RoutineCreated / RoutineEdited
      // - Universal planner / WorshipStrategy: WorshipPracticeChanged / WorshipUpdated
      // - Universal planner / ReflectionStrategy: ReflectionChanged
      // - Planning commands / allocations: commitmentChanged / planningCycleActivated / ReshuffleApplied
      // - Courses creation / session completion: CourseCreated / CourseSessionCompleted
      // - Goal step toggle / creation: GoalStepToggled / GoalUpdated
      final requiredEvents = [
        'EventCreated',
        'task_created',
        'TaskCreated',
        'RoutineCreated',
        'RoutineEdited',
        'RoutineUpdated',
        'RoutineChanged',
        'RoutineDeleted',
        'WorshipPracticeChanged',
        'WorshipUpdated',
        'ReflectionChanged',
        'commitmentChanged',
        'planningCycleActivated',
        'ReshuffleApplied',
        'CourseCreated',
        'CourseSessionCompleted',
        'GoalStepToggled',
        'GoalUpdated',
        'DayRolledOver',
        'DataImported',
      ];

      // Read day_agenda_service.dart source file to verify registration in _cacheInvalidatingEvents
      final serviceFile = File('lib/core/domain/agenda/day_agenda_service.dart');
      expect(serviceFile.existsSync(), isTrue);
      final serviceContent = serviceFile.readAsStringSync();

      for (final eventName in requiredEvents) {
        expect(
          serviceContent.contains("'$eventName'"),
          isTrue,
          reason: 'Event $eventName must be registered in DayAgendaService._cacheInvalidatingEvents',
        );
      }
    });
  });
}
