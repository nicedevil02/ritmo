import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class MockTwoStageAgendaService implements DayAgendaService {
  final List<List<DateTime>> requestedRanges = [];

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    requestedRanges.add([start, end]);
    final result = <String, DayAgenda>{};
    var cur = DateKey.dayOf(start);
    final finish = DateKey.dayOf(end);
    while (!cur.isAfter(finish)) {
      final key = DateKey.of(cur);
      result[key] = DayAgenda(dateStr: key, items: const []);
      cur = DateKey.addDays(cur, 1);
    }
    return result;
  }

  @override
  Future<int> countOverdueBefore(DateTime cutoff) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-39: Two-Stage Agenda Range Loading', () {
    test('loadAgendaRange performs fast stage-1 query followed by full background stage-2 query', () async {
      final mockService = MockTwoStageAgendaService();
      final controller = JourneyController(agendaService: mockService);
      final anchor = DateTime(2026, 8, 18);

      await controller.loadAgendaRange(anchorDate: anchor);

      // Verify two queries were performed
      expect(mockService.requestedRanges.length, equals(2));

      // Stage 1: fast immediate window (-3 .. +3 days)
      final stage1Start = mockService.requestedRanges[0][0];
      final stage1End = mockService.requestedRanges[0][1];
      expect(stage1Start, equals(DateKey.addDays(anchor, -JourneyController.agendaFastWindowDays)));
      expect(stage1End, equals(DateKey.addDays(anchor, JourneyController.agendaFastWindowDays)));

      // Stage 2: full window (-14 .. +45 days)
      final stage2Start = mockService.requestedRanges[1][0];
      final stage2End = mockService.requestedRanges[1][1];
      expect(stage2Start, equals(DateKey.addDays(anchor, -JourneyController.agendaWindowDaysBack)));
      expect(stage2End, equals(DateKey.addDays(anchor, JourneyController.agendaWindowDaysForward)));

      // Verify controller state
      expect(controller.isLoading, isFalse);
      expect(controller.snapshot, isNotNull);
      expect(controller.rangeSnapshots.length, greaterThanOrEqualTo(60));
    });
  });
}
