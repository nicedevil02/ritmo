import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class StubDayAgendaService implements DayAgendaService {
  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
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

  group('CAL-19: Explicit Window Bounds and Background Refresh Flag', () {
    test('Initial load populates windowStart and windowEnd for agenda scale', () async {
      final controller = JourneyController(agendaService: StubDayAgendaService());
      final anchor = DateKey.dayOf(DateTime.now());

      await controller.loadAgendaRange(anchorDate: anchor);

      expect(controller.windowStart, equals(DateKey.addDays(anchor, -JourneyController.agendaWindowDaysBack)));
      expect(controller.windowEnd, equals(DateKey.addDays(anchor, JourneyController.agendaWindowDaysForward)));
      expect(controller.snapshot, isNotNull);
      expect(controller.isLoading, isFalse);

      // Verify that background refresh does not flip isLoading to true when snapshot exists
      final loadingStates = <bool>[];
      controller.addListener(() {
        loadingStates.add(controller.isLoading);
      });

      await controller.refresh();

      // Ensure isLoading remained false throughout background refresh
      expect(loadingStates.every((state) => state == false), isTrue,
          reason: 'Background refresh must never flip isLoading to true when snapshot exists');
    });

    test('Non-agenda scale populates windowStart and windowEnd', () async {
      final controller = JourneyController(agendaService: StubDayAgendaService());
      final anchor = DateTime(2026, 8, 18);

      controller.selectDate(anchor, scaleToSet: JourneyScale.day);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.windowStart, equals(DateKey.dayOf(anchor)));
      expect(controller.windowEnd, equals(DateKey.dayOf(anchor)));
    });
  });
}
