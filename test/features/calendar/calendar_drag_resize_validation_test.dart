import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';

class StubActionHandler extends AgendaActionHandler {
  StubActionHandler() : super.test();

  String? lastMovedTime;
  int? lastResizedDuration;

  @override
  Future<void> updateAgendaItemTimeAndDuration({
    required AgendaItem item,
    String? newTimeOfDay,
    int? newDurationMinutes,
  }) async {
    lastMovedTime = newTimeOfDay;
    lastResizedDuration = newDurationMinutes;
  }
}

class FakeDayAgendaService implements DayAgendaService {
  FakeDayAgendaService(this.items);
  final List<AgendaItem> items;

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    return {
      '2026-08-18': DayAgenda(dateStr: '2026-08-18', items: items),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-26: Drag and Resize Validation, Snapping, and Overlap Warning', () {
    test('commitItemDrag with invalid time format is rejected with error', () async {
      final actionHandler = StubActionHandler();
      final overrideRepo = InMemoryOverrideRepository();
      final controller = JourneyController(
        actionHandler: actionHandler,
        agendaService: FakeDayAgendaService([]),
        overrideRepo: overrideRepo,
      );

      final item = AgendaItem(
        id: 'routine:1:2026-08-18',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: '1',
        title: 'Task 1',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '1'),
        dateStr: '2026-08-18',
        timeOfDay: '08:00',
        durationMinutes: 30,
      );

      await controller.commitItemDrag(item, 'invalid_time_str');

      expect(controller.errorMessage, equals(CalendarMessagesFa.invalidTime));
      expect(actionHandler.lastMovedTime, isNull);
    });

    test('commitItemDrag crossing midnight (e.g. 23:50 with 30m) is clamped safely within day bounds', () async {
      final actionHandler = StubActionHandler();
      final overrideRepo = InMemoryOverrideRepository();
      final controller = JourneyController(
        actionHandler: actionHandler,
        agendaService: FakeDayAgendaService([]),
        overrideRepo: overrideRepo,
      );

      final item = AgendaItem(
        id: 'routine:1:2026-08-18',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: '1',
        title: 'Late Routine',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '1'),
        dateStr: '2026-08-18',
        timeOfDay: '23:00',
        durationMinutes: 30,
      );

      // 23:50 is 1430 minutes, 1430 + 30 = 1460 > 1440
      await controller.commitItemDrag(item, '23:50');

      // Snapping helper safely clamps start to 1440 - 30 = 1410 (23:30)
      final override = await overrideRepo.readOne(item.domain.name, item.sourceId, item.dateStr);
      expect(override?.timeOfDay, equals('23:30'));
    });

    test('commitItemDrag snaps 09:07 to 09:00 or 09:15 interval', () async {
      final actionHandler = StubActionHandler();
      final overrideRepo = InMemoryOverrideRepository();
      final controller = JourneyController(
        actionHandler: actionHandler,
        agendaService: FakeDayAgendaService([]),
        overrideRepo: overrideRepo,
      );

      final item = AgendaItem(
        id: 'routine:1:2026-08-18',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: '1',
        title: 'Morning Routine',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '1'),
        dateStr: '2026-08-18',
        timeOfDay: '08:00',
        durationMinutes: 30,
      );

      await controller.commitItemDrag(item, '09:07');

      final override = await overrideRepo.readOne(item.domain.name, item.sourceId, item.dateStr);
      expect(override?.timeOfDay, equals('09:00'),
          reason: '09:07 (547 mins) snaps to 540 mins (09:00)');
    });

    test('commitItemDrag overlapping another item executes but sets warningMessage', () async {
      final actionHandler = StubActionHandler();
      final overrideRepo = InMemoryOverrideRepository();
      final existingItem = AgendaItem(
        id: 'routine:existing:2026-08-18',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'existing',
        title: 'Existing Meeting',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'existing'),
        dateStr: '2026-08-18',
        timeOfDay: '10:00',
        durationMinutes: 60,
      );

      final itemToMove = AgendaItem(
        id: 'routine:tomove:2026-08-18',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'tomove',
        title: 'Call',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'tomove'),
        dateStr: '2026-08-18',
        timeOfDay: '08:00',
        durationMinutes: 30,
      );

      final service = FakeDayAgendaService([existingItem, itemToMove]);
      final controller = JourneyController(
        actionHandler: actionHandler,
        agendaService: service,
        overrideRepo: overrideRepo,
      );

      // Load agenda so snapshot exists
      await controller.loadAgendaRange(anchorDate: DateTime(2026, 8, 18));

      // Move into existing item window (10:00 - 11:00)
      await controller.commitItemDrag(itemToMove, '10:15');

      final override = await overrideRepo.readOne(itemToMove.domain.name, itemToMove.sourceId, itemToMove.dateStr);
      expect(override?.timeOfDay, equals('10:15'));
      expect(controller.warningMessage, equals(CalendarMessagesFa.overlap),
          reason: 'Overlap should issue a warning message without blocking the user');
    });
  });
}
