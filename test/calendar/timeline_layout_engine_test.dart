import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';

void main() {
  group('CAL-54: Comprehensive TimelineLayoutEngine Tests', () {
    const engine = TimelineLayoutEngine();

    test('1. Transitive overlap cluster (A/B/E/C) yields identical totalLanes for all connected items', () {
      // Item A: 10:00 - 11:00
      // Item B: 10:30 - 11:30 (overlaps A and E)
      // Item E: 11:15 - 12:00 (overlaps B and C)
      // Item C: 11:45 - 12:30 (overlaps E)
      final itemA = AgendaItem(
        id: 'A',
        sourceId: 'src_A',
        title: 'رویداد A',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '10:00',
        durationMinutes: 60,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_A'),
      );

      final itemB = AgendaItem(
        id: 'B',
        sourceId: 'src_B',
        title: 'رویداد B',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '10:30',
        durationMinutes: 60,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_B'),
      );

      final itemE = AgendaItem(
        id: 'E',
        sourceId: 'src_E',
        title: 'رویداد E',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '11:15',
        durationMinutes: 45,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_E'),
      );

      final itemC = AgendaItem(
        id: 'C',
        sourceId: 'src_C',
        title: 'رویداد C',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '11:45',
        durationMinutes: 45,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_C'),
      );

      final layout = engine.calculateLayout([itemA, itemB, itemE, itemC]);
      expect(layout.length, equals(4));

      final firstTotalLanes = layout.first.totalLanes;
      expect(firstTotalLanes, greaterThanOrEqualTo(2));
      for (final l in layout) {
        expect(l.totalLanes, equals(firstTotalLanes), reason: 'Item ${l.item.id} has differing totalLanes');
      }
    });

    test('2. No item.id appears twice across rendered items and overflowItems', () {
      final items = List.generate(6, (i) {
        return AgendaItem(
          id: 'item_$i',
          sourceId: 'src_$i',
          title: 'رویداد $i',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.work,
          dateStr: '2026-08-18',
          timeOfDay: '10:00',
          durationMinutes: 60,
          deepLink: AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_$i'),
        );
      });

      const max2Engine = TimelineLayoutEngine(maxLanes: 2);
      final layout = max2Engine.calculateLayout(items);

      final seenIds = <String>{};
      for (final l in layout) {
        if (l.overflowCount > 0) {
          for (final over in l.overflowItems) {
            expect(seenIds.contains(over.id), isFalse, reason: 'Overflow item ${over.id} was already seen');
            seenIds.add(over.id);
          }
        } else {
          expect(seenIds.contains(l.item.id), isFalse);
          seenIds.add(l.item.id);
        }
      }
      expect(seenIds.length, equals(6));
    });

    test('3. maxLanes: 2 with 2 items -> 2 cards without chip; with 3 items -> 1 card + chip with overflowCount = 2', () {
      final item1 = AgendaItem(
        id: '1',
        sourceId: '1',
        title: '۱',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '10:00',
        durationMinutes: 60,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '1'),
      );

      final item2 = AgendaItem(
        id: '2',
        sourceId: '2',
        title: '۲',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '10:00',
        durationMinutes: 60,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '2'),
      );

      final item3 = AgendaItem(
        id: '3',
        sourceId: '3',
        title: '۳',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '10:00',
        durationMinutes: 60,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: '3'),
      );

      const max2Engine = TimelineLayoutEngine(maxLanes: 2);

      // 2 items case
      final layout2 = max2Engine.calculateLayout([item1, item2]);
      expect(layout2.length, equals(2));
      expect(layout2[0].overflowCount, equals(0));
      expect(layout2[1].overflowCount, equals(0));

      // 3 items case: 1 primary card + 1 overflow chip
      final layout3 = max2Engine.calculateLayout([item1, item2, item3]);
      expect(layout3.length, equals(2));
      expect(layout3[0].overflowCount, equals(0));
      expect(layout3[1].overflowCount, equals(2));
      expect(layout3[1].overflowItems.length, equals(2));
    });

    test('4. Item at 23:55 with 5 minutes duration does not throw and produces valid positive height', () {
      final lateItem = AgendaItem(
        id: 'late',
        sourceId: 'late',
        title: 'پایان شب',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.personal,
        dateStr: '2026-08-18',
        timeOfDay: '23:55',
        durationMinutes: 5,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'late'),
      );

      final layout = engine.calculateLayout([lateItem]);
      expect(layout.length, equals(1));
      final l = layout.first;
      expect(l.top, greaterThan(0));
      expect(l.height, greaterThan(0));
      expect(l.top + l.height, lessThanOrEqualTo(engine.totalTimelineHeight + 0.001));
    });

    test('5. Determinism: 20 consecutive runs produce identical layout results', () {
      final items = List.generate(5, (i) {
        return AgendaItem(
          id: 'item_$i',
          sourceId: 'src_$i',
          title: 'رویداد $i',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.work,
          dateStr: '2026-08-18',
          timeOfDay: '${(9 + (i % 3)).toString().padLeft(2, '0')}:30',
          durationMinutes: 45,
          deepLink: AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'src_$i'),
        );
      });

      final baseline = engine.calculateLayout(items);
      for (int r = 0; r < 20; r++) {
        final current = engine.calculateLayout(items);
        expect(current.length, equals(baseline.length));
        for (int i = 0; i < current.length; i++) {
          expect(current[i].item.id, equals(baseline[i].item.id));
          expect(current[i].top, equals(baseline[i].top));
          expect(current[i].height, equals(baseline[i].height));
          expect(current[i].laneIndex, equals(baseline[i].laneIndex));
          expect(current[i].totalLanes, equals(baseline[i].totalLanes));
        }
      }
    });

    test('6. Invalid times ("99:99", "abc", null) are safely excluded, not sent to midnight', () {
      final invalidItems = [
        AgendaItem(
          id: 'inv_1',
          sourceId: 'inv_1',
          title: 'نامعتبر ۱',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.personal,
          dateStr: '2026-08-18',
          timeOfDay: '99:99',
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'inv_1'),
        ),
        AgendaItem(
          id: 'inv_2',
          sourceId: 'inv_2',
          title: 'نامعتبر ۲',
          domain: AgendaDomain.routine,
          kind: AgendaItemKind.routine,
          category: Category.personal,
          dateStr: '2026-08-18',
          timeOfDay: 'abc',
          deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'inv_2'),
        ),
        AgendaItem(
          id: 'inv_3',
          sourceId: 'inv_3',
          title: 'بی‌زمان',
          domain: AgendaDomain.task,
          kind: AgendaItemKind.task,
          category: Category.personal,
          dateStr: '2026-08-18',
          timeOfDay: null,
          deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 'inv_3'),
        ),
      ];

      final layout = engine.calculateLayout(invalidItems);
      expect(layout, isEmpty);
    });

    test('7. Split range (rangeStartMinutes: 720): item crossing boundary receives isClippedAtStart = true', () {
      const splitEngine = TimelineLayoutEngine(
        rangeStartMinutes: 720, // 12:00
        rangeEndMinutes: 1440,  // 24:00
      );

      // Item starting at 11:30 (690 mins) and lasting 60 mins -> ends at 12:30 (750 mins)
      final crossingItem = AgendaItem(
        id: 'cross',
        sourceId: 'cross',
        title: 'عبوری از مرز ظهر',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.work,
        dateStr: '2026-08-18',
        timeOfDay: '11:30',
        durationMinutes: 60,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'cross'),
      );

      final layout = splitEngine.calculateLayout([crossingItem]);
      expect(layout.length, equals(1));
      final l = layout.first;
      expect(l.isClippedAtStart, isTrue);
      expect(l.top, equals(0.0));
      expect(l.renderDurationMinutes, equals(30)); // 12:00 to 12:30
    });
  });
}
