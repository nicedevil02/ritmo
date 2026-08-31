import 'package:sqflite/sqflite.dart';

/// Schema definitions and self-healing migrations for Planning Module tables
/// (`planning_cycles`, `planning_commitments`, `planning_allocations`, `planning_reviews`).
class PlanningTables {
  static Future<void> create(DatabaseExecutor db) async {
    // 1. planning_cycles
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

    // 2. planning_commitments
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

    // 3. planning_allocations
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

    // 4. planning_reviews
    await db.execute('''
      CREATE TABLE IF NOT EXISTS planning_reviews (
        id TEXT PRIMARY KEY,
        cycleId TEXT NOT NULL REFERENCES planning_cycles(id) ON DELETE CASCADE,
        horizon TEXT NOT NULL CHECK (horizon IN ('WEEK','MONTH')),
        dayKey TEXT NOT NULL,
        plannedMinutes INTEGER NOT NULL,
        executedMinutes INTEGER NOT NULL,
        calibrationScore REAL,
        answersJson TEXT,
        createdAt INTEGER NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_planning_rev_cycle ON planning_reviews(cycleId);');
  }

  /// Self-healing schema validation to ensure all planning tables and indexes
  /// exist safely on any existing or fresh database.
  static Future<void> ensureSchema(DatabaseExecutor db) async {
    await create(db);
  }
}
