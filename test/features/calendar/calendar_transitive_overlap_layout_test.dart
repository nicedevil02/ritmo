import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-27: Transitive Overlap Clustering for Total Lanes', () {
    test('All items in a connected overlap cluster receive the exact same totalLanes', () {
      const engine = TimelineLayoutEngine();

      final itemA = AgendaItem(
        id: 'A',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'A',
        title: 'Item A',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'A'),
        dateStr: '2026-08-18',
        timeOfDay: '09:00',
        durationMinutes: 180, // 09:00 to 12:00
      );

      final itemB = AgendaItem(
        id: 'B',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'B',
        title: 'Item B',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'B'),
        dateStr: '2026-08-18',
        timeOfDay: '09:30',
        durationMinutes: 30, // 09:30 to 10:00
      );

      final itemE = AgendaItem(
        id: 'E',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'E',
        title: 'Item E',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'E'),
        dateStr: '2026-08-18',
        timeOfDay: '09:30',
        durationMinutes: 30, // 09:30 to 10:00
      );

      final itemC = AgendaItem(
        id: 'C',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'C',
        title: 'Item C',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'C'),
        dateStr: '2026-08-18',
        timeOfDay: '10:30',
        durationMinutes: 30, // 10:30 to 11:00 (overlaps with A, but not B or E)
      );

      final layoutItems = engine.calculateLayout([itemA, itemB, itemE, itemC]);

      expect(layoutItems.length, equals(4));

      // All items in this cluster must have totalLanes == 3
      for (final l in layoutItems) {
        expect(l.totalLanes, equals(3),
            reason: 'Item ${l.item.id} should have totalLanes == 3 from the connected component');
        expect(l.widthFraction, equals(1.0 / 3.0));
      }

      // No two overlapping items share the same laneIndex
      final itemALayout = layoutItems.firstWhere((l) => l.item.id == 'A');
      final itemBLayout = layoutItems.firstWhere((l) => l.item.id == 'B');
      final itemELayout = layoutItems.firstWhere((l) => l.item.id == 'E');
      final itemCLayout = layoutItems.firstWhere((l) => l.item.id == 'C');

      expect(itemALayout.laneIndex, equals(0));
      expect(itemBLayout.laneIndex, equals(1));
      expect(itemELayout.laneIndex, equals(2));
      // Item C comes after B and can reuse lane 1
      expect(itemCLayout.laneIndex, equals(1));
    });
  });
}
