import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class FakeDelayedDayAgendaService implements DayAgendaService {
  final Map<String, Completer<Map<String, DayAgenda>>> pendingRequests = {};
  final Map<String, Map<String, DayAgenda>> syncResponses = {};

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) {
    final startKey = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    if (pendingRequests.containsKey(startKey)) {
      return pendingRequests[startKey]!.future;
    }
    if (syncResponses.containsKey(startKey)) {
      return Future.value(syncResponses[startKey]!);
    }
    return Future.value({
      startKey: DayAgenda(dateStr: startKey, items: const []),
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-17: Load Generation Token Race Protection', () {
    test('Earlier load that finishes later does not overwrite newer load snapshots', () async {
      final fakeService = FakeDelayedDayAgendaService();
      final date1 = DateTime(2026, 8, 1);
      final date2 = DateTime(2026, 8, 15);
      const key1 = '2026-08-01';
      const key2 = '2026-08-15';

      // Setup delayed response for date1 (call 1)
      final completer1 = Completer<Map<String, DayAgenda>>();
      fakeService.pendingRequests[key1] = completer1;

      // Setup immediate response for date2 (call 2)
      final item2 = AgendaItem(
        id: 'task:call2:$key2',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: 'call2',
        title: 'Call 2 Item',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 'call2'),
        dateStr: key2,
      );
      fakeService.syncResponses[key2] = {
        key2: DayAgenda(dateStr: key2, items: [item2]),
      };

      final controller = JourneyController(agendaService: fakeService);
      final initialGen = controller.loadGeneration;

      // 1. Trigger call 1 (slow)
      controller.selectDate(date1, scaleToSet: JourneyScale.day);
      final gen1 = controller.loadGeneration;
      expect(gen1, equals(initialGen + 1));
      expect(controller.isLoading, isTrue);

      // 2. Trigger call 2 (fast)
      controller.selectDate(date2);
      final gen2 = controller.loadGeneration;
      expect(gen2, equals(gen1 + 1));

      // Let call 2 microtasks complete
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // At this point, call 2 has completed
      expect(controller.rangeSnapshots.containsKey(key2), isTrue);
      expect(controller.rangeSnapshots[key2]?.items.first.title, equals('Call 2 Item'));
      expect(controller.isLoading, isFalse);

      // 3. Now let call 1 finally finish with old data
      final item1 = AgendaItem(
        id: 'task:call1:$key1',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        sourceId: 'call1',
        title: 'Call 1 Stale Item',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 'call1'),
        dateStr: key1,
      );
      completer1.complete({
        key1: DayAgenda(dateStr: key1, items: [item1]),
      });

      // Let call 1 microtasks settle
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // 4. Verification: call 1 was ignored because generation token advanced!
      expect(controller.rangeSnapshots.containsKey(key1), isFalse,
          reason: 'Stale call 1 must not write into rangeSnapshots');
      expect(controller.rangeSnapshots.containsKey(key2), isTrue);
      expect(controller.rangeSnapshots[key2]?.items.first.title, equals('Call 2 Item'));

      controller.dispose();
    });
  });
}
