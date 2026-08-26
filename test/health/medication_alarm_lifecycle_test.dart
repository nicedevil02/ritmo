import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
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

  group('Medication Alarm Lifecycle & Course Duration Tests', () {
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

    test('archive and delete properly cancel pending reminders and mark them cancelled', () async {
      const med = Medication(
        id: 'routine_med_alarm_test',
        name: 'Aspirin 80mg',
        routineType: 'timeBased',
        createdAt: 1000,
        updatedAt: 1000,
        profile: MedicationProfile(
          routineId: 'routine_med_alarm_test',
          form: MedicationForm.TABLET,
        ),
      );

      final scheduleData = {
        'id': 'sched_alarm_1',
        'routineId': 'routine_med_alarm_test',
        'timeOfDay': '10:00',
        'daysOfWeek': '6,7,1,2,3,4,5',
      };

      await repo.saveMedication(medication: med, scheduleData: scheduleData);

      // Insert an active pending reminder
      final schedTime = DateTime.now().add(const Duration(hours: 3)).millisecondsSinceEpoch;
      await db.insert('pending_reminders', {
        'id': 'rem_test_1',
        'routineId': 'routine_med_alarm_test',
        'scheduleId': 'sched_alarm_1',
        'scheduledTime': schedTime,
        'originalTime': schedTime,
        'state': 'active',
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      // Archive medication
      await repo.archive('routine_med_alarm_test');

      // Pending reminder must be marked cancelled
      final rems = await db.query('pending_reminders', where: 'id = ?', whereArgs: ['rem_test_1']);
      expect(rems.isNotEmpty, isTrue);
      expect(rems.first['state'], equals('cancelled'));
    });

    test('AlarmSchedulerService respects course end date for non-chronic medications', () async {
      final now = DateTime.now();
      // Acute course started 10 days ago with duration of 5 days (ended 5 days ago)
      final pastStartMs = now.subtract(const Duration(days: 10)).millisecondsSinceEpoch;

      const med = Medication(
        id: 'routine_med_acute_test',
        name: 'Antibiotic 500',
        routineType: 'timeBased',
        createdAt: 1000,
        updatedAt: 1000,
        profile: MedicationProfile(
          routineId: 'routine_med_acute_test',
          form: MedicationForm.CAPSULE,
          isChronic: false,
          durationDays: 5,
        ),
      );

      final scheduleData = {
        'id': 'sched_acute_1',
        'routineId': 'routine_med_acute_test',
        'timeOfDay': '09:00',
        'daysOfWeek': '6,7,1,2,3,4,5',
      };

      await repo.saveMedication(medication: med, scheduleData: scheduleData);

      // Update profile with past start date and 5 days duration
      await db.update(
        'medication_profiles',
        {'startDate': pastStartMs, 'durationDays': 5, 'isChronic': 0},
        where: 'routineId = ?',
        whereArgs: ['routine_med_acute_test'],
      );

      // Run scheduleNextAlarms
      await AlarmSchedulerService.scheduleNextAlarms();

      // No new pending reminders should be scheduled because course has expired
      final newReminders = await db.query(
        'pending_reminders',
        where: 'routineId = ?',
        whereArgs: ['routine_med_acute_test'],
      );
      expect(newReminders.isEmpty, isTrue);
    });
  });
}
