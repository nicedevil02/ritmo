import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Single source of truth for onboarding completion state.
class OnboardingGate {
  const OnboardingGate._();

  static const int currentVersion = 1;

  /// Returns true if onboarding has been completed in SettingsService cache, SQLite or SharedPreferences.
  static Future<bool> isCompleted(DatabaseExecutor db) async {
    if (SettingsService.instance.isInitialized) {
      try {
        if (SettingsService.instance.get<bool>('onboarding_completed') == true) {
          return true;
        }
      } catch (e, st) {
        RitmoLogger.warning(
          'OnboardingGate SettingsService read error: $e',
          error: e,
          stack: st,
        );
      }
    }

    try {
      final completedRows = await db.query(
        'app_settings',
        where: "key = 'onboarding_completed'",
        limit: 1,
      );
      if (completedRows.isNotEmpty && completedRows.first['value'] == 'true') {
        return true;
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingGate DB read error: $e',
        error: e,
        stack: st,
      );
    }

    // Fallback: Check SharedPreferences and heal DB if completed
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSpCompleted = prefs.getBool('onboarding_completed') == true;
      if (isSpCompleted) {
        return true;
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingGate SharedPreferences read error: $e',
        error: e,
        stack: st,
      );
    }

    return false;
  }

  /// Explicitly heals SQLite app_settings from SharedPreferences if SharedPreferences has completed state.
  static Future<bool> healFromPrefs(DatabaseExecutor db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSpCompleted = prefs.getBool('onboarding_completed') == true;
      final spUserName = prefs.getString('user_name');

      if (isSpCompleted) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (spUserName != null && spUserName.isNotEmpty) {
          await db.insert(
            'app_settings',
            {'key': 'user_name', 'value': spUserName, 'updatedAt': nowMs},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await db.insert(
          'app_settings',
          {'key': 'onboarding_completed', 'value': 'true', 'updatedAt': nowMs},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingGate healFromPrefs error: $e',
        error: e,
        stack: st,
      );
    }
    return false;
  }

  /// Returns the version number of the completed onboarding flow.
  static Future<int> completedVersion(DatabaseExecutor db) async {
    try {
      final rows = await db.query(
        'app_settings',
        where: "key = 'onboarding_version'",
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return int.tryParse(rows.first['value']! as String) ?? 0;
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingGate completedVersion DB error: $e',
        error: e,
        stack: st,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('onboarding_version') ?? 0;
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingGate completedVersion SP error: $e',
        error: e,
        stack: st,
      );
    }

    return 0;
  }

  /// Marks onboarding as completed in SQLite.
  static Future<void> markCompleted(
    DatabaseExecutor txn, {
    required int version,
    String? userName,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await UpsertHelper.upsert(
      txn,
      'app_settings',
      {
        'key': 'onboarding_completed',
        'value': 'true',
        'updatedAt': nowMs,
      },
      conflictColumns: const ['key'],
    );
    await UpsertHelper.upsert(
      txn,
      'app_settings',
      {
        'key': 'onboarding_version',
        'value': version.toString(),
        'updatedAt': nowMs,
      },
      conflictColumns: const ['key'],
    );

    if (userName != null && userName.isNotEmpty) {
      await UpsertHelper.upsert(
        txn,
        'app_settings',
        {
          'key': 'user_name',
          'value': userName,
          'updatedAt': nowMs,
        },
        conflictColumns: const ['key'],
      );
    }
  }

  /// Syncs onboarding completion state to SharedPreferences asynchronously outside transactions.
  static Future<void> syncToPrefs({
    required int version,
    String? userName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      await prefs.setInt('onboarding_version', version);
      if (userName != null && userName.isNotEmpty) {
        await prefs.setString('user_name', userName);
      }
    } catch (e, st) {
      RitmoLogger.warning(
        'OnboardingGate syncToPrefs error: $e',
        error: e,
        stack: st,
      );
    }
  }
}
