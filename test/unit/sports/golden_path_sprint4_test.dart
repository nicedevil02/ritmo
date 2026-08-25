import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_finish_session_use_case.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_start_session_use_case.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/mv_kind_profile_seed.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('S4-T8 Golden Path Sprint 4 Regression Harness Test', () {
    late Database db;
    late MvCommitmentRepository commitmentRepo;
    late MvKindRepository kindRepo;
    late MvKindProfileRepository kindProfileRepo;
    late MvSessionRepository sessionRepo;
    late MvPrescriptionRepository prescriptionRepo;
    late MvPrRepository prRepo;
    late MvRouteRepository routeRepo;
    late MvStartSessionUseCase startUseCase;
    late MvFinishSessionUseCase finishUseCase;

    const planEngine = PlanEngine();
    const budgetEngine = BudgetEngine();
    const loadEngine = LoadEngine();

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
          await d.execute('''
            CREATE TABLE IF NOT EXISTS ss_exercise (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              category TEXT NOT NULL,
              equipment TEXT,
              defaultReps INTEGER,
              difficulty TEXT
            );
          ''');
        },
      );

      // Seed 49 movement kinds and profiles
      await MovementKindsSeed.seed(db);
      await MvKindProfileSeed.ensureSchema(db);
      await MvKindProfileSeed.ensureSeed(db);

      commitmentRepo = MvCommitmentRepositoryImpl(db);
      kindRepo = MvKindRepository();
      kindProfileRepo = MvKindProfileRepositoryImpl(db);
      sessionRepo = MvSessionRepository(db);
      prescriptionRepo = MvPrescriptionRepository(db);
      prRepo = MvPrRepository(db);
      routeRepo = MvRouteRepository(db);

      startUseCase = MvStartSessionUseCase(
        sessionRepo: sessionRepo,
        kindRepo: kindRepo,
      );
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
      'Full E2E Lifecycle: Anchor Slot -> Route Mode Player -> Metrics & Hard RPE -> DB Saved -> Route Updated -> Weekly Budget Updated',
      () async {
        final now = DateTime(2026, 8, 28, 7, 0); // Friday of week 2026-08-22

        // 1. Create a saved Route «قله دارآباد»
        final savedRouteId = await routeRepo.insertRoute(
          const MvRoute(
            titleFa: 'قله دارآباد',
            kindCode: 'HIKING',
            distanceM: 12000.0,
            elevationGainM: 950.0,
            notes: 'مسیر یال شرقی و جان‌پناه',
            createdAt: '2026-08-01T06:00:00Z',
          ),
        );
        expect(savedRouteId, greaterThan(0));

        // 2. User has Friday Anchor commitment for HIKING (dayOfWeekSat0: 6 = Friday)
        await commitmentRepo.upsert(
          MvCommitment(
            kindCode: 'HIKING',
            titleFa: 'کوهنوردی جمعه',
            dayOfWeekSat0: 6,
            startTime: '07:00',
            durationMinutes: 180,
            recurrence: CommitmentRecurrence.weekly,
            isActive: true,
            createdAt: '2026-08-01T00:00:00Z',
            updatedAt: '2026-08-01T00:00:00Z',
          ),
        );

        // 3. Generate Week Plan via PlanEngine
        final profiles = await kindProfileRepo.getMapByCodes([
          'HIKING',
          'BODYWEIGHT',
          'STRETCHING',
          'RUNNING',
        ]);
        final commitments = await commitmentRepo.getActive();
        final kinds = await kindRepo.getMapByCodes([
          'HIKING',
          'BODYWEIGHT',
          'STRETCHING',
          'RUNNING',
        ]);

        final weekPlan = planEngine.generateWeek(
          weekStartSat: DateTime(2026, 8, 22),
          profile: MvUserProfile.empty(),
          commitments: commitments,
          overrides: const [],
          kinds: kinds,
          kindProfiles: profiles,
          budget: const MvBudgetSnapshot(
            moderateEquivalentMinutes: 0,
            rawMetMinutes: 0,
            strengthDays: 0,
            targetMin: 150,
            targetOptimal: 300,
            strengthDaysTarget: 2,
          ),
          load: null,
          readiness: MvReadinessTier.full,
        );

        // Friday slot (index 6) MUST be locked HIKING
        final fridaySlot = weekPlan.slots[6];
        expect(fridaySlot.isLocked, isTrue);
        expect(fridaySlot.kindCode, equals('HIKING'));
        expect(fridaySlot.slotType, equals(MvSlotType.outdoor));
        expect(fridaySlot.targetMinutes, equals(180));

        // 4. Start Session via MvStartSessionUseCase -> Mode is resolved to ROUTE
        final hikingKind = await kindRepo.getByCode('HIKING');
        expect(hikingKind, isNotNull);

        final startResult = await startUseCase.execute(
          slot: fridaySlot,
          profile: MvUserProfile.empty(),
        );
        final session = startResult.session;

        expect(session.sessionMode, equals(MvSessionMode.route));
        expect(session.status, equals(MvSessionStatus.active));

        // 5. Complete Session with all 7 metrics and Hard effort
        final startedAt = now.millisecondsSinceEpoch;
        final endedAt = startedAt + (180 * 60 * 1000); // 180 minutes

        final activeSession = session.copyWith(
          startedAt: startedAt,
          endedAt: endedAt,
        );

        await finishUseCase.execute(
          session: activeSession,
          distanceM: 12000.0,
          elevationGainM: 950.0,
          packWeightKg: 7.5,
          routeId: savedRouteId,
          rpe1To10: 8, // Hard effort
          effortSource: 'user',
          note: 'تمرین استقامتی فوق‌العاده در هوای مطبوع',
        );

        // 6. Verification: Database State
        final activeFromDb = await sessionRepo.getActiveSession();
        expect(
          activeFromDb,
          isNull,
          reason: 'Session must no longer be active',
        );

        final savedSession = await db.query(
          'movement_sessions',
          where: 'id = ?',
          whereArgs: [session.id],
        );
        expect(savedSession.isNotEmpty, isTrue);
        final row = savedSession.first;
        expect(row['status'], equals('COMPLETED'));
        expect(row['distanceM'], equals(12000.0));
        expect(row['elevationGainM'], equals(950.0));
        expect(row['packWeightKg'], equals(7.5));
        expect(row['routeId'], equals(savedRouteId));
        expect(row['rpe1To10'], equals(8));
        expect(row['effortSource'], equals('user'));
        expect(row['note'], equals('تمرین استقامتی فوق‌العاده در هوای مطبوع'));

        // Check sessionLoad computed getter
        final restoredSession = MvSession.fromMap(row);
        expect(restoredSession.sessionLoad, equals(8 * 180)); // 1440 sRPE

        // 7. Verification: Route Completion Statistics Updated
        final updatedRoute = await routeRepo.getRouteById(savedRouteId);
        expect(updatedRoute, isNotNull);
        expect(updatedRoute!.timesCompleted, equals(1));
        expect(updatedRoute.bestDurationMin, equals(180));
        expect(updatedRoute.lastDoneAt, isNotNull);

        // 8. Verification: Weekly WHO Activity Budget Updated
        final weeklySessions = [restoredSession];
        final budgetDecision = budgetEngine.calculateWeeklyProgress(
          weekCompletedSessions: weeklySessions,
          currentDayOfWeekSat0: 6,
          kindsByCode: kinds,
        );
        final progress = budgetDecision.value;

        // HIKING baseMet = 7.5 (> 6.0 vigorous) -> 180 min * 2.0 = 360 moderate equivalent min
        expect(progress.moderateEquivalentMinutes, equals(360));
        expect(progress.percentage, greaterThanOrEqualTo(1.0));

        // 9. Verification: LoadEngine ACWR & sRPE
        final loadSnapshot = loadEngine.computeLoadSnapshot(
          completedSessions: [restoredSession],
          daysOfHistory: 7,
          referenceDate: DateTime(2026, 8, 28, 12, 0),
        );
        expect(loadSnapshot.acuteLoad, equals(1440));
        // < 14 days history -> ratio is safely null
        expect(loadSnapshot.ratio, isNull);
      },
    );
  });
}
