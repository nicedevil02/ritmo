import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';
import 'package:ritmo/features/simple_tasks/data/simple_task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SqliteOccurrenceOverrideRepository repo;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await SqliteOccurrenceOverrideRepository.ensureTable(d);
        await d.execute('''
          CREATE TABLE simple_tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            titleNormalized TEXT,
            note TEXT,
            isDone INTEGER NOT NULL DEFAULT 0,
            dueDate TEXT,
            dueTime TEXT,
            reminderAtMs INTEGER,
            reminderId TEXT,
            linkedRoutineId TEXT,
            orderIndex INTEGER NOT NULL DEFAULT 0,
            origin TEXT NOT NULL DEFAULT 'SIMPLE',
            isImportant INTEGER NOT NULL DEFAULT 0,
            importantAt INTEGER,
            doneAt INTEGER,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          );
        ''');
      },
    );
    DatabaseHelper.databaseInstance = db;
    repo = const SqliteOccurrenceOverrideRepository();
  });

  tearDown(() async {
    DatabaseHelper.databaseInstance = null;
    await db.close();
  });

  group('CAL-16: _PostponeItemCommand Real Postpone with Correct Date Math', () {
    test('Standard task postpone (+1 day) updates dueDate and undo reverts it', () async {
      final today = DateKey.dayOf(DateTime.now());
      final todayStr = DateKey.of(today);
      final tomorrowStr = DateKey.of(DateKey.addDays(today, 1));

      await SimpleTaskRepository.instance.create(
        title: 'Task 101',
        dueDate: todayStr,
      );

      // Fetch created task ID
      final tasks = await SimpleTaskRepository.instance.today(todayStr);
      expect(tasks, isNotEmpty);
      final createdTask = tasks.first;

      final item = AgendaItem(
        id: 'task:${createdTask.id}:$todayStr',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: createdTask.id,
        title: 'Task 101',
        category: Category.work,
        deepLink: AgendaDeepLink(domain: AgendaDomain.task, targetId: createdTask.id),
        dateStr: todayStr,
      );

      final cmd = JourneyController.createPostponeItemCommand(
        item: item,
        days: 1,
        overrideRepo: repo,
        taskRepo: SimpleTaskRepository.instance,
      );

      // Execute postpone
      await cmd.execute();

      var task = await SimpleTaskRepository.instance.getById(createdTask.id);
      expect(task?.dueDate, equals(tomorrowStr));

      // Undo postpone
      await cmd.undo();

      task = await SimpleTaskRepository.instance.getById(createdTask.id);
      expect(task?.dueDate, equals(todayStr));
    });

    test('Overdue task postpone calculates base relative to today, not the past', () async {
      final today = DateKey.dayOf(DateTime.now());
      final pastDate = DateKey.addDays(today, -10);
      final pastDateStr = DateKey.of(pastDate);
      final expectedPostponedStr = DateKey.of(DateKey.addDays(today, 2));

      await SimpleTaskRepository.instance.create(
        title: 'Overdue Task',
        dueDate: pastDateStr,
      );

      final tasks = await SimpleTaskRepository.instance.today(DateKey.of(today));
      expect(tasks, isNotEmpty);
      final createdTask = tasks.first;

      final item = AgendaItem(
        id: 'task:${createdTask.id}:$pastDateStr',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: createdTask.id,
        title: 'Overdue Task',
        category: Category.work,
        deepLink: AgendaDeepLink(domain: AgendaDomain.task, targetId: createdTask.id),
        dateStr: pastDateStr,
      );

      final cmd = JourneyController.createPostponeItemCommand(
        item: item,
        days: 2,
        overrideRepo: repo,
        taskRepo: SimpleTaskRepository.instance,
      );

      await cmd.execute();

      final task = await SimpleTaskRepository.instance.getById(createdTask.id);
      expect(task?.dueDate, equals(expectedPostponedStr),
          reason: 'Overdue task must be postponed relative to today, not past');
    });

    test('Recurring item postpone creates SKIPPED on source day and MOVED on target day', () async {
      const routineId = 'routine-555';
      final today = DateKey.dayOf(DateTime.now());
      final todayStr = DateKey.of(today);
      final tomorrowStr = DateKey.of(DateKey.addDays(today, 1));

      final item = AgendaItem(
        id: 'routine:$routineId:$todayStr',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: routineId,
        title: 'Daily Meditation',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: routineId),
        dateStr: todayStr,
        timeOfDay: '08:00',
        durationMinutes: 20,
      );

      final cmd = JourneyController.createPostponeItemCommand(
        item: item,
        days: 1,
        overrideRepo: repo,
      );

      // Execute postpone
      await cmd.execute();

      final srcOvr = await repo.readOne('routine', routineId, todayStr);
      expect(srcOvr, isNotNull);
      expect(srcOvr!.status, equals('SKIPPED'));

      final tgtOvr = await repo.readOne('routine', routineId, tomorrowStr);
      expect(tgtOvr, isNotNull);
      expect(tgtOvr!.status, equals('MOVED'));
      expect(tgtOvr.timeOfDay, equals('08:00'));
      expect(tgtOvr.durationMinutes, equals(20));

      // Undo postpone
      await cmd.undo();

      final srcAfterUndo = await repo.readOne('routine', routineId, todayStr);
      expect(srcAfterUndo, isNull);

      final tgtAfterUndo = await repo.readOne('routine', routineId, tomorrowStr);
      expect(tgtAfterUndo, isNull);
    });

    test('Non-postponable domains (prayer, cycle) are rejected with Persian error message', () async {
      final controller = JourneyController();
      final item = AgendaItem(
        id: 'prayer:fajr:2026-08-18',
        domain: AgendaDomain.prayer,
        kind: AgendaItemKind.practice,
        sourceId: 'fajr',
        title: 'نماز صبح',
        category: Category.religious,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.prayer, targetId: 'fajr'),
        dateStr: '2026-08-18',
        timeOfDay: '04:30',
      );

      await controller.postponeItem(item);

      expect(controller.errorMessage, equals(CalendarMessagesFa.notSupported));
    });
  });
}
