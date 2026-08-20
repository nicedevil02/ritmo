import 'package:sqflite/sqflite.dart';

/// اسکیما و تعریف جداول اختصاصی ماژول حرکت (Movement Greenfield)
abstract final class MovementTables {
  static const String tableActivityKinds = 'movement_activity_kinds';
  static const String tableOccurrences = 'movement_occurrences';
  static const String tableLiveSessions = 'movement_live_sessions';
  static const String tableExercises = 'movement_exercises';
  static const String tableSetLogs = 'movement_set_logs';
  static const String tablePlanTemplates = 'movement_plan_templates';
  static const String tablePlanSchedules = 'movement_plan_schedules';
  static const String tablePlanVersions = 'movement_plan_versions';
  static const String tableWorkoutLogs = 'movement_workout_logs';
  static const String tableReadinessCheckins = 'movement_readiness_checkins';
  static const String tablePreferences = 'movement_preferences';
  static const String tablePersonalRecords = 'movement_personal_records';

  static Future<void> create(DatabaseExecutor db) async {
    // ۱. جدول گونه‌های فعالیت حرکتی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableActivityKinds (
        id TEXT PRIMARY KEY,
        nameFa TEXT NOT NULL,
        nameEn TEXT,
        aliasesJson TEXT,
        family TEXT NOT NULL,
        icon TEXT NOT NULL,
        primaryMetric TEXT NOT NULL,
        defaultUnitsJson TEXT,
        isCustom INTEGER NOT NULL DEFAULT 0,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        archivedAt TEXT,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_activity_kinds_family
        ON $tableActivityKinds (family);
    ''');

    // ۲. جدول رخدادها و جلسات برنامه
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOccurrences (
        id TEXT PRIMARY KEY,
        activityKindId TEXT NOT NULL,
        templateId TEXT,
        scheduleId TEXT,
        dateIso TEXT NOT NULL,
        startTime TEXT,
        status TEXT NOT NULL,
        goalType TEXT,
        goalValue REAL,
        goalUnit TEXT,
        movedToDateIso TEXT,
        origin TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_occurrences_date
        ON $tableOccurrences (dateIso);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_occurrences_status
        ON $tableOccurrences (status);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_occurrences_template
        ON $tableOccurrences (templateId);
    ''');

    // ۳. جدول جلسات زنده
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableLiveSessions (
        id TEXT PRIMARY KEY,
        occurrenceId TEXT,
        activityKindId TEXT NOT NULL,
        mode TEXT NOT NULL,
        status TEXT NOT NULL,
        startedAt TEXT,
        accumulatedPauseMs INTEGER NOT NULL DEFAULT 0,
        targetSnapshotJson TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_live_sessions_status
        ON $tableLiveSessions (status);
    ''');

    // ۴. جدول حرکات و تمرینات ورزشی (Exercise Dictionary)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableExercises (
        id TEXT PRIMARY KEY,
        nameFa TEXT NOT NULL,
        nameEn TEXT,
        aliasesJson TEXT,
        muscleGroup TEXT,
        equipment TEXT,
        category TEXT,
        isCustom INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_exercises_muscle
        ON $tableExercises (muscleGroup);
    ''');

    // ۵. جدول لاگ ست‌های تمرین قدرتی
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSetLogs (
        id TEXT PRIMARY KEY,
        sessionId TEXT,
        occurrenceId TEXT,
        exerciseId TEXT NOT NULL,
        setIndex INTEGER NOT NULL,
        weightKg REAL,
        reps INTEGER,
        completed INTEGER NOT NULL DEFAULT 0,
        skipped INTEGER NOT NULL DEFAULT 0,
        at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_set_logs_session
        ON $tableSetLogs (sessionId);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_set_logs_exercise
        ON $tableSetLogs (exerciseId);
    ''');

    // ۶. جدول قالب‌های برنامهٔ حرکت
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePlanTemplates (
        id TEXT PRIMARY KEY,
        activityKindId TEXT NOT NULL,
        sessionType TEXT NOT NULL,
        goalJson TEXT,
        reminderType TEXT NOT NULL,
        reminderOffsetMin INTEGER,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        archivedAt TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_plan_templates_kind
        ON $tablePlanTemplates (activityKindId);
    ''');

    // ۷. جدول زمان‌بندی‌های قالب برنامه
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePlanSchedules (
        id TEXT PRIMARY KEY,
        templateId TEXT NOT NULL,
        weekday INTEGER NOT NULL,
        timeOfDay TEXT NOT NULL,
        recurrence TEXT NOT NULL,
        startDateIso TEXT NOT NULL,
        weeksCount INTEGER,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_plan_schedules_template
        ON $tablePlanSchedules (templateId);
    ''');

    // ۸. جدول تاریخچه نسخه‌های برنامه
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePlanVersions (
        id TEXT PRIMARY KEY,
        templateId TEXT NOT NULL,
        versionNumber INTEGER NOT NULL,
        planSnapshotJson TEXT NOT NULL,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_plan_versions_template
        ON $tablePlanVersions (templateId);
    ''');

