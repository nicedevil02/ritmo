import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 800),
          padding: EdgeInsets.only(top: 24),
        ),
        child: Material(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WeekRail Widget Tests', () {
    final testDays = [
      MovementDayData(
        date: DateTime(2026, 8, 15),
        dayName: 'ش',
        dayNumber: 24,
        monthName: 'مرداد',
        state: MovementDaySlotState.normal,
      ),
      MovementDayData(
        date: DateTime(2026, 8, 16),
        dayName: 'ی',
        dayNumber: 25,
        monthName: 'مرداد',
        state: MovementDaySlotState.selected,
      ),
      MovementDayData(
        date: DateTime(2026, 8, 17),
        dayName: 'د',
        dayNumber: 26,
        monthName: 'مرداد',
        state: MovementDaySlotState.today,
      ),
      MovementDayData(
        date: DateTime(2026, 8, 18),
        dayName: 'س',
        dayNumber: 27,
        monthName: 'مرداد',
        state: MovementDaySlotState.normal,
      ),
      MovementDayData(
        date: DateTime(2026, 8, 19),
        dayName: 'چ',
        dayNumber: 28,
        monthName: 'مرداد',
        state: MovementDaySlotState.normal,
      ),
      MovementDayData(
        date: DateTime(2026, 8, 20),
        dayName: 'پ',
        dayNumber: 29,
        monthName: 'مرداد',
        state: MovementDaySlotState.normal,
      ),
      MovementDayData(
        date: DateTime(2026, 8, 21),
        dayName: 'ج',
        dayNumber: 30,
        monthName: 'مرداد',
        state: MovementDaySlotState.normal,
      ),
    ];

    testWidgets('Renders 7 days in Saturday to Friday order in RTL', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WeekRail(
            days: testDays,
            onDaySelected: (_) {},
          ),
        ),
      );

      final satFinder = find.text('ش');
      final sunFinder = find.text('ی');
      final friFinder = find.text('ج');

      expect(satFinder, findsOneWidget);
      expect(sunFinder, findsOneWidget);
      expect(friFinder, findsOneWidget);

      // در چیدمان RTL: شنبه سمت راست‌ترین (بزرگترین مختصات X) و جمعه سمت چپ‌ترین (کوچکترین مختصات X)
      final satTopRight = tester.getTopRight(satFinder);
      final friTopLeft = tester.getTopLeft(friFinder);

      expect(satTopRight.dx, greaterThan(friTopLeft.dx));
    });

    testWidgets('Touch target size for each slot is at least 48x48', (tester) async {
      await tester.pumpWidget(
        _wrap(
          WeekRail(
            days: testDays,
            onDaySelected: (_) {},
          ),
        ),
      );

      final slotFinders = find.byType(DaySlot);
      expect(slotFinders, findsNWidgets(7));

      for (var i = 0; i < 7; i++) {
        final size = tester.getSize(slotFinders.at(i));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });

    testWidgets('Tapping on unselected day triggers onDaySelected', (tester) async {
      DateTime? selected;
      await tester.pumpWidget(
        _wrap(
          WeekRail(
            days: testDays,
            onDaySelected: (date) {
              selected = date;
            },
          ),
        ),
      );

      await tester.tap(find.text('ش'));
      await tester.pumpAndSettle();

      expect(selected, equals(DateTime(2026, 8, 15)));
    });

    testWidgets('Tapping on selected day triggers onDayReselected', (tester) async {
      DateTime? reselected;
      await tester.pumpWidget(
        _wrap(
          WeekRail(
            days: testDays,
            onDaySelected: (_) {},
            onDayReselected: (date) {
              reselected = date;
            },
          ),
        ),
      );

      await tester.tap(find.text('ی'));
      await tester.pumpAndSettle();

      expect(reselected, equals(DateTime(2026, 8, 16)));
    });
  });
}
