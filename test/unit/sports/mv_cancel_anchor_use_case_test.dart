import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MvCancelAnchorUseCase & S2-T7 Unit Tests', () {
    late Database db;
    late MvCommitmentRepository commitmentRepo;
    late MvSlotOverrideRepository overrideRepo;
    late MvPrescriptionRepository prescriptionRepo;
    late MvCancelAnchorUseCase cancelAnchorUseCase;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);

      commitmentRepo = MvCommitmentRepositoryImpl(db);
      overrideRepo = MvSlotOverrideRepositoryImpl(db);
      prescriptionRepo = MvPrescriptionRepository(db);
      cancelAnchorUseCase = MvCancelAnchorUseCase(
        overrideRepo: overrideRepo,
        prescriptionRepo: prescriptionRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Cancelling Thursday anchor slot writes override, preserves commitment isActive == 1, compensates upcoming slot',
      () async {
        // 1. Create active commitment for Thursday (Sat0 = 5)
        final commitment = MvCommitment(
          kindCode: 'FUTSAL',
          titleFa: 'فوتسال پنجشنبه‌ها',
          dayOfWeekSat0: 5,
          startTime: '21:00',
          durationMinutes: 60,
          isActive: true,
        );
        final savedCommitment = await commitmentRepo.upsert(commitment);
        expect(savedCommitment.isActive, isTrue);

        // 2. Initial week slots with Thursday locked anchor and Friday rest
        final thurSlot = MvSlot(
          id: 'slot_2026-08-27',
          dateIso: '2026-08-27', // پنجشنبه
          cycleWeek: 1,
          slotType: MvSlotType.sport,
          kindCode: 'FUTSAL',
          headlineFa: 'فوتسال',
          targetMinutes: 60,
          plannedTime: '21:00',
          isLocked: true,
          intensityTier: MvIntensityTier.hard,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        final friSlot = MvSlot(
          id: 'slot_2026-08-28',
          dateIso: '2026-08-28', // جمعه
          cycleWeek: 1,
          slotType: MvSlotType.rest,
          headlineFa: 'استراحت',
          targetMinutes: 0,
          isLocked: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        final initialSlots = [thurSlot, friSlot];
        for (final s in initialSlots) {
          await prescriptionRepo.savePrescription(s);
        }

        // 3. Cancel Thursday anchor for this week
        final result = await cancelAnchorUseCase.cancelAnchorThisWeek(
          anchorSlot: thurSlot,
          currentWeekSlots: initialSlots,
        );

        // 4. Assert override record exists
        final overrides = await overrideRepo.getForRoutine('FUTSAL');
        expect(overrides, isNotEmpty);
        expect(overrides.first.action, equals('CANCEL_ANCHOR'));
        expect(overrides.first.dateIso, equals('2026-08-27'));

        // 5. Assert original commitment isActive remains true
        final retrievedCommitment = await commitmentRepo.getById(
          savedCommitment.id!,
        );
        expect(retrievedCommitment, isNotNull);
        expect(retrievedCommitment!.isActive, isTrue);

        // 6. Assert Thursday slot status is skipped & isLocked is false
        final updatedThur = result.updatedWeekSlots.firstWhere(
          (s) => s.dateIso == '2026-08-27',
        );
        expect(updatedThur.status, equals(MvSlotStatus.skipped));
        expect(updatedThur.isLocked, isFalse);

        // 7. Assert Friday slot was compensated (converted to training / minutes added)
        final updatedFri = result.updatedWeekSlots.firstWhere(
          (s) => s.dateIso == '2026-08-28',
        );
        expect(updatedFri.targetMinutes, greaterThan(0));
        expect(result.replacedMinutes, greaterThan(0));
        expect(result.replacedOnWeekday, equals('جمعه'));
        expect(result.feedbackFa, contains('دقیقه تمرین به روز جمعه اضافه شد'));
        expect(result.suggestDeactivate, isFalse);
      },
    );

    test(
      'Suggests deactivation when cancelled 3 times within 4 consecutive weeks',
      () async {
        const routineId = 'FUTSAL';

        // Insert 2 previous cancellations in the last 20 days
        final now = DateTime.parse('2026-08-27');
        await overrideRepo.insert(
          MvSlotOverride(
            id: 'prev_1',
            routineId: routineId,
            dateIso: '2026-08-13',
            action: 'CANCEL_ANCHOR',
            createdAt: now
                .subtract(const Duration(days: 14))
                .millisecondsSinceEpoch,
          ),
        );
        await overrideRepo.insert(
          MvSlotOverride(
            id: 'prev_2',
            routineId: routineId,
            dateIso: '2026-08-20',
            action: 'CANCEL_ANCHOR',
            createdAt: now
                .subtract(const Duration(days: 7))
                .millisecondsSinceEpoch,
          ),
        );

        final thurSlot = MvSlot(
          id: 'slot_2026-08-27',
          dateIso: '2026-08-27',
          cycleWeek: 1,
          slotType: MvSlotType.sport,
          kindCode: 'FUTSAL',
          headlineFa: 'فوتسال',
          targetMinutes: 60,
          isLocked: true,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        );

        final result = await cancelAnchorUseCase.cancelAnchorThisWeek(
          anchorSlot: thurSlot,
          currentWeekSlots: [thurSlot],
        );

        // 3rd cancellation within 4 weeks -> suggestDeactivate must be true
        expect(result.suggestDeactivate, isTrue);
      },
    );
  });
}
