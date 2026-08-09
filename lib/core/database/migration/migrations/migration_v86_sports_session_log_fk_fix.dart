import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV86SportsSessionLogFkFix extends Migration {
  @override
  int get version => 86;

  @override
  Future<void> up(Database db) async {
    try {
      await db.execute('PRAGMA foreign_keys = OFF;');

      // 1. Create new table without foreign key constraint on planId
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ss_workout_session_log_temp (
          id TEXT PRIMARY KEY,
          planId TEXT,
          startedAt INTEGER NOT NULL,
          finishedAt INTEGER,
          durationSeconds INTEGER DEFAULT 0,
          completedExercisesCount INTEGER DEFAULT 0,
          totalExercisesCount INTEGER DEFAULT 0,
          overallFeeling TEXT,
          note TEXT
        );
      ''');

      // 2. Copy existing data if ss_workout_session_log exists
      try {
        await db.execute('''
          INSERT OR IGNORE INTO ss_workout_session_log_temp (
            id, planId, startedAt, finishedAt, durationSeconds, completedExercisesCount, totalExercisesCount, overallFeeling, note
          )
          SELECT id, planId, startedAt, finishedAt, durationSeconds, completedExercisesCount, totalExercisesCount, overallFeeling, note
          FROM ss_workout_session_log;
        ''');
      } catch (_) {}

      // 3. Drop old table and rename new table
      await db.execute('DROP TABLE IF EXISTS ss_workout_session_log;');
      await db.execute('ALTER TABLE ss_workout_session_log_temp RENAME TO ss_workout_session_log;');

      // 4. Recreate index
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ss_session_log_date '
        'ON ss_workout_session_log(startedAt);',
      );
    } catch (_) {
    } finally {
      await db.execute('PRAGMA foreign_keys = ON;');
    }
  }

  @override
  Future<void> down(Database db) async {}
}
