import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/data/task_preferences.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:ritmo/features/simple_tasks/logic/my_day_service.dart';
import 'package:ritmo/features/simple_tasks/logic/my_day_suggestions.dart';
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

  group('MyDayService & Midnight Reset', () {
    test('1. resetIfNewDay in the same day does not remove any tasks from My Day', () async {
      final now = DateTime.now();
      final todayIso = DayKey.from(now).value;

      final task = await SimpleTaskRepository.instance.create(title: 'Task 1');
      await MyDayService.instance.addToMyDay(task.id);
      await TaskPreferences.setMyDayLastReset(todayIso);

      // Call reset on the same day
      await MyDayService.instance.resetIfNewDay();

      final myDayTasks = await MyDayService.instance.myDayTasks();
      expect(myDayTasks.length, equals(1));
      expect(myDayTasks.first.id, equals(task.id));
      expect(myDayTasks.first.isInMyDay, isTrue);
    });

    test('2. resetIfNewDay on the next day clears addedToMyDayAt, keeps row count & dueDate intact', () async {
      final yesterdayIso = '2026-08-19';

      final task1 = await SimpleTaskRepository.instance.create(title: 'Task 1', dueDate: '2026-08-25');
      final task2 = await SimpleTaskRepository.instance.create(title: 'Task 2', dueDate: '2026-08-26');

      await MyDayService.instance.addToMyDay(task1.id);
      await MyDayService.instance.addToMyDay(task2.id);

      // Simulate last reset was yesterday
      await TaskPreferences.setMyDayLastReset(yesterdayIso);

      // Reset for today
      await MyDayService.instance.resetIfNewDay();

      // Verify My Day is cleared
      final myDayTasks = await MyDayService.instance.myDayTasks();
      expect(myDayTasks, isEmpty);

      // Verify total tasks in DB is still 2 and dueDates untouched
      final allTasksRows = await db.query('simple_tasks');
      expect(allTasksRows.length, equals(2));

      final restoredTask1 = await SimpleTaskRepository.instance.getById(task1.id);
      final restoredTask2 = await SimpleTaskRepository.instance.getById(task2.id);

      expect(restoredTask1?.dueDate, equals('2026-08-25'));
      expect(restoredTask2?.dueDate, equals('2026-08-26'));
      expect(restoredTask1?.isInMyDay, isFalse);
      expect(restoredTask2?.isInMyDay, isFalse);
    });
  });

  group('MyDaySuggestions Engine', () {
    test('3. buildSuggestions caps results at 5 suggestions maximum', () async {
      final now = DateTime(2026, 8, 20);
      final todayIso = DayKey.from(now).value;

      // Create 8 tasks overdue
      for (int i = 1; i <= 8; i++) {
        await SimpleTaskRepository.instance.create(
          title: 'Overdue Task $i',
          dueDate: '2026-08-1$i',
        );
      }

      final suggestions = await buildSuggestions(now: now);
      expect(suggestions.length, equals(5));
      for (final s in suggestions) {
        expect(s.reason, equals(MyDaySuggestionReason.overdue));
      }
    });

    test('4. Tasks already in My Day are excluded from suggestions', () async {
      final now = DateTime(2026, 8, 20);
      final todayIso = DayKey.from(now).value;

      final t1 = await SimpleTaskRepository.instance.create(title: 'Task 1', dueDate: todayIso);
      final t2 = await SimpleTaskRepository.instance.create(title: 'Task 2', dueDate: todayIso);

      // Add t1 to My Day
      await MyDayService.instance.addToMyDay(t1.id);

      final suggestions = await buildSuggestions(now: now);
      expect(suggestions.length, equals(1));
      expect(suggestions.first.task.id, equals(t2.id));
    });
  });
}
