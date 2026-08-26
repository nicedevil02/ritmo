import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/health/data/medication_repository.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/features/health/models/medication_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Medication Stock Tracking, PRN Logs & Models Tests', () {
    late Database db;
    late MedicationRepository repo;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath, version: 1);
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await SchemaManager.createAll(db);
      await SchemaManager.ensureAllSchemas(db);

      repo = MedicationRepository.instance;
    });

    tearDown(() async {
      DatabaseHelper.databaseInstance = null;
      await db.close();
    });

    test('hasStockTracking and isOutOfStock remain true when remainingAmount hits 0', () {
      const profileZeroStock = MedicationProfile(
        routineId: 'r_stock_zero',
        form: MedicationForm.TABLET,
        remainingAmount: 0.0,
        refillThresholdAmount: 5.0,
      );

      expect(profileZeroStock.hasStockTracking, isTrue);
      expect(profileZeroStock.isOutOfStock, isTrue);
      expect(profileZeroStock.isLowStock, isTrue);

      const profileWithStock = MedicationProfile(
        routineId: 'r_stock_low',
        form: MedicationForm.TABLET,
        remainingAmount: 3.0,
        refillThresholdAmount: 5.0,
      );
      expect(profileWithStock.hasStockTracking, isTrue);
      expect(profileWithStock.isLowStock, isTrue);
      expect(profileWithStock.isOutOfStock, isFalse);
    });

    test('recordIntake inserts into prn_logs for PRN medications and undoIntake removes it', () async {
      const prnMed = Medication(
        id: 'routine_med_prn_test',
        name: 'Acetaminophen 500',
        routineType: 'asNeeded',
        createdAt: 1000,
        updatedAt: 1000,
        profile: MedicationProfile(
          routineId: 'routine_med_prn_test',
          form: MedicationForm.TABLET,
          doseAmount: 1.0,
          doseUnit: DoseUnit.TABLET,
          remainingAmount: 10.0,
          refillThresholdAmount: 2.0,
        ),
      );

      await repo.saveMedication(medication: prnMed, scheduleData: {});

      // Record PRN intake
      final logId = await repo.recordIntake(
        routineId: 'routine_med_prn_test',
        status: 'TAKEN',
        doseAmount: 1.0,
      );

      // Verify insertion in prn_logs
      final prnLogs = await db.query('prn_logs', where: 'routineId = ?', whereArgs: ['routine_med_prn_test']);
      expect(prnLogs.length, equals(1));
      expect(prnLogs.first['dosage'], contains('1 TABLET'));

      // Undo PRN intake
      await repo.undoIntake(logId);

      // Verify deletion from prn_logs
      final prnLogsAfterUndo = await db.query('prn_logs', where: 'routineId = ?', whereArgs: ['routine_med_prn_test']);
      expect(prnLogsAfterUndo.isEmpty, isTrue);
    });

    test('BloodSugarLog.fromMap handles num and double values safely', () {
      final logInt = BloodSugarLog.fromMap({
        'id': 'bs_1',
        'value': 110,
        'measurementType': 'FASTING',
        'loggedAt': 1700000000000,
      });
      expect(logInt.value, equals(110));

      final logDouble = BloodSugarLog.fromMap({
        'id': 'bs_2',
        'value': 125.6,
        'measurementType': 'AFTER_MEAL',
        'loggedAt': 1700000000000,
      });
      expect(logDouble.value, equals(126)); // rounded safely without exception
    });

    test('Medication.displayStock formats dose units properly without mixing with package units', () {
      const med = Medication(
        id: 'r_disp_test',
        name: 'Omeprazole 20',
        routineType: 'timeBased',
        createdAt: 1000,
        updatedAt: 1000,
        profile: MedicationProfile(
          routineId: 'r_disp_test',
          form: MedicationForm.CAPSULE,
          doseUnit: DoseUnit.CAPSULE,
          packageUnit: 'جعبه',
          remainingAmount: 14.0,
        ),
      );

      expect(med.displayStock, equals('14 کپسول'));
    });
  });
}
