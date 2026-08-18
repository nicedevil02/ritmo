// C-13: CycleSettings Façade
// Single authoritative source of truth for Cycle configuration, canonical keys, defaults, and ranges.
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:sqflite/sqflite.dart';

class CycleSettings {
  const CycleSettings._();

  // Canonical setting keys
  static const String keyCycleLength = 'cycle_length_days';
  static const String keyPeriodDuration = 'period_duration_days';
  static const String keyLutealPhase = 'luteal_phase_days';
  static const String keyLockEnabled = 'cycle_lock_enabled';
  static const String keyPregnancyMode = 'cycle_pregnancy_mode';
  static const String keyConsentReminders = 'cycle_consent_reminders';
  static const String keyConsentWorship = 'cycle_consent_worship';
  static const String keyConsentDashboard = 'cycle_consent_dashboard';
  static const String keyConsentEnergy = 'cycle_consent_energy';
  static const String keyConsentSleep = 'cycle_consent_sleep';
  static const String keyFertilityVisible = 'cycle_fertility_visible';
  static const String keyPmsWindowDays = 'cycle_pms_window_days';

  // Authoritative defaults
  static const int defaultCycleLength = 28;
  static const int minCycleLength = 21;
  static const int maxCycleLength = 45;

  static const int defaultPeriodDuration = 6;
  static const int minPeriodDuration = 2;
  static const int maxPeriodDuration = 10;

  static const int defaultLutealPhase = 14;
  static const int minLutealPhase = 10;
  static const int maxLutealPhase = 16;

  static const int defaultPmsWindowDays = 4;

  // Legacy fallback aliases
  static const List<String> _cycleLengthAliases = [
    'cycle_avg_length',
    'user_cycle_length',
  ];
  static const List<String> _periodDurationAliases = [
    'cycle_avg_period',
    'period_avg_duration',
    'user_period_duration',
  ];
  static const List<String> _lutealPhaseAliases = ['luteal_phase_length'];
  static const List<String> _lockEnabledAliases = ['cycle_lock_active'];
  static const List<String> _pregnancyModeAliases = ['pregnancy_mode'];

  /// Gets the cycle length in days (clamped to [minCycleLength, maxCycleLength]).
  static int getCycleLength(Map<String, dynamic> settings) {
    final raw = settings[keyCycleLength];
    if (raw != null) {
      final parsed = int.tryParse(raw.toString());
      if (parsed != null &&
          parsed >= minCycleLength &&
          parsed <= maxCycleLength) {
        return parsed;
      }
    }
    // Check fallback aliases
    for (final alias in _cycleLengthAliases) {
      final aliasVal = settings[alias];
      if (aliasVal != null) {
        final parsed = int.tryParse(aliasVal.toString());
        if (parsed != null &&
            parsed >= minCycleLength &&
            parsed <= maxCycleLength) {
          return parsed;
        }
      }
    }
    return defaultCycleLength;
  }

  /// Gets the period duration in days (clamped to [minPeriodDuration, maxPeriodDuration]).
  static int getPeriodDuration(Map<String, dynamic> settings) {
    final raw = settings[keyPeriodDuration];
    if (raw != null) {
      final parsed = int.tryParse(raw.toString());
      if (parsed != null &&
          parsed >= minPeriodDuration &&
          parsed <= maxPeriodDuration) {
        return parsed;
      }
    }
    // Check fallback aliases
    for (final alias in _periodDurationAliases) {
      final aliasVal = settings[alias];
      if (aliasVal != null) {
        final parsed = int.tryParse(aliasVal.toString());
        if (parsed != null &&
            parsed >= minPeriodDuration &&
            parsed <= maxPeriodDuration) {
          return parsed;
        }
      }
    }
    return defaultPeriodDuration;
  }

