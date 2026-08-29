import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Migration V2: Ensures full schema for Planning Module
/// (planning_cycles, planning_commitments, planning_allocations, planning_reviews, calendar_exceptions).
class MigrationV2PlanningSchema extends Migration {
  @override
  int get version => 2;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV2', 'Applying Migration V2 (Planning Schema)...');

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

    // 5. calendar_exceptions
    await db.execute('''
      CREATE TABLE IF NOT EXISTS calendar_exceptions (
        date TEXT PRIMARY KEY,
        id TEXT,
        exceptionType TEXT NOT NULL DEFAULT 'SYSTEM',
        behavior TEXT NOT NULL DEFAULT 'NORMAL',
        reason TEXT,
        title TEXT,
        isAutoGrace INTEGER NOT NULL DEFAULT 0,
        isUserDefined INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_calendar_exceptions_exceptionType ON calendar_exceptions(exceptionType);');

    // Column self-healing via safeAddColumn for existing databases that might have older tables
    await safeAddColumn(db, 'planning_commitments', 'isUserLocked', 'INTEGER NOT NULL DEFAULT 0');
    await safeAddColumn(db, 'planning_commitments', 'origin', "TEXT NOT NULL DEFAULT 'USER'");
    await safeAddColumn(db, 'planning_commitments', 'planningReason', 'TEXT');

    await safeAddColumn(db, 'planning_allocations', 'materializedEntityType', 'TEXT');
    await safeAddColumn(db, 'planning_allocations', 'materializedEntityId', 'TEXT');
    await safeAddColumn(db, 'planning_allocations', 'idempotencyKey', "TEXT NOT NULL DEFAULT ''");

    await safeAddColumn(db, 'calendar_exceptions', 'id', 'TEXT');
    await safeAddColumn(db, 'calendar_exceptions', 'reason', 'TEXT');
    await safeAddColumn(db, 'calendar_exceptions', 'updatedAt', 'INTEGER');

    RitmoLog.info('MigrationV2', 'Migration V2 successfully executed.');
  }

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    RitmoLog.warning('MigrationV2', 'Migration V2 down invoked - preserving user planning tables.');
  }
}
