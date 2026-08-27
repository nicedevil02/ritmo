import 'package:sqflite/sqflite.dart';

class ZoneTables {
  static Future<void> create(DatabaseExecutor db) async {
    // 5. zones table
    await db.execute('''
      CREATE TABLE zones (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color TEXT,
          icon TEXT,
          mode TEXT NOT NULL DEFAULT 'NORMAL',
          isDefault INTEGER NOT NULL DEFAULT 0,
          hideOtherRealms INTEGER NOT NULL DEFAULT 0,
          ritualOnEnter TEXT,
          ritualOnExit TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
      );
    ''');

    // 6. zone_schedules table
    await db.execute('''
      CREATE TABLE zone_schedules (
          id TEXT PRIMARY KEY,
          zoneId TEXT NOT NULL,
          daysOfWeek TEXT NOT NULL,
          startTime TEXT NOT NULL,
          endTime TEXT NOT NULL,
          profileId TEXT,
          isEnabled INTEGER NOT NULL DEFAULT 1,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX index_zone_schedules_zoneId ON zone_schedules(zoneId);');

    // 7. routine_zone_rules table
    await db.execute('''
      CREATE TABLE routine_zone_rules (
          routineId TEXT NOT NULL,
          zoneId TEXT NOT NULL,
          ruleType TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          PRIMARY KEY (routineId, zoneId),
          FOREIGN KEY(routineId) REFERENCES routines(id) ON DELETE CASCADE,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX index_routine_zone_rules_zoneId ON routine_zone_rules(zoneId);');

    // 8. zone_sessions table (F-01, F-02)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_sessions (
          id           TEXT PRIMARY KEY,
          zoneId       TEXT NOT NULL,
          startedAt    INTEGER NOT NULL,
          endedAt      INTEGER,
          plannedEndAt INTEGER,
          source       TEXT NOT NULL DEFAULT 'SCHEDULE',
          endReason    TEXT,
          createdAt    INTEGER NOT NULL,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zone_sessions_started ON zone_sessions(startedAt);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zone_sessions_zone ON zone_sessions(zoneId, startedAt);');

    // 9. zone_triggers table (F-08)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_triggers (
          id         TEXT PRIMARY KEY,
          zoneId     TEXT NOT NULL,
          kind       TEXT NOT NULL,
          value      TEXT NOT NULL,
          priority   INTEGER NOT NULL DEFAULT 0,
          isEnabled  INTEGER NOT NULL DEFAULT 1,
          createdAt  INTEGER NOT NULL,
          updatedAt  INTEGER NOT NULL,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zone_triggers_kind ON zone_triggers(kind, isEnabled);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zone_triggers_zone ON zone_triggers(zoneId);');

    // 10. zone_budgets table (F-12)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_budgets (
          zoneId              TEXT PRIMARY KEY,
          weeklyTargetMinutes INTEGER NOT NULL,
          createdAt           INTEGER NOT NULL,
          updatedAt           INTEGER NOT NULL,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');

    // 11. zone_profiles table (F-13)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_profiles (
          id        TEXT PRIMARY KEY,
          name      TEXT NOT NULL,
          isActive  INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
      );
    ''');
  }

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info(zones)');
      final columnNames = columns.map((c) => c['name']?.toString().toLowerCase()).toSet();
      if (!columnNames.contains('hideotherrealms')) {
        await db.execute('ALTER TABLE zones ADD COLUMN hideOtherRealms INTEGER NOT NULL DEFAULT 0;');
      }
      if (!columnNames.contains('ritualonenter')) {
        await db.execute('ALTER TABLE zones ADD COLUMN ritualOnEnter TEXT;');
      }
      if (!columnNames.contains('ritualonexit')) {
        await db.execute('ALTER TABLE zones ADD COLUMN ritualOnExit TEXT;');
      }

      final sessionCols = await db.rawQuery('PRAGMA table_info(zone_sessions)');
      final sessionColNames = sessionCols.map((c) => c['name']?.toString().toLowerCase()).toSet();
      if (!sessionColNames.contains('endreason')) {
        await db.execute('ALTER TABLE zone_sessions ADD COLUMN endReason TEXT;');
      }
    } catch (_) {}
  }
}
