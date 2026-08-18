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
      },
    );
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
  });
}
