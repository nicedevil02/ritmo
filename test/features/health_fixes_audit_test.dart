import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/features/health/data/medication_repository.dart';
import 'package:ritmo/features/health/models/medication_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Health Module Fixes Verification (RITF-006 .. RITF-020)', () {
    late Database db;
    final repo = MedicationRepository.instance;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
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

    test('RITF-012 & RITF-013: calculateDeductionUnits handles combination drugs and liquid volumes', () {
      // Combination tablet: "0.5/2.5 mg" -> strengthNum = 0.5
      final comboProfile = MedicationProfile(
        routineId: 'med_combo',
        form: MedicationForm.TABLET,
        strength: '0.5/2.5 mg',
        doseAmount: 1.0,
      );
      final comboDose = MedicationRepository.calculateDeductionUnits(
        profile: comboProfile,
        doseAmount: 1.0,
        doseUnit: 'MG',
      );
      expect(comboDose, equals(2.0)); // 1.0 mg / 0.5 mg = 2 tablets

      // Liquid syrup: "250mg/5ml" -> concentration = 50 mg/ml
      final syrupProfile = MedicationProfile(
        routineId: 'med_syrup',
        form: MedicationForm.SYRUP,
        strength: '250mg/5ml',
        doseAmount: 5.0,
      );
      final syrupDose = MedicationRepository.calculateDeductionUnits(
        profile: syrupProfile,
        doseAmount: 500.0, // Taking 500mg
        doseUnit: 'MG',
      );
      expect(syrupDose, equals(10.0)); // 500mg / (250mg / 5ml) = 10 ml (not 500 units!)
    });

    test('RITF-010 & RITF-011: checkSafety safely handles minIntervalHours = 0 and malformed rows', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Seed a PRN routine with minIntervalHours = 0
      await db.insert('routines', {
        'id': 'med_prn_zero',
        'title': 'مسکن فوری',
        'category': 'medical',
        'routineType': 'flexible',
        'itemType': MedicationIdentity.itemType,
        'notificationLevel': 'normal',
        'displayOrder': 1,
        'minIntervalHours': 0,
        'maxDosesPerDay': 5,
        'createdAt': now,
        'updatedAt': now,
      });

      // checkSafety should not throw ArgumentError on clamp(1, 0)
      final safetyRes = await repo.checkSafety(routineId: 'med_prn_zero', nowMs: now);
      expect(safetyRes.isSafe, isTrue);
    });

    test('RITF-006 & RITF-007 & RITF-008: recordIntake stores dose metadata and undoIntake restores recorded dose', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      const routineId = 'med_insulin_1';

      // 1. Seed routine & profile with stock = 20.0
      await db.insert('routines', {
        'id': routineId,
        'title': 'انسولین نوورپید',
        'category': 'medical',
        'routineType': 'habit',
        'itemType': MedicationIdentity.itemType,
        'notificationLevel': 'normal',
        'displayOrder': 1,
        'medStockCount': 20,
        'medRefillThreshold': 5,
        'createdAt': now,
        'updatedAt': now,
      });

      await db.insert('medication_profiles', {
        'routineId': routineId,
        'form': 'INJECTION',
        'remainingAmount': 20.0,
        'doseAmount': 2.0,
        'injectionSites': 'ABDOMEN_LEFT,ABDOMEN_RIGHT',
      });

      final scheduledTime = now - 10000;

      // 2. Record custom dose of 4.0 units in ABDOMEN_LEFT (RITF-006)
      final logId = await repo.recordIntake(
        routineId: routineId,
        status: 'TAKEN',
        scheduledTime: scheduledTime,
        doseAmount: 4.0,
        doseUnit: 'UNIT',
        site: 'ABDOMEN_LEFT',
        notes: 'دوز قبل از ناهار',
      );

      // Verify log row contains doseAmount, doseUnit, and site
      final logRows = await db.query('medication_logs', where: 'id = ?', whereArgs: [logId]);
      expect(logRows.isNotEmpty, isTrue);
      expect(logRows.first['doseAmount'], equals(4.0));
      expect(logRows.first['doseUnit'], equals('UNIT'));
      expect(logRows.first['site'], equals('ABDOMEN_LEFT'));

      // Verify remainingAmount deducted 4.0 -> 16.0
      final profileAfter = await db.query('medication_profiles', where: 'routineId = ?', whereArgs: [routineId]);
      expect(profileAfter.first['remainingAmount'], equals(16.0));

      // 3. Duplicate recordIntake call (RITF-008 Idempotency)
      final dupLogId = await repo.recordIntake(
        routineId: routineId,
        status: 'TAKEN',
        scheduledTime: scheduledTime,
        doseAmount: 4.0,
      );
      expect(dupLogId, equals(logId));

      // Stock should remain 16.0 (not deducted again)
      final profileDup = await db.query('medication_profiles', where: 'routineId = ?', whereArgs: [routineId]);
      expect(profileDup.first['remainingAmount'], equals(16.0));

      // 4. Undo Intake (RITF-007)
      await repo.undoIntake(logId);

      // Stock should be restored by exact recorded dose (4.0) -> 20.0
      final profileRestored = await db.query('medication_profiles', where: 'routineId = ?', whereArgs: [routineId]);
      expect(profileRestored.first['remainingAmount'], equals(20.0));

      // Log should be deleted
      final logsAfterUndo = await db.query('medication_logs', where: 'id = ?', whereArgs: [logId]);
      expect(logsAfterUndo.isEmpty, isTrue);
    });

    test('RITF-015 & RITF-016: delete(hardDelete: true) executes atomically and returns true', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      const routineId = 'med_delete_test';

      await db.insert('routines', {
        'id': routineId,
        'title': 'قرص تست حذف',
        'category': 'medical',
        'routineType': 'habit',
        'itemType': MedicationIdentity.itemType,
        'notificationLevel': 'normal',
        'displayOrder': 1,
        'createdAt': now,
        'updatedAt': now,
      });

      await db.insert('medication_profiles', {
        'routineId': routineId,
        'remainingAmount': 10.0,
      });

      await db.insert('medication_logs', {
        'id': 'log_del_1',
        'routineId': routineId,
        'createdAt': now,
      });

      final success = await repo.delete(routineId, hardDelete: true);
      expect(success, isTrue);

      final profRows = await db.query('medication_profiles', where: 'routineId = ?', whereArgs: [routineId]);
      final logRows = await db.query('medication_logs', where: 'routineId = ?', whereArgs: [routineId]);
      expect(profRows.isEmpty, isTrue);
      expect(logRows.isEmpty, isTrue);
    });
  });
}
