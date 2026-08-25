import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_finish_session_use_case.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('S4-T7 MvRoute & Recurring Routes Repository Tests', () {
    late Database db;
    late MvRouteRepository routeRepo;
    late MvSessionRepository sessionRepo;
    late MvPrescriptionRepository prescriptionRepo;
    late MvPrRepository prRepo;
    late MvFinishSessionUseCase finishUseCase;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (d, v) async {
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
            CREATE TABLE IF NOT EXISTS movement_session_events (
              id TEXT PRIMARY KEY,
              sessionId TEXT NOT NULL,
              type TEXT NOT NULL,
              at INTEGER NOT NULL,
              dataJson TEXT
            );
          ''');
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
        },
      );

      routeRepo = MvRouteRepository(db);
      sessionRepo = MvSessionRepository(db);
      prescriptionRepo = MvPrescriptionRepository(db);
      prRepo = MvPrRepository(db);
      finishUseCase = MvFinishSessionUseCase(
        sessionRepo: sessionRepo,
        prescriptionRepo: prescriptionRepo,
        prRepo: prRepo,
        routeRepo: routeRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Inserting route and completing it twice updates timesCompleted and bestDurationMin accurately',
      () async {
        // 1. Insert route «دارآباد»
        const newRoute = MvRoute(
          titleFa: 'دارآباد',
          kindCode: 'HIKING',
          distanceM: 11000.0,
          elevationGainM: 850.0,
          notes: 'مسیر صخره‌ای و چشمه درازلش',
          createdAt: '2026-08-01T08:00:00Z',
        );

        final routeId = await routeRepo.insertRoute(newRoute);
        expect(routeId, greaterThan(0));

        final initial = await routeRepo.getRouteById(routeId);
        expect(initial, isNotNull);
        expect(initial!.titleFa, equals('دارآباد'));
        expect(initial.timesCompleted, equals(0));
        expect(initial.bestDurationMin, isNull);

        // 2. First completion: duration = 240 minutes
        await routeRepo.recordRouteCompletion(
          routeId: routeId,
          durationMin: 240,
          completedAt: DateTime(2026, 8, 10, 14, 0),
        );

        final afterFirst = await routeRepo.getRouteById(routeId);
        expect(afterFirst!.timesCompleted, equals(1));
        expect(afterFirst.bestDurationMin, equals(240));
        expect(afterFirst.lastDoneAt, contains('2026-08-10'));

        // 3. Second completion: duration = 225 minutes (PR breakthrough!)
        await routeRepo.recordRouteCompletion(
          routeId: routeId,
          durationMin: 225,
          completedAt: DateTime(2026, 8, 25, 14, 0),
        );

        final afterSecond = await routeRepo.getRouteById(routeId);
        expect(afterSecond!.timesCompleted, equals(2));
        expect(afterSecond.bestDurationMin, equals(225));
        expect(afterSecond.lastDoneAt, contains('2026-08-25'));
      },
    );

    test(
      'Finish session use case automatically updates linked route stats when routeId is provided',
      () async {
        // Create route
        final rId = await routeRepo.insertRoute(
          const MvRoute(
            titleFa: 'توچال به شیرپلا',
            kindCode: 'HIKING',
            distanceM: 7500.0,
            elevationGainM: 950.0,
            createdAt: '2026-08-01T06:00:00Z',
          ),
        );

        final session = MvSession(
          id: 'sess_hike_1',
          kindCode: 'HIKING',
          sessionMode: MvSessionMode.route,
          status: MvSessionStatus.active,
          startedAt: 1700000000,
          endedAt: 1700000000 + (180 * 60 * 1000), // 180 min
          distanceM: 7500.0,
          elevationGainM: 950.0,
          packWeightKg: 6.0,
          routeId: rId,
          createdAt: 1700000000,
          updatedAt: 1700000000,
        );

        await sessionRepo.startSession(session);

        // Finish session via UseCase
        await finishUseCase.execute(
          session: session,
          rpe1To10: 8,
          effortSource: 'user',
          note: 'هوای عالی و مسیر خلوت',
        );

        final updatedRoute = await routeRepo.getRouteById(rId);
        expect(updatedRoute, isNotNull);
        expect(updatedRoute!.timesCompleted, equals(1));
        expect(updatedRoute.bestDurationMin, equals(180));
      },
    );

    test(
      'getRoutesForKind filters and sorts routes by completion count and recency',
      () async {
        await routeRepo.insertRoute(
          const MvRoute(
            titleFa: 'مسیر ۱ پیاده‌روی',
            kindCode: 'BRISK_WALKING',
            distanceM: 5000.0,
            timesCompleted: 1,
            createdAt: '2026-08-01T06:00:00Z',
          ),
        );
        await routeRepo.insertRoute(
          const MvRoute(
            titleFa: 'مسیر ۲ پیاده‌روی',
            kindCode: 'BRISK_WALKING',
            distanceM: 8000.0,
            timesCompleted: 5,
            createdAt: '2026-08-02T06:00:00Z',
          ),
        );
        await routeRepo.insertRoute(
          const MvRoute(
            titleFa: 'مسیر کوه کلک‌چال',
            kindCode: 'HIKING',
            distanceM: 10000.0,
            timesCompleted: 3,
            createdAt: '2026-08-03T06:00:00Z',
          ),
        );

        final walkingRoutes = await routeRepo.getRoutesForKind('BRISK_WALKING');
        expect(walkingRoutes.length, equals(2));
        expect(
          walkingRoutes.first.titleFa,
          equals('مسیر ۲ پیاده‌روی'),
        ); // 5 completions first
        expect(walkingRoutes.last.titleFa, equals('مسیر ۱ پیاده‌روی'));

        final hikingRoutes = await routeRepo.getRoutesForKind('HIKING');
        expect(hikingRoutes.length, equals(1));
        expect(hikingRoutes.first.titleFa, equals('مسیر کوه کلک‌چال'));
      },
    );
  });
}
