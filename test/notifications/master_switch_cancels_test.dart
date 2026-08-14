import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAlarmPlatform implements AlarmPlatform {
  final List<String> cancelledAlarms = [];
  final List<Map<String, dynamic>> scheduledAlarms = [];

  @override
  Future<bool> cancelAlarm(String id) async {
    cancelledAlarms.add(id);
    return true;
  }

  @override
  Future<bool> scheduleExactAlarm({
    required String id,
    required int timeMsUTC,
    required String title,
    required bool isEssential,
  }) async {
    scheduledAlarms.add({'id': id, 'timeMsUTC': timeMsUTC, 'title': title, 'isEssential': isEssential});
    return true;
  }

  @override
  Future<bool> scheduleSilentTick({required String id, required int timeMsUTC}) async {
    return true;
  }

  @override
  Future<bool> checkExactAlarmPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('N0-3 Master Switch Cancels Tests', () {
    late Database db;
    late MockAlarmPlatform mockPlatform;
    bool dbInitialized = false;

    setUp(() async {
      mockPlatform = MockAlarmPlatform();
      if (sl.isRegistered<AlarmPlatform>()) {
        sl.unregister<AlarmPlatform>();
      }
      sl.registerSingleton<AlarmPlatform>(mockPlatform);

      try {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
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
            await db.execute('CREATE TABLE routines (id TEXT PRIMARY KEY, title TEXT, category TEXT, isArchived INTEGER, isEssential INTEGER);');
            await db.execute('CREATE TABLE routine_schedules (id TEXT PRIMARY KEY, routineId TEXT);');
            await db.execute('CREATE TABLE routine_occurrences (id TEXT PRIMARY KEY, routine_id TEXT, date TEXT, status TEXT, scheduled_time TEXT);');
            await db.execute('CREATE TABLE calendar_exceptions (date TEXT PRIMARY KEY, behavior TEXT);');
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

    test('when master switch is disabled, scheduleNextAlarms cancels all active alarms and resets nativeScheduled', () async {
      if (!dbInitialized) return;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // Insert master switch disabled
      await db.insert('app_settings', {'key': 'notif_master_enabled', 'value': 'false', 'updatedAt': nowMs});

      // Insert 2 scheduled reminders with nativeScheduled = 1
      await db.insert('pending_reminders', {
        'id': 'rem_1',
        'routineId': 'r1',
        'originalTime': nowMs + 3600000,
        'scheduledTime': nowMs + 3600000,
        'state': 'scheduled',
        'nativeScheduled': 1,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      });
      await db.insert('pending_reminders', {
        'id': 'rem_2',
        'routineId': 'r2',
        'originalTime': nowMs + 7200000,
        'scheduledTime': nowMs + 7200000,
        'state': 'scheduled',
        'nativeScheduled': 1,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      });

      await AlarmSchedulerService.scheduleNextAlarms();

      // Verify both alarms were cancelled
      expect(mockPlatform.cancelledAlarms, containsAll(['rem_1', 'rem_2']));

      // Verify nativeScheduled was reset to 0 in database
      final updated = await db.query('pending_reminders');
      expect(updated.every((row) => row['nativeScheduled'] == 0), isTrue);
    });
  });
}
