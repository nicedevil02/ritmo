import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/database/legacy_database_recovery.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/database/seed/mock_data_seeder.dart';
import 'package:ritmo/core/database/seed/seed_service.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session_writer.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/services/end_of_day_sweep.dart';
import 'package:ritmo/features/worship/logic/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {

  DatabaseHelper._init();
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const int _dbVersion = 132;
  static int get dbVersionForTest => _dbVersion;

  /// Optional decoupled warmup hooks registered by application features.
  static final List<Future<void> Function()> warmupHooks = [];

  /// Hijri month number of Ramadan - the only month qada fasting is owed for.
  static const int _ramadanHijriMonth = 9;

  @visibleForTesting
  static set databaseInstance(Database? db) {
    _database = db;
    _dbInitCompleter = null;
  }
  void overrideDatabaseForTesting(Database db) {
    _database = db;
    _dbInitCompleter = null;
  }
  static Database? get rawDatabase => _database;

  static Completer<Database>? _dbInitCompleter;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final completer = _dbInitCompleter;
    if (completer != null) return completer.future;

    final newCompleter = Completer<Database>();
    newCompleter.future.ignore();
    _dbInitCompleter = newCompleter;

    try {
      final db = await _initDB('ritmo.db');
      _database = db;
      newCompleter.complete(db);
      return db;
    } catch (e, st) {
      newCompleter.completeError(e, st);
      rethrow;
    } finally {
      _dbInitCompleter = null;
    }
  }

  /// Explicitly warms up background database tasks and seed verification (BOOT-07).
  static Future<void> warmUp(Database db) async {
    try {
      await SchemaManager.ensureAllSchemas(db);
      await SchemaManager.safeAddColumn(db, 'worship_practices', 'showInCalendar', 'INTEGER DEFAULT 0');
      try {
        await db.execute("UPDATE routines SET energyRule = 'NONE' WHERE energyRule = 'none';");
      } catch (_) {}
      await SeedService.seedSupplementarySports(db);
      await MockDataSeeder.purgeIfLegacyMock(db);
      await _checkDailySweep(db);
      try {
        await AiMemoryService.instance.backfillSensitiveFlags();
      } catch (e) {
        RitmoLog.warning('DatabaseHelper', 'backfillSensitiveFlags non-fatal error: $e');
      }
      try {
        await ZoneSessionWriter().recoverAbandonedSessions(executor: db);
      } catch (e) {
        RitmoLog.warning('DatabaseHelper', 'recoverAbandonedSessions non-fatal error: $e');
      }
      for (final hook in warmupHooks) {
        try {
          unawaited(hook());
        } catch (_) {}
      }
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

      int attempts = 0;
      while (true) {
        attempts++;
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
          final isLocked = e is DatabaseException &&
              (errStr.contains('database is locked') ||
                  errStr.contains('sqlite_busy') ||
                  (errStr.contains('code 5') && errStr.contains('busy')));
          if (isLocked && attempts < 5) {
            RitmoLog.warning('DatabaseHelper', 'Database locked on open attempt $attempts (SQLITE_BUSY). Retrying in ${attempts * 400}ms...');
            await Future.delayed(Duration(milliseconds: attempts * 400));
            continue;
          }

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
  }

  Future<void> _createDB(Database db, int version) async {
    await SchemaManager.createAll(db);

    // A brand-new database goes straight to [version] through onCreate, so
    // onUpgrade (and therefore the migration chain) never runs for it. Anything
    // that lives only inside a migration - the `day_marks` table and the default
    // calendar settings from v83, later added columns, seeded settings rows -
    // used to be present on every upgraded install but missing on a fresh one,
    // surfacing as `no such table` / `no such column` errors at runtime.
    // Replaying the chain best-effort here makes a new database equivalent to a
    // migrated one; seeds then land in the completed schema.
    await MigrationRunner.runForFreshInstall(db, version);

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
    try {
      await db.rawQuery('PRAGMA cache_size = -2000;'); // Bound SQLite cache to ~2MB
      await db.rawQuery('PRAGMA temp_store = MEMORY;');
      await db.rawQuery('PRAGMA wal_autocheckpoint = 100;');
      await db.rawQuery('PRAGMA busy_timeout = 10000;');
    } catch (_) {}
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

  /// Reads the user-configured Hijri offset (`hijri_offset`) so qada days are
  /// counted against exactly the same Ramadan the worship screens display.
  Future<int> _hijriOffsetDays(DatabaseExecutor db) async {
    try {
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['hijri_offset'],
        limit: 1,
      );
      if (rows.isEmpty) return 0;
      return int.tryParse(rows.first['value']?.toString() ?? '') ?? 0;
    } catch (e) {
      RitmoLog.warning('DatabaseHelper', 'hijri_offset read failed, assuming 0: $e');
      return 0;
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

      // Qada is owed only for Ramadan days. This used to read the `ws_ramadan`
      // row of `worship_seasons`, but the worship-seasons feature was removed
      // from the product and that table is now always empty - so this method
      // took the "no season" branch on every single run, deleted the debt and
      // returned. Menstruating during Ramadan therefore recorded no qada at
      // all, silently. Ramadan is now derived from the Hijri calendar itself,
      // honouring the user's own `hijri_offset`.
      final offsetDays = await _hijriOffsetDays(db);
      final pStart = DateTime.parse(startDateClean);
      final pEnd = DateTime.parse(endDateClean);

      // Counting day-by-day (instead of intersecting two ranges) also stays
      // correct when a period straddles the first or last day of Ramadan.
      // The cap only guards against a corrupt endDate producing a runaway loop.
      const maxPeriodDays = 60;
      var overlapDays = 0;
      for (var i = 0; i < maxPeriodDays; i++) {
        final day = DateTime(pStart.year, pStart.month, pStart.day + i);
        if (day.isAfter(pEnd)) break;
        final hijri = HijriCalendarCalculator.hijriFromGregorian(day, offsetDays: offsetDays);
        if (hijri.month == _ramadanHijriMonth) {
          overlapDays++;
        }
      }

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
    try {
      final rows = await exec.query('cycle_periods', orderBy: 'startDate DESC');
      return rows.map((r) {
        return {
          ...r,
          'cycleStartDate': r['startDate'],
          'cycleEndDate': r['endDate'],
        };
      }).toList();
    } catch (_) {
      return [];
    }
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
