import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-32: Deterministic Timeline Layout Sorting', () {
    test('calculateLayout produces 100% identical laneIndex and item order across 20 iterations', () {
      const engine = TimelineLayoutEngine();

      final items = [
        AgendaItem(
          id: 'item_c',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          sourceId: 'c',
          title: 'Routine C',
          category: Category.work,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'c'),
          dateStr: '2026-08-18',
          timeOfDay: '10:00',
          durationMinutes: 60,
        ),
        AgendaItem(
          id: 'item_a',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          sourceId: 'a',
          title: 'Routine A',
          category: Category.work,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'a'),
          dateStr: '2026-08-18',
          timeOfDay: '10:00',
          durationMinutes: 60,
        ),
        AgendaItem(
          id: 'item_b',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          sourceId: 'b',
          title: 'Routine B',
          category: Category.work,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'b'),
          dateStr: '2026-08-18',
          timeOfDay: '10:00',
          durationMinutes: 60,
        ),
      ];

      List<String>? firstRunOrder;

      for (var iteration = 0; iteration < 20; iteration++) {
        // Pass a freshly shuffled list to simulate non-deterministic initial list order
        final shuffled = List<AgendaItem>.from(items)..shuffle();
        final layout = engine.calculateLayout(shuffled);
        final currentOrder = layout.map((l) => '${l.item.id}:${l.laneIndex}').toList();

        if (firstRunOrder == null) {
          firstRunOrder = currentOrder;
          // Verify items are ordered alphabetically by ID when start & duration are equal
          expect(firstRunOrder, equals(['item_a:0', 'item_b:1', 'item_c:2']));
        } else {
          expect(currentOrder, equals(firstRunOrder),
              reason: 'Iteration $iteration produced different layout order: $currentOrder vs $firstRunOrder');
        }
      }
    });
  });
}
