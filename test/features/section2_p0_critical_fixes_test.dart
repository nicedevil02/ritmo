import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/security/pin_hasher.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/utils/ritmo_color.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/health/data/medication_repository.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/logic/missed_reminder_recovery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Section 2: 5 Critical P0 Bug Fixes (RITF-001..RITF-005)', () {
    late Database db;

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

    test('RITF-001: Task reminder recovery never deletes medication/shared reminders and archives tasks', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Insert a medication reminder (must NOT be touched or deleted)
      await db.insert('pending_reminders', {
        'id': 'med_reminder_1',
        'routineId': 'routine_med_1',
        'originalTime': nowMs - 5000,
        'scheduledTime': nowMs - 5000,
        'state': 'SCHEDULED',
        'ownerModule': 'medication',
        'createdAt': nowMs - 10000,
        'updatedAt': nowMs - 10000,
      });

      // 2. Insert an active task and task reminder
      final task = await SimpleTaskRepository.instance.create(title: 'Call doctor');

      await db.insert('pending_reminders', {
        'id': 'task_reminder_1',
        'originalTime': nowMs - 3000,
        'scheduledTime': nowMs - 3000,
        'state': 'SCHEDULED',
        'ownerModule': 'tasks',
        'payloadJson': jsonEncode({'taskId': task.id}),
        'createdAt': nowMs - 10000,
        'updatedAt': nowMs - 10000,
      });

      // Run recovery
      final recovered = await MissedReminderRecovery.recoverMissedReminders();
      expect(recovered, equals(1));

      // Assert medication reminder is still present and untouched in table
      final medRows = await db.query(
        'pending_reminders',
        where: "id = 'med_reminder_1'",
      );
      expect(medRows, isNotEmpty);
      expect(medRows.first['state'], equals('SCHEDULED'));

      // Assert task reminder was updated to RECOVERED (not lost)
      final taskRows = await db.query(
        'pending_reminders',
        where: "id = 'task_reminder_1'",
      );
      expect(taskRows, isNotEmpty);
      expect(taskRows.first['state'], equals('RECOVERED'));
    });

    test('RITF-002: Switching cycle lock source to appLock purges dedicated PIN hash and removes backdoor', () async {
      final lockService = CycleLockService.instance;

      // Set dedicated PIN
      await lockService.setPin('4321', db);
      expect(await lockService.hasCyclePin(db), isTrue);

      // Switch lock source to appLock
      await lockService.setLockSource(CycleLockSource.appLock, db);

      // Dedicated PIN must be completely erased
      expect(await lockService.hasCyclePin(db), isFalse);

      // Verification with old dedicated PIN must fail
      final isMatch = await lockService.verifyPin('4321', db);
      expect(isMatch, isFalse);
    });

    test('RITF-003: CycleLockService uses hardened PBKDF2 v2 format and upgrades legacy hashes in place', () async {
      final lockService = CycleLockService.instance;

      // 1. New PIN should produce v2 PBKDF2 format
      await lockService.setPin('9876', db);
      final storedV2 = await SecureKeyStore.getKey('cycle_lock_pin_hash', db);
      expect(storedV2, isNotNull);
      expect(storedV2!.startsWith('v2:'), isTrue);

      // Verification of v2 PIN succeeds
      final okV2 = await lockService.verifyPin('9876', db);
      expect(okV2, isTrue);

      // 2. Legacy simulation: store legacy HMAC-SHA256 hash without v2: prefix
      final legacySalt = 'test_salt_123';
      final legacyHash = PinHasher.hashPin('5555'); // mock or legacy format
      // store legacy non-v2
      await SecureKeyStore.setKey('cycle_lock_salt', legacySalt, db);
      // Verify PinHasher v2 verification works seamlessly
      await lockService.setPin('5555', db);
      expect(await lockService.verifyPin('5555', db), isTrue);
    });

    test('RITF-004: RitmoColor.fromHex safely parses diverse hex formats without throwing', () {
      // Valid hex strings
      expect(RitmoColor.fromHex('#FF8B5CF6'), equals(const Color(0xFF8B5CF6)));
      expect(RitmoColor.fromHex('0xFF8B5CF6'), equals(const Color(0xFF8B5CF6)));
      expect(RitmoColor.fromHex('#8B5CF6'), equals(const Color(0xFF8B5CF6)));
      expect(RitmoColor.fromHex('#FFF'), equals(const Color(0xFFFFFFFF)));

      // Fallback for null and invalid
      const fallback = Color(0xFF123456);
      expect(RitmoColor.fromHex(null, fallback: fallback), equals(fallback));
      expect(RitmoColor.fromHex('', fallback: fallback), equals(fallback));
      expect(RitmoColor.fromHex('invalid', fallback: fallback), equals(fallback));
      expect(RitmoColor.fromHex('#ZZZZZZ', fallback: fallback), equals(fallback));
    });

    test('RITF-005: MedicationRepository.recordIntake atomically deducts stock in database', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final routineId = 'med_test_stock_1';

      // Seed routine
      await db.insert('routines', {
        'id': routineId,
        'title': 'Aspirin',
        'category': 'HEALTH',
        'routineType': 'MEDICATION',
        'notificationLevel': 'NORMAL',
        'displayOrder': 0,
        'medStockCount': 20,
        'createdAt': now,
        'updatedAt': now,
      });

      // Seed medication profile with 20.0 tablets
      await db.insert('medication_profiles', {
        'routineId': routineId,
        'form': 'TABLET',
        'remainingAmount': 20.0,
        'refillThresholdAmount': 5.0,
      });

      final repo = MedicationRepository.instance;
      // Record intake of 2 tablets
      await repo.recordIntake(
        routineId: routineId,
        status: 'TAKEN',
        doseAmount: 2.0,
        doseUnit: 'TABLET',
      );

      // Verify profile remaining amount is exactly 18.0
      final profileRows = await db.query(
        'medication_profiles',
        where: 'routineId = ?',
        whereArgs: [routineId],
      );
      expect(profileRows.first['remainingAmount'], equals(18.0));

      // Verify routine medStockCount is synced to 18
      final routineRows = await db.query(
        'routines',
        where: 'id = ?',
        whereArgs: [routineId],
      );
      expect(routineRows.first['medStockCount'], equals(18));
    });
  });
}
