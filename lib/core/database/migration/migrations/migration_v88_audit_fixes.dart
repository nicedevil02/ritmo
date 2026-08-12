import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Migration V88: Re-creates worship_seasons, zones, zone_schedules, routine_zone_rules,
/// workout_split_days, ss_ai_memory, ss_workout_set_log tables, cleans orphaned foreign keys,
/// backfills user gender from ss_user_profile to app_settings, and adds fasting_debt index.
class MigrationV88AuditFixes extends Migration {
  @override
  bool get requiresTransaction => false;
  @override
  int get version => 88;

  @override
  Future<void> up(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV88', 'Applying V88 database audit fixes...');

    // 1. Re-create worship_seasons table if missing (DB-04 / DB-10)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worship_seasons (
          id TEXT PRIMARY KEY,
          seasonType TEXT NOT NULL,
          title TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT NOT NULL,
          calendar TEXT NOT NULL DEFAULT 'HIJRI',
          behaviorJson TEXT,
          isActive INTEGER NOT NULL DEFAULT 1,
          createdAt INTEGER NOT NULL,
          priority_weight REAL NOT NULL DEFAULT 1.0,
          start_date TEXT,
          end_date TEXT,
          type TEXT DEFAULT 'custom',
          is_active INTEGER DEFAULT 1,
          recurrence TEXT,
          dayList TEXT,
          hijriMonth INTEGER
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_worship_seasons_startDate ON worship_seasons(startDate);');

    // 2. Re-create zones, zone_schedules, and routine_zone_rules if missing (DB-10 parity)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zones (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color TEXT,
          icon TEXT,
          mode TEXT NOT NULL DEFAULT 'NORMAL',
          isDefault INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_schedules (
          id TEXT PRIMARY KEY,
          zoneId TEXT NOT NULL,
          daysOfWeek TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_zone_schedules_zoneId ON zone_schedules(zoneId);');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS routine_zone_rules (
          routineId TEXT NOT NULL,
          zoneId TEXT NOT NULL,
          ruleType TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          PRIMARY KEY (routineId, zoneId),
          FOREIGN KEY(routineId) REFERENCES routines(id) ON DELETE CASCADE,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_routine_zone_rules_zoneId ON routine_zone_rules(zoneId);');

    // 3. Re-create workout_split_days, ss_ai_memory, ss_workout_set_log if missing (DB-10 parity)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_split_days (
        weekday INTEGER PRIMARY KEY,
        muscleGroups TEXT NOT NULL DEFAULT '',
        isRest INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_ai_memory (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        confidence REAL DEFAULT 1.0,
        updatedAt INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_workout_set_log (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        set_index INTEGER NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        rpe REAL
      );
    ''');
    await safeAddColumn(db, 'worship_debts', 'userDisabledAt', 'INTEGER');
    await safeAddColumn(db, 'assistant_audit_log', 'assistant_id', 'TEXT');
    await safeAddColumn(db, 'ss_workout_set_log', 'feeling', 'TEXT');
    await safeAddColumn(db, 'day_plan_templates', 'title', 'TEXT');
    await safeAddColumn(db, 'day_plan_templates', 'plan_json', 'TEXT');

    // 4. Orphan rows cleanup prior to strict PRAGMA foreign_keys = ON (DB-01)
    try {
      await db.execute('''
        DELETE FROM task_steps WHERE taskId NOT IN (SELECT id FROM tasks UNION SELECT id FROM simple_tasks);
      ''');
    } catch (_) {}

    try {
      await db.execute('''
        DELETE FROM task_attachments WHERE taskId NOT IN (SELECT id FROM tasks UNION SELECT id FROM simple_tasks);
      ''');
    } catch (_) {}

    try {
      await db.execute('''
        DELETE FROM routine_occurrences WHERE routineId NOT IN (SELECT id FROM routines);
      ''');
    } catch (_) {}

    try {
      await db.execute('''
        DELETE FROM workout_exercise_logs WHERE sessionLogId NOT IN (SELECT id FROM ss_workout_session_log);
      ''');
    } catch (_) {}

    // 5. Gender backfill from ss_user_profile to app_settings (DB-06)
    try {
      final genderRows = await db.query(
        'app_settings',
        where: "key = 'user_gender' AND (value IS NULL OR value = '' OR value = 'UNSET' OR value = 'UNKNOWN')",
      );
      if (genderRows.isNotEmpty) {
        final profileRows = await db.query('ss_user_profile', limit: 1);
        if (profileRows.isNotEmpty && profileRows.first['gender'] != null) {
          final profileGender = profileRows.first['gender'].toString().toUpperCase();
          final cleanGender = (profileGender == 'FEMALE' || profileGender == 'ZAN' || profileGender == 'زن')
              ? 'FEMALE'
              : 'MALE';

          await db.insert(
            'app_settings',
            {
              'key': 'user_gender',
              'value': cleanGender,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          RitmoLog.info('MigrationV88', 'Backfilled app_settings.user_gender to $cleanGender from ss_user_profile');
        }
      }
    } catch (e) {
      RitmoLog.warning('MigrationV88', 'Gender backfill non-fatal error: $e');
    }

    // 6. Ensure index on fasting_debt (DB-05)
    try {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_fasting_debt_period ON fasting_debt(id);');
    } catch (_) {}

    RitmoLog.info('MigrationV88', 'V88 migration applied successfully.');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    // Non-destructive down migration
  }
}
