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
  static const String keyPmsWindowDays = 'cycle_pms_window_days';
  static const String keyReminderLeadDays = 'cycle_reminder_lead_days';
  static const String keyReminderHour = 'cycle_reminder_hour';
  static const String keyConfirmStartEnabled = 'cycle_confirm_start_enabled';
  static const String keyConfirmEndEnabled = 'cycle_confirm_end_enabled';
  static const String keyInboxMaskEnabled = 'cycle_inbox_mask_enabled';
  static const String keyConfirmSnoozeUntil = 'cycle_confirm_snooze_until';
  static const String keyBiometricEnabled = 'cycle_biometric_enabled';

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

  /// آستانهٔ واحد «دورهٔ باز فراموش‌شده».
  /// قبلاً همین مفهوم در سه فایل با سه عملگر متفاوت (>=12، >12، <12) پیاده شده بود.
  static const int forgottenOpenPeriodDays = 12;

  /// مهلت اضافه پیش از پرسیدن «هنوز ادامه دارد؟»
  static const int prolongedBleedingGraceDays = 2;

  // Forecast constraints (F-12)
  static const int minCyclesForReliableForecast = 3;

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

  /// Parses lead days from comma-separated string, clamped to [1, 14], sorted descending.
  static List<int> getReminderLeadDays(Map<String, dynamic> settings) {
    final raw = settings[keyReminderLeadDays]?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      final parts = raw.split(',');
      final result = <int>{};
      for (final p in parts) {
        final v = int.tryParse(p.trim());
        if (v != null && v >= 1 && v <= 14) {
          result.add(v);
        }
      }
      if (result.isNotEmpty) {
        final list = result.toList()..sort((a, b) => b.compareTo(a));
        return list;
      }
    }
    return const [3, 1];
  }

  /// Gets reminder hour clamped to [6, 22], default 10.
  static int getReminderHour(Map<String, dynamic> settings) {
    final raw = settings[keyReminderHour]?.toString();
    if (raw != null) {
      final v = int.tryParse(raw);
      if (v != null) {
        return v.clamp(6, 22);
      }
    }
    return 10;
  }

  /// Returns whether start confirmation is enabled, default true.
  static bool isConfirmStartEnabled(Map<String, dynamic> settings) {
    final raw = settings[keyConfirmStartEnabled]?.toString().toLowerCase();
    if (raw == 'false') return false;
    return true;
  }

  /// Returns whether end confirmation is enabled, default true.
  static bool isConfirmEndEnabled(Map<String, dynamic> settings) {
    final raw = settings[keyConfirmEndEnabled]?.toString().toLowerCase();
    if (raw == 'false') return false;
    return true;
  }

  /// Returns whether inbox masking is enabled, default true.
  static bool isInboxMaskEnabled(Map<String, dynamic> settings) {
    final raw = settings[keyInboxMaskEnabled]?.toString().toLowerCase();
    if (raw == 'false') return false;
    return true;
  }

  /// Returns whether biometric authentication is enabled for cycle, default false.
  static bool isBiometricEnabled(Map<String, dynamic> settings) {
    final raw = settings[keyBiometricEnabled]?.toString().toLowerCase();
    if (raw == 'true') return true;
    return false;
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
