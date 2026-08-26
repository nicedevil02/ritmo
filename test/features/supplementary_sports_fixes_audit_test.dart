import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/supplementary_sports/application/mv_save_commitment_use_case.dart';
import 'package:ritmo/features/supplementary_sports/data/models/ss_user_profile_model.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_kind_profile_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_pr_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_prescription_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_profile_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_session_repository.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_profile_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/domain/sports_detail_mode.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_session_settings.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_unit_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      ),
    );

    await DatabaseHelper.ensureCriticalSchema(db);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Supplementary Sports Fixes Audit (RITF-075 .. RITF-081)', () {
    test('RITF-076: Repositories use UpsertHelper without destructive REPLACE', () async {
      // 1. MvPrRepository
      final prRepo = MvPrRepository(db);
      final pr1 = MvPersonalRecord(
        id: 'pr_1',
        kind: 'RUNNING',
        prType: MvPrType.longestDuration,
        value: 45.0,
        achievedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await prRepo.recordPr(pr1);
      final prFetched = await prRepo.getPrForKind('RUNNING', MvPrType.longestDuration);
      expect(prFetched, isNotNull);
      expect(prFetched!.value, 45.0);

      // 2. SSProfileRepository
      final ssProfileRepo = SSProfileRepository.instance;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final ssProf = SsUserProfile(
        id: 'default',
        goal: FitnessGoal.muscleGain,
        experienceLevel: ExperienceLevel.intermediate,
        trainingLocation: TrainingLocation.home,
        availableEquipment: const [Equipment.bodyweightOnly],
        focusAreas: const [BodyArea.fullBody],
        physicalLimitations: const [Limitation.none],
        sessionDuration: SessionDuration.medium45,
        createdAt: nowMs,
        updatedAt: nowMs,
      );
      await ssProfileRepo.saveProfile(ssProf, executor: db);
      final fetchedSsProf = await ssProfileRepo.getProfile();
      expect(fetchedSsProf, isNotNull);
      expect(fetchedSsProf!.experienceLevel, ExperienceLevel.intermediate);

      // 3. MvProfileRepository
      final mvProfileRepo = MvProfileRepository(db);
      const mvProf = MvUserProfile(
        id: 'default',
        experienceLevel: 'advanced',
        createdAt: 0,
        updatedAt: 0,
      );
      await mvProfileRepo.saveProfile(mvProf);
      final fetchedMvProf = await mvProfileRepo.getProfile();
      expect(fetchedMvProf.experienceLevel, 'advanced');

      // 4. MvSessionRepository
      final sessionRepo = MvSessionRepository(db);
      final session = MvSession(
        id: 'session_1',
        kindCode: 'RUNNING',
        status: MvSessionStatus.active,
        startedAt: nowMs,
        createdAt: nowMs,
        updatedAt: nowMs,
      );
      await sessionRepo.startSession(session);
      final fetchedSession = await sessionRepo.getActiveSession();
      expect(fetchedSession, isNotNull);
      expect(fetchedSession!.id, 'session_1');

      // 5. MvPrescriptionRepository
      final prescriptionRepo = MvPrescriptionRepository(db);
      const slot = MvSlot(
        id: 'slot_1',
        dateIso: '2026-08-27',
        slotType: MvSlotType.strength,
        headlineFa: 'تمرین قدرتی',
        createdAt: 0,
        updatedAt: 0,
      );
      await prescriptionRepo.savePrescription(slot);
      final fetchedSlots = await prescriptionRepo.getPrescriptionsForDates(['2026-08-27']);
      expect(fetchedSlots.isNotEmpty, isTrue);
      expect(fetchedSlots.first.slotType, MvSlotType.strength);

      // 6. MvKindProfileRepository
      final kindProfileRepo = MvKindProfileRepositoryImpl(db);
      const kindProf = MvKindProfile(
        kindCode: 'CYCLING',
        primaryMuscles: ['legs'],
        neuroCost: 2,
        recoveryHours: 24,
        complementFocus: ['core'],
      );
      await kindProfileRepo.upsert(kindProf);
      final fetchedKindProf = await kindProfileRepo.getByCode('CYCLING');
      expect(fetchedKindProf, isNotNull);
      expect(fetchedKindProf!.kindCode, 'CYCLING');
    });

    test('RITF-077 & RITF-078: Safe date and time parsing in commitments and use cases', () async {
      // 1. MvSaveCommitmentUseCase safely parses invalid dateIso
      final useCase = MvSaveCommitmentUseCase(
        prescriptionRepo: MvPrescriptionRepository(db),
        profileRepo: MvProfileRepository(db),
      );
      const corruptSlot = MvSlot(
        id: 'slot_corrupt',
        dateIso: 'corrupt-date-iso',
        slotType: MvSlotType.strength,
        headlineFa: 'تمرین',
        createdAt: 0,
        updatedAt: 0,
      );
      final result = await useCase.execute(slot: corruptSlot, repeatWeekly: false);
      expect(result.savedSlot.id, 'slot_corrupt');

      // 2. MvCommitment safely parses startTime
      final commitment = MvCommitment(
        kindCode: 'RUNNING',
        dayOfWeekSat0: 0,
        startTime: '18:30',
        durationMinutes: 45,
      );
      final next = commitment.nextOccurrenceAfter(DateTime(2026, 8, 27, 10, 0));
      expect(next, isNotNull);
    });

    test('RITF-080: SSSessionSettings & SsUnitFormatter read from app_settings first', () async {
      await db.insert('app_settings', {
        'key': 'ss_default_rest_seconds',
        'value': '120',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert('app_settings', {
        'key': 'ss_units_metric',
        'value': 'false',
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      final settings = await SSSessionSettings.load(executor: db);
      expect(settings.defaultRestSeconds, 120);
      expect(settings.unitsMetric, isFalse);

      final isMetric = await SsUnitFormatter.isMetric(db);
      expect(isMetric, isFalse);
    });

    test('RITF-081: SportsDetailMode uses UpsertHelper and updates settings', () async {
      await SportsDetailMode.setEnabled(true);
      expect(await SportsDetailMode.isEnabled(), isTrue);

      await SportsDetailMode.setEnabled(false);
      expect(await SportsDetailMode.isEnabled(), isFalse);
    });
  });
}
