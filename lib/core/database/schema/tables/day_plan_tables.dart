import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class DayPlanTables {
  static Future<void> create(DatabaseExecutor db) async {
    await ensureSchema(db);
  }

  /// Self-healing schema check for `day_plan_commits` and `day_plan_templates`.
  /// Ensures all required columns and indexes exist safely without crashing migrations.
  static Future<void> ensureSchema(DatabaseExecutor db) async {
    try {
      // 1. Create day_plan_commits table with full schema if it does not exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS day_plan_commits (
          id TEXT PRIMARY KEY,
          date_iso TEXT NOT NULL,
          dateIso TEXT,
          plan_json TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          updatedAt INTEGER NOT NULL DEFAULT 0,
          groupId TEXT
        );
      ''');

      // Add missing columns to existing day_plan_commits if table existed from an older version
      final pragmaCommits = await db.rawQuery("PRAGMA table_info('day_plan_commits');");
      final rawCommitCols = pragmaCommits.map((r) => r['name'] as String).toSet();
      final lowerCommitCols = rawCommitCols.map((n) => n.toLowerCase()).toSet();

      final commitAdditions = <String, String>{
        'date_iso': "TEXT NOT NULL DEFAULT ''",
        'dateIso': "TEXT",
        'groupId': "TEXT",
        'created_at': "INTEGER NOT NULL DEFAULT 0",
        'createdAt': "INTEGER NOT NULL DEFAULT 0",
        'updated_at': "INTEGER NOT NULL DEFAULT 0",
        'updatedAt': "INTEGER NOT NULL DEFAULT 0",
      };

      for (final entry in commitAdditions.entries) {
        if (!rawCommitCols.contains(entry.key) && !lowerCommitCols.contains(entry.key.toLowerCase())) {
          try {
            await db.execute('ALTER TABLE day_plan_commits ADD COLUMN ${entry.key} ${entry.value};');
          } catch (e) {
            debugPrint('[DAY_PLAN_TABLES] Note adding commit column ${entry.key}: $e');
          }
        }
      }

      // Safely create index for day_plan_commits
      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_day_plan_commits_date '
          'ON day_plan_commits(date_iso);',
        );
      } catch (e) {
        try {
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_day_plan_commits_date '
            'ON day_plan_commits(dateIso);',
          );
        } catch (_) {}
      }

      // 2. Create day_plan_templates table if it does not exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS day_plan_templates (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          title TEXT,
          plan_json TEXT,
          itemsJson TEXT NOT NULL DEFAULT '[]',
          useCount INTEGER NOT NULL DEFAULT 0,
          lastUsedAt INTEGER,
          created_at INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0,
          updatedAt INTEGER NOT NULL DEFAULT 0
        );
      ''');

      final pragmaTemplates = await db.rawQuery("PRAGMA table_info('day_plan_templates');");
      final rawTemplateCols = pragmaTemplates.map((r) => r['name'] as String).toSet();
      final lowerTemplateCols = rawTemplateCols.map((n) => n.toLowerCase()).toSet();

      final templateAdditions = <String, String>{
        'name': "TEXT NOT NULL DEFAULT ''",
        'itemsJson': "TEXT NOT NULL DEFAULT '[]'",
        'useCount': "INTEGER NOT NULL DEFAULT 0",
        'lastUsedAt': "INTEGER",
        'created_at': "INTEGER NOT NULL DEFAULT 0",
        'createdAt': "INTEGER NOT NULL DEFAULT 0",
        'updated_at': "INTEGER NOT NULL DEFAULT 0",
        'updatedAt': "INTEGER NOT NULL DEFAULT 0",
      };

      for (final entry in templateAdditions.entries) {
        if (!rawTemplateCols.contains(entry.key) && !lowerTemplateCols.contains(entry.key.toLowerCase())) {
          try {
            await db.execute('ALTER TABLE day_plan_templates ADD COLUMN ${entry.key} ${entry.value};');
          } catch (e) {
            debugPrint('[DAY_PLAN_TABLES] Note adding template column ${entry.key}: $e');
          }
        }
      }

      try {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_day_plan_templates_title '
          'ON day_plan_templates(title);',
        );
      } catch (_) {}

      // 3. Planning Cycles (V87)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planning_cycles (
          id TEXT PRIMARY KEY,
          horizon TEXT NOT NULL CHECK (horizon IN ('DAY','WEEK','MONTH')),
          startDayKey TEXT NOT NULL,
          endDayKey TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'DRAFT'
            CHECK (status IN ('DRAFT','ACTIVE','CLOSED','ABANDONED')),
          title TEXT,
          theme TEXT,
          capacityMinutes INTEGER NOT NULL DEFAULT 0,
          reserveMinutes INTEGER NOT NULL DEFAULT 0,
          version INTEGER NOT NULL DEFAULT 1,
          supersedesCycleId TEXT,
          createdAt INTEGER NOT NULL,
          activatedAt INTEGER,
          closedAt INTEGER
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_cycles_hs ON planning_cycles(horizon, status);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_cycles_start ON planning_cycles(startDayKey);');

      // 4. Planning Commitments (V87)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planning_commitments (
          id TEXT PRIMARY KEY,
          cycleId TEXT NOT NULL REFERENCES planning_cycles(id) ON DELETE CASCADE,
          title TEXT NOT NULL,
          sourceType TEXT NOT NULL DEFAULT 'MANUAL'
            CHECK (sourceType IN ('GOAL_STEP','TASK','ROUTINE','COURSE_SESSION','KONKUR_ITEM','MANUAL')),
          sourceId TEXT,
          goalId TEXT,
          importance TEXT NOT NULL DEFAULT 'SHOULD'
            CHECK (importance IN ('MUST','SHOULD','COULD')),
          flexibility TEXT NOT NULL DEFAULT 'FLEXIBLE'
            CHECK (flexibility IN ('FIXED','WINDOWED','FLEXIBLE')),
          effortMinutes INTEGER NOT NULL DEFAULT 30,
          workKind TEXT NOT NULL DEFAULT 'LIGHT'
            CHECK (workKind IN ('DEEP','LIGHT','ADMIN','SOCIAL','RECOVERY')),
          earliestDayKey TEXT,
          latestDayKey TEXT,
          preferredDayPartsJson TEXT,
          status TEXT NOT NULL DEFAULT 'PROPOSED'
            CHECK (status IN ('PROPOSED','ACCEPTED','SCHEDULED','DONE','MOVED','DROPPED')),
          isUserLocked INTEGER NOT NULL DEFAULT 0,
          origin TEXT NOT NULL DEFAULT 'USER' CHECK (origin IN ('USER','AI','IMPORTED')),
          planningReason TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_commit_cycle ON planning_commitments(cycleId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_commit_status ON planning_commitments(status);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_commit_goal ON planning_commitments(goalId);');

      // 5. Planning Allocations (V87)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planning_allocations (
          id TEXT PRIMARY KEY,
          commitmentId TEXT NOT NULL REFERENCES planning_commitments(id) ON DELETE CASCADE,
          dayKey TEXT NOT NULL,
          plannedMinutes INTEGER NOT NULL,
          timeWindowStart TEXT,
          timeWindowEnd TEXT,
          exactTime TEXT,
          status TEXT NOT NULL DEFAULT 'PLANNED'
            CHECK (status IN ('PLANNED','DONE','MOVED','DROPPED')),
          materializedEntityType TEXT,
          materializedEntityId TEXT,
          idempotencyKey TEXT NOT NULL UNIQUE,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_alloc_day ON planning_allocations(dayKey);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_alloc_commit ON planning_allocations(commitmentId);');

      // 6. Planning Reviews (V87)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS planning_reviews (
          id TEXT PRIMARY KEY,
          cycleId TEXT NOT NULL REFERENCES planning_cycles(id) ON DELETE CASCADE,
          reviewType TEXT NOT NULL CHECK (reviewType IN ('MID_CYCLE','END_CYCLE')),
          plannedMinutes INTEGER NOT NULL DEFAULT 0,
          completedMinutes INTEGER NOT NULL DEFAULT 0,
          movedMinutes INTEGER NOT NULL DEFAULT 0,
          droppedMinutes INTEGER NOT NULL DEFAULT 0,
          unplannedCompletedMinutes INTEGER NOT NULL DEFAULT 0,
          calibrationScore REAL,
          answersJson TEXT,
          createdAt INTEGER NOT NULL
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_reviews_cycle ON planning_reviews(cycleId);');

    } catch (e, st) {
      debugPrint('[DAY_PLAN_TABLES] Error in ensureSchema: $e\n$st');
    }
  }
}
