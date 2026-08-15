import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// Migration v104: Add worship_day_exceptions and ensure occurrence_overrides (Phase M2-E / P8).
class MigrationV104WorshipDayExceptions extends Migration {
  @override
  int get version => 104;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Create worship_day_exceptions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worship_day_exceptions (
        id TEXT PRIMARY KEY,
        dateStr TEXT NOT NULL,
        reason TEXT NOT NULL,
        suppressObligatory INTEGER NOT NULL DEFAULT 1,
        suppressMustahab INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_worship_day_exceptions_date
        ON worship_day_exceptions(dateStr);
    ''');

    // 2. Ensure occurrence_overrides table exists
    await db.execute('''
      CREATE TABLE IF NOT EXISTS occurrence_overrides (
        id TEXT PRIMARY KEY,
        sourceType TEXT NOT NULL,
        sourceId TEXT NOT NULL,
        dateStr TEXT NOT NULL,
        timeOfDay TEXT,
        durationMinutes INTEGER,
        status TEXT,
        note TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_occ_override_unique
        ON occurrence_overrides (sourceType, sourceId, dateStr);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_occ_override_date
        ON occurrence_overrides (dateStr);
    ''');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS worship_day_exceptions;');
  }
}
