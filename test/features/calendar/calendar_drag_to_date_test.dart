import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class StubAgendaService implements DayAgendaService {
  StubAgendaService(this.items);
  List<AgendaItem> items;
  final List<String> invalidatedDates = [];

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    return {
      '2026-08-18': DayAgenda(dateStr: '2026-08-18', items: items),
      '2026-08-19': const DayAgenda(dateStr: '2026-08-19', items: []),
    };
  }

  @override
  void invalidateDate(String dateStr) {
    invalidatedDates.add(dateStr);
  }

  @override
  void invalidateAll() {}

  @override
  Future<int> countOverdueBefore(DateTime cutoff) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubActionHandler extends AgendaActionHandler {
  StubActionHandler() : super.test();
}

class InMemoryOverrideRepo implements OccurrenceOverrideRepository {
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
  Future<List<OccurrenceOverride>> readAllFuture(String sourceType, String sourceId, String fromDateStr, {String? untilDateStr}) async => [];

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-48: Move Item Across Days with Multi-Day Drag & Undo', () {
    setUp(() {
      CommandStack.instance.clear();
    });

    test('moveItemToDate creates source SKIPPED override, target MOVED override and undo restores both', () async {
      final item = AgendaItem(
        id: 'r1',
        sourceId: '1',
        title: 'ورزش صبحگاهی',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '1'),
        timeOfDay: '07:00',
        durationMinutes: 45,
        dateStr: '2026-08-18',
      );

      final service = StubAgendaService([item]);
      final overrideRepo = InMemoryOverrideRepo();
      final actionHandler = StubActionHandler();

      final controller = JourneyController(
        agendaService: service,
        actionHandler: actionHandler,
        overrideRepo: overrideRepo,
      );

      controller.selectDate(DateTime(2026, 8, 18), scaleToSet: JourneyScale.day);
      await controller.loadForActiveScale();

      // Move item from 2026-08-18 to 2026-08-19
      final targetDate = DateTime(2026, 8, 19);
      await controller.moveItemToDate(item, targetDate);

      // Verify overrides
      final sourceOverride = await overrideRepo.readOne('routine', '1', '2026-08-18');
      expect(sourceOverride, isNotNull);
      expect(sourceOverride!.status, equals('SKIPPED'));

      final targetOverride = await overrideRepo.readOne('routine', '1', '2026-08-19');
      expect(targetOverride, isNotNull);
      expect(targetOverride!.status, equals('MOVED'));
      expect(targetOverride.timeOfDay, equals('07:00'));
      expect(targetOverride.durationMinutes, equals(45));

      // Undo move
      final undone = await controller.undoLastAction();
      expect(undone, isTrue);

      final sourceAfterUndo = await overrideRepo.readOne('routine', '1', '2026-08-18');
      expect(sourceAfterUndo, isNull);

      final targetAfterUndo = await overrideRepo.readOne('routine', '1', '2026-08-19');
      expect(targetAfterUndo, isNull);
    });
  });
}
