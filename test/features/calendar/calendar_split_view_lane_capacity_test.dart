import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-29: Off-by-one Column Capacity in Split View (maxLanes = 2)', () {
    AgendaItem makeItem(String id, String time, int dur, double priority) {
      return AgendaItem(
        id: id,
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: id,
        title: 'Task $id',
        category: Category.work,
        deepLink: AgendaDeepLink(domain: AgendaDomain.routine, targetId: id),
        dateStr: '2026-08-18',
        timeOfDay: time,
        durationMinutes: dur,
        priority: priority,
      );
    }

    test('Case 1: 1 item with maxLanes: 2 renders full width with totalLanes = 1', () {
      const engine = TimelineLayoutEngine(maxLanes: 2);
      final item = makeItem('1', '10:00', 60, 1.0);

      final result = engine.calculateLayout([item]);

      expect(result.length, equals(1));
      expect(result[0].totalLanes, equals(1));
      expect(result[0].laneIndex, equals(0));
      expect(result[0].widthFraction, equals(1.0));
      expect(result[0].overflowCount, equals(0));
    });

    test('Case 2: 2 concurrent items with maxLanes: 2 renders 2 primary cards without overflow chip', () {
      const engine = TimelineLayoutEngine(maxLanes: 2);
      final item1 = makeItem('1', '10:00', 60, 1.0);
      final item2 = makeItem('2', '10:00', 60, 2.0);

      final result = engine.calculateLayout([item1, item2]);

      expect(result.length, equals(2), reason: 'Both items must render as primary cards');
      for (final r in result) {
        expect(r.totalLanes, equals(2));
        expect(r.widthFraction, equals(0.5));
        expect(r.overflowCount, equals(0));
      }
      expect(result[0].laneIndex, equals(0));
      expect(result[1].laneIndex, equals(1));
    });

    test('Case 3: 3 concurrent items with maxLanes: 2 renders 1 primary card + 1 overflow chip (overflowCount = 2)', () {
      const engine = TimelineLayoutEngine(maxLanes: 2);
      final item1 = makeItem('1', '10:00', 60, 1.0);
      final item2 = makeItem('2', '10:00', 60, 2.0);
      final item3 = makeItem('3', '10:00', 60, 3.0);

      final result = engine.calculateLayout([item1, item2, item3]);

      expect(result.length, equals(2), reason: '1 primary card + 1 overflow chip');

      final primary = result.firstWhere((r) => r.overflowCount == 0);
      final chip = result.firstWhere((r) => r.overflowCount > 0);

      expect(primary.laneIndex, equals(0));
      expect(primary.totalLanes, equals(2));
      expect(primary.widthFraction, equals(0.5));

      expect(chip.laneIndex, equals(1));
      expect(chip.totalLanes, equals(2));
      expect(chip.widthFraction, equals(0.5));
      expect(chip.overflowCount, equals(2));
      expect(chip.overflowItems.length, equals(2));
    });
  });
}
