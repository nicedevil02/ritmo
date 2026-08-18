import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_gap_calculator.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_free_gaps_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-45: Drop Untimed AgendaItem on Free Gaps Section', () {
    testWidgets('Renders free gaps and invokes onDropItemOnGap on DragTarget drop', (tester) async {
      const snapshot = DayAgendaSnapshot(
        dayAgenda: DayAgenda(dateStr: '2026-08-18', items: []),
        completedCount: 0,
        remainingCount: 0,
        freeGaps: [
          TimeGap(startMinutes: 480, endMinutes: 540),
        ],
        conflicts: [],
        overloadScore: 0.0,
        suggestions: [],
      );

      AgendaItem? droppedItem;
      TimeGap? droppedGap;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JourneyFreeGapsSection(
              snapshot: snapshot,
              onDropItemOnGap: (item, gap) {
                droppedItem = item;
                droppedGap = gap;
              },
            ),
          ),
        ),
      );

      expect(find.text('بلاک‌های زمان آزاد (۱)'), findsOneWidget);
      expect(find.byType(DragTarget<AgendaItem>), findsOneWidget);

      final item = AgendaItem(
        id: 'task:1:2026-08-18',
        sourceId: '1',
        title: 'Untimed Task',
        domain: AgendaDomain.task,
        kind: AgendaItemKind.task,
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: '1'),
        dateStr: '2026-08-18',
      );

      final dragTargetFinder = find.byType(DragTarget<AgendaItem>);
      final dragTarget = tester.widget<DragTarget<AgendaItem>>(dragTargetFinder);

      dragTarget.onAcceptWithDetails?.call(DragTargetDetails<AgendaItem>(data: item, offset: Offset.zero));
      await tester.pump();

      expect(droppedItem, isNotNull);
      expect(droppedItem!.id, equals('task:1:2026-08-18'));
      expect(droppedGap, isNotNull);
      expect(droppedGap!.startMinutes, equals(480));
    });
  });
}