    // ۹. جدول تاریخچهٔ ثبت تمرین (Log)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWorkoutLogs (
        id TEXT PRIMARY KEY,
        occurrenceId TEXT,
        activityKindId TEXT NOT NULL,
        dateIso TEXT NOT NULL,
        startTime TEXT,
        durationSec INTEGER NOT NULL,
        metricJson TEXT,
        feeling TEXT,
        note TEXT,
        source TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_workout_logs_date
        ON $tableWorkoutLogs (dateIso);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_workout_logs_occurrence
        ON $tableWorkoutLogs (occurrenceId);
    ''');

    // ۱۰. جدول چک‌این و وضعیت آمادگی روزانه
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableReadinessCheckins (
        id TEXT PRIMARY KEY,
        dateIso TEXT NOT NULL,
        sleep INTEGER,
        energy INTEGER,
        soreness INTEGER,
        stress INTEGER,
        availableMinutes INTEGER,
        createdAt TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_readiness_date
        ON $tableReadinessCheckins (dateIso);
    ''');

    // ۱۱. جدول تنظیمات و ترجیحات ماژول حرکت
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePreferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    // ۱۲. جدول رکوردهای شخصی واقعی (Personal Records)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePersonalRecords (
        id TEXT PRIMARY KEY,
        activityKindId TEXT,
        exerciseId TEXT,
        recordType TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        achievedAt TEXT NOT NULL,
        sourceId TEXT
      );
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_pr_kind
        ON $tablePersonalRecords (activityKindId);
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_movement_pr_exercise
        ON $tablePersonalRecords (exerciseId);
    ''');
  }

  static Future<void> seedInitialData(DatabaseExecutor db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final seeds = [
      {
        'id': 'kind_walking',
        'nameFa': 'پیاده‌روی',
        'nameEn': 'Walking',
        'aliasesJson': '["قدم زدن","پیاده روی"]',
        'family': 'walking',
        'icon': 'directions_walk',
        'primaryMetric': 'duration',
        'defaultUnitsJson': '["min","km","step"]',
        'isCustom': 0,
        'isFavorite': 1,
        'archivedAt': null,
        'createdAt': now,
      },
      {
        'id': 'kind_running',
        'nameFa': 'دویدن',
        'nameEn': 'Running',
        'aliasesJson': '["دو","دویدن استقامتی"]',
        'family': 'running',
        'icon': 'directions_run',
        'primaryMetric': 'distance',
        'defaultUnitsJson': '["km","min"]',
        'isCustom': 0,
        'isFavorite': 1,
        'archivedAt': null,
        'createdAt': now,
      },
      {
        'id': 'kind_cycling',
        'nameFa': 'دوچرخه‌سواری',
        'nameEn': 'Cycling',
        'aliasesJson': '["دوچرخه"]',
        'family': 'cycling',
        'icon': 'directions_bike',
        'primaryMetric': 'distance',
        'defaultUnitsJson': '["km","min"]',
        'isCustom': 0,
        'isFavorite': 0,
        'archivedAt': null,
        'createdAt': now,
      },
      {
        'id': 'kind_swimming',
        'nameFa': 'شنا',
        'nameEn': 'Swimming',
        'aliasesJson': '["استخر","شنا کرال"]',
        'family': 'swimming',
        'icon': 'pool',
        'primaryMetric': 'distance',
        'defaultUnitsJson': '["m","lap","min"]',
        'isCustom': 0,
        'isFavorite': 0,
        'archivedAt': null,
        'createdAt': now,
      },
      {
        'id': 'kind_team_sports',
        'nameFa': 'ورزش تیمی',
        'nameEn': 'Team Sports',
        'aliasesJson': '["فوتبال","والیبال","بسکتبال"]',
        'family': 'team_sports',
        'icon': 'sports_soccer',
        'primaryMetric': 'duration',
        'defaultUnitsJson': '["min"]',
        'isCustom': 0,
        'isFavorite': 0,
        'archivedAt': null,
        'createdAt': now,
      },
      {
        'id': 'kind_hiking',
        'nameFa': 'کوهنوردی',
        'nameEn': 'Hiking',
        'aliasesJson': '["کوه پیمایی","طبیعت گردی"]',
        'family': 'hiking',
        'icon': 'hiking',
        'primaryMetric': 'elevation',
        'defaultUnitsJson': '["m","km","min"]',
        'isCustom': 0,
        'isFavorite': 0,
        'archivedAt': null,
        'createdAt': now,
      },
      {
        'id': 'kind_yoga_mobility',
        'nameFa': 'یوگا و کشش',
        'nameEn': 'Yoga & Mobility',
        'aliasesJson': '["کشش","انعطاف پذیری","یوگا"]',
        'family': 'yoga_mobility',
        'icon': 'self_improvement',
        'primaryMetric': 'duration',
        'defaultUnitsJson': '["min"]',
        'isCustom': 0,
        'isFavorite': 1,
        'archivedAt': null,
        'createdAt': now,
      },
      {
        'id': 'kind_strength',
        'nameFa': 'تمرین قدرتی ساده',
        'nameEn': 'Strength Training',
        'aliasesJson': '["بدنسازی","تمرین با وزن بدن","قدرتی"]',
        'family': 'strength',
        'icon': 'fitness_center',
        'primaryMetric': 'volume',
        'defaultUnitsJson': '["reps","kg","sets"]',
        'isCustom': 0,
        'isFavorite': 1,
        'archivedAt': null,
        'createdAt': now,
      },
    ];

    for (final seed in seeds) {
      await db.insert(
        tableActivityKinds,
        seed,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    await create(db);
    await seedInitialData(db);
  }
}
