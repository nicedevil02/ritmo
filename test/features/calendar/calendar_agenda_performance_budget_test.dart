import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class FastMockAgendaService implements DayAgendaService {
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

  group('CAL-42: Agenda Loading Performance Budget', () {
    test('agendaLoadBudget constant is defined as 250ms', () {
      expect(JourneyController.agendaLoadBudget, equals(const Duration(milliseconds: 250)));
    });

    test('loadAgendaRange executes within performance budget', () async {
      final service = FastMockAgendaService();
      final controller = JourneyController(agendaService: service);

      final sw = Stopwatch()..start();
      await controller.loadAgendaRange(anchorDate: DateTime(2026, 8, 18));
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(JourneyController.agendaLoadBudget.inMilliseconds * 4));
      expect(controller.isLoading, isFalse);
      expect(controller.snapshot, isNotNull);
    });
  });
}
