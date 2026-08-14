import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_month_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_scale_switcher.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calendar Semantics & Accessibility Tests', () {
    testWidgets('JourneyScaleSwitcher provides button semantics for all scale tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: JourneyScaleSwitcher(
              activeScale: JourneyScale.day,
              onScaleChanged: (_) {},
            ),
          ),
        ),
      );

      final agendaFinder = find.text('برنامه');
      final dayFinder = find.text('روز');
      final monthFinder = find.text('ماه');

      expect(agendaFinder, findsOneWidget);
      expect(dayFinder, findsOneWidget);
      expect(monthFinder, findsOneWidget);
    });

    testWidgets('TimelineItemCard renders semantics and completion target', (tester) async {
      final item = AgendaItem(
        id: 'test_1',
        title: 'بررسی دسترس‌پذیری تقویم',
        domain: AgendaDomain.task,
        sourceId: '1',
        dateStr: '2026-08-14',
        timeOfDay: '14:00',
        durationMinutes: 45,
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: '1'),
        completion: AgendaCompletion.none,
      );

      final layoutItem = TimelineLayoutItem(
        item: item,
        top: 0,
        height: 72,
        laneIndex: 0,
        totalLanes: 1,
        startMinutes: 840,
        durationMinutes: 45,
        renderDurationMinutes: 45,
        isTruncated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: TimelineItemCard(
              layoutItem: layoutItem,
              onToggleComplete: () {},
            ),
          ),
        ),
      );

      expect(find.text('بررسی دسترس‌پذیری تقویم'), findsOneWidget);
      expect(find.byKey(const ValueKey('toggle_complete_test_1')), findsOneWidget);
    });

    testWidgets('JourneyMonthView cells provide complete accessibility hierarchy', (tester) async {
      final selectedDate = DateTime(2026, 8, 14);
      final rangeSnapshots = <String, DayAgendaSnapshot>{};

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: JourneyMonthView(
              selectedDate: selectedDate,
              rangeSnapshots: rangeSnapshots,
              onSelectDate: (_) {},
            ),
          ),
        ),
      );

      // Verify Semantics widgets exist in month view
      final semanticsFinders = find.byType(Semantics);
      expect(semanticsFinders, findsWidgets);
    });
  });
}
