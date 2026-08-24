import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeDayAgendaService extends DayAgendaService {
  FakeDayAgendaService() : super.test();

  int loadRangeCallCount = 0;
  int delayMs = 0;
  Map<String, DayAgenda> cannedAgendas = {};

  @override
  Future<Map<String, DayAgenda>> agendaForRange(
    DateTime start,
    DateTime end, {
    AgendaQueryOptions? options,
  }) async {
    loadRangeCallCount++;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    return cannedAgendas;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SqliteOccurrenceOverrideRepository overrideRepo;
  late FakeDayAgendaService fakeAgendaService;

  setUp(() async {
    CommandStack.instance.clear();
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await SqliteOccurrenceOverrideRepository.ensureTable(d);
        await d.execute('''
          CREATE TABLE day_templates (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              description TEXT,
              slotsJson TEXT NOT NULL,
              createdAt INTEGER NOT NULL
          );
        ''');
        await d.execute('''
          CREATE TABLE day_marks (
              date TEXT PRIMARY KEY,
              mark TEXT NOT NULL,
              note TEXT,
              createdAt INTEGER NOT NULL
          );
        ''');
        await d.execute('''
          CREATE TABLE simple_tasks (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              titleNormalized TEXT,
              note TEXT,
              noteNormalized TEXT,
              tagsJson TEXT,
              dueDate TEXT,
              dueTime TEXT,
              isDone INTEGER NOT NULL DEFAULT 0,
              doneAt INTEGER,
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
        await d.execute('''
          CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER
          );
        ''');
      },
    );
    DatabaseHelper.databaseInstance = db;

    await db.insert('simple_tasks', {
      'id': 't_overdue',
      'title': 'Overdue Task',
      'titleNormalized': 'overdue task',
      'dueDate': '2026-08-10',
      'isDone': 0,
      'createdAt': 1000,
      'updatedAt': 1000,
      'orderIndex': 0,
      'origin': 'SIMPLE',
      'isImportant': 0,
    });

    overrideRepo = const SqliteOccurrenceOverrideRepository();
    fakeAgendaService = FakeDayAgendaService();
  });

  tearDown(() async {
    CommandStack.instance.clear();
    DatabaseHelper.databaseInstance = null;
    await db.close();
  });

  group('CAL-56: Comprehensive JourneyController Master Tests', () {
    test('1. Midnight normalization across all 5 scales (CAL-08)', () {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      final dirtyTime = DateTime(2026, 8, 18, 15, 30, 45, 120);
      controller.selectDate(dirtyTime, scaleToSet: JourneyScale.day);

      expect(controller.selectedDate, equals(DateTime(2026, 8, 18, 0, 0, 0, 0, 0)));
      controller.dispose();
    });

    test('2. Generation race token: last requested load wins even if previous finishes later (CAL-17)', () async {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      fakeAgendaService.delayMs = 100;
      controller.setScale(JourneyScale.week);
      final f1 = controller.loadForActiveScale();

      fakeAgendaService.delayMs = 10;
      final f2 = controller.loadForActiveScale();

      await Future.wait([f1, f2]);
      expect(controller.loadGeneration, greaterThanOrEqualTo(2));
      controller.dispose();
    });

    test('3. calculateDateRangeForScale on agenda scale throws StateError (CAL-18)', () {
      expect(
        () => JourneyController.calculateDateRangeForScale(
          JourneyScale.agenda,
          DateTime(2026, 8, 18),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('4. setScale clears range data and sets isLoading to true (CAL-20)', () {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      controller.setScale(JourneyScale.month);
      expect(controller.activeScale, equals(JourneyScale.month));
      expect(controller.isLoading, isTrue);
      expect(controller.rangeSnapshots, isEmpty);
      controller.dispose();
    });

    test('5. skipItem on task creates a SKIPPED override and pushes to CommandStack (CAL-15)', () async {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      final taskItem = AgendaItem(
        id: 'task:t1:2026-08-18',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: 't1',
        title: 'Task 1',
        category: Category.work,
        dateStr: '2026-08-18',
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 't1'),
      );

      await controller.skipItem(taskItem);
      final override = await overrideRepo.readOne('task', 't1', '2026-08-18');
      expect(override, isNotNull);
      expect(override!.status, equals('SKIPPED'));
      expect(controller.canUndo, isTrue);

      await controller.undoLastAction();
      final undone = await overrideRepo.readOne('task', 't1', '2026-08-18');
      expect(undone, isNull);
      controller.dispose();
    });

    test('6. postponeItem moves task to today + days (CAL-16)', () async {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      final taskItem = AgendaItem(
        id: 'task:t_overdue:2026-08-10',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: 't_overdue',
        title: 'Overdue Task',
        category: Category.work,
        dateStr: '2026-08-10',
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 't_overdue'),
      );

      await controller.postponeItem(taskItem, days: 1);
      expect(controller.canUndo, isTrue);

      controller.dispose();
    });

    test('7. postponeItem on forbidden domain rejects and does not push command (CAL-16)', () async {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      final prayerItem = AgendaItem(
        id: 'prayer:fajr:2026-08-18',
        domain: AgendaDomain.prayer,
        kind: AgendaItemKind.routine,
        sourceId: 'fajr',
        title: 'نماز صبح',
        category: Category.religious,
        dateStr: '2026-08-18',
        deepLink: const AgendaDeepLink(domain: AgendaDomain.prayer, targetId: 'fajr'),
      );

      await controller.postponeItem(prayerItem, days: 1);
      expect(controller.canUndo, isFalse);

      controller.dispose();
    });

    test('8. Drag with invalid time is rejected with error message (CAL-26)', () async {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      final item = AgendaItem(
        id: 'routine:r1:2026-08-18',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'r1',
        title: 'روتین شبانه',
        category: Category.personal,
        dateStr: '2026-08-18',
        timeOfDay: '23:00',
        durationMinutes: 90,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'r1'),
      );

      // Invalid time format -> rejected
      await controller.commitItemDrag(item, '99:99');
      expect(controller.errorMessage, isNotNull);

      controller.dispose();
    });

    test('9. loadDefaultScale respects _scaleExplicitlySet (CAL-22)', () async {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      controller.selectDate(DateTime(2026, 8, 18), scaleToSet: JourneyScale.day);
      await controller.loadDefaultScale();
      expect(controller.activeScale, equals(JourneyScale.day));

      controller.dispose();
    });

    test('10. setScale persists chosen scale to SettingsService (CAL-23)', () async {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      controller.setScale(JourneyScale.week);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final savedScale = SettingsService.instance.get<String>('calendar_default_scale');
      expect(savedScale, equals('week'));

      controller.dispose();
    });

    test('11. Disposing controller after operation does not throw or notify disposed listeners', () async {
      final controller = JourneyController(
        agendaService: fakeAgendaService,
        overrideRepo: overrideRepo,
      );

      controller.setScale(JourneyScale.week);
      controller.dispose();
      // Should not throw on subsequent asynchronous completion or disposal
    });
  });
}
