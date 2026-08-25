import 'package:sqflite/sqflite.dart';

class CourseTables {
  static Future<void> create(DatabaseExecutor db) async {
    // 9. courses table
    await db.execute('''
      CREATE TABLE courses (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          totalSessions INTEGER NOT NULL CHECK(totalSessions > 0),
          sessionDurationMinutes INTEGER NOT NULL CHECK(sessionDurationMinutes BETWEEN 1 AND 600),
          activityType TEXT NOT NULL,
          zoneId TEXT,
          isArchived INTEGER NOT NULL DEFAULT 0,
          energyRule TEXT NOT NULL DEFAULT 'ALL' CHECK(energyRule IN ('ALL','OFFER_LIGHT','MEDIUM_OR_HIGH','HIGH_ONLY','SKIP_LOW')),
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          courseType TEXT NOT NULL DEFAULT 'VIDEO' CHECK(courseType IN ('VIDEO','BOOK','SKILL','CUSTOM')),
          unitLabel TEXT,
          emoji TEXT,
          colorHex TEXT,
          provider TEXT,
          weeklyTargetSessions INTEGER NOT NULL DEFAULT 3 CHECK(weeklyTargetSessions BETWEEN 1 AND 21),
          isAdaptive INTEGER NOT NULL DEFAULT 0,
          preferredDays TEXT,
          preferredTime TEXT,
          reminderEnabled INTEGER NOT NULL DEFAULT 0,
          linkedGoalId TEXT,
          status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','PAUSED','COMPLETED')),
          completedAt INTEGER,
          targetEndDate TEXT,
          adaptiveLastAppliedAt INTEGER,
          masteryScore REAL NOT NULL DEFAULT 0,
          reviewEnabled INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE SET NULL,
          FOREIGN KEY(linkedGoalId) REFERENCES goals(id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_courses_zoneId ON courses(zoneId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_courses_status ON courses(status, isArchived);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_courses_linkedGoalId ON courses(linkedGoalId);');

    // 10. course_sessions table
    await db.execute('''
      CREATE TABLE course_sessions (
          id TEXT PRIMARY KEY,
          courseId TEXT NOT NULL,
          sessionNumber INTEGER NOT NULL,
          plannedDate TEXT,
          completionStatus TEXT NOT NULL CHECK(completionStatus IN ('PENDING','COMPLETED','SKIPPED')),
          actualDurationMinutes INTEGER,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          sessionTitle TEXT,
          completedAt INTEGER,
          isUserScheduled INTEGER NOT NULL DEFAULT 0,
          plannedStartTime TEXT,
          estimatedDurationMinutes INTEGER,
          sectionTitle TEXT,
          learningObjective TEXT,
          difficulty INTEGER CHECK(difficulty IS NULL OR difficulty BETWEEN 1 AND 5),
          activityKind TEXT NOT NULL DEFAULT 'LEARN' CHECK(activityKind IN ('LEARN','PRACTICE','REVIEW','PROJECT','EXAM')),
          understandingScore INTEGER CHECK(understandingScore IS NULL OR understandingScore BETWEEN 1 AND 5),
          needsReview INTEGER NOT NULL DEFAULT 0,
          keyTakeaway TEXT,
          openQuestion TEXT,
          questionResolved INTEGER NOT NULL DEFAULT 0,
          sourceSessionId TEXT,
          skipReason TEXT,
          displayOrder INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(courseId) REFERENCES courses(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS index_course_sessions_courseId_sessionNumber ON course_sessions(courseId, sessionNumber);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_course_sessions_planned ON course_sessions(plannedDate, completionStatus);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_course_sessions_course_status ON course_sessions(courseId, completionStatus);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_course_sessions_completedAt ON course_sessions(completedAt);');

    // 11. course_active_timers table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS course_active_timers (
          courseSessionId TEXT PRIMARY KEY,
          courseId TEXT NOT NULL,
          startedAt INTEGER NOT NULL,
          pausedAccumulatedMs INTEGER NOT NULL DEFAULT 0,
          state TEXT NOT NULL DEFAULT 'RUNNING' CHECK(state IN ('RUNNING','PAUSED')),
          targetDurationMinutes INTEGER,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY(courseSessionId) REFERENCES course_sessions(id) ON DELETE CASCADE
      );
    ''');

    // 12. study_active_session table (V73)
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
  }

  /// Self-healing schema validation to ensure course tables, columns, and indexes exist. (Fixes K-13 & M1)
  static Future<void> ensureSchema(DatabaseExecutor db) async {
    // 1. Ensure courses table & indexes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS courses (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          totalSessions INTEGER NOT NULL,
          sessionDurationMinutes INTEGER NOT NULL,
          activityType TEXT NOT NULL,
          zoneId TEXT,
          isArchived INTEGER NOT NULL DEFAULT 0,
          energyRule TEXT NOT NULL DEFAULT 'ALL',
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          courseType TEXT NOT NULL DEFAULT 'VIDEO',
          unitLabel TEXT,
          emoji TEXT,
          colorHex TEXT,
          provider TEXT,
          weeklyTargetSessions INTEGER NOT NULL DEFAULT 3,
          isAdaptive INTEGER NOT NULL DEFAULT 0,
          preferredDays TEXT,
          preferredTime TEXT,
          reminderEnabled INTEGER NOT NULL DEFAULT 0,
          linkedGoalId TEXT,
          status TEXT NOT NULL DEFAULT 'ACTIVE',
          completedAt INTEGER,
          targetEndDate TEXT,
          adaptiveLastAppliedAt INTEGER,
          masteryScore REAL NOT NULL DEFAULT 0,
          reviewEnabled INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(zoneId) REFERENCES zones(id) ON DELETE SET NULL,
          FOREIGN KEY(linkedGoalId) REFERENCES goals(id) ON DELETE SET NULL
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_courses_zoneId ON courses(zoneId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_courses_status ON courses(status, isArchived);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_courses_linkedGoalId ON courses(linkedGoalId);');

    // 2. Ensure course_sessions table & indexes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS course_sessions (
          id TEXT PRIMARY KEY,
          courseId TEXT NOT NULL,
          sessionNumber INTEGER NOT NULL,
          plannedDate TEXT,
          completionStatus TEXT NOT NULL DEFAULT 'PENDING',
          actualDurationMinutes INTEGER,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          sessionTitle TEXT,
          completedAt INTEGER,
          isUserScheduled INTEGER NOT NULL DEFAULT 0,
          plannedStartTime TEXT,
          estimatedDurationMinutes INTEGER,
          sectionTitle TEXT,
          learningObjective TEXT,
          difficulty INTEGER,
          activityKind TEXT NOT NULL DEFAULT 'LEARN',
          understandingScore INTEGER,
          needsReview INTEGER NOT NULL DEFAULT 0,
          keyTakeaway TEXT,
          openQuestion TEXT,
          questionResolved INTEGER NOT NULL DEFAULT 0,
          sourceSessionId TEXT,
          skipReason TEXT,
          displayOrder INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(courseId) REFERENCES courses(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS index_course_sessions_courseId_sessionNumber ON course_sessions(courseId, sessionNumber);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_course_sessions_planned ON course_sessions(plannedDate, completionStatus);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_course_sessions_course_status ON course_sessions(courseId, completionStatus);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_course_sessions_completedAt ON course_sessions(completedAt);');

    // 3. Ensure course_active_timers table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS course_active_timers (
          courseSessionId TEXT PRIMARY KEY,
          courseId TEXT NOT NULL,
          startedAt INTEGER NOT NULL,
          pausedAccumulatedMs INTEGER NOT NULL DEFAULT 0,
          state TEXT NOT NULL DEFAULT 'RUNNING',
          targetDurationMinutes INTEGER,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY(courseSessionId) REFERENCES course_sessions(id) ON DELETE CASCADE
      );
    ''');

    // 4. Ensure study_active_session table (V73)
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

    // 5. Data Normalization Migrations (Fixes C1, C2)
    try {
      await db.execute("UPDATE courses SET courseType = UPPER(courseType) WHERE courseType IS NOT NULL;");
      await db.execute("UPDATE courses SET energyRule = 'ALL' WHERE energyRule IN ('NONE', '', 'all', 'none') OR energyRule IS NULL;");
      await db.execute("UPDATE courses SET energyRule = 'OFFER_LIGHT' WHERE energyRule IN ('offerLight', 'OFFERLIGHT');");
      await db.execute("UPDATE courses SET energyRule = 'HIGH_ONLY' WHERE energyRule IN ('highEnergyOnly', 'HIGHENERGYONLY');");
      await db.execute("UPDATE courses SET energyRule = 'SKIP_LOW' WHERE energyRule IN ('skip', 'SKIP', 'skipLow');");
      await db.execute("UPDATE courses SET energyRule = 'MEDIUM_OR_HIGH' WHERE energyRule IN ('mediumOrHigh', 'MEDIUMORHIGH');");
    } catch (_) {}
  }
}
