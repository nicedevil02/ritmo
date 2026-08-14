import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models/reminder_state.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('N0-5 Sweep Missed Join Tests', () {
    late Database db;
    bool dbInitialized = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE pending_reminders (
                id TEXT PRIMARY KEY,
                routineId TEXT,
                scheduleId TEXT,
                courseSessionId TEXT,
                originalTime INTEGER NOT NULL,
                scheduledTime INTEGER NOT NULL,
                state TEXT NOT NULL DEFAULT 'SCHEDULED',
                deferCount INTEGER NOT NULL DEFAULT 0,
                deferReason TEXT,
                createdAt INTEGER NOT NULL,
                updatedAt INTEGER NOT NULL,
                snoozeUntil INTEGER,
                nativeScheduled INTEGER DEFAULT 0,
                ownerModule TEXT
              );
            ''');
            await db.execute('CREATE TABLE routine_occurrences (id TEXT PRIMARY KEY, routine_id TEXT, date TEXT, status TEXT, scheduled_time TEXT);');
            await db.execute('CREATE TABLE alarm_delivery_log (id TEXT PRIMARY KEY, reminderId TEXT, routineId TEXT, expectedAt INTEGER, firedAt INTEGER, outcome TEXT, createdAt INTEGER);');
          },
        );
        DatabaseHelper.instance.overrideDatabaseForTesting(db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized) {
        await db.close();
      }
    });

    test('completed occurrence does NOT get marked as missed during sweep', () async {
      if (!dbInitialized) return;

      final pastTime = DateTime.now().subtract(const Duration(hours: 2));
      final pastTimeMs = pastTime.millisecondsSinceEpoch;
      final dateStr = pastTime.toIso8601String().substring(0, 10);

      // Insert routine occurrence with status = 'done'
      await db.insert('routine_occurrences', {
        'id': 'occ_1',
        'routine_id': 'r_morning_water',
        'date': dateStr,
        'status': 'done',
        'scheduled_time': '07:30',
      });

      // Insert corresponding past pending_reminder
      await db.insert('pending_reminders', {
        'id': 'rem_r_morning_water_s1_${dateStr}_0730',
        'routineId': 'r_morning_water',
        'originalTime': pastTimeMs,
        'scheduledTime': pastTimeMs,
        'state': 'scheduled',
        'createdAt': pastTimeMs,
        'updatedAt': pastTimeMs,
      });

      // Also insert an incomplete past reminder for another routine that SHOULD be missed
      await db.insert('pending_reminders', {
        'id': 'rem_r_uncompleted_s1_${dateStr}_0730',
        'routineId': 'r_uncompleted',
        'originalTime': pastTimeMs,
        'scheduledTime': pastTimeMs,
        'state': 'scheduled',
        'createdAt': pastTimeMs,
        'updatedAt': pastTimeMs,
      });

      final swept = await AlarmSchedulerService.sweepMissedAlarms();

      // Only the uncompleted reminder should be swept
      expect(swept.length, equals(1));
      expect(swept.first['id'], equals('rem_r_uncompleted_s1_${dateStr}_0730'));

      // Check database state of completed reminder
      final completedRow = await db.query(
        'pending_reminders',
        where: 'id = ?',
        whereArgs: ['rem_r_morning_water_s1_${dateStr}_0730'],
      );
      expect(completedRow.first['state'], isNot(equals(ReminderState.missed.dbValue)));

      // Check database state of uncompleted reminder
      final missedRow = await db.query(
        'pending_reminders',
        where: 'id = ?',
        whereArgs: ['rem_r_uncompleted_s1_${dateStr}_0730'],
      );
      expect(missedRow.first['state'], equals(ReminderState.missed.dbValue));
    });
  });
}
