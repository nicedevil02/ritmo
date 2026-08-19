import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/movement_app_bar.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

Widget _wrapWithScale(Widget child, {double textScale = 1.3}) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: const Size(380, 750),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RTL & Text Scale 1.3x Overflow Tests', () {
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

    testWidgets(
      'MovementAppBar renders with zero overflow at 1.3x text scale',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithScale(
            Scaffold(
              appBar: MovementAppBar(
                title: MovementStrings.centerTitle,
                subtitle: '۲۵ تا ۳۱ مرداد',
                onProgressPressed: () {},
                onSettingsPressed: () {},
              ),
              body: const SizedBox.shrink(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('WeekRail renders with zero overflow at 1.3x text scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithScale(
          Scaffold(
            body: WeekRail(days: testDays, onDaySelected: (_) {}),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'MovementScreenShell renders with zero overflow at 1.3x text scale',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithScale(
            MovementScreenShell(
              title: MovementStrings.centerTitle,
              subtitle: MovementStrings.centerDayPlan,
              body: Column(
                children: [
                  WeekRail(days: testDays, onDaySelected: (_) {}),
                  const SizedBox(height: 16),
                  const Text('محتوای صفحه حرکت'),
                ],
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
