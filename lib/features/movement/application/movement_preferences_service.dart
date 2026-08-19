import 'dart:async';
import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس مدیریت ترجیحات و تنظیمات ماژول حرکت (Gate 5)
class MovementPreferencesService {
  MovementPreferencesService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  // کلیدهای پیش‌فرض تنظیمات
  static const String keyDistanceUnit = 'distance_unit'; // km, mi
  static const String keyWeightUnit = 'weight_unit'; // kg, lb
  static const String keyDefaultReminderTime = 'default_reminder_time'; // 08:00
  static const String keyMorningReminder = 'morning_reminder'; // true, false
  static const String keyPreSessionReminder =
      'pre_session_reminder'; // true, false
  static const String keyQuietMode = 'quiet_mode'; // true, false
  static const String keyKeepScreenOn = 'keep_screen_on'; // true, false
  static const String keySoundEnabled = 'sound_enabled'; // true, false
  static const String keyHapticEnabled = 'haptic_enabled'; // true, false
  static const String keyCountdownSeconds = 'countdown_seconds'; // 5, 3, 0
  static const String keySmartSuggestionsEnabled =
      'smart_suggestions_enabled'; // true, false
  static const String keyInterventionLevel =
      'intervention_level'; // low, medium, high
  static const String keyPlanBBehavior =
      'plan_b_behavior'; // auto_suggest, manual_only

  final Map<String, String> _memoryCache = {};

  /// دریافت مقدار متنی یک ترجیح با مقدار پیش‌فرض
  Future<String> getString(String key, {String defaultValue = ''}) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key]!;
    }

    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tablePreferences,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) {
      _memoryCache[key] = defaultValue;
      return defaultValue;
    }

    final val = rows.first['value'] as String? ?? defaultValue;
    _memoryCache[key] = val;
    return val;
  }

  /// ذخیره مقدار متنی
  Future<void> setString(String key, String value) async {
    _memoryCache[key] = value;
    final dbExec = await _database;
    await dbExec.insert(
      MovementTables.tablePreferences,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// دریافت مقدار بولی
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final str = await getString(
      key,
      defaultValue: defaultValue ? 'true' : 'false',
    );
    return str.toLowerCase() == 'true';
  }

  /// ذخیره مقدار بولی
  Future<void> setBool(String key, bool value) async {
    await setString(key, value ? 'true' : 'false');
  }

  /// دریافت مقدار عددی عدد صحیح
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final str = await getString(key, defaultValue: defaultValue.toString());
    return int.tryParse(str) ?? defaultValue;
  }

  /// ذخیره مقدار عددی
  Future<void> setInt(String key, int value) async {
    await setString(key, value.toString());
  }

  // ---------------------------------------------------------------------------
  // خواندن همهٔ تنظیمات یکجا
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getAllSettings() async {
    return {
      'distanceUnit': await getString(keyDistanceUnit, defaultValue: 'km'),
      'weightUnit': await getString(keyWeightUnit, defaultValue: 'kg'),
      'defaultReminderTime': await getString(
        keyDefaultReminderTime,
        defaultValue: '08:00',
      ),
      'morningReminder': await getBool(keyMorningReminder, defaultValue: true),
      'preSessionReminder': await getBool(
        keyPreSessionReminder,
        defaultValue: true,
      ),
      'quietMode': await getBool(keyQuietMode, defaultValue: false),
      'keepScreenOn': await getBool(keyKeepScreenOn, defaultValue: true),
      'soundEnabled': await getBool(keySoundEnabled, defaultValue: true),
      'hapticEnabled': await getBool(keyHapticEnabled, defaultValue: true),
      'countdownSeconds': await getInt(keyCountdownSeconds, defaultValue: 3),
      'smartSuggestionsEnabled': await getBool(
        keySmartSuggestionsEnabled,
        defaultValue: true,
      ),
      'interventionLevel': await getString(
        keyInterventionLevel,
        defaultValue: 'medium',
      ),
      'planBBehavior': await getString(
        keyPlanBBehavior,
        defaultValue: 'auto_suggest',
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // حریم خصوصی و عملیات داده
  // ---------------------------------------------------------------------------

  /// دریافت خلاصه داده‌های ذخیره‌شده برای نمایش در تنظیمات
  Future<Map<String, int>> getStoredDataCounts() async {
    final dbExec = await _database;
    final counts = <String, int>{};

    final tables = [
      MovementTables.tableOccurrences,
      MovementTables.tableWorkoutLogs,
      MovementTables.tableSetLogs,
      MovementTables.tableStrengthPrograms,
      MovementTables.tableReadinessCheckins,
      MovementTables.tablePersonalRecords,
    ];

    for (final tbl in tables) {
      try {
        final res = await dbExec.rawQuery('SELECT COUNT(*) as cnt FROM $tbl');
        counts[tbl] = Sqflite.firstIntValue(res) ?? 0;
      } catch (_) {
        counts[tbl] = 0;
      }
    }

    return counts;
  }

  /// خروجی گرفتن داده‌های حرکت به صورت JSON
  Future<String> exportMovementData() async {
    final dbExec = await _database;
    final data = <String, dynamic>{};

    final tables = [
      MovementTables.tableActivityKinds,
      MovementTables.tableOccurrences,
      MovementTables.tableWorkoutLogs,
      MovementTables.tableSetLogs,
      MovementTables.tableStrengthPrograms,
      MovementTables.tableReadinessCheckins,
      MovementTables.tablePersonalRecords,
    ];

    for (final tbl in tables) {
      try {
        final rows = await dbExec.query(tbl);
        data[tbl] = rows;
      } catch (_) {}
    }

    return jsonEncode(data);
  }

  /// حذف کامل و بدون بازگشت تمام داده‌های ماژول حرکت (پاکسازی جداول movement_*)
  Future<void> deleteAllMovementData() async {
    final dbExec = await _database;
    _memoryCache.clear();

    await dbExec.transaction((txn) async {
      await txn.delete(MovementTables.tablePersonalRecords);
      await txn.delete(MovementTables.tableReadinessCheckins);
      await txn.delete(MovementTables.tableSetLogs);
      await txn.delete(MovementTables.tableStrengthExercises);
      await txn.delete(MovementTables.tableStrengthDays);
      await txn.delete(MovementTables.tableStrengthPrograms);
      await txn.delete(MovementTables.tableSessionEvents);
      await txn.delete(MovementTables.tableWorkoutLogs);
      await txn.delete(MovementTables.tableOccurrences);
      await txn.delete(MovementTables.tablePlanSchedules);
      await txn.delete(MovementTables.tablePlanTemplates);
      await txn.delete(MovementTables.tableLiveSessions);
      await txn.delete(MovementTables.tablePreferences);

      // بازنشانی فعالیت‌های سفارشی به حالت پیش‌فرض
      await txn.delete(
        MovementTables.tableActivityKinds,
        where: 'isCustom = ?',
        whereArgs: [1],
      );
    });
  }
}
