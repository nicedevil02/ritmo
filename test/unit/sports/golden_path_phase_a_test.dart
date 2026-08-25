import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late MvProfileRepository profileRepo;
  late MvPrescriptionRepository prescriptionRepo;
  late MvSessionRepository sessionRepo;
  late MvPrRepository prRepo;
  late MvExerciseRepository exerciseRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // Initialize schema
    await SupplementarySportsTables.create(db);

    profileRepo = MvProfileRepository(db);
    prescriptionRepo = MvPrescriptionRepository(db);
    sessionRepo = MvSessionRepository(db);
    prRepo = MvPrRepository(db);
    exerciseRepo = MvExerciseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase A — Golden Path (Start to Summary)', () {
    test('Full Golden Path: Start Session -> Exercise Selection -> Set Logs -> Finish -> PR Breakthrough', () async {
      // 1. Setup profile and seed exercises
      await profileRepo.saveProfile(
        const MvUserProfile(
          id: 'default',
          onboardingCompleted: true,
          experienceLevel: 'beginner',
          daysPerWeek: 3,
          availableEquipment: ['bodyweight'],
          physicalLimitations: [],
          neighborFriendly: true,
          createdAt: 0,
          updatedAt: 0,
        ),
      );

      final testExercises = [
        const MvExercise(
          id: 'test_pushup',
          name: 'شنا سوئدی',
          category: 'CHEST',
          defaultReps: 15,
          durationSeconds: 0,
          noisy: false,
          impact: 1,
          toolsRequired: ['none'],
        ),
        const MvExercise(
          id: 'test_squat',
          name: 'اسکات با وزن بدن',
          category: 'LEGS',
          defaultReps: 20,
          durationSeconds: 0,
          noisy: false,
          impact: 1,
          toolsRequired: ['none'],
        ),
      ];

      for (final ex in testExercises) {
        await db.insert('ss_exercise', ex.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final todayIso = MvCalendar.formatDateIso(DateTime.now());
      final slot = MvSlot(
        id: 'slot_today',
        dateIso: todayIso,
        headlineFa: 'تمرین بالاتنه و سینه',
        focusCodes: const ['CHEST'],
        targetMinutes: 20,
        status: MvSlotStatus.planned,
        createdAt: 0,
        updatedAt: 0,
      );
      await prescriptionRepo.savePrescription(slot);

      // 2. Execute StartSessionUseCase
      final startUseCase = MvStartSessionUseCase(
        sessionRepo: sessionRepo,
        exerciseRepo: exerciseRepo,
      );

      final profile = await profileRepo.getProfile();
      final startResult = await startUseCase.execute(
        slot: slot,
        profile: profile,
        preloadedPool: testExercises,
      );

      expect(startResult.session.status, MvSessionStatus.active);
      expect(startResult.exercises.isNotEmpty, isTrue);
      expect(startResult.exercises.first.id, 'test_pushup');

      // Verify SESSION_START event recorded in DB
      final events = await sessionRepo.getEventsForSession(startResult.session.id);
      expect(events.length, 1);
      expect(events.first.type, 'SESSION_START');

      // 3. Complete Sets
      final now = DateTime.now().millisecondsSinceEpoch;
      final setLogs = [
        MvSetLog(
          id: 'set_1',
          sessionId: startResult.session.id,
          exerciseId: 'test_pushup',
          setNumber: 1,
          reps: 18, // Breakthrough over default 15
          loggedAt: now,
        ),
        MvSetLog(
          id: 'set_2',
          sessionId: startResult.session.id,
          exerciseId: 'test_pushup',
          setNumber: 2,
          reps: 16,
          loggedAt: now + 60000,
        ),
      ];

      // 4. Finish Session
      final finishUseCase = MvFinishSessionUseCase(
        sessionRepo: sessionRepo,
        prescriptionRepo: prescriptionRepo,
        prRepo: prRepo,
      );

      final completedSession = startResult.session.copyWith(
        status: MvSessionStatus.completed,
        endedAt: now + 120000,
      );

      final newPrs = await finishUseCase.execute(
        session: completedSession,
        setLogs: setLogs,
        feeling: MvSessionFeeling.good,
        note: 'تمرین عالی بود',
      );

      // Verify PR recorded
      expect(newPrs.length, 1);
      expect(newPrs.first.value, 18.0);
      expect(newPrs.first.prType, MvPrType.maxReps);

      // Verify Prescription slot marked done
      final updatedSlot = await prescriptionRepo.getPrescriptionForDate(todayIso);
      expect(updatedSlot?.status, MvSlotStatus.done);

      // Verify finish event recorded
      final allEvents = await sessionRepo.getEventsForSession(startResult.session.id);
      expect(allEvents.any((e) => e.type == 'SESSION_FINISH'), isTrue);
    });

    test('Crash Recovery: Active session is resumed on app re-open', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final activeSession = MvSession(
        id: 'sess_active_123',
        kindCode: 'strength',
        status: MvSessionStatus.active,
        startedAt: now - 300000,
        createdAt: now - 300000,
        updatedAt: now - 300000,
      );
      await sessionRepo.startSession(activeSession);

      final startUseCase = MvStartSessionUseCase(
        sessionRepo: sessionRepo,
        exerciseRepo: exerciseRepo,
      );

      final profile = await profileRepo.getProfile();
      final resumedResult = await startUseCase.execute(
        slot: const MvSlot(id: 's1', dateIso: '2026-08-25', headlineFa: 'T', createdAt: 0, updatedAt: 0),
        profile: profile,
        preloadedPool: const [
          MvExercise(id: 'e1', name: 'حرکت', category: 'CHEST'),
        ],
      );

      expect(resumedResult.session.id, 'sess_active_123');
      expect(resumedResult.session.status, MvSessionStatus.active);
    });
  });
}
