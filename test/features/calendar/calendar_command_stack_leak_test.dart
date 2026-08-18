import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';

class InMemoryOverrideRepository implements OccurrenceOverrideRepository {
  final Map<String, OccurrenceOverride> _map = {};

  @override
  Future<OccurrenceOverride?> readOne(String sourceType, String sourceId, String dateStr) async {
    return _map['${sourceType.toLowerCase()}:$sourceId:$dateStr'];
  }

  @override
  Future<void> upsert(OccurrenceOverride override) async {
    _map['${override.sourceType.toLowerCase()}:${override.sourceId}:${override.dateStr}'] = override;
  }

  @override
  Future<void> remove(String sourceType, String sourceId, String dateStr) async {
    _map.remove('${sourceType.toLowerCase()}:$sourceId:$dateStr');
  }

  @override
  Future<List<OccurrenceOverride>> readAllFuture(String sourceType, String sourceId, String fromDateStr, {String? untilDateStr}) async {
    return [];
  }

  @override
  Future<void> removeAllFuture(String sourceType, String sourceId, String fromDateStr, {String? untilDateStr}) async {}

  @override
  Future<void> restoreAll(List<OccurrenceOverride> overrides) async {
    for (final o in overrides) {
      _map['${o.sourceType.toLowerCase()}:${o.sourceId}:${o.dateStr}'] = o;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSimpleCommand implements UndoableCommand {
  MockSimpleCommand(this.id);
  final int id;
  bool executed = false;
  bool undone = false;

  @override
  String get description => 'Mock command $id';

  @override
  Future<void> execute() async {
    executed = true;
  }

  @override
  Future<void> undo() async {
    undone = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-25: CommandStack Decoupling and Bounded Capacity', () {
    setUp(() {
      CommandStack.instance.clear();
    });

    test('Calendar commands execute and undo without UI controller reference', () async {
      final repo = InMemoryOverrideRepository();
      final item = AgendaItem(
        id: 'routine:123:2026-08-18',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: '123',
        title: 'Morning Yoga',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '123'),
        dateStr: '2026-08-18',
        timeOfDay: '07:00',
        durationMinutes: 30,
      );

      final cmd = JourneyController.createSkipItemCommand(
        item: item,
        overrideRepo: repo,
      );

      await cmd.execute();
      final override = await repo.readOne('routine', '123', '2026-08-18');
      expect(override, isNotNull);
      expect(override!.status, equals('SKIPPED'));

      await cmd.undo();
      final afterUndo = await repo.readOne('routine', '123', '2026-08-18');
      expect(afterUndo, isNull);
    });

    test('CommandStack bounds maximum depth to maxStackDepth (50 items)', () {
      final stack = CommandStack.instance;
      for (int i = 0; i < 70; i++) {
        stack.push(MockSimpleCommand(i));
      }

      expect(stack.length, equals(CommandStack.maxStackDepth));
      expect(stack.canUndo, isTrue);
    });
  });
}
