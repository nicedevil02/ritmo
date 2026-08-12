import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV95 extends Migration {
  @override
  bool get requiresTransaction => false;

  @override
  int get version => 95;

  Future<bool> _columnExists(DatabaseExecutor db, String table, String column) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return info.any((row) => row['name'] == column);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Create movement_sessions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_sessions (
        id            TEXT PRIMARY KEY,
        kindCode      TEXT NOT NULL,
        routineId     TEXT,
        occurrenceId  TEXT,
        prescriptionId TEXT,
        sessionMode   TEXT NOT NULL,
        status        TEXT NOT NULL,
        startedAt     INTEGER NOT NULL,
        endedAt       INTEGER,
        pausedMs      INTEGER NOT NULL DEFAULT 0,
        targetJson    TEXT,
        liveJson      TEXT,
        workoutLogId  TEXT,
        createdAt     INTEGER NOT NULL,
        updatedAt     INTEGER NOT NULL
      );
    ''');

    // 2. Partial unique index for active/paused sessions
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_movement_sessions_active
        ON movement_sessions(status) WHERE status IN ('ACTIVE', 'PAUSED');
    ''');

    // 3. Create movement_session_events table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_session_events (
        id        TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        type      TEXT NOT NULL,
        at        INTEGER NOT NULL,
        dataJson  TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mse_session
        ON movement_session_events(sessionId, at);
    ''');

    // 4. Safely add columns to workout_logs
    if (!await _columnExists(db, 'workout_logs', 'updatedAt')) {
      await db.execute('ALTER TABLE workout_logs ADD COLUMN updatedAt INTEGER;');
    }
    if (!await _columnExists(db, 'workout_logs', 'deletedAt')) {
      await db.execute('ALTER TABLE workout_logs ADD COLUMN deletedAt INTEGER;');
    }
    // 5. Add sessionModeOverride TEXT to movement_kinds
    if (!await _columnExists(db, 'movement_kinds', 'sessionModeOverride')) {
      await db.execute('ALTER TABLE movement_kinds ADD COLUMN sessionModeOverride TEXT;');
    }

    // 6. Create movement_campaigns table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_campaigns (
        id           TEXT PRIMARY KEY,
        titleFa      TEXT NOT NULL,
        goalCode     TEXT NOT NULL,
        startDate    TEXT NOT NULL,
        weeks        INTEGER NOT NULL,
        status       TEXT NOT NULL,
        routineIds   TEXT NOT NULL,
        progressJson TEXT,
        createdAt    INTEGER NOT NULL,
        updatedAt    INTEGER NOT NULL
      );
    ''');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS movement_campaigns;');
    await db.execute('DROP TABLE IF EXISTS movement_session_events;');
    await db.execute('DROP TABLE IF EXISTS movement_sessions;');
  }
}
