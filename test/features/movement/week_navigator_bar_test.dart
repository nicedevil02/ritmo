import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_navigator_bar.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Material(child: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeekNavigatorBar Widget Tests', () {
    testWidgets('Shows/hides "this week" chip based on isCurrentWeek', (tester) async {
      // 1. Current week: Chip is not shown
      await tester.pumpWidget(
        _wrap(
          WeekNavigatorBar(
            rangeTitle: '۲۵ تا ۳۱ مرداد',
            isCurrentWeek: true,
            onPreviousWeek: () {},
            onNextWeek: () {},
            onCurrentWeekPressed: () {},
          ),
        ),
      );

      expect(find.text(MovementStrings.centerThisWeek), findsNothing);

      // 2. Different week: Chip is shown
      await tester.pumpWidget(
        _wrap(
          WeekNavigatorBar(
            rangeTitle: '۱۸ تا ۲۴ مرداد',
            isCurrentWeek: false,
            onPreviousWeek: () {},
            onNextWeek: () {},
            onCurrentWeekPressed: () {},
          ),
        ),
      );

      expect(find.text(MovementStrings.centerThisWeek), findsOneWidget);
    });

    testWidgets('Tapping buttons triggers navigation callbacks', (tester) async {
      bool prevTapped = false;
      bool nextTapped = false;
      bool currentTapped = false;

      await tester.pumpWidget(
        _wrap(
          WeekNavigatorBar(
            rangeTitle: '۱۸ تا ۲۴ مرداد',
            isCurrentWeek: false,
            onPreviousWeek: () {
              prevTapped = true;
            },
            onNextWeek: () {
              nextTapped = true;
            },
            onCurrentWeekPressed: () {
              currentTapped = true;
            },
          ),
        ),
      );

      // Tap Previous
      await tester.tap(find.byTooltip(MovementStrings.navPreviousWeek));
      await tester.pumpAndSettle();
      expect(prevTapped, isTrue);

      // Tap Next
      await tester.tap(find.byTooltip(MovementStrings.navNextWeek));
      await tester.pumpAndSettle();
      expect(nextTapped, isTrue);

      // Tap Current Week Chip
      await tester.tap(find.text(MovementStrings.centerThisWeek));
      await tester.pumpAndSettle();
      expect(currentTapped, isTrue);
    });

    testWidgets('Swipe to right in RTL triggers onPreviousWeek', (tester) async {
      bool prevSwiped = false;
      bool nextSwiped = false;

      await tester.pumpWidget(
        _wrap(
          WeekNavigatorBar(
            rangeTitle: '۲۵ تا ۳۱ مرداد',
            isCurrentWeek: true,
            onPreviousWeek: () {
              prevSwiped = true;
            },
            onNextWeek: () {
              nextSwiped = true;
            },
          ),
        ),
      );

      // Drag horizontally from left to right (positive delta/velocity)
      await tester.drag(find.byType(WeekNavigatorBar), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(prevSwiped, isTrue);
      expect(nextSwiped, isFalse);

      // Drag horizontally from right to left (negative delta/velocity)
      await tester.drag(find.byType(WeekNavigatorBar), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(nextSwiped, isTrue);
    });
  });
}
