import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class EmptyDayAgendaService implements DayAgendaService {
  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    // Return empty map simulating missing keys
    return {};
  }

  @override
  Future<int> countOverdueBefore(DateTime cutoff) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-21: Unified Fallback for Empty Snapshot', () {
    test('loadForActiveScale provides non-null fallback snapshot when selectedKey is missing in range', () async {
      final service = EmptyDayAgendaService();
      final controller = JourneyController(agendaService: service);
      final testDate = DateTime(2026, 8, 18);
      final testKey = DateKey.of(DateKey.dayOf(testDate));

      controller.selectDate(testDate, scaleToSet: JourneyScale.day);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.snapshot, isNotNull,
          reason: 'Snapshot must never be left as null when key is missing from rangeSnapshots');
      expect(controller.snapshot!.dateStr, equals(testKey));
      expect(controller.snapshot!.items, isEmpty);
    });

    test('loadAgendaRange provides non-null fallback snapshot when selectedKey is missing', () async {
      final service = EmptyDayAgendaService();
      final controller = JourneyController(agendaService: service);
      final testDate = DateTime(2026, 8, 18);
      final testKey = DateKey.of(DateKey.dayOf(testDate));

      await controller.loadAgendaRange(anchorDate: testDate);

      expect(controller.snapshot, isNotNull);
      expect(controller.snapshot!.dateStr, equals(testKey));
      expect(controller.snapshot!.items, isEmpty);
    });
  });
}
