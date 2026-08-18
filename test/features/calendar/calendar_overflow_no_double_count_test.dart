import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-28: No Double Counting in Overflow Card', () {
    test('maxLanes: 2 with 4 overlapping items produces unique set with no duplicates', () {
      const engine = TimelineLayoutEngine(maxLanes: 2);

      final items = List.generate(4, (i) {
        return AgendaItem(
          id: 'item_$i',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          sourceId: 'item_$i',
          title: 'Routine $i',
          category: Category.work,
          deepLink: AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'item_$i'),
          dateStr: '2026-08-18',
          timeOfDay: '10:00',
          durationMinutes: 60,
          priority: i.toDouble(), // distinct priorities
        );
      });

      final result = engine.calculateLayout(items);

      // Primary cards + overflow chips
      final renderedPrimaryIds = <String>{};
      final overflowIds = <String>{};

      for (final r in result) {
        if (r.overflowCount > 0) {
          for (final o in r.overflowItems) {
            expect(overflowIds.contains(o.id), isFalse,
                reason: 'Item ${o.id} appeared multiple times in overflowItems');
            overflowIds.add(o.id);
          }
        } else {
          expect(renderedPrimaryIds.contains(r.item.id), isFalse,
              reason: 'Item ${r.item.id} rendered multiple times as primary card');
          renderedPrimaryIds.add(r.item.id);
        }
      }

      // No intersection between primary and overflow
      final intersection = renderedPrimaryIds.intersection(overflowIds);
      expect(intersection, isEmpty,
          reason: 'Items should never appear in both primary cards and overflowItems');

      // Total count should exactly equal input items
      expect(renderedPrimaryIds.length + overflowIds.length, equals(4));
    });
  });
}
