import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:sqflite/sqflite.dart';

class KonkurTables {
  static Future<void> create(DatabaseExecutor db) async {
    // 23. konkur_subjects (V2 table)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_subjects (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          importanceFactor REAL NOT NULL DEFAULT 1.0,
          progressPercentage REAL NOT NULL DEFAULT 0.0,
          isArchived INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          subjectGroup TEXT NOT NULL DEFAULT 'SPECIALIZED',
          examQuestionCount INTEGER NOT NULL DEFAULT 0,
          orderIndex INTEGER NOT NULL DEFAULT 0,
          colorHex TEXT,
          isPreset INTEGER NOT NULL DEFAULT 0,
          origin TEXT NOT NULL DEFAULT 'USER',
          emoji TEXT,
          weeklyTargetMinutes INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // 24. konkur_topics (V2 table)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_topics (
          id TEXT PRIMARY KEY,
          subjectId TEXT NOT NULL,
          parentTopicId TEXT,
          name TEXT NOT NULL,
          progressPercentage REAL NOT NULL DEFAULT 0.0,
          studyTargetMinutes INTEGER NOT NULL DEFAULT 0,
          studyCompletedMinutes INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          examQuestionCount INTEGER NOT NULL DEFAULT 0,
          masteryLevel TEXT NOT NULL DEFAULT 'NOT_STARTED',
          lastStudiedAt INTEGER,
          nextReviewDate TEXT,
          plannedDate TEXT,
          orderIndex INTEGER NOT NULL DEFAULT 0,
          prerequisiteTopicIds TEXT,
          conceptCompletedMinutes INTEGER NOT NULL DEFAULT 0,
          practiceCompletedMinutes INTEGER NOT NULL DEFAULT 0,
          reviewCompletedMinutes INTEGER NOT NULL DEFAULT 0,
          conceptTargetMinutes INTEGER NOT NULL DEFAULT 0,
          practiceTargetMinutes INTEGER NOT NULL DEFAULT 0,
          reviewTargetMinutes INTEGER NOT NULL DEFAULT 0,
          chapter TEXT,
          reviewCount INTEGER NOT NULL DEFAULT 0,
          origin TEXT NOT NULL DEFAULT 'USER',
          FOREIGN KEY(subjectId) REFERENCES konkur_subjects(id) ON DELETE CASCADE,
          FOREIGN KEY(parentTopicId) REFERENCES konkur_topics(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_konkur_topics_subjectId ON konkur_topics(subjectId);');
    await db.execute('CREATE INDEX IF NOT EXISTS index_konkur_topics_parentTopicId ON konkur_topics(parentTopicId);');

    // 25. konkur_mock_exams (V2 table)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_mock_exams (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          examDate TEXT NOT NULL,
          createdAt INTEGER NOT NULL,
          provider TEXT,
          note TEXT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_konkur_mock_exams_examDate ON konkur_mock_exams(examDate);');

    // 26. konkur_mock_exam_results (V2 table)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_mock_exam_results (
          id TEXT PRIMARY KEY,
          mockExamId TEXT NOT NULL,
          subjectId TEXT NOT NULL,
          percentage REAL NOT NULL,
          correctAnswers INTEGER NOT NULL DEFAULT 0,
          wrongAnswers INTEGER NOT NULL DEFAULT 0,
          emptyAnswers INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          totalQuestions INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(mockExamId) REFERENCES konkur_mock_exams(id) ON DELETE CASCADE,
          FOREIGN KEY(subjectId) REFERENCES konkur_subjects(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_konkur_mock_exam_results_mockExamId ON konkur_mock_exam_results(mockExamId);');
    await db.execute('CREATE INDEX IF NOT EXISTS index_konkur_mock_exam_results_subjectId ON konkur_mock_exam_results(subjectId);');

    // V15 konkur_study_sessions table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_study_sessions (
        id TEXT PRIMARY KEY,
        topicId TEXT,
        subjectId TEXT,
        dateIso TEXT NOT NULL,
        durationMinutes INTEGER NOT NULL DEFAULT 0,
        mode TEXT NOT NULL DEFAULT 'STUDY',
        testsTotal INTEGER NOT NULL DEFAULT 0,
        testsCorrect INTEGER NOT NULL DEFAULT 0,
        testsWrong INTEGER NOT NULL DEFAULT 0,
        testsBlank INTEGER NOT NULL DEFAULT 0,
        testsEmpty INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        sessionOutcome TEXT,
        createdAt INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'MANUAL',
        startedAtMs INTEGER,
        endedAtMs INTEGER,
        quality INTEGER
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_konkur_sessions_dateIso ON konkur_study_sessions(dateIso);');
    await db.execute('CREATE INDEX IF NOT EXISTS index_konkur_sessions_subjectId ON konkur_study_sessions(subjectId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_konkur_sessions_date ON konkur_study_sessions(dateIso);');

    // V15 konkur_plan_items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_plan_items (
        id TEXT PRIMARY KEY,
        dateIso TEXT NOT NULL,
        subjectId TEXT,
        topicId TEXT,
        plannedMinutes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING',
        createdAt INTEGER NOT NULL,
        plannedMode TEXT,
        priorityScore REAL,
        planningReason TEXT,
        isLocked INTEGER NOT NULL DEFAULT 0,
        isUserEdited INTEGER NOT NULL DEFAULT 0,
        carryOverCount INTEGER NOT NULL DEFAULT 0,
        sourceType TEXT DEFAULT 'AUTO',
        recommendedEnergy TEXT,
        energyNote TEXT
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS index_konkur_plan_dateIso ON konkur_plan_items(dateIso);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_konkur_plan_date_status ON konkur_plan_items(dateIso, status);');

    // V81 konkur_plans table
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

    // study_deadlines table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_deadlines (
          id TEXT PRIMARY KEY,
          subjectId TEXT,
          title TEXT NOT NULL,
          deadlineType TEXT NOT NULL DEFAULT 'EXAM',
          dueDateIso TEXT NOT NULL,
          dueTime TEXT,
          priority TEXT NOT NULL DEFAULT 'MEDIUM',
          isCompleted INTEGER NOT NULL DEFAULT 0,
          weight REAL NOT NULL DEFAULT 1.0,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY(subjectId) REFERENCES konkur_subjects(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_deadlines_due ON study_deadlines(dueDateIso, isCompleted);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_deadlines_subject ON study_deadlines(subjectId);',
    );
  }

  /// Self-healing schema validation to ensure konkur plan tables and topic columns exist.
  static Future<void> ensureSchema(DatabaseExecutor db) async {
    // 1. konkur_subjects missing columns
    await SchemaManager.safeAddColumn(
      db,
      'konkur_subjects',
      'origin',
      "TEXT NOT NULL DEFAULT 'USER'",
    );
    await SchemaManager.safeAddColumn(
      db,
      'konkur_subjects',
      'emoji',
      'TEXT',
    );
    await SchemaManager.safeAddColumn(
      db,
      'konkur_subjects',
      'weeklyTargetMinutes',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // 2. konkur_topics missing columns
    await SchemaManager.safeAddColumn(
      db,
      'konkur_topics',
      'origin',
      "TEXT NOT NULL DEFAULT 'USER'",
    );
    await SchemaManager.safeAddColumn(
      db,
      'konkur_topics',
      'reviewCount',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // 3. konkur_study_sessions missing columns
    await SchemaManager.safeAddColumn(
      db,
      'konkur_study_sessions',
      'source',
      "TEXT NOT NULL DEFAULT 'MANUAL'",
    );
    await SchemaManager.safeAddColumn(
      db,
      'konkur_study_sessions',
      'startedAtMs',
      'INTEGER',
    );
    await SchemaManager.safeAddColumn(
      db,
      'konkur_study_sessions',
      'endedAtMs',
      'INTEGER',
    );
    await SchemaManager.safeAddColumn(
      db,
      'konkur_study_sessions',
      'quality',
      'INTEGER',
    );
    await SchemaManager.safeAddColumn(
      db,
      'konkur_study_sessions',
      'testsEmpty',
      'INTEGER NOT NULL DEFAULT 0',
    );

    // 4. study_deadlines table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_deadlines (
          id TEXT PRIMARY KEY,
          subjectId TEXT,
          title TEXT NOT NULL,
          deadlineType TEXT NOT NULL DEFAULT 'EXAM',
          dueDateIso TEXT NOT NULL,
          dueTime TEXT,
          priority TEXT NOT NULL DEFAULT 'MEDIUM',
          isCompleted INTEGER NOT NULL DEFAULT 0,
          weight REAL NOT NULL DEFAULT 1.0,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          FOREIGN KEY(subjectId) REFERENCES konkur_subjects(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_deadlines_due ON study_deadlines(dueDateIso, isCompleted);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_deadlines_subject ON study_deadlines(subjectId);',
    );

    // 5. konkur_plans table
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

    // 6. Data backfill: if origin is null or default, update preset subjects/topics
    try {
      await db.execute(
        "UPDATE konkur_subjects SET origin = 'KONKUR_PRESET' WHERE isPreset = 1 AND (origin IS NULL OR origin = 'USER');",
      );
      await db.execute(
        "UPDATE konkur_topics SET origin = 'KONKUR_PRESET' WHERE subjectId IN (SELECT id FROM konkur_subjects WHERE isPreset = 1) AND (origin IS NULL OR origin = 'USER');",
      );
    } catch (_) {}
  }
}
