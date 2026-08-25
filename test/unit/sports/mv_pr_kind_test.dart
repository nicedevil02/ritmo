import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_finish_session_use_case.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('S5-T3 Kind-Specific Personal Record Tests', () {
    late Database db;
    late MvPrRepository prRepo;
    late MvSessionRepository sessionRepo;
    late MvFinishSessionUseCase finishUseCase;
    const progressionEngine = ProgressionEngine();

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
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
          await d.execute('''
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
          await d.execute('''
            CREATE TABLE IF NOT EXISTS movement_session_events (
              id TEXT PRIMARY KEY,
              sessionId TEXT NOT NULL,
              type TEXT NOT NULL,
              at INTEGER NOT NULL,
              dataJson TEXT
            );
          ''');
          await d.execute('''
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
              loggedAt INTEGER NOT NULL
            );
          ''');
          await d.execute('''
            CREATE TABLE IF NOT EXISTS ss_session_prescription (
              id TEXT PRIMARY KEY,
              dateIso TEXT NOT NULL UNIQUE,
              status TEXT NOT NULL,
              slotType TEXT NOT NULL,
              kindCode TEXT,
              targetMinutes INTEGER NOT NULL,
              intensityTier TEXT NOT NULL,
              targetLoad INTEGER,
              completedMinutes INTEGER,
              workoutLogId TEXT,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await d.execute('''
            CREATE TABLE IF NOT EXISTS mv_routes (
              id              INTEGER PRIMARY KEY AUTOINCREMENT,
              titleFa         TEXT    NOT NULL,
              kindCode        TEXT    NOT NULL,
              distanceM       REAL,
              elevationGainM  REAL,
              notes           TEXT,
              timesCompleted  INTEGER NOT NULL DEFAULT 0,
              bestDurationMin INTEGER,
              lastDoneAt      TEXT,
              createdAt       TEXT    NOT NULL
            );
          ''');
        },
      );

      prRepo = MvPrRepository(db);
      sessionRepo = MvSessionRepository(db);
      finishUseCase = MvFinishSessionUseCase(
        sessionRepo: sessionRepo,
        prRepo: prRepo,
        progressionEngine: progressionEngine,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Two hiking sessions with 600m and 780m elevation gain update HIKING elevation PR to 780m while FUTSAL PR remains untouched', () async {
      // 1. Initial FUTSAL duration PR
      await prRepo.recordPr(
        const MvPersonalRecord(
          id: 'pr_futsal_duration',
          kind: 'FUTSAL',
          prType: MvPrType.longestDuration,
          value: 90.0,
          achievedAt: 1700000000,
        ),
      );

      // 2. First HIKING session: elevation = 600m
      const hikeSession1 = MvSession(
        id: 'sess_hike_600',
        kindCode: 'HIKING',
        sessionMode: MvSessionMode.route,
        status: MvSessionStatus.active,
        startedAt: 1700100000,
        endedAt: 1700100000 + (120 * 60 * 1000), // 120 min
        elevationGainM: 600.0,
        distanceM: 7000.0,
        createdAt: 1700100000,
        updatedAt: 1700100000,
      );
      await sessionRepo.startSession(hikeSession1);

      final prs1 = await finishUseCase.execute(
        session: hikeSession1,
        elevationGainM: 600.0,
        distanceM: 7000.0,
      );

      expect(prs1.any((p) => p.kind == 'HIKING' && p.prType == MvPrType.maxElevation && p.value == 600.0), isTrue);

      final hikePrAfter1 = await prRepo.getPrForKind('HIKING', MvPrType.maxElevation);
      expect(hikePrAfter1, isNotNull);
      expect(hikePrAfter1!.value, equals(600.0));

      // 3. Second HIKING session: elevation = 780m (PR breakthrough!)
      const hikeSession2 = MvSession(
        id: 'sess_hike_780',
        kindCode: 'HIKING',
        sessionMode: MvSessionMode.route,
        status: MvSessionStatus.active,
        startedAt: 1700200000,
        endedAt: 1700200000 + (150 * 60 * 1000),
        elevationGainM: 780.0,
        distanceM: 8500.0,
        createdAt: 1700200000,
        updatedAt: 1700200000,
      );
      await sessionRepo.startSession(hikeSession2);

      final prs2 = await finishUseCase.execute(
        session: hikeSession2,
        elevationGainM: 780.0,
        distanceM: 8500.0,
      );

      expect(prs2.any((p) => p.kind == 'HIKING' && p.prType == MvPrType.maxElevation && p.value == 780.0), isTrue);

      final hikePrAfter2 = await prRepo.getPrForKind('HIKING', MvPrType.maxElevation);
      expect(hikePrAfter2, isNotNull);
      expect(hikePrAfter2!.value, equals(780.0));

      // 4. Verify FUTSAL PR remains completely isolated and untouched
      final futsalPr = await prRepo.getPrForKind('FUTSAL', MvPrType.longestDuration);
      expect(futsalPr, isNotNull);
      expect(futsalPr!.value, equals(90.0));
      expect(futsalPr.kind, equals('FUTSAL'));

      final futsalElevationPr = await prRepo.getPrForKind('FUTSAL', MvPrType.maxElevation);
      expect(futsalElevationPr, isNull);
    });

    test('ProgressionEngine evaluates 5 distinct sport metric PRs accurately', () {
      const session = MvSession(
        id: 'sess_run_1',
        kindCode: 'RUNNING',
        sessionMode: MvSessionMode.distance,
        status: MvSessionStatus.completed,
        startedAt: 1700000000,
        endedAt: 1700000000 + (30 * 60 * 1000), // 30 min (1800s)
        distanceM: 6000.0, // 6km -> pace = 1800 / 6 = 300 sec/km
        createdAt: 1700000000,
        updatedAt: 1700000000,
      );

      final newPrs = progressionEngine.evaluateSessionRecords(
        session: session,
        existingPrsForKind: [],
      );

      expect(newPrs.any((p) => p.prType == MvPrType.longestDuration && p.value == 30.0), isTrue);
      expect(newPrs.any((p) => p.prType == MvPrType.longestDistance && p.value == 6000.0), isTrue);
      expect(newPrs.any((p) => p.prType == MvPrType.bestPace5k && p.value == 300.0), isTrue);
    });
  });
}
