import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class CallCountingDayAgendaService implements DayAgendaService {
  int agendaForRangeCallCount = 0;

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    agendaForRangeCallCount++;
    return {};
  }

  @override
  Future<int> countOverdueBefore(DateTime cutoff) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-24: Refresh Storm Debounce and Coalescing', () {
    test('10 rapid events within 50ms coalesce into exactly 1 agendaForRange call', () async {
      final bus = RitmoEventBus();
      final service = CallCountingDayAgendaService();
      final controller = JourneyController(
        agendaService: service,
        eventBus: bus,
      );

      // Initial load (2 calls: stage 1 + stage 2)
      await controller.loadAgendaRange(anchorDate: DateTime(2026, 8, 18));
      expect(service.agendaForRangeCallCount, equals(2));

      // Emit 10 rapid events on the bus
      for (int i = 0; i < 10; i++) {
        bus.fire(RitmoEvent(
          type: 'TaskToggled',
          timestamp: DateTime.now(),
          payload: {'date': '2026-08-18'},
        ));
      }

      // Wait 100ms (less than 250ms debounce)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(service.agendaForRangeCallCount, equals(2),
          reason: 'Before debounce timer elapses, no extra reloads should execute');

      // Wait until debounce (250ms) completes
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(service.agendaForRangeCallCount, equals(4),
          reason: '10 rapid events must coalesce into exactly 1 refresh call (2 stages)');

      controller.dispose();
    });

    test('Out-of-window event date does NOT trigger calendar reload', () async {
      final bus = RitmoEventBus();
      final service = CallCountingDayAgendaService();
      final controller = JourneyController(
        agendaService: service,
        eventBus: bus,
      );

      // Initial load for 2026-08-18 (window: ~2026-08-04 to 2026-10-02)
      await controller.loadAgendaRange(anchorDate: DateTime(2026, 8, 18));
      expect(service.agendaForRangeCallCount, equals(2));

      // Fire an event 1 year in the future (outside loaded window)
      bus.fire(RitmoEvent(
        type: 'TaskToggled',
        timestamp: DateTime.now(),
        payload: {'date': '2027-08-18'},
      ));

      // Wait for debounce window
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(service.agendaForRangeCallCount, equals(2),
          reason: 'Event outside window bounds must be discarded to prevent pointless reload');

      controller.dispose();
    });
  });
}
