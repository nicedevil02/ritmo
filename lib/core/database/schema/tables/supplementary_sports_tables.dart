import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/mv_kind_profile_seed.dart';
import 'package:sqflite/sqflite.dart';

class SupplementarySportsTables {
  static Future<void> create(DatabaseExecutor db) async {
    await MovementKindsSeed.ensureSchema(db);
    await MovementKindsSeed.seed(db);
    await ensureCommitmentTables(db);
    await ensureKindProfileTables(db);

    // 1. ss_exercise
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_exercise (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        nameEn TEXT,
        category TEXT NOT NULL,
        equipment TEXT,
        instructions TEXT,
        videoUrl TEXT,
        isCustom INTEGER DEFAULT 0,
        changeSides INTEGER DEFAULT 0,
        noisy INTEGER DEFAULT 0,
        impact INTEGER DEFAULT 0,
        repsDouble INTEGER DEFAULT 0,
        repDurationLow REAL DEFAULT 0,
        repDurationMedium REAL DEFAULT 0,
        repDurationHigh REAL DEFAULT 0,
        sexynessMale REAL DEFAULT 0,
        sexynessFemale REAL DEFAULT 0,
        isolatedVsCompound REAL DEFAULT 0,
        durationSeconds INTEGER DEFAULT 0,
        defaultReps INTEGER DEFAULT 0,
        repsHint TEXT,
        toolsRequired TEXT DEFAULT '[]',        -- JSON array
        constraintNegative TEXT,
        weightSupported INTEGER DEFAULT 0,
        weightPerHand INTEGER DEFAULT 0,
        muscleIntensity TEXT DEFAULT '{}',      -- JSON map
        skillRequired INTEGER DEFAULT 0,
        strengthVsCardio REAL DEFAULT 0,        -- 0=قدرتی .. 100=هوازی (نرمالایز کن)
        machineVsFreeweight REAL DEFAULT 0,
        looksCool INTEGER DEFAULT 0,
        stance TEXT,
        code TEXT UNIQUE,
        cat_cardio INTEGER DEFAULT 0,
        cat_plyometric INTEGER DEFAULT 0,
        cat_lower_body INTEGER DEFAULT 0,
        cat_upper_body INTEGER DEFAULT 0,
        cat_shoulder_and_back INTEGER DEFAULT 0,
        cat_core INTEGER DEFAULT 0,
        cat_stretching INTEGER DEFAULT 0,
        cat_yoga INTEGER DEFAULT 0,
        cat_balance INTEGER DEFAULT 0,
        cat_warmup INTEGER DEFAULT 0,
        skill_max INTEGER DEFAULT 0,
        sexyness_m INTEGER DEFAULT 0,
        sexyness_f INTEGER DEFAULT 0,
        animation_asset TEXT
      );
    ''');

    // 2. ss_workout_plan
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_workout_plan (
        id TEXT PRIMARY KEY,
        dayOfWeek INTEGER NOT NULL,
        week INTEGER DEFAULT 1,
        muscleGroups TEXT NOT NULL,
        estimatedMinutes INTEGER DEFAULT 45,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');

    // 3. ss_workout_exercise_crossref
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_workout_exercise_crossref (
        id TEXT PRIMARY KEY,
        planId TEXT NOT NULL,
        exerciseId TEXT NOT NULL,
        orderIndex INTEGER NOT NULL,
        difficultyOffset REAL DEFAULT 0,
        targetSets INTEGER DEFAULT 3,
        targetReps INTEGER DEFAULT 10,
        targetWeight REAL,
        FOREIGN KEY(planId) REFERENCES ss_workout_plan(id) ON DELETE CASCADE,
        FOREIGN KEY(exerciseId) REFERENCES ss_exercise(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_crossref_plan '
      'ON ss_workout_exercise_crossref(planId, orderIndex);',
    );

    // 4. ss_workout_session_log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_workout_session_log (
        id TEXT PRIMARY KEY,
        planId TEXT,
        prescriptionId TEXT,
        startedAt INTEGER NOT NULL,
        finishedAt INTEGER,
        durationSeconds INTEGER DEFAULT 0,
        completedExercisesCount INTEGER DEFAULT 0,
        totalExercisesCount INTEGER DEFAULT 0,
        overallFeeling TEXT,
        note TEXT,
        FOREIGN KEY(planId) REFERENCES ss_workout_plan(id) ON DELETE SET NULL
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_session_log_date '
      'ON ss_workout_session_log(startedAt);',
    );
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ss_session_log_prescription
      ON ss_workout_session_log(prescriptionId)
      WHERE prescriptionId IS NOT NULL;
    ''');

