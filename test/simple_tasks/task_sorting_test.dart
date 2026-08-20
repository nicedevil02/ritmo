import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/domain/task_bucket.dart';
import 'package:ritmo/features/simple_tasks/logic/task_bucketing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
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
        },
      ),
    );
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 4: Task Sorting and Bucketing Tests', () {
    final now = DateTime(2026, 8, 20, 10, 0); // Shamsi Thursday (1405-05-29)

    test('1. TaskSortMode.smart maintains exact previous ranking', () {
      final task1 = SimpleTask(
        id: '1',
        title: 'Normal task',
        isDone: false,
        orderIndex: 2,
        createdAt: now,
        updatedAt: now,
      );
      final task2 = SimpleTask(
        id: '2',
        title: 'Important task',
        isDone: false,
        isImportant: true,
        orderIndex: 3,
        createdAt: now,
        updatedAt: now,
      );
      final task3 = SimpleTask(
        id: '3',
        title: 'Done task',
        isDone: true,
        orderIndex: 1,
        createdAt: now,
        updatedAt: now,
      );

      final buckets = groupTasks([task1, task2, task3], now: now, sortMode: TaskSortMode.smart);
      final somedayList = buckets[TaskBucket.someday]!;
      expect(somedayList.map((t) => t.id).toList(), equals(['2', '1']));
      final doneList = buckets[TaskBucket.doneToday]!;
      expect(doneList.map((t) => t.id).toList(), equals(['3']));
    });

    test('2. TaskSortMode.alphabetical sorts Persian titles properly (5 titles)', () {
      final t1 = SimpleTask(id: '1', title: 'خرید نان', isDone: false, createdAt: now, updatedAt: now);
      final t2 = SimpleTask(id: '2', title: 'آب دادن به گل‌ها', isDone: false, createdAt: now, updatedAt: now);
      final t3 = SimpleTask(id: '3', title: 'ورزش صبحگاهی', isDone: false, createdAt: now, updatedAt: now);
      final t4 = SimpleTask(id: '4', title: 'مطالعه کتاب', isDone: false, createdAt: now, updatedAt: now);
      final t5 = SimpleTask(id: '5', title: 'پاسخ به ایمیل‌ها', isDone: false, createdAt: now, updatedAt: now);

      final buckets = groupTasks([t1, t2, t3, t4, t5], now: now, sortMode: TaskSortMode.alphabetical);
      final titles = buckets[TaskBucket.someday]!.map((t) => t.title).toList();

      final expected = [t1.title, t2.title, t3.title, t4.title, t5.title]..sort((a, b) => a.compareTo(b));
      expect(titles, equals(expected));
    });

    test('3. Changing sort mode never moves tasks between buckets', () {
      final tToday = SimpleTask(id: '1', title: 'Task Today', dueDate: '2026-08-20', isDone: false, createdAt: now, updatedAt: now);
      final tTomorrow = SimpleTask(id: '2', title: 'Task Tomorrow', dueDate: '2026-08-21', isDone: false, createdAt: now, updatedAt: now);
      final tSomeday = SimpleTask(id: '3', title: 'Task Someday', isDone: false, createdAt: now, updatedAt: now);

      final list = [tToday, tTomorrow, tSomeday];

      for (final mode in TaskSortMode.values) {
        final buckets = groupTasks(list, now: now, sortMode: mode);
        expect(buckets[TaskBucket.today]?.map((t) => t.id), contains('1'));
        expect(buckets[TaskBucket.tomorrow]?.map((t) => t.id), contains('2'));
        expect(buckets[TaskBucket.someday]?.map((t) => t.id), contains('3'));
      }
    });

    test('4. tasks_hide_completed removes doneToday bucket while database rows remain intact', () async {
      final active = await SimpleTaskRepository.instance.create(title: 'Active Task');
      final done = await SimpleTaskRepository.instance.create(title: 'Done Task');
      await SimpleTaskRepository.instance.setDone(done.id, done: true);

      final testNow = DateTime.now();

      // Without hideCompleted
      final visibleBuckets = await SimpleTaskRepository.instance.buckets(
        now: testNow,
        hideCompleted: false,
      );
      expect(visibleBuckets.containsKey(TaskBucket.doneToday), isTrue);

      // With hideCompleted = true
      final hiddenBuckets = await SimpleTaskRepository.instance.buckets(
        now: testNow,
        hideCompleted: true,
      );
      expect(hiddenBuckets.containsKey(TaskBucket.doneToday), isFalse);

      // Database rows still exist
      final fetchedDone = await SimpleTaskRepository.instance.getById(done.id);
      expect(fetchedDone, isNotNull);
      expect(fetchedDone!.isDone, isTrue);
    });

    test('5. doneToday does not return tasks completed two weeks ago even if dueDate is today', () async {
      final twoWeeksAgo = now.subtract(const Duration(days: 14)).millisecondsSinceEpoch;
      
      // Directly insert task completed 2 weeks ago with dueDate today
      await db.insert('simple_tasks', {
        'id': 'old_done_task',
        'title': 'Old Done Task',
        'titleNormalized': 'old done task',
        'isDone': 1,
        'doneAt': twoWeeksAgo,
        'dueDate': '2026-08-20',
        'orderIndex': 1,
        'origin': 'SIMPLE',
        'isImportant': 0,
        'createdAt': twoWeeksAgo,
        'updatedAt': twoWeeksAgo,
      });

      final buckets = await SimpleTaskRepository.instance.buckets(now: DateTime(2026, 8, 20));
      final doneTasks = buckets[TaskBucket.doneToday] ?? [];
      expect(doneTasks.any((t) => t.id == 'old_done_task'), isFalse);
    });
  });
}
