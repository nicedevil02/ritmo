import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/migration/migration_interface.dart';

class MigrationV87Planning extends Migration {
  @override
  bool get requiresTransaction => false;
  @override
  int get version => 87;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1) Schema migration for day_plan_templates (A-03)
    final templateCols = (await db.rawQuery("PRAGMA table_info('day_plan_templates');"))
        .map((r) => r['name'] as String)
        .toSet();

    if (templateCols.contains('title') && !templateCols.contains('name')) {
      await db.execute('ALTER TABLE day_plan_templates RENAME TO day_plan_templates_legacy;');
      await db.execute('''
        CREATE TABLE day_plan_templates (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          icon TEXT,
          itemsJson TEXT NOT NULL,
          createdAt INTEGER NOT NULL DEFAULT 0,
          updatedAt INTEGER NOT NULL DEFAULT 0,
          lastUsedAt INTEGER NOT NULL DEFAULT 0,
          useCount INTEGER NOT NULL DEFAULT 0
        );
      ''');
      await db.execute('''
        INSERT INTO day_plan_templates (id, name, icon, itemsJson, createdAt, updatedAt, lastUsedAt, useCount)
        SELECT id, title, NULL, plan_json, COALESCE(createdAt, created_at, 0), COALESCE(updatedAt, updated_at, 0), 0, 0
        FROM day_plan_templates_legacy;
      ''');
      await db.execute('DROP TABLE day_plan_templates_legacy;');
    } else if (!templateCols.contains('name')) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS day_plan_templates (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, icon TEXT, itemsJson TEXT NOT NULL,
          createdAt INTEGER NOT NULL DEFAULT 0, updatedAt INTEGER NOT NULL DEFAULT 0,
          lastUsedAt INTEGER NOT NULL DEFAULT 0, useCount INTEGER NOT NULL DEFAULT 0
        );
      ''');
    }

    // 2) Planning Cycles
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

    // 3) Commitments
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

    // 4) Allocations
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

    // 5) Reviews
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

    // 6) Settings keys seed (D-02)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final defaultSettings = {
      'planning_week_ritual_enabled': 'true',
      'planning_reserve_profile': 'BALANCED',
      'planning_month_focus_limit': '3',
      'planning_midweek_checkin_enabled': 'true',
      'planning_show_on_dashboard': 'true',
      'planning_ai_scenarios_enabled': 'true',
    };

    for (final entry in defaultSettings.entries) {
      await db.execute('''
        INSERT OR IGNORE INTO app_settings (key, value, updatedAt)
        VALUES ('${entry.key}', '${entry.value}', $nowMs);
      ''');
    }
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS planning_reviews;');
    await db.execute('DROP TABLE IF EXISTS planning_allocations;');
    await db.execute('DROP TABLE IF EXISTS planning_commitments;');
    await db.execute('DROP TABLE IF EXISTS planning_cycles;');
  }
}
