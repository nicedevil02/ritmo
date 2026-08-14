import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_snapping.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_hour_axis.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Timeline Interaction & Hour Axis Tests', () {
    test('TimelineSnapping snaps minutes to 15-minute intervals', () {
      expect(TimelineSnappingHelper.snapStartMinutes(607), 600); // 10:07 -> 10:00
      expect(TimelineSnappingHelper.snapStartMinutes(612), 615); // 10:12 -> 10:15
      expect(TimelineSnappingHelper.snapStartMinutes(625), 630); // 10:25 -> 10:30
      expect(TimelineSnappingHelper.snapStartMinutes(640), 645); // 10:40 -> 10:45
      expect(TimelineSnappingHelper.snapStartMinutes(1435), 1410); // Bounds check clamped to maxStart (1440 - 30 = 1410)
    });

    testWidgets('TimelineHourAxis highlights current hour only when isToday is true', (tester) async {
      final now = DateTime(2026, 8, 14, 10, 30);

      // 1. isToday = false: current hour 10 is NOT highlighted with primary
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: TimelineHourAxis(
              pxPerMinute: 1.6,
              rangeStartMinutes: 0,
              rangeEndMinutes: 1440,
              isToday: false,
              now: now,
            ),
          ),
        ),
      );

      final textFinder10 = find.text('۱۰:۰۰');
      expect(textFinder10, findsOneWidget);

      Text textWidget = tester.widget<Text>(textFinder10);
      expect(textWidget.style?.fontWeight, FontWeight.w500);

      // 2. isToday = true: current hour 10 IS highlighted with bold
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: Scaffold(
            body: TimelineHourAxis(
              pxPerMinute: 1.6,
              rangeStartMinutes: 0,
              rangeEndMinutes: 1440,
              isToday: true,
              now: now,
            ),
          ),
        ),
      );

      textWidget = tester.widget<Text>(textFinder10);
      expect(textWidget.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('TimelineGridLines renders custom paint canvas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              child: TimelineGridLines(
                pxPerMinute: 1.6,
                rangeStartMinutes: 0,
                rangeEndMinutes: 1440,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TimelineGridLines), findsOneWidget);
    });
  });
}
