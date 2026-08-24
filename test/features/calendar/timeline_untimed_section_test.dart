import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_untimed_section.dart';

void main() {
  group('TimelineUntimedSection Option 3 Tests', () {
    List<AgendaItem> createTestItems(int count) {
      return List.generate(
        count,
        (i) => AgendaItem(
          id: 'item_$i',
          title: 'آیتم آزمایشی $i',
          domain: AgendaDomain.task,
          sourceId: 'source_$i',
          dateStr: '2026-08-23',
          category: Category.work,
          deepLink: AgendaDeepLink(domain: AgendaDomain.task, targetId: 'source_$i'),
        ),
      );
    }

    testWidgets('Renders compact horizontal scroll view by default', (tester) async {
      final items = createTestItems(5);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineUntimedSection(
              untimedItems: items,
            ),
          ),
        ),
      );

      // Verify title shows Persian count
      expect(find.textContaining('بدون زمانبندی (۵)'), findsOneWidget);

      // Verify SingleChildScrollView with horizontal scroll is present
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final scrollView = tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollView.scrollDirection, equals(Axis.horizontal));

      // Verify expand chevron is visible when items > 2
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('Tapping header toggles expand to Wrap view and back', (tester) async {
      final items = createTestItems(4);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineUntimedSection(
              untimedItems: items,
            ),
          ),
        ),
      );

      // Initially in horizontal scroll mode
      expect(find.byType(Wrap), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Tap header to expand
      await tester.tap(find.textContaining('بدون زمانبندی'));
      await tester.pumpAndSettle();

      // Now expanded into Wrap mode
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);

      // Tap header again to collapse
      await tester.tap(find.textContaining('بدون زمانبندی'));
      await tester.pumpAndSettle();

      // Back in horizontal scroll mode
      expect(find.byType(Wrap), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('Tapping a chip triggers onItemTap callback', (tester) async {
      AgendaItem? tappedItem;
      final items = createTestItems(3);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineUntimedSection(
              untimedItems: items,
              onItemTap: (item) => tappedItem = item,
            ),
          ),
        ),
      );

      await tester.tap(find.text('آیتم آزمایشی 0'));
      expect(tappedItem, isNotNull);
      expect(tappedItem!.id, equals('item_0'));
    });
  });
}
