import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// V130: لایه‌ی تاریخچه قلمرو — جدول zone_sessions و ایندکس‌های نشست (F-01, F-02)
class MigrationV130ZoneSessions extends Migration {
  @override
  int get version => 130;

  @override
  Future<void> up(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV130', 'Creating zone_sessions table and indexes...');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_sessions (
          id            TEXT PRIMARY KEY,
          zoneId        TEXT NOT NULL,
          startedAt     INTEGER NOT NULL,
          endedAt       INTEGER,
          plannedEndAt  INTEGER,
          source        TEXT NOT NULL DEFAULT 'SCHEDULE',
          endReason     TEXT,
          createdAt     INTEGER NOT NULL,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_zone_sessions_started ON zone_sessions(startedAt);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_zone_sessions_zone ON zone_sessions(zoneId, startedAt);');

    // Partial unique index ensuring at most one open session at any time (F-02)
    // Note: Indexing (1) ensures NULL values collide on the constant expression
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_zone_sessions_single_open
        ON zone_sessions((1)) WHERE endedAt IS NULL;
    ''');

    RitmoLog.info('MigrationV130', 'zone_sessions table created successfully');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP INDEX IF EXISTS idx_zone_sessions_single_open;');
    await db.execute('DROP INDEX IF EXISTS idx_zone_sessions_zone;');
    await db.execute('DROP INDEX IF EXISTS idx_zone_sessions_started;');
    await db.execute('DROP TABLE IF EXISTS zone_sessions;');
  }
}
