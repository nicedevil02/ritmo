import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV91SchemaCanonicalization extends Migration {
  @override
  int get version => 91;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Create missing tables exactly as they appear in their source migrations
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS station_bundles (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          category TEXT NOT NULL,
          itemsJson TEXT NOT NULL,
          isUserTemplate INTEGER NOT NULL DEFAULT 0,
          usageCount INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ss_plan_schedule (
          id TEXT PRIMARY KEY,
          planId TEXT NOT NULL,
          scheduledDate TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'PENDING',
          sessionId TEXT,
          shiftedFromDate TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY(planId) REFERENCES ss_workout_plan(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ss_exercise_pr (
          id TEXT PRIMARY KEY,
          exerciseId TEXT NOT NULL,
          prType TEXT NOT NULL,
          value REAL NOT NULL,
          sessionId TEXT,
          achievedAt INTEGER NOT NULL,
          UNIQUE(exerciseId, prType)
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ss_session_set_log (
          id TEXT PRIMARY KEY,
          sessionId TEXT NOT NULL,
          exerciseId TEXT NOT NULL,
          setNumber INTEGER NOT NULL,
          weight REAL,
          reps INTEGER,
          rir INTEGER,
          durationSeconds INTEGER,
          isCompleted INTEGER NOT NULL DEFAULT 1,
          loggedAt INTEGER NOT NULL,
          FOREIGN KEY(sessionId) REFERENCES ss_workout_session_log(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS movement_budget (
          id TEXT PRIMARY KEY DEFAULT 'default',
          weeklyMetMinutesTarget REAL NOT NULL DEFAULT 500,
          weeklyActiveDaysTarget INTEGER NOT NULL DEFAULT 4,
          isAutoAdjusted INTEGER NOT NULL DEFAULT 1,
          updatedAt INTEGER NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS movement_pr (
          id TEXT PRIMARY KEY,
          kind TEXT NOT NULL,
          prType TEXT NOT NULL,
          value REAL NOT NULL,
          logId TEXT,
          achievedAt INTEGER NOT NULL,
          UNIQUE(kind, prType)
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS wellbeing_daily (
          date TEXT PRIMARY KEY,
          indexValue REAL,
          confidence REAL NOT NULL DEFAULT 0,
          sleepScore REAL,
          energyScore REAL,
          moodScore REAL,
          reflectionScore REAL,
          contributionsJson TEXT,
          computedAt INTEGER NOT NULL
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_steps (
          id TEXT PRIMARY KEY,
          taskId TEXT NOT NULL,
          title TEXT NOT NULL,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          displayOrder INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          completedAt INTEGER
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_task_steps_task ON task_steps(taskId, displayOrder);',
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_attachments (
          id TEXT PRIMARY KEY,
          taskId TEXT NOT NULL,
          fileName TEXT NOT NULL,
          fileSizeBytes INTEGER NOT NULL DEFAULT 0,
          mimeType TEXT,
          localPath TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_task_attachments_task ON task_attachments(taskId);',
      );
    } catch (e) {
      debugPrint('[MigrationV91] Error creating missing tables: $e');
    }

    // 2. Add safe columns
    try {
      await safeAddColumn(db, 'ss_workout_plan', 'week', 'INTEGER NOT NULL DEFAULT 1');
      await safeAddColumn(db, 'ss_workout_plan', 'executionMode', "TEXT NOT NULL DEFAULT 'LINEAR'");
      await safeAddColumn(db, 'simple_tasks', 'isImportant', 'INTEGER NOT NULL DEFAULT 0');
      await safeAddColumn(db, 'simple_tasks', 'importantAt', 'INTEGER');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_simple_tasks_important ON simple_tasks(isImportant);',
      );
    } catch (e) {
      debugPrint('[MigrationV91] Error adding columns: $e');
    }

    // 3. V70 Indexes (A-3 cleanup)
    try {
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_routine_completions_date ON routine_completions(completionDate);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_routine_occurrences_date ON routine_occurrences(date);');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_energy_logs_logged_at ON energy_logs(loggedAt);');
    } catch (e) {
      debugPrint('[MigrationV91] Error creating V70 indexes: $e');
    }

    // 4. A-5 Fix V60 duplicate unique index issue
    try {
      await db.execute('DROP INDEX IF EXISTS idx_uniq_routine_completions_routine_date_result');
      
      // Delete exact duplicates before unique index (keeping the latest)
      await db.execute('''
        DELETE FROM routine_completions
        WHERE rowid NOT IN (
          SELECT MAX(rowid)
          FROM routine_completions
          GROUP BY routineId, completionDate, completionTime, resultType
        )
      ''');

      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_uniq_routine_completions_routine_date_time_result ON routine_completions(routineId, completionDate, completionTime, resultType);'
      );
    } catch (e) {
      debugPrint('[MigrationV91] Error fixing V60 unique index: $e');
    }

    // 5. A-6 Rebuild skip_reasons with V56 NOT NULL constraints
    try {
      await db.execute('''
        CREATE TABLE skip_reasons_temp (
          id TEXT PRIMARY KEY,
          itemId TEXT NOT NULL,
          domain TEXT NOT NULL,
          dateStr TEXT NOT NULL,
          reason TEXT NOT NULL,
          note TEXT,
          createdAt INTEGER NOT NULL
        );
      ''');
      await db.execute('''
        INSERT INTO skip_reasons_temp (id, itemId, domain, dateStr, reason, note, createdAt)
        SELECT 
          id, 
          COALESCE(itemId, 'unknown_item'), 
          COALESCE(domain, 'UNKNOWN'), 
          COALESCE(dateStr, '1970-01-01'), 
          COALESCE(reason, 'OTHER'), 
          note, 
          COALESCE(createdAt, strftime('%s','now') * 1000)
        FROM skip_reasons;
      ''');
      await db.execute('DROP TABLE skip_reasons;');
      await db.execute('ALTER TABLE skip_reasons_temp RENAME TO skip_reasons;');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_skip_reasons_item ON skip_reasons(itemId, dateStr);');
    } catch (e) {
      debugPrint('[MigrationV91] Error rebuilding skip_reasons: $e');
    }

    // 6. A-7 Migrate camelCase to snake_case in daily_reflections
    try {
      await db.execute('''
        UPDATE daily_reflections
        SET reflection_text = reflectionNote
        WHERE (reflection_text IS NULL OR reflection_text = '') AND reflectionNote IS NOT NULL AND reflectionNote != '';
      ''');
      await db.execute('''
        UPDATE daily_reflections
        SET wins = goodThing
        WHERE (wins IS NULL OR wins = '') AND goodThing IS NOT NULL AND goodThing != '';
      ''');
      await db.execute('''
        UPDATE daily_reflections
        SET createdAt = timestamp
        WHERE (createdAt IS NULL OR createdAt = 0) AND timestamp IS NOT NULL AND timestamp > 0;
      ''');
    } catch (e) {
      debugPrint('[MigrationV91] Error migrating daily_reflections data: $e');
    }
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
