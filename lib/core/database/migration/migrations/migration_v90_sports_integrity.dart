import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV90SportsIntegrity extends Migration {
  @override
  int get version => 90;

  @override
  Future<void> up(Database db) async {
    await db.transaction((txn) async {
      await _safeAddColumn(txn, 'ss_session_prescription', 'workoutPlanId', 'TEXT');
      await _safeAddColumn(txn, 'ss_session_prescription', 'actualRpe', 'INTEGER');
      await _safeAddColumn(txn, 'ss_workout_session_log', 'prescriptionId', 'TEXT');
      await _safeAddColumn(txn, 'ss_workout_set_log', 'rir', 'INTEGER');
      await _safeAddColumn(txn, 'ss_workout_set_log', 'note', 'TEXT');

      await _safeAddColumn(txn, 'workout_logs', 'kind', 'TEXT');
      await _safeAddColumn(txn, 'workout_logs', 'sourceModule', "TEXT NOT NULL DEFAULT 'MOVEMENT'");
      await _safeAddColumn(txn, 'workout_logs', 'sourceEntityId', 'TEXT');
      await _safeAddColumn(txn, 'workout_logs', 'endedAt', 'INTEGER');
      await _safeAddColumn(txn, 'workout_logs', 'metMinutes', 'REAL NOT NULL DEFAULT 0');
      await _safeAddColumn(txn, 'workout_logs', 'caloriesKcal', 'REAL NOT NULL DEFAULT 0');
      await _safeAddColumn(txn, 'workout_logs', 'distanceMeters', 'REAL');
      await _safeAddColumn(txn, 'workout_logs', 'elevationMeters', 'REAL');
      await _safeAddColumn(txn, 'workout_logs', 'laps', 'INTEGER');
      await _safeAddColumn(txn, 'workout_logs', 'steps', 'INTEGER');
      await _safeAddColumn(txn, 'workout_logs', 'avgHeartRate', 'INTEGER');
      await _safeAddColumn(txn, 'workout_logs', 'venue', 'TEXT');
      await _safeAddColumn(txn, 'workout_logs', 'companions', 'TEXT');
      await _safeAddColumn(txn, 'workout_logs', 'metricsJson', 'TEXT');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS ss_daily_checkin (
          dateIso TEXT PRIMARY KEY,
          energy INTEGER,
          soreness INTEGER,
          fatigue INTEGER,
          painLevel INTEGER,
          availableMinutes INTEGER,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');

      await txn.execute('''
        UPDATE ss_session_prescription
        SET workoutPlanId = legacyPlanId
        WHERE (workoutPlanId IS NULL OR workoutPlanId = '')
          AND legacyPlanId IS NOT NULL
          AND legacyPlanId != '';
      ''');

      await txn.execute('''
        UPDATE workout_logs
        SET kind = type
        WHERE (kind IS NULL OR kind = '') AND type IS NOT NULL;
      ''');

      await txn.execute('''
        UPDATE workout_logs
        SET sourceEntityId = id
        WHERE sourceEntityId IS NULL OR sourceEntityId = '';
      ''');

      // Deduplicate potential existing duplicate entries before creating UNIQUE indexes
      await txn.execute('''
        DELETE FROM ss_workout_session_log
        WHERE rowid NOT IN (
          SELECT min(rowid)
          FROM ss_workout_session_log
          WHERE prescriptionId IS NOT NULL
          GROUP BY prescriptionId
        ) AND prescriptionId IS NOT NULL;
      ''');

      await txn.execute('''
        DELETE FROM workout_logs
        WHERE rowid NOT IN (
          SELECT min(rowid)
          FROM workout_logs
          WHERE sourceEntityId IS NOT NULL
          GROUP BY sourceModule, sourceEntityId
        ) AND sourceEntityId IS NOT NULL;
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_ss_prescription_plan
        ON ss_session_prescription(workoutPlanId, dateIso);
      ''');
      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_ss_session_log_prescription
        ON ss_workout_session_log(prescriptionId)
        WHERE prescriptionId IS NOT NULL;
      ''');
      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_logs_source_entity
        ON workout_logs(sourceModule, sourceEntityId)
        WHERE sourceEntityId IS NOT NULL;
      ''');
      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_ss_set_log_exercise_time
        ON ss_workout_set_log(exercise_id, id);
      ''');
    });
  }

  Future<void> _safeAddColumn(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any(
      (c) => c['name']?.toString().toLowerCase() == column.toLowerCase(),
    );
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
    }
  }

  @override
  Future<void> down(Database db) async {
    // SQLite does not reliably support DROP COLUMN on all supported versions.
    // Destructive rollback is intentionally disabled to preserve user data.
  }
}
