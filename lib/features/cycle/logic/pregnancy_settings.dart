import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
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

  // Three synchronized pregnancy mode flags
  static const String keyCyclePregnancyMode = 'cycle_pregnancy_mode';
  static const String keyPregnancyMode = 'pregnancy_mode';
  static const String keyCycleIsPregnant = 'cycle_is_pregnant';

  static const List<String> pregnancyFlagKeys = [
    keyCyclePregnancyMode,
    keyPregnancyMode,
    keyCycleIsPregnant,
  ];

  // Extended keys used in later PRG phases
  static const String keyShowCountdown = 'preg_show_countdown';
  static const String keySupplementReminder = 'preg_supplement_reminder';
  static const String keyKickReminder = 'preg_kick_reminder';
  static const String keyPrevConsentReminders = 'preg_prev_consent_reminders';
  static const String keyPrevConsentWorship = 'preg_prev_consent_worship';
  static const String keyPrevConsentDashboard = 'preg_prev_consent_dashboard';
  static const String keyMigrationPromptShown = 'preg_migration_prompt_shown';
  static const String keyHospitalBag = 'preg_hospital_bag';

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
    keyHospitalBag,
  ];

  static PregnancyProfile loadProfile(Map<String, dynamic> settings) {
    return PregnancyProfile.fromMap(settings);
  }

  static Map<String, String> toMap(PregnancyProfile profile) {
    return profile.toMap();
  }

  static bool isSetupDone(Map<String, dynamic> settings) {
    return settings[keySetupDone]?.toString().toLowerCase() == 'true';
  }

  static bool hasValidDates(Map<String, dynamic> settings) {
    final startStr = settings[keyStartDate]?.toString();
    final dueStr = settings[keyDueDate]?.toString();
    if (startStr == null || dueStr == null) return false;

    final start = CycleDateContract.parseDayKey(startStr);
    final due = CycleDateContract.parseDayKey(dueStr);
    if (start == null || due == null) return false;

    final diff = CycleDateContract.daysBetween(start, due);
    return diff >= 200 && diff <= 320;
  }

  static bool isPregnancyUsable(Map<String, dynamic> settings) {
    return CycleSettings.isPregnancyMode(settings) && hasValidDates(settings);
  }

  static Future<void> setPregnancyActive(
    bool active, {
    DatabaseExecutor? db,
  }) async {
    try {
      final executor = db ?? await DatabaseHelper.instance.database;
      final now = CycleClock.nowMillisecondsSinceEpoch;
      final valueStr = active ? 'true' : 'false';

      if (executor is Database) {
        final batch = executor.batch();
        for (final key in pregnancyFlagKeys) {
          batch.insert('app_settings', {
            'key': key,
            'value': valueStr,
            'updatedAt': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      } else {
        for (final key in pregnancyFlagKeys) {
          await executor.insert('app_settings', {
            'key': key,
            'value': valueStr,
            'updatedAt': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      if (!active) {
        await restoreCycleConsents(db: executor);
      }

      CycleEngine().invalidate();
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancySettings] error setting pregnancy active to $active',
        error: e,
        stack: st,
      );
      rethrow;
    }
  }

  /// Restores cycle consents (reminders, worship, dashboard) when exiting pregnancy mode.
  /// Uses backup values if present, or defaults to true (active).
  static Future<void> restoreCycleConsents({DatabaseExecutor? db}) async {
    try {
      final executor = db ?? await DatabaseHelper.instance.database;
      final rows = await executor.query(
        'app_settings',
        where: 'key IN (?, ?, ?)',
        whereArgs: [
          keyPrevConsentReminders,
          keyPrevConsentWorship,
          keyPrevConsentDashboard,
        ],
      );
      final map = {
        for (final r in rows) r['key'] as String: r['value']?.toString()
      };

      final restoreReminders = map[keyPrevConsentReminders] ?? 'true';
      final restoreWorship = map[keyPrevConsentWorship] ?? 'true';
      final restoreDashboard = map[keyPrevConsentDashboard] ?? 'true';

      await saveSetting('cycle_consent_reminders', restoreReminders, executor);
      await saveSetting('cycle_consent_worship', restoreWorship, executor);
      await saveSetting('cycle_consent_dashboard', restoreDashboard, executor);

      // Remove backup keys after restoration
      if (executor is Database) {
        await executor.delete(
          'app_settings',
          where: 'key IN (?, ?, ?)',
          whereArgs: [
            keyPrevConsentReminders,
            keyPrevConsentWorship,
            keyPrevConsentDashboard,
          ],
        );
      } else {
        await executor.rawDelete(
          'DELETE FROM app_settings WHERE key IN (?, ?, ?)',
          [
            keyPrevConsentReminders,
            keyPrevConsentWorship,
            keyPrevConsentDashboard,
          ],
        );
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancySettings] error restoring cycle consents: $e',
        error: e,
        stack: st,
      );
    }
  }

  /// Wipes all dedicated pregnancy keys (preg_*) and deactivates pregnancy mode.
  /// Only invoked during full pregnancy data purge explicitly initiated by the user.
  static Future<void> clearAll([DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final pregKeys = allKeys.where((k) => k.startsWith('preg_')).toList();
      for (final key in pregKeys) {
        if (db is Database) {
          await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
        } else {
          await db.rawDelete('DELETE FROM app_settings WHERE key = ?', [key]);
        }
      }

      // Also ensure any wild card preg_* keys are removed
      if (db is Database) {
        await db.delete('app_settings', where: "key LIKE 'preg_%'");
      } else {
        await db.rawDelete("DELETE FROM app_settings WHERE key LIKE 'preg_%'");
      }

      await setPregnancyActive(false, db: db);
      CycleEngine().invalidate();
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancySettings] error in clearAll: $e',
        error: e,
        stack: st,
      );
    }
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
