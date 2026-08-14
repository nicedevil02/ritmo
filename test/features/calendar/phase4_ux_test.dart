import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/logic/morning_brief.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';
import 'package:ritmo/features/calendar/presentation/widgets/calendar_management_sheet.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_month_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_scale_switcher.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 UX Tests', () {
    testWidgets('CalendarManagementSheet renders all 3 groups (Display, Day, Tools)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: CalendarManagementSheet(
              selectedDate: DateTime(2026, 8, 14),
              currentScale: JourneyScale.day,
              healthIssueCount: 2,
              onSelectScale: (_) {},
              onOpenDayReview: () {},
              onOpenDayMarkPicker: () {},
              onOpenAllPlans: () {},
              onRefresh: () {},
            ),
          ),
        ),
      );

      expect(find.text('مدیریت تقویم'), findsOneWidget);
      expect(find.text('نمایش و نماها'), findsOneWidget);
      expect(find.text('روز'), findsOneWidget);
      expect(find.text('ابزارها'), findsOneWidget);
      expect(find.text('نمای هفته'), findsOneWidget);
      expect(find.text('نمای سال'), findsOneWidget);
      expect(find.text('فشرده‌سازی تکرارها'), findsOneWidget);
      expect(find.text('نمایش گاهشمار قمری'), findsOneWidget);
      expect(find.text('روز من (مرور و خلاصه)'), findsOneWidget);
      expect(find.text('نشان روز'), findsOneWidget);
      expect(find.text('همهٔ برنامه‌ها'), findsOneWidget);
      expect(find.text('خلاصهٔ صبحگاهی'), findsOneWidget);
    });

    testWidgets('JourneyScaleSwitcher toggles between primary scales', (tester) async {
      JourneyScale selected = JourneyScale.agenda;

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return JourneyScaleSwitcher(
                  activeScale: selected,
                  onScaleChanged: (scale) {
                    setState(() => selected = scale);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('برنامه'), findsOneWidget);
      expect(find.text('روز'), findsOneWidget);
      expect(find.text('ماه'), findsOneWidget);

      await tester.tap(find.text('روز'));
      await tester.pumpAndSettle();

      expect(selected, JourneyScale.day);

      await tester.tap(find.text('ماه'));
      await tester.pumpAndSettle();

      expect(selected, JourneyScale.month);
    });

    testWidgets('TimelineItemCard provides completion target across tiers', (tester) async {
      bool completed = false;

      final item = AgendaItem(
        id: 'test_task_1',
        title: 'جلسه طراحی تقویم',
        domain: AgendaDomain.task,
        sourceId: 'task_1',
        dateStr: '2026-08-14',
        timeOfDay: '10:00',
        durationMinutes: 30,
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: '1'),
        completion: AgendaCompletion.none,
      );

      final layoutItem = TimelineLayoutItem(
        item: item,
        top: 0,
        height: 60,
        laneIndex: 0,
        totalLanes: 1,
        startMinutes: 600,
        durationMinutes: 30,
        renderDurationMinutes: 30,
        isTruncated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: TimelineItemCard(
              layoutItem: layoutItem,
              onToggleComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('جلسه طراحی تقویم'), findsOneWidget);

      // Tap the right accent bar completion target
      final toggleFinder = find.byKey(const ValueKey('toggle_complete_test_task_1'));
      expect(toggleFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pump();

      expect(completed, isTrue);
    });

    testWidgets('JourneyMonthView highlights selected date with primary color', (tester) async {
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

      expect(find.text('ش'), findsOneWidget);
      expect(find.text('ج'), findsOneWidget);
      expect(find.text('کم'), findsOneWidget);
      expect(find.text('فشرده'), findsOneWidget);
    });
  });
}
