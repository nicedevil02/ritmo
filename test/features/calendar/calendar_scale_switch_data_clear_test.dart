import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class PausableDayAgendaService implements DayAgendaService {
  Completer<Map<String, DayAgenda>>? pauseCompleter;

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    if (pauseCompleter != null) {
      return pauseCompleter!.future;
    }
    final key = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    return {
      key: DayAgenda(dateStr: key, items: const []),
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-20: Scale Switch Data Clear', () {
    test('setScale resets previous scale rangeSnapshots, snapshot, and sets isLoading = true immediately', () async {
      final service = PausableDayAgendaService();
      final controller = JourneyController(agendaService: service);

      // Load initial agenda range
      await controller.loadAgendaRange(anchorDate: DateTime(2026, 8, 18));
      expect(controller.snapshot, isNotNull);
      expect(controller.rangeSnapshots, isNotEmpty);
      expect(controller.isLoading, isFalse);

      // Setup a pause for next load
      service.pauseCompleter = Completer<Map<String, DayAgenda>>();

      // Switch scale to month
      controller.setScale(JourneyScale.month);

      // Verify that prior to async completion, stale scale data is completely cleared
      expect(controller.rangeSnapshots.isEmpty, isTrue,
          reason: 'Previous scale range snapshots must be wiped immediately on setScale');
      expect(controller.snapshot, isNull,
          reason: 'Snapshot must be cleared on setScale');
      expect(controller.windowStart, isNull);
      expect(controller.windowEnd, isNull);
      expect(controller.isLoading, isTrue,
          reason: 'isLoading must be set to true immediately on setScale');

      // Complete pause
      service.pauseCompleter!.complete({});
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    test('selectDate with new scaleToSet also clears stale scale data and sets isLoading = true', () async {
      final service = PausableDayAgendaService();
      final controller = JourneyController(agendaService: service);

      await controller.loadAgendaRange(anchorDate: DateTime(2026, 8, 18));
      expect(controller.snapshot, isNotNull);

      service.pauseCompleter = Completer<Map<String, DayAgenda>>();

      controller.selectDate(DateTime(2026, 8, 19), scaleToSet: JourneyScale.day);

      expect(controller.rangeSnapshots.isEmpty, isTrue);
      expect(controller.snapshot, isNull);
      expect(controller.isLoading, isTrue);

      service.pauseCompleter!.complete({});
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
  });
}
