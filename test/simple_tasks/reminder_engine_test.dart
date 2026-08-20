import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/logic/daily_planning_nudge.dart';
import 'package:ritmo/features/simple_tasks/logic/missed_reminder_recovery.dart';
import 'package:ritmo/features/simple_tasks/logic/task_snooze.dart';
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
    bool isEssential = false,
  }) async {
    scheduledAlarms.add({
      'id': id,
      'timeMsUTC': timeMsUTC,
      'title': title,
      'isEssential': isEssential,
    });
    return true;
  }

  @override
  Future<bool> checkExactAlarmPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> scheduleSilentTick({required String id, required int timeMsUTC}) async => true;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late MockAlarmPlatform mockAlarm;

  setUp(() async {
    mockAlarm = MockAlarmPlatform();
    if (sl.isRegistered<AlarmPlatform>()) {
      sl.unregister<AlarmPlatform>();
    }
    sl.registerSingleton<AlarmPlatform>(mockAlarm);

    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE simple_tasks (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              titleNormalized TEXT,
              note TEXT,
              noteNormalized TEXT,
              tagsJson TEXT,
              isDone INTEGER NOT NULL DEFAULT 0,
              doneAt INTEGER,
              dueDate TEXT,
              dueTime TEXT,
              reminderAtMs INTEGER,
              reminderId TEXT,
              linkedRoutineId TEXT,
              orderIndex INTEGER NOT NULL DEFAULT 0,
              origin TEXT NOT NULL DEFAULT 'SIMPLE',
              isImportant INTEGER NOT NULL DEFAULT 0,
              importantAt INTEGER,
              addedToMyDayAt INTEGER,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE pending_reminders (
              id TEXT PRIMARY KEY,
              routineId TEXT,
              scheduleId TEXT,
              originalTime INTEGER,
              title TEXT,
              body TEXT,
              scheduledTime INTEGER,
              payloadJson TEXT,
              state TEXT DEFAULT 'unknown',
              deferCount INTEGER DEFAULT 0,
              nativeScheduled INTEGER DEFAULT 0,
              ownerModule TEXT,
              createdAt INTEGER,
              updatedAt INTEGER
            );
          ''');
          await db.execute('''
            CREATE TABLE alarm_delivery_log (
              id TEXT PRIMARY KEY,
              reminderId TEXT,
              routineId TEXT,
              expectedAt INTEGER,
              firedAt INTEGER,
              outcome TEXT,
              createdAt INTEGER
            );
          ''');
          await db.execute('''
            CREATE TABLE inbox_items (
              id TEXT PRIMARY KEY,
              category TEXT NOT NULL,
              sourceSystem TEXT,
              entityId TEXT,
              eventType TEXT,
              title TEXT NOT NULL,
              body TEXT,
              priority INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL DEFAULT 'UNREAD',
              linkModule TEXT,
              linkEntityId TEXT,
              linkAction TEXT,
              dateBucket TEXT,
              payloadJson TEXT,
              dedupeKey TEXT,
              expiresAt INTEGER,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
        },
      ),
    );
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DailyPlanningNudge Scheduling', () {
    test('1. When enabled, schedules exactly one alarm via NotificationGateway', () async {
      await TaskPreferences.setDailyNudgeEnabled(true);
      await TaskPreferences.setDailyNudgeTime('08:30');

      await DailyPlanningNudge.syncNudgeSchedule();

      expect(mockAlarm.scheduledAlarms.length, equals(1));
      expect(mockAlarm.scheduledAlarms.first['id'], equals(DailyPlanningNudge.reminderId));

      final pending = await db.query('pending_reminders', where: 'id = ?', whereArgs: [DailyPlanningNudge.reminderId]);
      expect(pending.length, equals(1));
    });

    test('2. When disabled, cancels alarm and does not schedule', () async {
      await TaskPreferences.setDailyNudgeEnabled(false);

      await DailyPlanningNudge.syncNudgeSchedule();

      expect(mockAlarm.scheduledAlarms, isEmpty);
      expect(mockAlarm.cancelledAlarms, contains(DailyPlanningNudge.reminderId));
    });

    test('3. If configured time has already passed today, schedules for tomorrow', () async {
      await TaskPreferences.setDailyNudgeEnabled(true);
      // Set to 00:01 which has passed
      await TaskPreferences.setDailyNudgeTime('00:01');

      await DailyPlanningNudge.syncNudgeSchedule();

      expect(mockAlarm.scheduledAlarms.length, equals(1));
      final scheduledUtc = mockAlarm.scheduledAlarms.first['timeMsUTC'] as int;
      expect(scheduledUtc, greaterThan(DateTime.now().millisecondsSinceEpoch));
    });
  });

  group('TaskSnooze Logic', () {
    test('4. snoozeTask updates reminderAtMs and reminderId without modifying dueDate', () async {
      final task = await SimpleTaskRepository.instance.create(
        title: 'Task with Due Date',
        dueDate: '2026-08-30',
      );

      final now = DateTime(2026, 8, 20, 10, 0);
      await snoozeTask(task.id, SnoozePreset.oneHour, nowOverride: now);

      final updated = await SimpleTaskRepository.instance.getById(task.id);
      expect(updated?.dueDate, equals('2026-08-30')); // DueDate is untouched
      expect(updated?.reminderAtMs, equals(DateTime(2026, 8, 20, 11, 0).millisecondsSinceEpoch));
      expect(updated?.reminderId, equals('rem_${task.id}'));
    });

    test('5. thisEvening preset throws StateError when called after 20:00', () async {
      final task = await SimpleTaskRepository.instance.create(title: 'Late Task');
      final lateNow = DateTime(2026, 8, 20, 20, 30);

      expect(
        () => snoozeTask(task.id, SnoozePreset.thisEvening, nowOverride: lateNow),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('MissedReminderRecovery', () {
    test('6. recoverMissedReminders skips completed tasks and cleans pending rows', () async {
      final task = await SimpleTaskRepository.instance.create(title: 'Done Task');
      await SimpleTaskRepository.instance.setDone(task.id, done: true);

      final pastMs = DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch;
      await SimpleTaskRepository.instance.addPendingReminder(
        reminderId: 'rem_${task.id}',
        title: task.title,
        body: '',
        scheduledTimeMs: pastMs,
        taskId: task.id,
      );

      final count = await MissedReminderRecovery.recoverMissedReminders();
      expect(count, equals(0));

      final remaining = await db.query('pending_reminders');
      expect(remaining, isEmpty);
    });

    test('7. recoverMissedReminders with 10 pending reminders sends 1 aggregated notification', () async {
      final now = DateTime.now();
      final pastMs = now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch;

      for (int i = 1; i <= 10; i++) {
        final task = await SimpleTaskRepository.instance.create(title: 'Active Task $i');
        await SimpleTaskRepository.instance.addPendingReminder(
          reminderId: 'rem_${task.id}',
          title: task.title,
          body: '',
          scheduledTimeMs: pastMs,
          taskId: task.id,
        );
      }

      mockAlarm.scheduledAlarms.clear();

      final count = await MissedReminderRecovery.recoverMissedReminders(nowOverride: now);
      expect(count, equals(10));

      // Dispatches 1 aggregated alarm
      expect(mockAlarm.scheduledAlarms.length, equals(1));
      expect(mockAlarm.scheduledAlarms.first['title'], equals('یادآور کارهای گذشته'));

      // All pending rows cleared
      final remaining = await db.query('pending_reminders');
      expect(remaining, isEmpty);
    });
  });
}
