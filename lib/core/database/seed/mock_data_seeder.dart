import 'package:ritmo/core/database/seed/seed_service.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Utilities for mock data purging and database cleansing.
class MockDataSeeder {
  static const List<String> userTablesToClear = [
    'routines',
    'routine_schedules',
    'routine_occurrences',
    'routine_completions',
    'simple_tasks',
    'courses',
    'course_sessions',
    'goals',
    'goal_steps',
    'konkur_subjects',
    'konkur_topics',
    'konkur_mock_exams',
    'konkur_mock_exam_results',
    'konkur_study_sessions',
    'konkur_plan_items',
    'cycle_periods',
    'cycle_logs',
    'cycle_day_logs',
    'cycle_predictions',
    'mood_logs',
    'daily_checkins',
    'daily_reflections',
    'energy_logs',
    'worship_practices',
    'worship_debts',
    'fasting_debt',
    'doctor_visits',
    'vaccinations',
    'medical_profile',
    'blood_pressure_logs',
    'blood_sugar_logs',
    'vital_signs_logs',
    'medication_logs',
    'ss_workout_plan',
    'ss_workout_exercise_crossref',
    'ss_workout_session_log',
    'ss_workout_set_log',
    'ss_exercise_feeling_log',
    'ss_user_profile',
    'ss_plan_version_history',
    'workout_split_days',
    'workout_logs',
    'workout_set_logs',
    'workout_recovery_logs',
    'day_marks',
    'day_templates',
    'bedtime_diagnostics',
    'focus_sessions',
    'chat_conversations',
    'chat_messages',
    'inbox_items',
  ];

  /// Completely wipes all mock/user data and re-seeds clean system defaults.
  static Future<void> clearMockData(DatabaseExecutor db) async {
    RitmoLog.info('MockDataSeeder', 'Purging all mock and sample data from database');
    for (final table in userTablesToClear) {
      try {
        await db.delete(table);
      } catch (_) {}
    }

    try {
      await db.delete('app_settings');
    } catch (_) {}

    // Re-seed essential system defaults (empty user state, dark theme, normal gentleness, standard prayers, iran cities)
    await SeedService.seedSettings(db);
    await SeedService.seedWorshipPractices(db);
    await SeedService.seedIranCities(db);
    await SeedService.seedSupplementarySports(db);
  }

  /// Automatically detects and purges legacy mock data if present in DB.
  static Future<void> purgeIfLegacyMock(DatabaseExecutor db) async {
    try {
      final rows = await db.query(
        'app_settings',
        where: "key = 'user_name' AND value = 'الهام'",
        limit: 1,
      );
      final hasMockUser = rows.isNotEmpty;

      final cycleCheck = await db.query(
        'cycle_day_logs',
        where: "note LIKE '%باروری%' OR note LIKE '%قاعدگی%'",
        limit: 1,
      );
      final hasMockCycle = cycleCheck.isNotEmpty;

      if (hasMockUser || hasMockCycle) {
        RitmoLog.info('MockDataSeeder', 'Legacy mock data detected. Purging now...');
        await clearMockData(db);
      }
    } catch (e, st) {
      RitmoLog.error('MockDataSeeder', 'Error during mock data check/purge', e, st);
    }
  }

  static Future<void> clearAllData(DatabaseExecutor db) async {
    await clearMockData(db);
  }
}
