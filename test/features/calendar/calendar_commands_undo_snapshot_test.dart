import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
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
          CREATE TABLE routine_schedules (
            id TEXT PRIMARY KEY,
            routineId TEXT NOT NULL,
            scheduleType TEXT NOT NULL,
            timeOfDay TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          );
        ''');
      },
    );
    await db.insert('routine_schedules', {
      'id': 'sched-888',
      'routineId': 'routine-888',
      'scheduleType': 'fixed',
      'timeOfDay': '07:00',
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    DatabaseHelper.databaseInstance = db;
    repo = const SqliteOccurrenceOverrideRepository();
  });

  tearDown(() async {
    DatabaseHelper.databaseInstance = null;
    await db.close();
  });

  group('_MoveItemCommand & _ResizeItemCommand Snapshot Undo (CAL-11 / CAL-57)', () {
    test('Undoing Move after a Resize preserves the previous Resize override duration', () async {
      const routineId = 'routine-777';
      const dateStr = '2026-08-18';
      final item = AgendaItem(
        id: 'routine:$routineId:$dateStr',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: routineId,
        title: 'Morning Exercise',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: routineId),
        dateStr: dateStr,
        timeOfDay: '07:00',
        durationMinutes: 30,
      );

      // 1. First action: Resize from 30 to 45 mins
      final resizeCmd = JourneyController.createResizeItemCommand(
        actionHandler: AgendaActionHandler.instance,
        item: item,
        oldDuration: 30,
        newDuration: 45,
        onRefresh: () async {},
        overrideRepo: repo,
      );
      await resizeCmd.execute();

      var override = await repo.readOne('routine', routineId, dateStr);
      expect(override, isNotNull);
      expect(override!.durationMinutes, equals(45));
      expect(override.status, equals('RESIZED'));

      // 2. Second action: Move from 07:00 to 09:30
      final moveCmd = JourneyController.createMoveItemCommand(
        actionHandler: AgendaActionHandler.instance,
        item: item.copyWith(durationMinutes: 45),
        oldTimeOfDay: '07:00',
        newTimeOfDay: '09:30',
        onRefresh: () async {},
        overrideRepo: repo,
      );
      await moveCmd.execute();

      override = await repo.readOne('routine', routineId, dateStr);
      expect(override, isNotNull);
      expect(override!.durationMinutes, equals(45));
      expect(override.timeOfDay, equals('09:30'));
      expect(override.status, equals('MOVED'));

      // 3. Undo Move: Should restore previous snapshot (duration=45, status='RESIZED', timeOfDay=null)
      await moveCmd.undo();

      override = await repo.readOne('routine', routineId, dateStr);
      expect(override, isNotNull, reason: 'Undo move wiped the entire override record');
      expect(override!.durationMinutes, equals(45), reason: 'Previous resize duration was lost');
      expect(override.timeOfDay, isNull, reason: 'Moved time was not reverted to null');
      expect(override.status, equals('RESIZED'));

      // 4. Undo Resize: Should remove override entirely since there was nothing before it
      await resizeCmd.undo();

      override = await repo.readOne('routine', routineId, dateStr);
      expect(override, isNull, reason: 'Override should be completely removed after undoing initial action');
    });

    test('allFutureDays move command snapshots and restores all deleted future overrides on undo (CAL-12 / CAL-57)', () async {
      const routineId = 'routine-888';
      const dateStr = '2026-08-18';
      const d1 = '2026-08-19';
      const d2 = '2026-08-20';
      const d3 = '2026-08-21';

      // 3 future custom overrides
      await repo.upsert(const OccurrenceOverride(
        sourceType: 'routine',
        sourceId: routineId,
        dateStr: d1,
        timeOfDay: '08:15',
        durationMinutes: 40,
        status: 'MOVED',
        createdAt: '2026-08-01T00:00:00Z',
        updatedAt: '2026-08-01T00:00:00Z',
      ));
      await repo.upsert(const OccurrenceOverride(
        sourceType: 'routine',
        sourceId: routineId,
        dateStr: d2,
        durationMinutes: 50,
        status: 'RESIZED',
        createdAt: '2026-08-01T00:00:00Z',
        updatedAt: '2026-08-01T00:00:00Z',
      ));
      await repo.upsert(const OccurrenceOverride(
        sourceType: 'routine',
        sourceId: routineId,
        dateStr: d3,
        note: 'Special routine',
        status: 'CUSTOM',
        createdAt: '2026-08-01T00:00:00Z',
        updatedAt: '2026-08-01T00:00:00Z',
      ));

      final item = AgendaItem(
        id: 'routine:$routineId:$dateStr',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: routineId,
        title: 'Morning Routine',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: routineId),
        dateStr: dateStr,
        timeOfDay: '07:00',
        durationMinutes: 30,
      );

      final moveAllCmd = JourneyController.createMoveItemCommand(
        actionHandler: AgendaActionHandler.instance,
        item: item,
        oldTimeOfDay: '07:00',
        newTimeOfDay: '10:00',
        onRefresh: () async {},
        scope: CalendarEditScope.allFutureDays,
        overrideRepo: repo,
      );

      // Execute allFutureDays move
      await moveAllCmd.execute();

      // All 3 future overrides should be removed by removeAllFuture
      var futureList = await repo.readAllFuture('routine', routineId, dateStr);
      expect(futureList, isEmpty, reason: 'Future overrides were not removed during allFutureDays move');

      // Undo allFutureDays move
      await moveAllCmd.undo();

      // All 3 future overrides must be completely restored!
      futureList = await repo.readAllFuture('routine', routineId, dateStr);
      expect(futureList.length, equals(3), reason: 'Future overrides were not restored on undo');

      final o1 = await repo.readOne('routine', routineId, d1);
      expect(o1?.timeOfDay, equals('08:15'));
      expect(o1?.durationMinutes, equals(40));

      final o2 = await repo.readOne('routine', routineId, d2);
      expect(o2?.durationMinutes, equals(50));

      final o3 = await repo.readOne('routine', routineId, d3);
      expect(o3?.note, equals('Special routine'));
    });
  });
}
