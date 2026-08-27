import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_deactivation_service.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/modules/module_registry.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/services/feature_limits.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:sqflite/sqflite.dart';

/// نتیجه تلاش برای فعال/غیرفعال‌کردن ماژول
enum ModuleToggleResult {
  /// موفق
  success,

  /// به سقف رایگان رسیده — نمایش آپگرید
  limitReached,

  /// خطا
  error,
}

/// Central Single Source of Truth for Module Activation & Synchronization in Ritmo.
class ModuleManagementService {
  ModuleManagementService._();
  static final ModuleManagementService instance = ModuleManagementService._();

  /// Canonical list of all module keys dynamically retrieved from ModuleRegistry (§2.1)
  static List<String> get allModuleKeys =>
      ModuleRegistry.modules.map((m) => m.key).toList();

  /// Fetches all module enable flags atomically from SettingsService
  Future<Map<String, bool>> getAllModuleStates() async {
    try {
      final states = <String, bool>{};
      for (final desc in ModuleRegistry.modules) {
        if (desc.isCore) {
          states[desc.key] = true;
        } else {
          states[desc.key] = SettingsService.instance.get<bool>(desc.key);
        }
      }
      return states;
    } catch (e, st) {
      RitmoLog.error('Modules', 'خطا در دریافت وضعیت ماژول‌ها', e, st);
      return {};
    }
  }

  /// Check if a specific module is enabled
  Future<bool> isModuleEnabled(String key) async {
    return ModuleGate.instance.isEnabled(key);
  }

  /// Sets a module enabled state with guaranteed atomic upsert, alarm cleanup/rescheduling,
  /// and global event bus notification.
  Future<ModuleToggleResult> setModuleEnabled(String key, bool enabled) async {
    try {
      if (!enabled) {
        // Complete deactivation: clear occurrences, cancel alarms, update settings
        await ModuleDeactivationService.deactivate(key);
        return ModuleToggleResult.success;
      }

      // Check concurrent module limit when enabling a non-core module
      if (!ModuleRegistry.isCoreModule(key)) {
        final alreadyEnabled = ModuleGate.instance.isEnabled(key);
        if (!alreadyEnabled && !ModuleGate.instance.canActivateMoreModules) {
          final limit = FeatureLimits.current.maxActiveModules;
          RitmoLog.warning(
            'Modules',
            'سقف ماژول‌های فعال ($limit) تکمیل است. نیاز به ارتقا به نسخه پیشرفته.',
          );
          return ModuleToggleResult.limitReached;
        }
      }

      // 1. Update settings via SettingsService
      await SettingsService.instance.set(key, true);

      if (key == 'module_sports_enabled' ||
          key == 'module_supplementary_sports_enabled') {
        await SettingsService.instance.set('module_sports_enabled', true);
        await SettingsService.instance.set(
          'module_supplementary_sports_enabled',
          true,
        );
      }

      if (key == 'module_medicine_enabled' ||
          key == 'module_health_enabled') {
        await SettingsService.instance.set('module_medicine_enabled', true);
        await SettingsService.instance.set('module_health_enabled', true);
      }

      // 2. Invalidate DayAgenda cache & schedule alarms
      DayAgendaService.instance.invalidateAll();
      try {
        await AlarmSchedulerService.scheduleNextAlarms();
      } catch (e, st) {
        RitmoLog.warning('Modules', 'Non-fatal alarm scheduling issue during module $key activation', e, st);
      }

      // 3. Refresh ModuleGate state
      await ModuleGate.instance.refresh();

      // 4. Broadcast global event to notify all listeners (UI screens, engines, services)
      RitmoEvents.notifyRoutineChanged();

      return ModuleToggleResult.success;
    } catch (e, st) {
      RitmoLog.error('Modules', 'خطا در تغییر وضعیت ماژول $key به $enabled', e, st);
      return ModuleToggleResult.error;
    }
  }

  /// Safely clear/reset all data associated with a specific module in SQLite.
  Future<void> resetModuleData(String key) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        Future<void> safeDelete(String table) async {
          try {
            await txn.delete(table);
          } catch (_) {}
        }

        Future<void> safeDeleteSettingsLike(String pattern) async {
          try {
            await txn.delete(
              'app_settings',
              where: 'key LIKE ? AND key != ?',
              whereArgs: [pattern, key],
            );
          } catch (_) {}
        }

