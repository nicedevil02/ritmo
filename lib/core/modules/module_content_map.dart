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
      moduleKey: 'module_supplementary_sports_enabled',
      agendaDomains: {AgendaDomain.sport},
      routineCategories: {'sports', 'fitness'},
      dataTables: {
        'ss_user_profile',
        'ss_workout_plan',
        'ss_workout_exercise_crossref',
        'ss_workout_session_log',
        'ss_exercise_feeling_log',
        'ss_plan_version_history',
        'ss_decision_log',
        'ss_weight_log',
        'ss_workout_set_log',
        'workout_logs',
      },
      settingsPrefixes: {'ss_'},
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
      routineCategories: {'personal', 'custom', 'free', 'work'},
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
    final cat = category.toLowerCase().trim();
    if (cat == 'religious' || cat == 'worship') {
      return 'module_religion_enabled';
    }
    if (cat == 'medical' || cat == 'health') {
      return 'module_medicine_enabled';
    }
    if (cat == 'sports' || cat == 'fitness') {
      return 'module_sports_enabled';
    }
    if (cat == 'learning') {
      return 'module_courses_enabled';
    }
    if (cat == 'konkur') {
      return 'module_study_enabled';
    }
    if (cat == 'habits') {
      return 'module_progressive_habits_enabled';
    }
    if (cat == 'personal' || cat == 'work' || cat == 'free' || cat == 'custom') {
      return 'module_today_routines';
    }
    for (final c in map) {
      if (c.routineCategories.contains(cat)) return c.moduleKey;
    }
    return null;
  }
}
