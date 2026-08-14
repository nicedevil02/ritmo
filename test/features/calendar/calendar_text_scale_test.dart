import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';
import 'package:ritmo/features/calendar/presentation/widgets/calendar_management_sheet.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_month_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_scale_switcher.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calendar Large TextScaleFactor & Layout Stability Tests', () {
    testWidgets('JourneyScaleSwitcher renders without overflow at 1.4x scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: JourneyScaleSwitcher(
                  activeScale: JourneyScale.day,
                  onScaleChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('برنامه'), findsOneWidget);
      expect(find.text('روز'), findsOneWidget);
      expect(find.text('ماه'), findsOneWidget);
    });

    testWidgets('TimelineItemCard renders without overflow in compact & normal tiers at 1.5x scale', (tester) async {
      final item = AgendaItem(
        id: 'test_overflow',
        title: 'تست پایداری چیدمان با متن بسیار طولانی در مقیاس بزرگ',
        domain: AgendaDomain.routine,
        sourceId: 'r1',
        dateStr: '2026-08-14',
        timeOfDay: '15:30',
        durationMinutes: 30,
        category: Category.personal,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'r1'),
        completion: AgendaCompletion.none,
      );

      final compactLayout = TimelineLayoutItem(
        item: item,
        top: 0,
        height: 24, // Compact tier
        laneIndex: 0,
        totalLanes: 1,
        startMinutes: 930,
        durationMinutes: 15,
        renderDurationMinutes: 15,
        isTruncated: false,
      );

      final normalLayout = TimelineLayoutItem(
        item: item,
        top: 0,
        height: 60, // Normal tier
        laneIndex: 0,
        totalLanes: 1,
        startMinutes: 930,
        durationMinutes: 30,
        renderDurationMinutes: 30,
        isTruncated: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: SizedBox(
                width: 300,
                child: Column(
                  children: [
                    TimelineItemCard(layoutItem: compactLayout),
                    const SizedBox(height: 10),
                    TimelineItemCard(layoutItem: normalLayout),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('JourneyMonthView renders without overflow at 1.3x scale', (tester) async {
      final selectedDate = DateTime(2026, 8, 14);
      final rangeSnapshots = <String, DayAgendaSnapshot>{};

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                height: 600,
                child: JourneyMonthView(
                  selectedDate: selectedDate,
                  rangeSnapshots: rangeSnapshots,
                  onSelectDate: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('CalendarManagementSheet renders without overflow at 1.3x scale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                height: 700,
                child: CalendarManagementSheet(
                  selectedDate: DateTime(2026, 8, 14),
                  currentScale: JourneyScale.day,
                  healthIssueCount: 1,
                  onSelectScale: (_) {},
                  onOpenDayReview: () {},
                  onOpenDayMarkPicker: () {},
                  onOpenAllPlans: () {},
                  onRefresh: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
