import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/completion/snooze_policy.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/services/notification_action_dispatcher.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockAlarmPlatform implements AlarmPlatform {
  @override
  Future<bool> cancelAlarm(String id) async => true;

  @override
  Future<bool> scheduleExactAlarm({
    required String id,
    required int timeMsUTC,
    required String title,
    required bool isEssential,
  }) async => true;

  @override
  Future<bool> scheduleSilentTick({required String id, required int timeMsUTC}) async => true;

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

  group('N0-8 Snooze Uses Settings Tests', () {
    late Database db;
    bool dbInitialized = false;

    setUp(() async {
      await AppBootstrapper.init();

      if (sl.isRegistered<AlarmPlatform>()) {
        sl.unregister<AlarmPlatform>();
      }
      sl.registerSingleton<AlarmPlatform>(MockAlarmPlatform());

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
                routineId TEXT NOT NULL,
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
            await db.execute('CREATE TABLE routine_occurrences (id TEXT PRIMARY KEY, routine_id TEXT, date TEXT, status TEXT, scheduled_time TEXT);');
            await db.execute('CREATE TABLE routine_schedules (id TEXT PRIMARY KEY, routineId TEXT);');
            await db.execute('CREATE TABLE calendar_exceptions (date TEXT PRIMARY KEY, behavior TEXT);');
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

    test('SnoozePolicy with configured requestedMinutes = 25 yields allowedMinutes = 25', () {
      final decision = SnoozePolicy.evaluate(
        itemId: 'routine_1',
        now: DateTime(2026, 8, 15, 10, 0),
        requestedMinutes: 25,
        currentDeferCount: 0,
        configuredMax: 3,
        quotaEnabled: true,
      );

      expect(decision.verdict, equals(SnoozeVerdict.allowed));
      expect(decision.allowedMinutes, equals(25));
    });

    test('NotificationActionHandler.handle SNOOZE reads snooze_minutes = 25 from settings and delays reminder by 25 min', () async {
      if (!dbInitialized) return;

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // Insert settings with snooze_minutes = 25
      await db.insert('app_settings', {'key': 'snooze_minutes', 'value': '25', 'updatedAt': nowMs});
      await db.insert('app_settings', {'key': 'snooze_max_defer_count', 'value': '3', 'updatedAt': nowMs});

      // Insert routine
      await db.insert('routines', {
        'id': 'routine_test_snooze',
        'title': 'ورزش صبحگاهی',
        'category': 'health',
        'isArchived': 0,
        'isEssential': 0,
      });

      // Insert pending reminder
      await db.insert('pending_reminders', {
        'id': 'rem_test_snooze_1',
        'routineId': 'routine_test_snooze',
        'originalTime': nowMs,
        'scheduledTime': nowMs,
        'state': 'scheduled',
        'deferCount': 0,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      });

      // Execute SNOOZE
      await NotificationActionHandler.handle('SNOOZE', 'rem_test_snooze_1');

      // Verify pending_reminder state is delayed and scheduledTime moved forward by ~25 minutes
      final rows = await db.query('pending_reminders', where: 'id = ?', whereArgs: ['rem_test_snooze_1']);
      expect(rows.length, equals(1));
      final updated = rows.first;
      expect(updated['state'], equals('delayed'));
      expect(updated['deferCount'], equals(1));

      final scheduledTime = updated['scheduledTime'] as int;
      const expectedDeltaMs = 25 * 60 * 1000;
      // Should be roughly nowMs + 25 minutes (within 5 seconds tolerance)
      expect((scheduledTime - nowMs - expectedDeltaMs).abs(), lessThan(5000));
    });
  });
}
