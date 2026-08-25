import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MvSaveCommitmentUseCase Unit Tests (S2-T4)', () {
    late Database db;
    late MvCommitmentRepository commitmentRepo;
    late MvPrescriptionRepository prescriptionRepo;
    late MvProfileRepository profileRepo;
    late MvSaveCommitmentUseCase useCase;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await SupplementarySportsTables.create(db);
      await MovementKindsSeed.seed(db);
      commitmentRepo = MvCommitmentRepositoryImpl(db);
      prescriptionRepo = MvPrescriptionRepository(db);
      profileRepo = MvProfileRepository(db);
      useCase = MvSaveCommitmentUseCase(
        commitmentRepo: commitmentRepo,
        prescriptionRepo: prescriptionRepo,
        profileRepo: profileRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Saving with repeatWeekly creates MvCommitment and regenerates week slots',
      () async {
        final slot = MvSlot(
          id: 'slot_2026-08-27',
          dateIso: '2026-08-27', // پنجشنبه (dayOfWeekSat0 = 5)
          cycleWeek: 1,
          slotType: MvSlotType.sport,
          kindCode: 'FUTSAL',
          plannedTime: '21:00',
          targetMinutes: 90,
          intensityTier: MvIntensityTier.hard,
          headlineFa: 'فوتسال پنجشنبه‌ها',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        final result = await useCase.execute(
          slot: slot,
          repeatWeekly: true,
          venueNote: 'سالن تختی',
        );

        expect(result.isRecurring, isTrue);
        expect(result.commitment, isNotNull);
        expect(result.commitment!.kindCode, equals('FUTSAL'));
        expect(result.commitment!.dayOfWeekSat0, equals(5));
        expect(result.commitment!.startTime, equals('21:00'));
        expect(result.commitment!.durationMinutes, equals(90));
        expect(result.commitment!.venueNote, equals('سالن تختی'));
        expect(result.savedSlot.isLocked, isTrue);

        // Verify in DB
        final dbCommitments = await commitmentRepo.getAll();
        expect(dbCommitments.length, equals(1));
        expect(dbCommitments.first.kindCode, equals('FUTSAL'));

        // Verify week prescriptions exist in DB
        final weekSlots = await prescriptionRepo.getWeekSlots('2026-08-22');
        expect(weekSlots.isNotEmpty, isTrue);
      },
    );

    test(
      'Saving without repeatWeekly locks single slot without creating commitment',
      () async {
        final slot = MvSlot(
          id: 'slot_2026-08-28',
          dateIso: '2026-08-28',
          cycleWeek: 1,
          slotType: MvSlotType.cardio,
          kindCode: 'RUNNING',
          plannedTime: '07:00',
          targetMinutes: 45,
          intensityTier: MvIntensityTier.moderate,
          headlineFa: 'دویدن جمعه',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        final result = await useCase.execute(slot: slot, repeatWeekly: false);

        expect(result.isRecurring, isFalse);
        expect(result.commitment, isNull);
        expect(result.savedSlot.isLocked, isTrue);

        final dbCommitments = await commitmentRepo.getAll();
        expect(dbCommitments, isEmpty);
      },
    );
  });
}
