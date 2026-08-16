import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_status_indicators.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Material(child: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DayStatusIndicators Widget Tests', () {
    testWidgets('Renders up to 3 status indicators directly without overflow counter', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DayStatusIndicators(
            statuses: [
              MovementDayStatus.completed,
              MovementDayStatus.planned,
            ],
          ),
        ),
      );

      // No +n text
      expect(find.textContaining('+'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          const DayStatusIndicators(
            statuses: [
              MovementDayStatus.completed,
              MovementDayStatus.planned,
              MovementDayStatus.recovery,
            ],
          ),
        ),
      );

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('Overflows to +n when more than 3 statuses exist', (tester) async {
      // 4 statuses -> 2 icons + "+۲"
      await tester.pumpWidget(
        _wrap(
          const DayStatusIndicators(
            statuses: [
              MovementDayStatus.completed,
              MovementDayStatus.planned,
              MovementDayStatus.partial,
              MovementDayStatus.recovery,
            ],
          ),
        ),
      );

      expect(find.text('+۲'), findsOneWidget);

      // 5 statuses -> 2 icons + "+۳"
      await tester.pumpWidget(
        _wrap(
          const DayStatusIndicators(
            statuses: [
              MovementDayStatus.completed,
              MovementDayStatus.planned,
              MovementDayStatus.partial,
              MovementDayStatus.moved,
              MovementDayStatus.recovery,
            ],
          ),
        ),
      );

      expect(find.text('+۳'), findsOneWidget);
    });

    testWidgets('Renders distinct glyphs for each status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DayStatusIndicators(
            statuses: [
              MovementDayStatus.completed,
              MovementDayStatus.moved,
              MovementDayStatus.recovery,
            ],
          ),
        ),
      );

      // Check for check icon (completed), swap icon (moved), spa icon (recovery)
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
      expect(find.byIcon(Icons.spa_rounded), findsOneWidget);
    });
  });
}
