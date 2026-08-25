import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Unified Repositories CRUD Tests', () {
    late Database db;
    late MvPrescriptionRepository prescriptionRepo;
    late MvSessionRepository sessionRepo;
    late MvProfileRepository profileRepo;
    late MvExerciseRepository exerciseRepo;
    late MvPrRepository prRepo;
    late MvDailyCheckinRepository checkinRepo;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);

      prescriptionRepo = MvPrescriptionRepository(db);
      sessionRepo = MvSessionRepository(db);
      profileRepo = MvProfileRepository(db);
      exerciseRepo = MvExerciseRepository(db);
      prRepo = MvPrRepository(db);
      checkinRepo = MvDailyCheckinRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('MvPrescriptionRepository saves, retrieves and updates slot', () async {
      final slot = MvSlot(
        id: 'slot_1',
        dateIso: '2026-08-25',
        cycleWeek: 1,
        slotType: MvSlotType.strength,
        headlineFa: 'قدرت بالاتنه',
        createdAt: 1000,
        updatedAt: 1000,
      );

      await prescriptionRepo.savePrescription(slot);
      final retrieved = await prescriptionRepo.getPrescriptionForDate('2026-08-25');
      expect(retrieved, isNotNull);
      expect(retrieved!.headlineFa, equals('قدرت بالاتنه'));

      await prescriptionRepo.updateSlotStatus('slot_1', MvSlotStatus.done, actualRpe: 7);
      final updated = await prescriptionRepo.getPrescriptionForDate('2026-08-25');
      expect(updated!.isCompleted, isTrue);
      expect(updated.actualRpe, equals(7));
    });

    test('MvSessionRepository manages live session lifecycle and finish', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final session = MvSession(
        id: 'sess_1',
        kindCode: 'bodyweight',
        prescriptionId: 'slot_1',
        sessionMode: MvSessionMode.guided,
        status: MvSessionStatus.active,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await sessionRepo.startSession(session);
      final active = await sessionRepo.getActiveSession();
      expect(active, isNotNull);
      expect(active!.id, equals('sess_1'));

      final setLog = MvSetLog(
        id: 'set_1',
        sessionId: 'sess_1',
        exerciseId: 'push_up',
        setNumber: 1,
        reps: 12,
        loggedAt: now,
      );

      await sessionRepo.finishSession(
        active.copyWith(status: MvSessionStatus.completed),
        setLogs: [setLog],
        feeling: MvSessionFeeling.good,
        note: 'جلسهٔ عالی بود',
      );

      final activeAfterFinish = await sessionRepo.getActiveSession();
      expect(activeAfterFinish, isNull);

      final sets = await sessionRepo.getSetLogsForSession('sess_1');
      expect(sets.length, equals(1));
      expect(sets.first.reps, equals(12));
    });

    test('MvProfileRepository retrieves default profile and updates', () async {
      final profile = await profileRepo.getProfile();
      expect(profile.id, equals('default'));
      expect(profile.daysPerWeek, equals(3));

      final updated = profile.copyWith(daysPerWeek: 4, goal: 'fatLoss');
      await profileRepo.saveProfile(updated);

      final restored = await profileRepo.getProfile();
      expect(restored.daysPerWeek, equals(4));
      expect(restored.goal, equals('fatLoss'));
    });

    test('MvPrRepository saves and retrieves personal records', () async {
      const pr = MvPersonalRecord(
        id: 'pr_1',
        kind: 'EXERCISE:push_up',
        prType: MvPrType.maxReps,
        value: 30.0,
        achievedAt: 100000,
      );

      await prRepo.recordPr(pr);
      final found = await prRepo.getPrForKind('EXERCISE:push_up', MvPrType.maxReps);
      expect(found, isNotNull);
      expect(found!.value, equals(30.0));
      expect(found.isExercisePr, isTrue);
      expect(found.exerciseId, equals('push_up'));
    });

    test('MvDailyCheckinRepository saves and retrieves daily checkin', () async {
      final checkin = MvDailyCheckin(
        dateIso: '2026-08-25',
        energy: 4,
        soreness: 2,
        fatigue: 1,
        painLevel: 0,
        availableMinutes: 30,
        note: 'احساس عالی',
        createdAt: 1000,
        updatedAt: 1000,
      );

      await checkinRepo.saveCheckin(checkin);
      final retrieved = await checkinRepo.getCheckinForDate('2026-08-25');
      expect(retrieved, isNotNull);
      expect(retrieved!.energy, equals(4));
      expect(retrieved.availableMinutes, equals(30));
    });
  });
}
