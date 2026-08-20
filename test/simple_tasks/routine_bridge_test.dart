import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:ritmo/features/simple_tasks/logic/routine_task_bridge.dart';
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
            CREATE TABLE routines (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              isArchived INTEGER NOT NULL DEFAULT 0,
              displayOrder INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL
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
              isDone INTEGER NOT NULL DEFAULT 0,
              displayOrder INTEGER NOT NULL DEFAULT 0,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE task_attachments (
              id TEXT PRIMARY KEY,
              taskId TEXT NOT NULL,
              fileName TEXT NOT NULL,
              relativePath TEXT NOT NULL,
              fileSizeBytes INTEGER NOT NULL,
              mimeType TEXT NOT NULL,
              createdAt INTEGER NOT NULL
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

  group('Phase 6: Routine Task Bridge Tests (T-37)', () {
    final now = DateTime(2026, 8, 20, 8, 0);

    test('1. First execution of materializeTodayRoutineTasks creates tasks', () async {
      await db.insert('routines', {'id': 'r1', 'title': 'ورزش صبحگاهی', 'isArchived': 0, 'displayOrder': 1, 'createdAt': now.millisecondsSinceEpoch});
      await db.insert('routines', {'id': 'r2', 'title': 'مطالعه روزانه', 'isArchived': 0, 'displayOrder': 2, 'createdAt': now.millisecondsSinceEpoch});

      final count = await RoutineTaskBridge.materializeTodayRoutineTasks(now: now);
      expect(count, equals(2));

      final tasks = await SimpleTaskRepository.instance.getAll();
      expect(tasks.length, equals(2));
      expect(tasks.map((t) => t.title), containsAll(['ورزش صبحگاهی', 'مطالعه روزانه']));
    });

    test('2. Second execution on the same day creates 0 tasks (Idempotency)', () async {
      await db.insert('routines', {'id': 'r1', 'title': 'ورزش صبحگاهی', 'isArchived': 0, 'displayOrder': 1, 'createdAt': now.millisecondsSinceEpoch});

      final count1 = await RoutineTaskBridge.materializeTodayRoutineTasks(now: now);
      expect(count1, equals(1));

      final count2 = await RoutineTaskBridge.materializeTodayRoutineTasks(now: now);
      expect(count2, equals(0));

      final tasks = await SimpleTaskRepository.instance.getAll();
      expect(tasks.length, equals(1));
    });

    test('3. If user manually deletes the generated task, it is not recreated on the same day', () async {
      await db.insert('routines', {'id': 'r1', 'title': 'ورزش صبحگاهی', 'isArchived': 0, 'displayOrder': 1, 'createdAt': now.millisecondsSinceEpoch});

      await RoutineTaskBridge.materializeTodayRoutineTasks(now: now);
      final tasks = await SimpleTaskRepository.instance.getAll();
      expect(tasks.length, equals(1));

      // User deletes task
      await SimpleTaskRepository.instance.delete(tasks.first.id);
      expect(await SimpleTaskRepository.instance.getAll(), isEmpty);

      // Subsequent call on same day
      final countAgain = await RoutineTaskBridge.materializeTodayRoutineTasks(now: now);
      expect(countAgain, equals(0));
      expect(await SimpleTaskRepository.instance.getAll(), isEmpty);
    });

    test('4. With 20 active routines, at most 5 tasks are materialized', () async {
      for (int i = 1; i <= 20; i++) {
        await db.insert('routines', {
          'id': 'routine_$i',
          'title': 'روتین شماره $i',
          'isArchived': 0,
          'displayOrder': i,
          'createdAt': now.millisecondsSinceEpoch,
        });
      }

      final count = await RoutineTaskBridge.materializeTodayRoutineTasks(now: now);
      expect(count, equals(5));

      final tasks = await SimpleTaskRepository.instance.getAll();
      expect(tasks.length, equals(5));
    });

    test('5. Materialized task has origin PROMOTED and is NOT in My Day', () async {
      await db.insert('routines', {'id': 'r1', 'title': 'ورزش صبحگاهی', 'isArchived': 0, 'displayOrder': 1, 'createdAt': now.millisecondsSinceEpoch});

      await RoutineTaskBridge.materializeTodayRoutineTasks(now: now);
      final tasks = await SimpleTaskRepository.instance.getAll();
      expect(tasks.first.origin, equals('PROMOTED'));
      expect(tasks.first.linkedRoutineId, equals('r1'));
      expect(tasks.first.isInMyDay, isFalse);
      expect(tasks.first.dueDate, equals(DayKey.from(now).value));
    });
  });
}
