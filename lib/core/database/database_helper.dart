import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/legacy_database_recovery.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/database/seed/seed_service.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/services/end_of_day_sweep.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {

  DatabaseHelper._init();
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _dbVersion = 97;
  static int get dbVersionForTest => _dbVersion;

  @visibleForTesting
  static set databaseInstance(Database? db) => _database = db;
  void overrideDatabaseForTesting(Database db) => _database = db;
  static Database? get rawDatabase => _database;

  static Completer<Database>? _dbInitCompleter;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    // Reset dead/closed database reference (P0-02)
    if (existing != null && !existing.isOpen) {
      _database = null;
      _dbInitCompleter = null;
    }

    final inFlight = _dbInitCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<Database>();
    _dbInitCompleter = completer;
    completer.future.ignore();

    try {
      final db = await _initDB('ritmo.db');
      _database = db;
      completer.complete(db);
      return db;
    } catch (e, st) {
      _dbInitCompleter = null;
      _database = null;
      completer.completeError(e, st);
      rethrow;
    }
  }

  /// Explicitly warms up background database tasks and seed verification (BOOT-07).
  static Future<void> warmUp(Database db) async {
    try {
      await SeedService.seedSupplementarySports(db);
      await _checkDailySweep(db);
    } catch (e, st) {
      RitmoLog.error('DatabaseHelper', 'Warmup error', e, st);
    }
  }

  static Future<void> _checkDailySweep(Database db) async {
    final todayStr = DayKey.from(DateTime.now()).value;
    try {
      final rows = await db.query('app_settings', where: "key = 'last_worship_sweep_date'");
      final lastDate = rows.isNotEmpty ? rows.first['value'] as String? : null;
      if (lastDate != todayStr) {
        await EndOfDaySweep.runSweep(db);
      }
    } catch (e, st) {
      RitmoLog.error('DatabaseHelper', 'Daily sweep error', e, st);
    }
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      return databaseFactoryFfiWeb.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: _dbVersion,
          onCreate: _createDB,
          onConfigure: _onConfigure,
          onUpgrade: onUpgrade,
          onDowngrade: _onDowngrade,
        ),
      );
    } else {
      final path = await LegacyDatabaseRecovery.getSafeDatabasePath();

      try {
        return await openDatabase(
          path,
          version: _dbVersion,
          onCreate: _createDB,
          onConfigure: _onConfigure,
          onUpgrade: onUpgrade,
          onDowngrade: _onDowngrade,
        );
      } catch (e, st) {
        final errStr = e.toString().toLowerCase();
        final isCorrupt = e is DatabaseException &&
            (errStr.contains('malformed') ||
                errStr.contains('not a database') ||
                errStr.contains('encrypted'));

        if (isCorrupt) {
          RitmoLog.error('DatabaseHelper', 'Database corruption detected ($e). Quarantining file and creating fresh database', e, st);
          final dbFile = File(path);
          if (await dbFile.exists()) {
            await LegacyDatabaseRecovery.quarantineCorruptFile(dbFile, 'open_failed_corrupt');
          }
          return await openDatabase(
            path,
            version: _dbVersion,
            onCreate: _createDB,
            onConfigure: _onConfigure,
            onUpgrade: onUpgrade,
            onDowngrade: _onDowngrade,
          );
        } else {
          RitmoLog.error('DatabaseHelper', 'Database open error non-fatal rethrow', e, st);
          rethrow;
        }
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await SchemaManager.createAll(db);
    await SeedService.seedAll(db);
  }

  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    await MigrationRunner.run(db, oldVersion, newVersion);
  }

  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    RitmoLog.warning(
      'DatabaseHelper',
      'Downgrade detected: db=$oldVersion app=$newVersion. Keeping data as-is.',
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
    await db.rawQuery('PRAGMA journal_mode=WAL;');
    await db.rawQuery('PRAGMA synchronous=NORMAL;');
  }

  Future<void> logNotificationEvent({
    required String? routineId,
    required String actionTaken,
    required String notificationType,
    DatabaseExecutor? executor,
  }) async {
    try {
      final exec = executor ?? await database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await exec.insert(
        'notification_history',
        {
          'id': 'notif_${nowMs}_${routineId ?? "sys"}',
          'routineId': routineId,
          'notificationType': notificationType,
          'sentAt': nowMs,
          'actionTaken': actionTaken,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      RitmoLog.error('DatabaseHelper', 'Failed to log notification event', e, st);
    }
  }

  /// Creates (or refreshes) a fasting-debt record for the period active on
  /// [dateStr] — but ONLY for days overlapping Ramadan, since qada is owed
  /// exclusively for missed Ramadan fasts. Uses the same `fd_<periodId>` id
  /// scheme as CycleScreen._savePeriod so both write paths stay consistent,
  /// and preserves an existing `isResolved` flag across idempotent rewrites
  /// (this runs daily from the intelligence engine while menstruating).
  Future<void> addFastingDebtIfNeeded(DatabaseExecutor db, String dateStr) async {
    try {
      final consentQuery = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['cycle_consent_worship'],
      );
      if (consentQuery.isEmpty || consentQuery.first['value'].toString().toLowerCase() != 'true') {
        return;
      }

      final activePeriods = await db.query(
        'cycle_periods',
        where: 'startDate <= ? AND (endDate IS NULL OR endDate >= ?)',
        whereArgs: [dateStr, dateStr],
        orderBy: 'startDate DESC',
      );
      if (activePeriods.isEmpty) {
        return;
      }

      final activePeriod = activePeriods.first;
      final periodId = activePeriod['id']?.toString() ?? 'period';
      final rawStart = activePeriod['startDate'] as String?;
      final rawEnd = activePeriod['endDate'] as String?;

      final startDateClean = (rawStart != null && rawStart.length >= 10) ? rawStart.substring(0, 10) : dateStr;
      final endDateClean = (rawEnd != null && rawEnd.length >= 10) ? rawEnd.substring(0, 10) : dateStr;

      final debtId = 'fd_$periodId';

      // Qada is owed only for Ramadan days — compute the overlap between the
      // period and the recorded Ramadan season (same rule as CycleScreen).
      final seasons = await db.query(
        'worship_seasons',
        where: "id = 'ws_ramadan'",
        limit: 1,
      );
      if (seasons.isEmpty) {
        await db.delete('fasting_debt', where: 'id = ?', whereArgs: [debtId]);
        return;
      }
      final rStart = DateTime.tryParse(seasons.first['startDate']?.toString() ?? '');
      final rEnd = DateTime.tryParse(seasons.first['endDate']?.toString() ?? '');
      if (rStart == null || rEnd == null) {
        await db.delete('fasting_debt', where: 'id = ?', whereArgs: [debtId]);
        return;
      }

      final pStart = DateTime.parse(startDateClean);
      final pEnd = DateTime.parse(endDateClean);
      final latestStart = pStart.isAfter(rStart) ? pStart : rStart;
      final earliestEnd = pEnd.isBefore(rEnd) ? pEnd : rEnd;
      final overlapDays = earliestEnd.difference(latestStart).inDays + 1;

      if (overlapDays <= 0) {
        // No Ramadan overlap -> no qada debt for this period.
        await db.delete('fasting_debt', where: 'id = ?', whereArgs: [debtId]);
        return;
      }

      // Preserve resolution state across rewrites.
      var isResolved = 0;
      final existing = await db.query('fasting_debt', where: 'id = ?', whereArgs: [debtId], limit: 1);
      if (existing.isNotEmpty) {
        isResolved = existing.first['isResolved'] as int? ?? 0;
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.insert(
        'fasting_debt',
        {
          'id': debtId,
          'dateIso': startDateClean,
          'daysOwed': overlapDays,
          'isResolved': isResolved,
          'reason': 'عذر شرعی (دوره ماهانه)',
          'createdAt': nowMs,
          'updatedAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      RitmoLog.error('DatabaseHelper', 'addFastingDebtIfNeeded error', e, st);
    }
  }

  /// Fetches user gender ('FEMALE', 'MALE', or null if unknown) from app_settings, ss_user_profile, or SharedPreferences.
  Future<String?> getUserGender({DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    try {
      final genderQuery = await exec.query('app_settings', where: 'key = ?', whereArgs: ['user_gender']);
      if (genderQuery.isNotEmpty && genderQuery.first['value'] != null) {
        final val = genderQuery.first['value'].toString().toUpperCase();
        if (val == 'FEMALE' || val == 'WOMAN' || val == 'ZAN' || val == 'زن') return 'FEMALE';
        if (val == 'MALE' || val == 'MAN' || val == 'MARD' || val == 'مرد') return 'MALE';
      }

      final ssProfileRows = await exec.query('ss_user_profile', limit: 1);
      if (ssProfileRows.isNotEmpty && ssProfileRows.first['gender'] != null) {
        final val = ssProfileRows.first['gender'].toString().toUpperCase();
        if (val == 'FEMALE' || val == 'WOMAN' || val == 'ZAN' || val == 'زن') return 'FEMALE';
        if (val == 'MALE' || val == 'MAN' || val == 'MARD' || val == 'مرد') return 'MALE';
      }

      final prefs = await SharedPreferences.getInstance();
      final spGender = prefs.getString('ss_onboarding_gender') ?? prefs.getString('user_gender');
      if (spGender != null && spGender.isNotEmpty) {
        final val = spGender.toUpperCase();
        if (val == 'FEMALE' || val == 'WOMAN' || val == 'ZAN' || val == 'زن') return 'FEMALE';
        if (val == 'MALE' || val == 'MAN' || val == 'MARD' || val == 'مرد') return 'MALE';
      }
    } catch (e, st) {
      RitmoLog.error('DatabaseHelper', 'Error getting user gender', e, st);
    }
    return null;
  }

  Future<bool> isUserMenstruating({DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;

    final gender = await getUserGender(executor: exec);
    if (gender != 'FEMALE') {
      return false;
    }

    final cycleEnabledQuery = await exec.query('app_settings', where: 'key = ?', whereArgs: ['module_cycle_enabled']);
    if (cycleEnabledQuery.isEmpty || cycleEnabledQuery.first['value'].toString().toLowerCase() != 'true') {
      return false;
    }

    final todayStr = DayKey.from(DateTime.now()).value;
    final activePeriods = await exec.query(
      'cycle_periods',
      where: 'startDate <= ? AND (endDate IS NULL OR endDate >= ?)',
      whereArgs: [todayStr, todayStr],
    );

    return activePeriods.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getCycleLogs({DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    return exec.query('cycle_logs', orderBy: 'cycleStartDate DESC');
  }

  Future<void> deleteNotificationHistory({DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    await exec.delete('notification_history');
  }

  Future<List<Map<String, dynamic>>> getCustomCategories({DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    return exec.query('custom_categories', where: 'isArchived = 0', orderBy: 'sortOrder ASC');
  }

  Future<void> insertCustomCategory(Map<String, dynamic> category, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    await exec.insert('custom_categories', category, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnlockedMilestones({DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    return exec.query('milestones_unlocked');
  }

  Future<void> unlockMilestone(String milestoneId, int unlockedAt, {DatabaseExecutor? executor}) async {
    final exec = executor ?? await database;
    await exec.insert(
      'milestones_unlocked',
      {
        'id': milestoneId,
        'unlockedAt': unlockedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    _dbInitCompleter = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
