import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';

@immutable
class ModuleContent {
  const ModuleContent({
    required this.moduleKey,
    this.agendaDomains = const <AgendaDomain>{},
    this.routineCategories = const <String>{},
    this.reminderTables = const <String>{},
    this.dataTables = const <String>{},
    this.settingsPrefixes = const <String>{},
    this.ownsWorshipPractices = false,
  });

  final String moduleKey;
  final Set<AgendaDomain> agendaDomains;
  final Set<String> routineCategories;
  final Set<String> reminderTables;
  final Set<String> dataTables;
  final Set<String> settingsPrefixes;
  final bool ownsWorshipPractices;
}

class ModuleContentMap {
  ModuleContentMap._();

  static const List<ModuleContent> map = [
    ModuleContent(
      moduleKey: 'module_religion_enabled',
      agendaDomains: {AgendaDomain.prayer, AgendaDomain.mustahab, AgendaDomain.worshipDebt},
      routineCategories: {'religious'},
      ownsWorshipPractices: true,
      dataTables: {'worship_practices', 'worship_completions', 'worship_debts'},
      settingsPrefixes: {'prayer_', 'worship_'},
    ),
    ModuleContent(
      moduleKey: 'module_medicine_enabled',
      agendaDomains: {AgendaDomain.medicine},
      routineCategories: {'medical', 'health'},
      dataTables: {'medicines', 'doctor_visits', 'health_metrics'},
    ),
    ModuleContent(
      moduleKey: 'module_courses_enabled',
      agendaDomains: {AgendaDomain.course},
      routineCategories: {'learning'},
      dataTables: {'courses', 'course_sessions', 'course_active_timers'},
    ),
    ModuleContent(
      moduleKey: 'module_study_enabled',
      agendaDomains: {AgendaDomain.konkur},
      routineCategories: {'konkur'},
      dataTables: {'konkur_plan_items', 'konkur_sessions'},
    ),
    ModuleContent(
      moduleKey: 'module_goals_enabled',
      agendaDomains: {AgendaDomain.goalStep},
      dataTables: {'goals', 'goal_steps'},
    ),
    ModuleContent(
      moduleKey: 'module_sports_enabled',
      agendaDomains: {AgendaDomain.sport},
      routineCategories: {'sports', 'fitness'},
      dataTables: {'workout_logs', 'ss_session_prescription', 'ss_fitness_assessments'},
    ),
    ModuleContent(
      moduleKey: 'module_cycle_enabled',
      agendaDomains: {AgendaDomain.cycle},
      dataTables: {'cycle_logs', 'cycle_predictions'},
      settingsPrefixes: {'cycle_'},
    ),
    ModuleContent(
      moduleKey: 'module_progressive_habits_enabled',
      routineCategories: {'habits'},
    ),
    ModuleContent(
      moduleKey: 'module_energy_enabled',
    ),
    ModuleContent(
      moduleKey: 'module_sleep_enabled',
    ),
    ModuleContent(
      moduleKey: 'module_assistant_enabled',
    ),
    ModuleContent(
      moduleKey: 'module_today_routines',
      agendaDomains: {AgendaDomain.routine, AgendaDomain.task, AgendaDomain.event},
      routineCategories: {'personal', 'custom', 'free'},
    ),
    ModuleContent(
      moduleKey: 'module_calendar_journey',
    ),
  ];

  static ModuleContent? findByKey(String key) {
    for (final c in map) {
      if (c.moduleKey == key) return c;
    }
    return null;
  }

  static String? ownerOfDomain(AgendaDomain domain) {
    for (final c in map) {
      if (c.agendaDomains.contains(domain)) return c.moduleKey;
    }
    return null;
  }

  static String? ownerOfCategory(String category) {
    for (final c in map) {
      if (c.routineCategories.contains(category)) return c.moduleKey;
    }
    return null;
  }
}
