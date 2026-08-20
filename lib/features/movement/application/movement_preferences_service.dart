import 'dart:async';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس مدیریت ترجیحات و تنظیمات ماژول حرکت (P-02)
class MovementPreferencesService {
  MovementPreferencesService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  static const String keyWeeklyGoalSessions = 'weekly_goal_sessions';
  static const String keyPreferredDays = 'preferred_days';
  static const String keyReminderHour = 'reminder_hour';
  static const String keyMovementTier = 'movement_tier';

  final Map<String, String> _memoryCache = {};

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

  Future<void> setString(String key, String value) async {
    _memoryCache[key] = value;
    final dbExec = await _database;
    await dbExec.insert(
      MovementTables.tablePreferences,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final str = await getString(key, defaultValue: defaultValue.toString());
    return int.tryParse(str) ?? defaultValue;
  }

  Future<void> setInt(String key, int value) async {
    await setString(key, value.toString());
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final str = await getString(key, defaultValue: defaultValue ? 'true' : 'false');
    return str.toLowerCase() == 'true';
  }

  Future<void> setBool(String key, bool value) async {
    await setString(key, value ? 'true' : 'false');
  }

  // ۱. هدف هفتگی (تعداد جلسات)
  Future<int> getWeeklyGoalSessions() async {
    return getInt(keyWeeklyGoalSessions, defaultValue: 3);
  }

  Future<void> setWeeklyGoalSessions(int count) async {
    await setInt(keyWeeklyGoalSessions, count.clamp(1, 7));
  }

  // ۲. روزهای ترجیحی (شنبه=0 تا جمعه=6)
  Future<List<int>> getPreferredDays() async {
    final str = await getString(keyPreferredDays, defaultValue: '0,2,4');
    return str
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }

  Future<void> setPreferredDays(List<int> days) async {
    await setString(keyPreferredDays, days.join(','));
  }

  // ۳. ساعت یادآور روزانه (یا null اگر غیرفعال)
  Future<int?> getReminderHour() async {
    final str = await getString(keyReminderHour, defaultValue: '8');
    if (str == 'null' || str.isEmpty) return null;
    return int.tryParse(str) ?? 8;
  }

  Future<void> setReminderHour(int? hour) async {
    if (hour == null) {
      await setString(keyReminderHour, 'null');
    } else {
      await setInt(keyReminderHour, hour.clamp(0, 23));
    }
  }

  // ۴. سطح (Tier) ماژول حرکت (P-02)
  Future<MovementTier> getTier() async {
    final val = await getInt(keyMovementTier, defaultValue: 1);
    return MovementTierX.fromValue(val);
  }

  Future<void> setTier(MovementTier tier) async {
    await setInt(keyMovementTier, tier.value);
  }

  /// اعتبارسنجی سطح واقعی کاربر بر اساس جلسات ثبت‌شده
  Future<MovementTier> resolveTier() async {
    final savedTier = await getTier();
    if (savedTier == MovementTier.three) {
      return MovementTier.three;
    }
    if (savedTier == MovementTier.one) {
      return MovementTier.one;
    }

    final dbExec = await _database;
    final countResult = await dbExec.rawQuery(
      'SELECT COUNT(*) as c FROM ${MovementTables.tableWorkoutLogs}',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count < kTierTwoUnlockSessions) {
      // کاربر هنوز حداقل ۶ جلسه را ثبت نکرده است
      return MovementTier.one;
    }

    return savedTier;
  }

  /// حذف کامل و بدون بازگشت تمام داده‌های ماژول حرکت در یک تراکنش امن
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

      await txn.delete(
        MovementTables.tableActivityKinds,
        where: 'isCustom = ?',
        whereArgs: [1],
      );
    });
  }
}
