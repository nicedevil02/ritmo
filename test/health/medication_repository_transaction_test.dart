import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/health/data/medication_repository.dart';
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

  group('Medication Repository Transaction & Concurrency Tests', () {
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

    test('saveMedication executes atomically without nested transaction deadlock', () async {
      const med = Medication(
        id: 'routine_med_txn_test',
        name: 'Amoxicillin 500mg',
        routineType: 'timeBased',
        createdAt: 1000,
        updatedAt: 1000,
        profile: MedicationProfile(
          routineId: 'routine_med_txn_test',
          form: MedicationForm.CAPSULE,
          doseAmount: 1.0,
          doseUnit: DoseUnit.CAPSULE,
          isChronic: false,
          durationDays: 7,
          remainingAmount: 21.0,
          refillThresholdAmount: 3.0,
        ),
      );

      final scheduleData = {
        'id': 'sched_txn_1',
        'routineId': 'routine_med_txn_test',
        'timeOfDay': '08:00',
        'daysOfWeek': '6,7,1,2,3,4,5',
      };

      // saveMedication must complete promptly without hanging / deadlock
      final resultId = await repo.saveMedication(
        medication: med,
        scheduleData: scheduleData,
        isEdit: false,
      );

      expect(resultId, equals('routine_med_txn_test'));

      final createdMed = await repo.getByRoutineId('routine_med_txn_test');
      expect(createdMed, isNotNull);
      expect(createdMed!.name, equals('Amoxicillin 500mg'));
      expect(createdMed.profile.form, equals(MedicationForm.CAPSULE));
      expect(createdMed.profile.remainingAmount, equals(21.0));
    });

    test('undoIntake restores stock and removes logs without deadlock', () async {
      const med = Medication(
        id: 'routine_med_undo_test',
        name: 'Metformin 500',
        routineType: 'timeBased',
        createdAt: 1000,
        updatedAt: 1000,
        profile: MedicationProfile(
          routineId: 'routine_med_undo_test',
          form: MedicationForm.TABLET,
          doseAmount: 1.0,
          doseUnit: DoseUnit.TABLET,
          remainingAmount: 30.0,
          refillThresholdAmount: 5.0,
        ),
      );

      final scheduleData = {
        'id': 'sched_undo_1',
        'routineId': 'routine_med_undo_test',
        'timeOfDay': '12:00',
        'daysOfWeek': '6,7,1,2,3,4,5',
      };

      await repo.saveMedication(medication: med, scheduleData: scheduleData);

      // Record intake
      final logId = await repo.recordIntake(
        routineId: 'routine_med_undo_test',
        status: 'TAKEN',
        doseAmount: 1.0,
      );

      var updatedMed = await repo.getByRoutineId('routine_med_undo_test');
      expect(updatedMed!.profile.remainingAmount, equals(29.0));

      // Undo intake - must restore stock to 30.0 and complete without deadlock
      await repo.undoIntake(logId);

      updatedMed = await repo.getByRoutineId('routine_med_undo_test');
      expect(updatedMed!.profile.remainingAmount, equals(30.0));

      final logs = await db.query('medication_logs', where: 'id = ?', whereArgs: [logId]);
      expect(logs.isEmpty, isTrue);
    });
  });
}
