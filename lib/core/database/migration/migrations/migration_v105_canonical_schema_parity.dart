import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// Migration v105: Canonical Schema Parity & Missing Tables Backfill.
/// Ensures all tables (occurrence_overrides, worship_day_exceptions, day_marks, etc.)
/// are fully instantiated across all running instances.
class MigrationV105CanonicalSchemaParity extends Migration {
  @override
  int get version => 105;

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. occurrence_overrides table
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

    // 2. worship_day_exceptions table
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

    // 3. day_marks table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS day_marks (
          date TEXT PRIMARY KEY,
          kind TEXT NOT NULL DEFAULT 'NORMAL',
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_day_marks_kind ON day_marks(kind);',
    );

    // 4. study_active_session table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_active_session (
        id TEXT PRIMARY KEY CHECK (id = 'singleton'),
        subjectId TEXT,
        topicId TEXT,
        mode TEXT NOT NULL DEFAULT 'LEARN',
        startedAtMs INTEGER NOT NULL,
        accumulatedSeconds INTEGER NOT NULL DEFAULT 0,
        isPaused INTEGER NOT NULL DEFAULT 0,
        plannedMinutes INTEGER,
        createdAt INTEGER NOT NULL
      );
    ''');

    // 5. alarm_delivery_log table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alarm_delivery_log (
        id TEXT PRIMARY KEY,
        reminderId TEXT NOT NULL,
        routineId TEXT,
        expectedAt INTEGER NOT NULL,
        firedAt INTEGER,
        outcome TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_alarm_delivery_expected ON alarm_delivery_log(expectedAt);',
    );

    // 6. assistant_plans table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS assistant_plans (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        schedule_json TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_assistant_plans_status ON assistant_plans(status);',
    );

    // 7. konkur_plans table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_plans (
        id TEXT PRIMARY KEY,
        plan_code TEXT NOT NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        start_date TEXT,
        end_date TEXT,
        weekly_hours REAL,
        schedule_json TEXT,
        review_strategy TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_konkur_plans_status ON konkur_plans(status);',
    );

    // 8. notification_channel_prefs table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_channel_prefs (
        channel_id TEXT PRIMARY KEY,
        enabled INTEGER NOT NULL DEFAULT 1,
        sound_mode TEXT NOT NULL DEFAULT 'default',
        vibration_enabled INTEGER NOT NULL DEFAULT 1,
        bypass_dnd INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');

    // 9. planning system tables
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
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