    // 5. ss_exercise_feeling_log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_exercise_feeling_log (
        id TEXT PRIMARY KEY,
        sessionLogId TEXT NOT NULL,
        exerciseId TEXT NOT NULL,
        feeling TEXT NOT NULL,
        loggedAt INTEGER NOT NULL,
        FOREIGN KEY(sessionLogId) REFERENCES ss_workout_session_log(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_feeling_session '
      'ON ss_exercise_feeling_log(sessionLogId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_feeling_exercise '
      'ON ss_exercise_feeling_log(exerciseId, loggedAt);',
    );

    // 6. ss_plan_version_history
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_plan_version_history (
        id TEXT PRIMARY KEY,
        serializedPlan TEXT NOT NULL,
        changeReason TEXT,
        createdAt INTEGER NOT NULL
      );
    ''');

    // 7. ss_exercise_similarity
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_exercise_similarity (
        exerciseId TEXT NOT NULL,
        similarExerciseId TEXT NOT NULL,
        similarityScore REAL NOT NULL,
        PRIMARY KEY(exerciseId, similarExerciseId),
        FOREIGN KEY(exerciseId) REFERENCES ss_exercise(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_similarity_main '
      'ON ss_exercise_similarity(exerciseId, similarityScore DESC);',
    );

    // 8. ss_user_profile
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_user_profile (
        id TEXT PRIMARY KEY DEFAULT 'default',
        goal TEXT NOT NULL,
        experienceLevel TEXT NOT NULL,
        trainingLocation TEXT NOT NULL,
        availableEquipment TEXT NOT NULL,
        daysPerWeek INTEGER DEFAULT 3,
        focusAreas TEXT,
        physicalLimitations TEXT,
        limitationNote TEXT,
        sessionDuration TEXT,
        gender TEXT,
        onboardingCompleted INTEGER DEFAULT 0,
        neighborFriendly INTEGER DEFAULT 0,
        programStartDate TEXT,
        deloadEveryNWeeks INTEGER DEFAULT 4,
        trainingDays TEXT,
        splitPattern TEXT DEFAULT 'AUTO',
        defaultIntensity TEXT DEFAULT 'MODERATE',
        usesExternalApp INTEGER DEFAULT 0,
        voiceCuesEnabled INTEGER DEFAULT 1,
        cycleConsentGranted INTEGER DEFAULT 0,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');

    await ensureUserProfileSchema(db);
    await ensurePrescriptionTables(db);
    await ensureLiveMovementSessionTables(db);
    await ensureSlotOverrideTable(db);
    await ensureMovementMuscleFocus(db);

    // 9. ss_decision_log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_decision_log (
        id TEXT PRIMARY KEY,
        userId TEXT DEFAULT 'default',
        sessionId TEXT,
        exerciseId TEXT,
        decisionType TEXT NOT NULL,
        rejectionReason TEXT,
        createdAt INTEGER NOT NULL
      );
    ''');

    // 10. ss_workout_set
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_workout_set (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        title_fa TEXT NOT NULL,
        description_fa TEXT,
        icon TEXT,
        focus TEXT, -- JSON structure
        difficulty_levels INTEGER,
        is_female_oriented INTEGER DEFAULT 0,
        sort_order INTEGER
      );
    ''');

    // 11. ss_exercise_set_suitability
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_exercise_set_suitability (
        exercise_id TEXT NOT NULL,
        set_code TEXT NOT NULL,
        suitability INTEGER NOT NULL,
        suitability_lowerbody INTEGER DEFAULT -1,
        suitability_abscore INTEGER DEFAULT -1,
        suitability_back INTEGER DEFAULT -1,
        suitability_upperbody INTEGER DEFAULT -1,
        difficulty INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        skill_required INTEGER DEFAULT -1,
        skill_max INTEGER DEFAULT -1,
        PRIMARY KEY(exercise_id, set_code)
      );
    ''');

    // 12. ss_ai_memory
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_ai_memory (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        confidence REAL DEFAULT 1.0,
        updatedAt INTEGER NOT NULL
      );
    ''');

    // 13. ss_workout_set_log
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_workout_set_log (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        set_index INTEGER NOT NULL,
        weight REAL NOT NULL,
        reps INTEGER NOT NULL,
        rir INTEGER,
        note TEXT,
        feeling TEXT,
        FOREIGN KEY(session_id) REFERENCES ss_workout_session_log(id) ON DELETE CASCADE
      );
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_workout_set_log_session '
      'ON ss_workout_set_log(session_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_set_log_exercise_time '
      'ON ss_workout_set_log(exercise_id, id);',
    );

    // 14. ss_daily_checkin
    await db.execute('''
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
  }

  /// Ensures all 21 columns of ss_user_profile exist on existing legacy databases safely.
  static Future<void> ensureUserProfileSchema(DatabaseExecutor db) async {
    await SchemaManager.safeAddColumn(db, 'ss_user_profile', 'programStartDate', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_user_profile', 'deloadEveryNWeeks', 'INTEGER DEFAULT 4');
    await SchemaManager.safeAddColumn(db, 'ss_user_profile', 'trainingDays', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_user_profile', 'splitPattern', "TEXT DEFAULT 'AUTO'");
    await SchemaManager.safeAddColumn(db, 'ss_user_profile', 'defaultIntensity', "TEXT DEFAULT 'MODERATE'");
    await SchemaManager.safeAddColumn(db, 'ss_user_profile', 'usesExternalApp', 'INTEGER DEFAULT 0');
    await SchemaManager.safeAddColumn(db, 'ss_user_profile', 'voiceCuesEnabled', 'INTEGER DEFAULT 1');
    await SchemaManager.safeAddColumn(db, 'ss_user_profile', 'cycleConsentGranted', 'INTEGER DEFAULT 0');
  }

  /// Ensures prescription tables exist on SQLite database safely.
  static Future<void> ensurePrescriptionTables(DatabaseExecutor db) async {
    // 1. ss_session_prescription
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_session_prescription (
        id TEXT PRIMARY KEY,
        dateIso TEXT NOT NULL,
        cycleWeek INTEGER NOT NULL,
        slotType TEXT NOT NULL,
        kindCode TEXT,
        routineId TEXT,
        plannedTime TEXT,
        sourceRef TEXT,
        focusCodes TEXT NOT NULL,
        targetMinutes INTEGER NOT NULL,
        intensityTier TEXT NOT NULL,
        targetRpe INTEGER,
        actualRpe INTEGER,
        headlineFa TEXT NOT NULL,
        coachNoteFa TEXT,
        source TEXT NOT NULL,
        isLocked INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PLANNED',
        movedToDateIso TEXT,
        legacyPlanId TEXT,
        workoutPlanId TEXT,
        workoutLogId TEXT,
        reasonKey TEXT,
        reasonParams TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      );
    ''');

    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'kindCode', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'routineId', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'plannedTime', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'sourceRef', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'reasonKey', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'reasonParams', 'TEXT');

    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_ss_prescription_date ON ss_session_prescription(dateIso);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_prescription_status ON ss_session_prescription(status, dateIso);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_prescription_plan ON ss_session_prescription(workoutPlanId, dateIso);',
    );

    // 2. ss_muscle_group
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ss_muscle_group (
        code TEXT PRIMARY KEY,
        titleFa TEXT NOT NULL,
        region TEXT NOT NULL,
        emoji TEXT,
        sortOrder INTEGER NOT NULL
      );
    ''');

    final muscleGroups = [
      ['CHEST', 'سینه', 'UPPER', '🫁', 1],
      ['SHOULDER', 'سرشانه', 'UPPER', '🎯', 2],
      ['BICEPS', 'جلوبازو', 'UPPER', '💪', 3],
      ['TRICEPS', 'پشت‌بازو', 'UPPER', '🦾', 4],
      ['BACK', 'زیربغل و پشت', 'UPPER', '🪽', 5],
      ['CORE', 'شکم و مرکز', 'CORE', '🎽', 6],
      ['QUADS_GLUTES', 'ران و باسن', 'LOWER', '🦵', 7],
      ['HAMSTRINGS', 'پشت ران', 'LOWER', '🦿', 8],
      ['CALVES', 'ساق پا', 'LOWER', '🎯', 9],
      ['CARDIO', 'هوازی', 'CARDIO', '🫀', 10],
      ['MOBILITY', 'تحرک و کشش', 'MOBILITY', '🧘', 11],
      ['FULL_BODY', 'کل بدن', 'FULL', '🔥', 12],
    ];

    for (final m in muscleGroups) {
      await db.insert(
        'ss_muscle_group',
        {
          'code': m[0],
          'titleFa': m[1],
          'region': m[2],
          'emoji': m[3],
          'sortOrder': m[4],
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // 3. station_bundles
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

    // 4. ss_plan_schedule
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

    // 5. ss_exercise_pr
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

    // 6. ss_session_set_log
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

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_set_log_exercise ON ss_session_set_log(exerciseId, loggedAt);',
    );

    // 7. movement_budget
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_budget (
          id TEXT PRIMARY KEY DEFAULT 'default',
          weeklyMetMinutesTarget REAL NOT NULL DEFAULT 500,
          weeklyActiveDaysTarget INTEGER NOT NULL DEFAULT 4,
          isAutoAdjusted INTEGER NOT NULL DEFAULT 1,
          updatedAt INTEGER NOT NULL
      );
    ''');

    // 8. movement_pr
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

    // 9. mv_commitments (S2-T1)
    await ensureCommitmentTables(db);
  }

  /// Ensures mv_commitments table and index exist safely.
  static Future<void> ensureCommitmentTables(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS mv_commitments (
          id                INTEGER PRIMARY KEY AUTOINCREMENT,
          kindCode          TEXT    NOT NULL,
          titleFa           TEXT,
          dayOfWeekSat0     INTEGER NOT NULL,
          startTime         TEXT    NOT NULL,
          durationMinutes   INTEGER NOT NULL,
          venueNote         TEXT,
          partnerNote       TEXT,
          recurrence        TEXT    NOT NULL DEFAULT 'WEEKLY',
          isActive          INTEGER NOT NULL DEFAULT 1,
          isFlexible        INTEGER NOT NULL DEFAULT 0,
          startDateIso      TEXT,
          endDateIso        TEXT,
          reminderMinutes   INTEGER,
          createdAt         TEXT    NOT NULL,
          updatedAt         TEXT    NOT NULL
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_mv_commitments_day ON mv_commitments(dayOfWeekSat0, isActive);
      ''');
    } catch (_) {}
  }

  /// Ensures mv_kind_profile table exists and is seeded.
  static Future<void> ensureKindProfileTables(DatabaseExecutor db) async {
    try {
      await MvKindProfileSeed.ensureSchema(db);
      await MvKindProfileSeed.ensureSeed(db);
    } catch (_) {}
  }

  /// Ensures movement_sessions, movement_session_events, and movement_campaigns tables exist safely.
  static Future<void> ensureLiveMovementSessionTables(DatabaseExecutor db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS movement_sessions (
          id            TEXT PRIMARY KEY,
          kindCode      TEXT NOT NULL,
          routineId     TEXT,
          occurrenceId  TEXT,
          prescriptionId TEXT,
          sessionMode   TEXT NOT NULL,
          status        TEXT NOT NULL,
          startedAt     INTEGER NOT NULL,
          endedAt       INTEGER,
          pausedMs      INTEGER NOT NULL DEFAULT 0,
          targetJson    TEXT,
          liveJson      TEXT,
          workoutLogId  TEXT,
          overallFeeling INTEGER,
          note          TEXT,
          distanceM     REAL,
          elevationGainM REAL,
          laps          INTEGER,
          packWeightKg  REAL,
          rpe1To10      INTEGER,
          effortSource  TEXT,
          routeId       INTEGER,
          createdAt     INTEGER NOT NULL,
          updatedAt     INTEGER NOT NULL
        );
      ''');

      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'overallFeeling', 'INTEGER');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'note', 'TEXT');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'distanceM', 'REAL');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'elevationGainM', 'REAL');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'laps', 'INTEGER');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'packWeightKg', 'REAL');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'rpe1To10', 'INTEGER');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'effortSource', 'TEXT');
      await SchemaManager.safeAddColumn(db, 'movement_sessions', 'routeId', 'INTEGER');

      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_movement_sessions_active
          ON movement_sessions(status) WHERE status IN ('ACTIVE', 'PAUSED');
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_movement_sessions_kind_date
          ON movement_sessions(kindCode, startedAt);
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS movement_session_events (
          id        TEXT PRIMARY KEY,
          sessionId TEXT NOT NULL,
          type      TEXT NOT NULL,
          at        INTEGER NOT NULL,
          dataJson  TEXT
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_mse_session
          ON movement_session_events(sessionId, at);
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS movement_campaigns (
          id           TEXT PRIMARY KEY,
          titleFa      TEXT NOT NULL,
          goalCode     TEXT NOT NULL,
          startDate    TEXT NOT NULL,
          weeks        INTEGER NOT NULL,
          status       TEXT NOT NULL,
          routineIds   TEXT NOT NULL,
          progressJson TEXT,
          createdAt    INTEGER NOT NULL,
          updatedAt    INTEGER NOT NULL
        );
      ''');
    } catch (_) {}
  }

  /// Tab 1 this-week exceptions. Mirrors migration v98 for fresh installs.
  static Future<void> ensureSlotOverrideTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_slot_overrides (
        id TEXT PRIMARY KEY,
        routineId TEXT NOT NULL,
        dateIso TEXT NOT NULL,
        action TEXT NOT NULL,
        newDateIso TEXT,
        newTime TEXT,
        createdAt INTEGER NOT NULL,
        UNIQUE(routineId, dateIso)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mso_date ON movement_slot_overrides(dateIso)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mso_routine ON movement_slot_overrides(routineId)',
    );
  }

  /// Tab 1 Phase 2: muscle focus on routines.
  static Future<void> ensureMovementMuscleFocus(DatabaseExecutor db) async {
    await SchemaManager.safeAddColumn(db, 'routines', 'movementMuscleFocus', 'TEXT');
  }

  /// Runs incremental, idempotent migrations M1–M7 for unified sports & movement architecture.
  static Future<void> migrateToUnifiedSchema(DatabaseExecutor db) async {
    // M1: Add kindCode, routineId, plannedTime, sourceRef to ss_session_prescription
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'kindCode', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'routineId', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'plannedTime', 'TEXT');
    await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'sourceRef', 'TEXT');

    // M3: Mirror ss_workout_session_log into movement_sessions
    try {
      final legacySessions = await db.rawQuery('SELECT * FROM ss_workout_session_log');
      for (final s in legacySessions) {
        final id = s['id']?.toString();
        if (id == null) continue;
        final existing = await db.rawQuery(
          'SELECT id FROM movement_sessions WHERE id = ? OR workoutLogId = ? LIMIT 1',
          [id, id],
        );
        if (existing.isEmpty) {
          final startedAt = (s['startedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
          final finishedAt = (s['finishedAt'] as num?)?.toInt();
          final durationSec = (s['durationSeconds'] as num?)?.toInt() ?? 0;
          final ended = finishedAt ?? (startedAt + durationSec * 1000);
          final presId = s['prescriptionId']?.toString();

          await db.insert(
            'movement_sessions',
            {
              'id': id,
              'kindCode': 'bodyweight',
              'prescriptionId': presId,
              'sessionMode': 'structured',
              'status': finishedAt != null ? 'COMPLETED' : 'ABANDONED',
              'startedAt': startedAt,
              'endedAt': ended,
              'pausedMs': 0,
              'workoutLogId': id,
              'createdAt': startedAt,
              'updatedAt': ended,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    } catch (_) {}

    // M4: Transfer ss_workout_set_log -> ss_session_set_log
    try {
      final legacySetLogs = await db.rawQuery('SELECT * FROM ss_workout_set_log');
      for (final setRow in legacySetLogs) {
        final id = setRow['id']?.toString() ?? 'set_${DateTime.now().millisecondsSinceEpoch}';
        final sessId = setRow['session_id']?.toString();
        final exId = setRow['exercise_id']?.toString();
        final setNum = (setRow['set_index'] as num?)?.toInt() ?? 1;
        final weight = (setRow['weight'] as num?)?.toDouble();
        final reps = (setRow['reps'] as num?)?.toInt();
        final rir = (setRow['rir'] as num?)?.toInt();

        if (sessId != null && exId != null) {
          await db.insert(
            'ss_session_set_log',
            {
              'id': id,
              'sessionId': sessId,
              'exerciseId': exId,
              'setNumber': setNum,
              'weight': weight,
              'reps': reps,
              'rir': rir,
              'durationSeconds': null,
              'isCompleted': 1,
              'loggedAt': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    } catch (_) {}

    // M5: Transfer ss_exercise_pr -> movement_pr
    try {
      final legacyPrs = await db.rawQuery('SELECT * FROM ss_exercise_pr');
      for (final pr in legacyPrs) {
        final id = pr['id']?.toString() ?? 'pr_${DateTime.now().millisecondsSinceEpoch}';
        final exId = pr['exerciseId']?.toString();
        final prType = pr['prType']?.toString() ?? 'maxWeight';
        final val = (pr['value'] as num?)?.toDouble() ?? 0.0;
        final sessId = pr['sessionId']?.toString();
        final achievedAt = (pr['achievedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

        if (exId != null) {
          await db.insert(
            'movement_pr',
            {
              'id': id,
              'kind': 'EXERCISE:$exId',
              'prType': prType,
              'value': val,
              'logId': sessId,
              'achievedAt': achievedAt,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    } catch (_) {}

    // M7: Ensure all hot path indexes
    try {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_ss_prescription_date ON ss_session_prescription(dateIso);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ss_prescription_status ON ss_session_prescription(status, dateIso);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ss_set_log_exercise ON ss_session_set_log(exerciseId, loggedAt);',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_movement_sessions_active ON movement_sessions(status) WHERE status IN (\'ACTIVE\', \'PAUSED\');',
      );
    } catch (_) {}
  }
}

