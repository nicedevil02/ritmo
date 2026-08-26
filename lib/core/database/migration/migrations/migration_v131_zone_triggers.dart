import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Migration V131: Creates `zone_triggers` table and indexes (F-08).
class MigrationV131ZoneTriggers extends Migration {
  @override
  int get version => 131;

  @override
  Future<void> up(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV131', 'Creating zone_triggers table and indexes...');

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

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_zone_triggers_kind 
        ON zone_triggers(kind, isEnabled);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_zone_triggers_zone 
        ON zone_triggers(zoneId);
    ''');

    RitmoLog.info('MigrationV131', 'zone_triggers table and indexes created successfully');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV131', 'Rolling back Migration V131...');
    await db.execute('DROP INDEX IF EXISTS idx_zone_triggers_zone;');
    await db.execute('DROP INDEX IF EXISTS idx_zone_triggers_kind;');
    await db.execute('DROP TABLE IF EXISTS zone_triggers;');
  }
}
