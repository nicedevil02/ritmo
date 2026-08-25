import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۲۱: یکپارچه‌سازی نهایی ورزش تکمیلی و حرکت (M1 تا M7)
///
/// اهداف:
/// - M1: ستون‌های تکمیلی جدول `ss_session_prescription` و ایندکس‌های تقویمی
/// - M2: تبدیل سوابق روتین‌های فیتنس (`category = 'fitness'`) به اسلات‌های تقویم روز
/// - M3: انتقال سوابق جلسات از `ss_workout_session_log` به `movement_sessions`
/// - M4: انتقال سوابق ست‌ها از `ss_workout_set_log` به `ss_session_set_log`
/// - M5: تجمیع رکوردهای شخصی از `ss_exercise_pr` به `movement_pr`
/// - M6: استانداردسازی کلید خارجی `ss_session_set_log` به `movement_sessions`
/// - M7: افزودن فیلدهای `voiceCuesEnabled` و `cycleConsentGranted` به `ss_user_profile`
class MigrationV121SportsUnification extends Migration {
  @override
  int get version => 121;

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    // Non-destructive down
  }

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV121SportsUnification', 'Starting M1-M7 sports unification migration...');

    // M1: Ensure ss_session_prescription columns & indexes exist
    await _applyM1PrescriptionColumns(db);

    // M7: Ensure ss_user_profile columns exist
    await _applyM7ProfileColumns(db);

    // Ensure unified tables exist
    await _ensureUnifiedTablesExist(db);

    // M2: Migrate category='fitness' routine completions to prescription slots
    await _applyM2FitnessRoutinesToSlots(db);

    // M3: Migrate ss_workout_session_log -> movement_sessions
    await _applyM3SessionsMigration(db);

    // M4: Migrate ss_workout_set_log -> ss_session_set_log
    await _applyM4SetLogsMigration(db);

    // M5: Migrate ss_exercise_pr -> movement_pr
    await _applyM5PersonalRecordsMigration(db);

    RitmoLog.info('MigrationV121SportsUnification', 'M1-M7 sports unification migration completed successfully.');
  }

  Future<void> _applyM1PrescriptionColumns(DatabaseExecutor db) async {
    final tableInfo = await db.rawQuery("PRAGMA table_info('ss_session_prescription');");
    if (tableInfo.isEmpty) return;

    final existingCols = tableInfo.map((c) => (c['name'] as String).toLowerCase()).toSet();

    final colsToAdd = {
      'kindcode': 'ALTER TABLE ss_session_prescription ADD COLUMN kindCode TEXT;',
      'dayofweeksat0': 'ALTER TABLE ss_session_prescription ADD COLUMN dayOfWeekSat0 INTEGER DEFAULT 0;',
      'movedtodateiso': 'ALTER TABLE ss_session_prescription ADD COLUMN movedToDateIso TEXT;',
      'intensitytier': 'ALTER TABLE ss_session_prescription ADD COLUMN intensityTier TEXT DEFAULT \'MODERATE\';',
      'targetrpe': 'ALTER TABLE ss_session_prescription ADD COLUMN targetRpe REAL DEFAULT 7.0;',
      'coachnotefa': 'ALTER TABLE ss_session_prescription ADD COLUMN coachNoteFa TEXT;',
      'actualrpe': 'ALTER TABLE ss_session_prescription ADD COLUMN actualRpe REAL;',
      'actualrir': 'ALTER TABLE ss_session_prescription ADD COLUMN actualRir INTEGER;',
      'actualfeeling': 'ALTER TABLE ss_session_prescription ADD COLUMN actualFeeling TEXT;',
    };

    for (final entry in colsToAdd.entries) {
      if (!existingCols.contains(entry.key)) {
        try {
          await db.execute(entry.value);
        } catch (e) {
          RitmoLog.warn('MigrationV121SportsUnification', 'Column ${entry.key} could not be added: $e');
        }
      }
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_prescription_date ON ss_session_prescription(dateIso);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ss_prescription_cycle_day ON ss_session_prescription(cycleWeek, dayOfWeekSat0);',
    );
  }

  Future<void> _applyM7ProfileColumns(DatabaseExecutor db) async {
    final tableInfo = await db.rawQuery("PRAGMA table_info('ss_user_profile');");
    if (tableInfo.isEmpty) return;

    final existingCols = tableInfo.map((c) => (c['name'] as String).toLowerCase()).toSet();

    if (!existingCols.contains('voicecuesenabled')) {
      try {
        await db.execute('ALTER TABLE ss_user_profile ADD COLUMN voiceCuesEnabled INTEGER DEFAULT 1;');
      } catch (e) {
        RitmoLog.warn('MigrationV121SportsUnification', 'voiceCuesEnabled column could not be added: $e');
      }
    }

    if (!existingCols.contains('cycleconsentgranted')) {
      try {
        await db.execute('ALTER TABLE ss_user_profile ADD COLUMN cycleConsentGranted INTEGER DEFAULT 0;');
      } catch (e) {
        RitmoLog.warn('MigrationV121SportsUnification', 'cycleConsentGranted column could not be added: $e');
      }
    }
  }

  Future<void> _ensureUnifiedTablesExist(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_sessions (
        id TEXT PRIMARY KEY,
        kindCode TEXT NOT NULL,
        prescriptionId TEXT,
        customTitle TEXT,
        sessionMode TEXT NOT NULL DEFAULT 'GUIDED',
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        startedAt INTEGER NOT NULL,
        endedAt INTEGER,
        pausedMs INTEGER DEFAULT 0,
        overallFeeling TEXT,
        note TEXT,
        targetJson TEXT,
        liveJson TEXT,
        workoutLogId TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
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
        durationSeconds INTEGER,
        rpe REAL,
        rir INTEGER,
        loggedAt INTEGER NOT NULL,
        FOREIGN KEY (sessionId) REFERENCES movement_sessions(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_pr (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        prType TEXT NOT NULL,
        value REAL NOT NULL,
        secondaryValue REAL,
        logId TEXT,
        achievedAt INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS movement_session_events (
        id TEXT PRIMARY KEY,
        sessionId TEXT NOT NULL,
        type TEXT NOT NULL,
        at INTEGER NOT NULL,
        dataJson TEXT,
        FOREIGN KEY (sessionId) REFERENCES movement_sessions(id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> _applyM2FitnessRoutinesToSlots(DatabaseExecutor db) async {
    final routinesTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='routine_completions';");
    if (routinesTable.isEmpty) return;

    try {
      final fitnessCompletions = await db.rawQuery('''
        SELECT rc.*, r.title, r.category 
        FROM routine_completions rc
        JOIN routines r ON rc.routine_id = r.id
        WHERE r.category = 'fitness' OR r.category = 'sports'
      ''');

      for (final row in fitnessCompletions) {
        final completedDate = row['date'] as String? ?? '';
        if (completedDate.isEmpty) continue;

        final existing = await db.query(
          'ss_session_prescription',
          where: 'dateIso = ?',
          whereArgs: [completedDate],
          limit: 1,
        );

        if (existing.isEmpty) {
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.insert('ss_session_prescription', {
            'id': 'routine_slot_$completedDate',
            'dateIso': completedDate,
            'cycleWeek': 1,
            'dayOfWeekSat0': 0,
            'slotType': 'STRENGTH',
            'kindCode': 'bodyweight',
            'focusCodes': '["FULL_BODY"]',
            'targetMinutes': 20,
            'intensityTier': 'MODERATE',
            'targetRpe': 7.0,
            'headlineFa': row['title'] as String? ?? 'ورزش روزانه',
            'source': 'ROUTINE_CONVERSION',
            'status': 'DONE',
            'workoutLogId': row['id'] as String?,
            'createdAt': now,
            'updatedAt': now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    } catch (e) {
      RitmoLog.warn('MigrationV121SportsUnification', 'M2 routine conversion error: $e');
    }
  }

  Future<void> _applyM3SessionsMigration(DatabaseExecutor db) async {
    final hasOldTable = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ss_workout_session_log';")).isNotEmpty;
    if (!hasOldTable) return;

    try {
      final oldLogs = await db.query('ss_workout_session_log');
      for (final old in oldLogs) {
        final id = old['id'] as String;
        final durationSeconds = (old['durationSeconds'] as num?)?.toInt() ?? 0;
        final timestamp = (old['timestamp'] as num?)?.toInt() ?? (old['startedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

        await db.insert('movement_sessions', {
          'id': id,
          'kindCode': 'strength',
          'prescriptionId': old['planId'] as String?,
          'sessionMode': 'GUIDED',
          'status': 'COMPLETED',
          'startedAt': timestamp,
          'endedAt': timestamp + (durationSeconds * 1000),
          'overallFeeling': old['feeling'] as String?,
          'note': old['note'] as String?,
          'workoutLogId': id,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      RitmoLog.warn('MigrationV121SportsUnification', 'M3 sessions migration error: $e');
    }
  }

  Future<void> _applyM4SetLogsMigration(DatabaseExecutor db) async {
    final hasOldSetTable = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ss_workout_set_log';")).isNotEmpty;
    if (!hasOldSetTable) return;

    try {
      final oldSets = await db.query('ss_workout_set_log');
      for (final old in oldSets) {
        final id = old['id'] as String;
        final sessionId = (old['workoutSessionLogId'] as String?) ?? (old['sessionId'] as String?) ?? '';
        if (sessionId.isEmpty) continue;

        await db.insert('ss_session_set_log', {
          'id': id,
          'sessionId': sessionId,
          'exerciseId': old['exerciseId'] as String? ?? 'unknown',
          'setNumber': (old['setIndex'] as num?)?.toInt() ?? (old['setNumber'] as num?)?.toInt() ?? 1,
          'weight': (old['weightKg'] as num?)?.toDouble() ?? (old['weight'] as num?)?.toDouble(),
          'reps': (old['reps'] as num?)?.toInt(),
          'durationSeconds': (old['durationSeconds'] as num?)?.toInt(),
          'rpe': (old['rpe'] as num?)?.toDouble(),
          'rir': (old['rir'] as num?)?.toInt(),
          'loggedAt': (old['loggedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      RitmoLog.warn('MigrationV121SportsUnification', 'M4 set logs migration error: $e');
    }
  }

  Future<void> _applyM5PersonalRecordsMigration(DatabaseExecutor db) async {
    final hasOldPrTable = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='ss_exercise_pr';")).isNotEmpty;
    if (!hasOldPrTable) return;

    try {
      final oldPrs = await db.query('ss_exercise_pr');
      for (final old in oldPrs) {
        final id = old['id'] as String;
        final exerciseId = old['exerciseId'] as String? ?? '';
        final prType = old['prType'] as String? ?? 'MAX_REPS';
        final val = (old['value'] as num?)?.toDouble() ?? 0.0;
        final achievedAt = (old['achievedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

        await db.insert('movement_pr', {
          'id': id,
          'kind': 'EXERCISE:$exerciseId',
          'prType': prType,
          'value': val,
          'secondaryValue': (old['secondaryValue'] as num?)?.toDouble(),
          'logId': old['workoutLogId'] as String?,
          'achievedAt': achievedAt,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      RitmoLog.warn('MigrationV121SportsUnification', 'M5 PRs migration error: $e');
    }
  }
}
