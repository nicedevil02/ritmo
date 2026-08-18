import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
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

  group('CAL-15: _SkipItemCommand Non-Routine Skip', () {
    test('skipItem on a task creates a SKIPPED override and undo restores state', () async {
      const taskId = 'task-999';
      const dateStr = '2026-08-18';
      final item = AgendaItem(
        id: 'task:$taskId:$dateStr',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: taskId,
        title: 'Submit Expense Report',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: taskId),
        dateStr: dateStr,
        timeOfDay: '14:00',
        durationMinutes: 45,
      );

      final skipCmd = JourneyController.createSkipItemCommand(
        item: item,
        onRefresh: () async {},
        overrideRepo: repo,
      );

      // Execute skip
      await skipCmd.execute();

      var override = await repo.readOne('task', taskId, dateStr);
      expect(override, isNotNull, reason: 'Skip override was not created in repository');
      expect(override!.status, equals('SKIPPED'));

      // Undo skip
      await skipCmd.undo();

      override = await repo.readOne('task', taskId, dateStr);
      expect(override, isNull, reason: 'Undo skip did not remove the SKIPPED override');
    });
  });
}
