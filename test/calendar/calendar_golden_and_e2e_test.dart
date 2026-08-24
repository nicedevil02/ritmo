import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/models/now_pill_view_model.dart';
import 'package:ritmo/features/calendar/presentation/widgets/now_pill.dart';
import 'package:ritmo/features/simple_tasks/domain/simple_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestDayAgendaService extends DayAgendaService {
  TestDayAgendaService() : super.test();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(
    DateTime start,
    DateTime end, {
    AgendaQueryOptions? options,
  }) async {
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SqliteOccurrenceOverrideRepository overrideRepo;
  late TestDayAgendaService agendaService;

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
    overrideRepo = const SqliteOccurrenceOverrideRepository();
    agendaService = TestDayAgendaService();
  });

  tearDown(() async {
    CommandStack.instance.clear();
    DatabaseHelper.databaseInstance = null;
    await db.close();
  });

  group('CAL-60: RTL Text Scaler Golden Overflow Tests (1.0, 1.3, 1.6)', () {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('NowPill renders without overflow at textScaleFactor $scale in RTL', (tester) async {
        final currentItem = AgendaItem(
          id: 'routine:reading:2026-08-18',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          sourceId: 'reading',
          title: 'مطالعهٔ عمیق کتاب معماری سیستم‌های توزیع‌شده با یادداشت‌برداری تفصیلی',
          category: Category.learning,
          dateStr: '2026-08-18',
          timeOfDay: '10:00',
          durationMinutes: 45,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'reading'),
        );

        final viewModel = NowPillViewModel(
          isVisible: true,
          isCurrent: true,
          targetItem: currentItem,
          statusLabel: 'در حال انجام',
          timeLabel: '۱۰:۰۰',
          remainingMinutesCurrent: 25,
          nextItemTitle: 'ورزش عصرگاهی و تمرینات کششی سبک',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: RitmoTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(scale),
                size: const Size(390, 844),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: NowPill(
                        viewModel: viewModel,
                        onTapPill: () {},
                        onTapComplete: () {},
                        onTapStartFocus: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byType(NowPill), findsOneWidget);
        expect(find.textContaining('مطالعهٔ عمیق'), findsOneWidget);
        expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
      });
    }
  });

  group('CAL-60: Full End-to-End User Flow & Triple Undo Regression Test', () {
    test('User journey: 3 items -> drag -> resize -> skip -> postpone -> 3x undo', () async {
      // 1. Setup initial tasks and controller
      final task1 = SimpleTask(
        id: 't1',
        title: 'Task 1 - Morning Planning',
        dueDate: '2026-08-18',
        dueTime: '08:00',
        createdAt: DateTime(2026, 8, 18, 7, 0),
        updatedAt: DateTime(2026, 8, 18, 7, 0),
      );
      final task3 = SimpleTask(
        id: 't3',
        title: 'Task 3 - Review Code',
        dueDate: '2026-08-18',
        dueTime: '14:00',
        createdAt: DateTime(2026, 8, 18, 7, 0),
        updatedAt: DateTime(2026, 8, 18, 7, 0),
      );

      await db.insert('simple_tasks', task1.toMap());
      await db.insert('simple_tasks', task3.toMap());

      final controller = JourneyController(
        agendaService: agendaService,
        overrideRepo: overrideRepo,
      );

      final item1 = AgendaItem(
        id: 'task:t1:2026-08-18',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: 't1',
        title: 'Task 1 - Morning Planning',
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '08:00',
        durationMinutes: 60,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 't1'),
      );

      final item2 = AgendaItem(
        id: 'routine:r2:2026-08-18',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'r2',
        title: 'Routine 2 - Meditation',
        category: Category.personal,
        dateStr: '2026-08-18',
        timeOfDay: '10:00',
        durationMinutes: 30,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'r2'),
      );

      final item3 = AgendaItem(
        id: 'task:t3:2026-08-18',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: 't3',
        title: 'Task 3 - Review Code',
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '14:00',
        durationMinutes: 45,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 't3'),
      );

      // 2. Drag item 1 to 09:00
      await controller.commitItemDrag(item1, '09:00');
      var override1 = await overrideRepo.readOne('task', 't1', '2026-08-18');
      expect(override1?.timeOfDay, equals('09:00'));

      // 3. Resize item 2 from 30m to 60m
      await controller.commitItemResize(item2, 60);
      var override2 = await overrideRepo.readOne('routine', 'r2', '2026-08-18');
      expect(override2?.durationMinutes, equals(60));

      // 4. Skip item 3
      await controller.skipItem(item3);
      var override3 = await overrideRepo.readOne('task', 't3', '2026-08-18');
      expect(override3?.status, equals('SKIPPED'));

      // 5. Postpone item 1 by 2 days
      await controller.postponeItem(item1, days: 2);
      final postponedTask = await db.query('simple_tasks', where: 'id = ?', whereArgs: ['t1']);
      final expectedPostponedDate = DateKey.of(DateKey.addDays(DateTime.now(), 2));
      expect(postponedTask.first['dueDate'], equals(expectedPostponedDate));

      // 6. Execute 3 consecutive undos
      expect(controller.canUndo, isTrue);

      // Undo 1: Postpone item 1 undone -> dueDate returns to 2026-08-18
      await controller.undoLastAction();
      final restoredTask1 = await db.query('simple_tasks', where: 'id = ?', whereArgs: ['t1']);
      expect(restoredTask1.first['dueDate'], equals('2026-08-18'));

      // Undo 2: Skip item 3 undone -> override3 removed
      await controller.undoLastAction();
      override3 = await overrideRepo.readOne('task', 't3', '2026-08-18');
      expect(override3, isNull);

      // Undo 3: Resize item 2 undone -> override2 removed / restored to initial
      await controller.undoLastAction();
      override2 = await overrideRepo.readOne('routine', 'r2', '2026-08-18');
      expect(override2, isNull);

      // Verify item 1 drag is still intact (the 4th action from the end)
      override1 = await overrideRepo.readOne('task', 't1', '2026-08-18');
      expect(override1?.timeOfDay, equals('09:00'));

      // Undo 4: Drag item 1 undone -> override1 removed
      await controller.undoLastAction();
      override1 = await overrideRepo.readOne('task', 't1', '2026-08-18');
      expect(override1, isNull);

      // Verify stack is now empty
      expect(controller.canUndo, isFalse);

      controller.dispose();
    });
  });
}