        Future<void> safeDeleteSettingExact(String exactKey) async {
          try {
            await txn.delete(
              'app_settings',
              where: 'key = ?',
              whereArgs: [exactKey],
            );
          } catch (_) {}
        }

        switch (key) {
          case 'module_religion_enabled':
            await safeDelete('worship_debts');
            await safeDelete('worship_seasons');
            await safeDelete('worship_practices');
            await safeDelete('fasting_debt');
            await safeDeleteSettingsLike('religion_%');
            await safeDeleteSettingsLike('religious_%');
            await safeDeleteSettingsLike('worship_%');
            await safeDeleteSettingsLike('prayer_%');
            await safeDeleteSettingsLike('quran_%');
            await safeDeleteSettingsLike('fasting_%');
            await _safeDeleteRoutinesByCategory(txn, 'religious');
            break;

          case 'module_medicine_enabled':
            await safeDelete('medications');
            await safeDelete('medication_logs');
            await safeDelete('prn_logs');
            await safeDelete('doctor_visits');
            await safeDelete('blood_sugar_logs');
            await safeDelete('blood_pressure_logs');
            await safeDelete('vital_signs_logs');
            await safeDelete('medical_documents');
            await safeDelete('medical_document_images');
            await safeDelete('vaccinations');
            await safeDelete('allergies');
            await safeDelete('medical_profile');
            await safeDelete('pregnancy_tracker');
            await safeDelete('pregnancy_checkups');
            await safeDelete('pregnancy_symptoms');
            await safeDelete('kick_counts');
            await safeDelete('contraction_timer');
            await safeDeleteSettingsLike('health_%');
            await safeDeleteSettingsLike('medical_%');
            await safeDeleteSettingsLike('medication_%');
            await safeDeleteSettingsLike('medicine_%');
            await _safeDeleteRoutinesByCategory(txn, 'medical');
            break;

          case 'module_sports_enabled':
            await safeDelete('workout_logs');
            await safeDelete('workout_split_days');
            await safeDelete('workout_recovery_logs');
            await safeDeleteSettingsLike('sports_%');
            await safeDeleteSettingsLike('workout_%');
            await _safeDeleteRoutinesByCategory(txn, 'sports');
            break;

          case 'module_supplementary_sports_enabled':
            await safeDelete('ss_user_profile');
            await safeDelete('ss_workout_plan');
            await safeDelete('ss_workout_exercise_crossref');
            await safeDelete('ss_workout_session_log');
            await safeDelete('ss_exercise_feeling_log');
            await safeDelete('ss_plan_version_history');
            await safeDelete('ss_decision_log');
            await safeDelete('ss_weight_log');
            await safeDelete('ss_workout_set_log');
            await safeDeleteSettingsLike('ss_%');
            break;

          case 'module_cycle_enabled':
            await safeDelete('cycle_periods');
            await safeDelete('cycle_day_logs');
            await safeDelete('cycle_reminders_config');
            await safeDeleteSettingsLike('cycle_%');
            await safeDeleteSettingsLike('period_%');
            await safeDeleteSettingExact('show_cycle_in_calendar');
            await safeDeleteSettingExact('period_duration_days');
            try {
              await txn.delete(
                'worship_debts',
                where: "id LIKE 'debt_cycle_fast_%'",
              );
              await txn.delete(
                'worship_day_context',
                where: "reason = 'MENSTRUATION'",
              );
            } catch (_) {}
            WorshipEngine.instance.invalidate();
            DayAgendaService.instance.invalidateDate(
              DateTime.now().toIso8601String().substring(0, 10),
            );
            RitmoEventBus().fire(
              RitmoEvent(
                type: 'WorshipUpdated',
                timestamp: DateTime.now(),
                payload: {
                  'date': DateTime.now().toIso8601String().substring(0, 10),
                },
              ),
            );
            break;

          case 'module_courses_enabled':
            await safeDelete('courses');
            await safeDelete('course_sessions');
            await safeDelete('course_logs');
            await safeDeleteSettingsLike('courses_%');
            await safeDeleteSettingsLike('course_%');
            break;

          case 'module_goals_enabled':
            await safeDelete('goals');
            await safeDelete('goal_steps');
            await safeDelete('planning_reviews');
            await safeDelete('planning_allocations');
            await safeDelete('planning_commitments');
            await safeDelete('planning_cycles');
            await safeDeleteSettingsLike('goals_%');
            await safeDeleteSettingsLike('goal_%');
            await safeDeleteSettingsLike('planning_%');
            break;

          case 'module_assistant_enabled':
            await safeDelete('assistant_chats');
            await safeDelete('assistant_audit_log');
            await safeDelete('assistant_threads');
            await safeDelete('assistant_suggestions');
            await safeDeleteSettingsLike('assistant_%');
            break;

          case 'module_study_enabled':
            await safeDelete('konkur_subjects');
            await safeDelete('konkur_topics');
            await safeDelete('konkur_mock_exams');
            await safeDelete('konkur_mock_exam_results');
            await safeDelete('konkur_study_sessions');
            await safeDelete('konkur_plan_items');
            await safeDelete('study_active_session');
            await safeDeleteSettingsLike('study_%');
            await safeDeleteSettingsLike('konkur_%');
            break;

          case 'module_energy_enabled':
            await safeDelete('energy_logs');
            await safeDelete('mood_logs');
            await safeDeleteSettingsLike('energy_%');
            await safeDeleteSettingsLike('mood_%');
            break;

          case 'module_pregnancy_enabled':
            await safeDelete('contraction_timer');
            await safeDelete('kick_counts');
            await safeDelete('pregnancy_symptoms');
            await safeDelete('pregnancy_checkups');
            await safeDelete('pregnancy_tracker');
            await safeDeleteSettingsLike('pregnancy_%');
            await safeDeleteSettingsLike('cycle_pregnancy_%');
            break;

          case 'module_sleep_enabled':
            await safeDelete('bedtime_diagnostics');
            await safeDelete('sleep_programs');
            await safeDelete('sleep_plan_days');
            await safeDeleteSettingsLike('sleep_%');
            await safeDeleteSettingsLike('bedtime_%');
            break;

          case 'module_progressive_habits_enabled':
            await safeDelete('daily_checkins');
            await safeDelete('daily_reflections');
            await safeDeleteSettingsLike('habit_%');
            await safeDeleteSettingsLike('reflection_%');
            await safeDeleteSettingsLike('checkin_%');
            await _safeDeleteRoutinesByCategory(txn, 'habits');
            break;

          case 'module_notes_enabled':
            await safeDelete('note_experience_meta');
            await safeDelete('note_revisions');
            await safeDelete('note_attachments');
            await safeDelete('note_tags');
            await safeDelete('note_links');
            await safeDelete('notes');
            await safeDelete('notes_fts');
            await safeDeleteSettingsLike('notes_%');
            break;
        }
      });

      // Set module enable flag to 'false' in SettingsService
      await SettingsService.instance.set(key, false);
      await ModuleGate.instance.refresh();
      RitmoEvents.notifyRoutineChanged();
    } catch (e, st) {
      RitmoLog.error('Modules', 'خطا در بازنشانی اطلاعات ماژول $key', e, st);
    }
  }

  static Future<void> _safeDeleteRoutinesByCategory(
    DatabaseExecutor txn,
    String category,
  ) async {
    final rows = await txn.query(
      'routines',
      columns: ['id'],
      where: 'category = ?',
      whereArgs: [category],
    );
    for (final row in rows) {
      final rId = row['id'] as String;

      final pendingRows = await txn.query(
        'pending_reminders',
        columns: ['id'],
        where: 'routineId = ?',
        whereArgs: [rId],
      );
      for (final pRow in pendingRows) {
        final pid = pRow['id'] as String;
        try {
          await sl<AlarmPlatform>().cancelAlarm(pid);
        } catch (_) {}
      }

      await txn.delete(
        'pending_reminders',
        where: 'routineId = ?',
        whereArgs: [rId],
      );
      await txn.delete(
        'routine_occurrences',
        where: 'routine_id = ?',
        whereArgs: [rId],
      );
      await txn.delete(
        'routine_completions',
        where: 'routineId = ?',
        whereArgs: [rId],
      );
      await txn.delete(
        'routine_logs',
        where: 'routineId = ?',
        whereArgs: [rId],
      );
      await txn.delete(
        'routine_schedules',
        where: 'routineId = ?',
        whereArgs: [rId],
      );
      await txn.delete('routines', where: 'id = ?', whereArgs: [rId]);
    }
  }
}
