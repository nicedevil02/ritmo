import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:sqflite/sqflite.dart';

class PregnancySettings {
  const PregnancySettings._();

  static const String keyStartDate = 'preg_start_date';
  static const String keyDueDate = 'preg_due_date';
  static const String keyEddSource = 'preg_edd_source';
  static const String keyTone = 'preg_tone';
  static const String keyAgeUnit = 'preg_age_unit';
  static const String keyIsMultiple = 'preg_is_multiple';
  static const String keyIsHighRisk = 'preg_is_high_risk';
  static const String keySectionHidden = 'preg_section_hidden';
  static const String keyMaskNotifications = 'preg_mask_notifications';
  static const String keyLockEnabled = 'preg_lock_enabled';
  static const String keyCycleResumeReminder = 'preg_cycle_resume_reminder';
  static const String keyKickTargetCount = 'preg_kick_target_count';
  static const String keyKickWindowMinutes = 'preg_kick_window_minutes';
  static const String keyKickBaselineCompare = 'preg_kick_baseline_compare';
  static const String keyVisitReminderLead = 'preg_visit_reminder_lead_days';
  static const String keyReminderHour = 'preg_reminder_hour';
  static const String keySetupDone = 'preg_setup_done';

  // Extended keys used in later PRG phases
  static const String keyShowCountdown = 'preg_show_countdown';
  static const String keySupplementReminder = 'preg_supplement_reminder';
  static const String keyKickReminder = 'preg_kick_reminder';
  static const String keyPrevConsentReminders = 'preg_prev_consent_reminders';
  static const String keyPrevConsentWorship = 'preg_prev_consent_worship';
  static const String keyPrevConsentDashboard = 'preg_prev_consent_dashboard';
  static const String keyMigrationPromptShown = 'preg_migration_prompt_shown';

  static const List<String> allKeys = [
    keyStartDate,
    keyDueDate,
    keyEddSource,
    keyTone,
    keyAgeUnit,
    keyIsMultiple,
    keyIsHighRisk,
    keySectionHidden,
    keyMaskNotifications,
    keyLockEnabled,
    keyCycleResumeReminder,
    keyKickTargetCount,
    keyKickWindowMinutes,
    keyKickBaselineCompare,
    keyVisitReminderLead,
    keyReminderHour,
    keySetupDone,
    keyShowCountdown,
    keySupplementReminder,
    keyKickReminder,
    keyPrevConsentReminders,
    keyPrevConsentWorship,
    keyPrevConsentDashboard,
    keyMigrationPromptShown,
  ];

  static PregnancyProfile loadProfile(Map<String, dynamic> settings) {
    return PregnancyProfile.fromMap(settings);
  }

  static bool isSetupDone(Map<String, dynamic> settings) {
    return settings[keySetupDone]?.toString().toLowerCase() == 'true';
  }

  static Future<void> saveProfile(
    PregnancyProfile profile, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final now = CycleClock.nowMillisecondsSinceEpoch;
      final map = profile.toMap();

      if (db is Database) {
        final batch = db.batch();
        map.forEach((k, v) {
          batch.insert('app_settings', {
            'key': k,
            'value': v,
            'updatedAt': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
        await batch.commit(noResult: true);
      } else {
        for (final entry in map.entries) {
          await db.insert('app_settings', {
            'key': entry.key,
            'value': entry.value,
            'updatedAt': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      CycleEngine().invalidate();
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancySettings] error saving profile',
        error: e,
        stack: st,
      );
      rethrow;
    }
  }

  static Future<void> clearAll([DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      for (final key in allKeys) {
        await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
      }
      await db.delete('app_settings', where: "key LIKE 'preg_%'");
      CycleEngine().invalidate();
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancySettings] error clearing all settings',
        error: e,
        stack: st,
      );
    }
  }

  static Future<void> saveSetting(
    String key,
    String value, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final now = CycleClock.nowMillisecondsSinceEpoch;
      await db.insert('app_settings', {
        'key': key,
        'value': value,
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      CycleEngine().invalidate();
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancySettings] error saving setting $key',
        error: e,
        stack: st,
      );
    }
  }

  static Future<void> deleteSetting(
    String key, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
      CycleEngine().invalidate();
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancySettings] error deleting setting $key',
        error: e,
        stack: st,
      );
    }
  }
}
