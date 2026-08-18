import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/logic/gap_finder.dart';

class StubGapAgendaService implements DayAgendaService {
  StubGapAgendaService(this.items);
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
  Future<int> countOverdueBefore(DateTime cutoff) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

AgendaItem _createItem({
  required String id,
  required String sourceId,
  required String title,
  required String timeOfDay,
  required int durationMinutes,
}) {
  return AgendaItem(
    id: id,
    sourceId: sourceId,
    title: title,
    domain: AgendaDomain.routine,
    kind: AgendaItemKind.routine,
    category: Category.fitness,
    deepLink: AgendaDeepLink(domain: AgendaDomain.routine, targetId: sourceId),
    timeOfDay: timeOfDay,
    durationMinutes: durationMinutes,
    dateStr: '2026-08-18',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-43: Smart Fit - GapFinder and Suggested Slot', () {
    test('Empty day returns full day window as free gap', () {
      final gaps = GapFinder.findFreeGaps([], minDurationMinutes: 30);
      expect(gaps.length, equals(1));
      expect(gaps.first.startMinutes, equals(6 * 60));
      expect(gaps.first.durationMinutes, equals(17 * 60)); // 06:00 to 23:00
    });

    test('findFreeGaps identifies gaps between occupied slots', () {
      final items = [
        _createItem(
          id: 'item1',
          sourceId: '1',
          title: 'Morning Routine',
          timeOfDay: '08:00', // 480-540
          durationMinutes: 60,
        ),
        _createItem(
          id: 'item2',
          sourceId: '2',
          title: 'Afternoon Study',
          timeOfDay: '12:00', // 720-840
          durationMinutes: 120,
        ),
      ];

      final gaps = GapFinder.findFreeGaps(items, minDurationMinutes: 30);
      // Gaps: 06:00-08:00 (360-480, 120min), 09:00-12:00 (540-720, 180min), 14:00-23:00 (840-1380, 540min)
      expect(gaps.length, equals(3));
      expect(gaps[0].startMinutes, equals(360));
      expect(gaps[0].durationMinutes, equals(120));
      expect(gaps[1].startMinutes, equals(540));
      expect(gaps[1].durationMinutes, equals(180));
      expect(gaps[2].startMinutes, equals(840));
      expect(gaps[2].durationMinutes, equals(540));
    });

    test('findFreeGaps ranks gaps by proximity to preferredStartMinutes', () {
      final items = [
        _createItem(
          id: 'item1',
          sourceId: '1',
          title: 'Morning',
          timeOfDay: '08:00', // 480-540
          durationMinutes: 60,
        ),
        _createItem(
          id: 'item2',
          sourceId: '2',
          title: 'Noon',
          timeOfDay: '12:00', // 720-840
          durationMinutes: 120,
        ),
      ];

      // Preferred start is 10:00 (600) -> Gap at 09:00 (540) is closest (diff 60)
      final gaps = GapFinder.findFreeGaps(
        items,
        minDurationMinutes: 30,
        preferredStartMinutes: 600,
      );

      expect(gaps.first.startMinutes, equals(540));
    });

    test('commitItemDrag on overlap sets warningMessage and suggestedSlot', () async {
      final existingItem = _createItem(
        id: 'existing',
        sourceId: '10',
        title: 'Existing Task',
        timeOfDay: '10:00', // 600-660
        durationMinutes: 60,
      );
      final dragItem = _createItem(
        id: 'dragged',
        sourceId: '20',
        title: 'Dragged Task',
        timeOfDay: '07:00',
        durationMinutes: 60,
      );

      final service = StubGapAgendaService([existingItem, dragItem]);
      final controller = JourneyController(
        agendaService: service,
        actionHandler: StubActionHandler(),
        overrideRepo: InMemoryOverrideRepo(),
      );

      controller.selectDate(DateTime(2026, 8, 18), scaleToSet: JourneyScale.day);
      await controller.loadForActiveScale();

      // Drag into 10:30 (overlaps with existing 10:00-11:00)
      await controller.commitItemDrag(dragItem, '10:30');

      expect(controller.warningMessage, isNotNull);
      expect(controller.suggestedSlot, isNotNull);
      // Suggested slot should be a free gap in the day
      expect(controller.suggestedSlot!.durationMinutes, greaterThanOrEqualTo(60));
    });
  });
}
