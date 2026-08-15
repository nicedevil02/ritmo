import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Single source of truth for onboarding completion state.
class OnboardingGate {
  const OnboardingGate._();

  static const int currentVersion = 1;

  /// Returns true if onboarding has been completed in SQLite or SharedPreferences.
  static Future<bool> isCompleted(DatabaseExecutor db) async {
    try {
      final completedRows = await db.query(
        'app_settings',
        where: "key = 'onboarding_completed'",
        limit: 1,
      );
      if (completedRows.isNotEmpty && completedRows.first['value'] == 'true') {
        return true;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('onboarding_completed') == true;
    } catch (_) {}

    return false;
  }

  /// Explicitly heals SQLite app_settings from SharedPreferences if SharedPreferences has completed state.
  static Future<bool> healFromPrefs(DatabaseExecutor db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSpCompleted = prefs.getBool('onboarding_completed') == true;
      final spUserName = prefs.getString('user_name');

      if (isSpCompleted && spUserName != null && spUserName.isNotEmpty) {
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        await db.insert(
          'app_settings',
          {'key': 'user_name', 'value': spUserName, 'updatedAt': nowMs},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await db.insert(
          'app_settings',
          {'key': 'onboarding_completed', 'value': 'true', 'updatedAt': nowMs},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      }
    } catch (_) {}
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
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('onboarding_version') ?? 0;
    } catch (_) {}

    return 0;
  }

  /// Marks onboarding as completed in SQLite.
  static Future<void> markCompleted(DatabaseExecutor txn, {required int version, String? userName}) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await txn.insert(
      'app_settings',
      {
        'key': 'onboarding_completed',
        'value': 'true',
        'updatedAt': nowMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await txn.insert(
      'app_settings',
      {
        'key': 'onboarding_version',
        'value': version.toString(),
        'updatedAt': nowMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (userName != null && userName.isNotEmpty) {
      await txn.insert(
        'app_settings',
        {
          'key': 'user_name',
          'value': userName,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Syncs onboarding completion state to SharedPreferences asynchronously outside transactions.
  static Future<void> syncToPrefs({required int version, String? userName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);
      await prefs.setInt('onboarding_version', version);
      if (userName != null && userName.isNotEmpty) {
        await prefs.setString('user_name', userName);
      }
    } catch (_) {}
  }
}
