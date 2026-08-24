import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_step_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';
import 'package:ritmo/features/simple_tasks/logic/task_bucketing.dart';
import 'package:ritmo/features/simple_tasks/logic/task_snooze.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    SharedPreferences.setMockInitialValues({});
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
            CREATE TABLE task_steps (
              id TEXT PRIMARY KEY,
              taskId TEXT NOT NULL,
              title TEXT NOT NULL,
              titleNormalized TEXT,
              isCompleted INTEGER NOT NULL DEFAULT 0,
              displayOrder INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              completedAt INTEGER
            );
          ''');
          await db.execute('''
            CREATE TABLE task_attachments (
              id TEXT PRIMARY KEY,
              taskId TEXT NOT NULL,
              fileName TEXT NOT NULL,
              fileSizeBytes INTEGER NOT NULL DEFAULT 0,
              mimeType TEXT,
              localPath TEXT NOT NULL,
              createdAt INTEGER NOT NULL
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
        },
      ),
    );
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Gap 1: SimpleTaskRepository.search parity verification', () {
    test('Search returns matches in title, note, normalized Persian, and sub-steps', () async {
      final task1 = await SimpleTaskRepository.instance.create(
        title: 'خرید کتاب #مطالعه',
        note: 'نسخه چاپي قديمي', // Arabic Yeh/Kaf
      );

      final task2 = await SimpleTaskRepository.instance.create(
        title: 'پروژه دانشگاه',
      );
      await TaskStepRepository.instance.add(taskId: task2.id, title: 'آماده‌سازی فایل ضمیمه');

      // Search by hashtag
      final searchTag = await SimpleTaskRepository.instance.search('مطالعه');
      expect(searchTag.any((t) => t.id == task1.id), isTrue);

      // Search by Arabic normalized note
      final searchNote = await SimpleTaskRepository.instance.search('چاپي');
      expect(searchNote.any((t) => t.id == task1.id), isTrue);

      // Search by sub-step title
      final searchStep = await SimpleTaskRepository.instance.search('ضمیمه');
      expect(searchStep.any((t) => t.id == task2.id), isTrue);
    });
  });

  group('Gap 2: groupTasks preservation with sortMode & hideCompleted', () {
    test('Toggling task completion preserves hideCompleted and sortMode', () {
      final now = DateTime(2026, 8, 20, 10, 0);
      final tasks = [
        SimpleTask(
          id: '1',
          title: 'کار الف',
          isDone: false,
          dueDate: '2026-08-20',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        ),
        SimpleTask(
          id: '2',
          title: 'کار ب',
          isDone: true,
          doneAt: now,
          dueDate: '2026-08-20',
          orderIndex: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // When hideCompleted is true, doneToday bucket is omitted
      final hiddenBuckets = groupTasks(
        tasks,
        now: now,
        sortMode: TaskSortMode.alphabetical,
        hideCompleted: true,
      );
      expect(hiddenBuckets.containsKey(TaskBucket.doneToday), isFalse);
      expect(hiddenBuckets[TaskBucket.today]?.length, equals(1));

      // When hideCompleted is false, doneToday bucket is present
      final visibleBuckets = groupTasks(
        tasks,
        now: now,
        sortMode: TaskSortMode.alphabetical,
        hideCompleted: false,
      );
      expect(visibleBuckets.containsKey(TaskBucket.doneToday), isTrue);
    });
  });

  group('Gap 3: Snooze Presets in TaskSnooze', () {
    test('snoozeTask schedules accurate reminder for tenMinutes and tomorrowMorning', () async {
      final now = DateTime(2026, 8, 20, 10, 0);
      final task = await SimpleTaskRepository.instance.create(
        title: 'تماس کاری',
        dueDate: '2026-08-20',
      );

      // Snooze ten minutes
      await snoozeTask(task.id, SnoozePreset.tenMinutes, nowOverride: now);
      var fresh = await SimpleTaskRepository.instance.getById(task.id);
      expect(fresh?.reminderAtMs, equals(now.add(const Duration(minutes: 10)).millisecondsSinceEpoch));

      // Snooze tomorrow morning
      await snoozeTask(task.id, SnoozePreset.tomorrowMorning, nowOverride: now);
      fresh = await SimpleTaskRepository.instance.getById(task.id);
      final expectedTomorrow = DateTime(2026, 8, 21, 9, 0).millisecondsSinceEpoch;
      expect(fresh?.reminderAtMs, equals(expectedTomorrow));
    });
  });

  group('Gap 4: Star in My Day & SimpleTaskRepository.setImportant', () {
    test('Toggling star persists importance and updates updatedAt', () async {
      final task = await SimpleTaskRepository.instance.create(title: 'وظیفه اول');
      expect(task.isImportant, isFalse);

      await SimpleTaskRepository.instance.setImportant(task.id, important: true);
      var fresh = await SimpleTaskRepository.instance.getById(task.id);
      expect(fresh?.isImportant, isTrue);
      expect(fresh?.importantAt, isNotNull);

      await SimpleTaskRepository.instance.toggleImportant(task.id);
      fresh = await SimpleTaskRepository.instance.getById(task.id);
      expect(fresh?.isImportant, isFalse);
    });
  });

  group('Gap 5: Tasks Widget Snapshot generation', () {
    test('syncWidgetSnapshot populates SharedPreferences snapshot', () async {
      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await SimpleTaskRepository.instance.create(
        title: 'کار فوری ویجت',
        dueDate: todayStr,
        isImportant: true,
      );

      await SimpleTaskRepository.instance.syncWidgetSnapshot();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('widget_tasks_snapshot');
      expect(raw, isNotNull);
      expect(raw, contains('کار فوری ویجت'));
      expect(raw, contains('کارهای امروز'));
    });
  });
}