  /// Gets the luteal phase length in days (clamped to [minLutealPhase, maxLutealPhase]).
  static int getLutealPhase(Map<String, dynamic> settings) {
    final raw = settings[keyLutealPhase];
    if (raw != null) {
      final parsed = int.tryParse(raw.toString());
      if (parsed != null &&
          parsed >= minLutealPhase &&
          parsed <= maxLutealPhase) {
        return parsed;
      }
    }
    for (final alias in _lutealPhaseAliases) {
      final aliasVal = settings[alias];
      if (aliasVal != null) {
        final parsed = int.tryParse(aliasVal.toString());
        if (parsed != null &&
            parsed >= minLutealPhase &&
            parsed <= maxLutealPhase) {
          return parsed;
        }
      }
    }
    return defaultLutealPhase;
  }

  /// Returns whether pregnancy mode is enabled.
  static bool isPregnancyMode(Map<String, dynamic> settings) {
    final raw = settings[keyPregnancyMode]?.toString().toLowerCase();
    if (raw == 'true') return true;
    if (raw == 'false') return false;

    for (final alias in _pregnancyModeAliases) {
      final aliasVal = settings[alias]?.toString().toLowerCase();
      if (aliasVal == 'true') return true;
      if (aliasVal == 'false') return false;
    }
    return false;
  }

  /// Returns whether cycle lock is enabled.
  static bool isLockEnabled(Map<String, dynamic> settings) {
    final raw = settings[keyLockEnabled]?.toString().toLowerCase();
    if (raw == 'false') return false;
    if (raw == 'true') return true;

    for (final alias in _lockEnabledAliases) {
      final aliasVal = settings[alias]?.toString().toLowerCase();
      if (aliasVal == 'false') return false;
      if (aliasVal == 'true') return true;
    }
    return true; // fail-secure default
  }

  /// Saves [days] as the canonical cycle length and synchronizes aliases.
  static Future<void> setCycleLength(
    int days, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    final clamped = days.clamp(minCycleLength, maxCycleLength);
    await _saveSetting(keyCycleLength, clamped.toString(), dbExecutor);
    for (final alias in _cycleLengthAliases) {
      await _deleteSetting(alias, dbExecutor);
    }
  }

  /// Saves [days] as the canonical period duration and synchronizes aliases.
  static Future<void> setPeriodDuration(
    int days, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    final clamped = days.clamp(minPeriodDuration, maxPeriodDuration);
    await _saveSetting(keyPeriodDuration, clamped.toString(), dbExecutor);
    for (final alias in _periodDurationAliases) {
      await _deleteSetting(alias, dbExecutor);
    }
  }

  /// Saves [days] as the canonical luteal phase length and synchronizes aliases.
  static Future<void> setLutealPhase(
    int days, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    final clamped = days.clamp(minLutealPhase, maxLutealPhase);
    await _saveSetting(keyLutealPhase, clamped.toString(), dbExecutor);
    for (final alias in _lutealPhaseAliases) {
      await _deleteSetting(alias, dbExecutor);
    }
  }

  /// Saves pregnancy mode status.
  static Future<void> setPregnancyMode(
    bool enabled, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    await _saveSetting(
      keyPregnancyMode,
      enabled ? 'true' : 'false',
      dbExecutor,
    );
    for (final alias in _pregnancyModeAliases) {
      await _deleteSetting(alias, dbExecutor);
    }
  }

  /// Saves cycle lock status.
  static Future<void> setLockEnabled(
    bool enabled, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    await _saveSetting(keyLockEnabled, enabled ? 'true' : 'false', dbExecutor);
    for (final alias in _lockEnabledAliases) {
      await _deleteSetting(alias, dbExecutor);
    }
  }

  static Future<void> _saveSetting(
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
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleSettings] error saving setting $key',
        error: e,
        stack: st,
      );
    }
  }

  static Future<void> _deleteSetting(
    String key, [
    DatabaseExecutor? dbExecutor,
  ]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleSettings] error deleting alias setting $key',
        error: e,
        stack: st,
      );
    }
  }
}
