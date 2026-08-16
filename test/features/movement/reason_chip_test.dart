import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/reason_chip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReasonChip Widget Tests', () {
    testWidgets('Renders reason text and icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ReasonChip(
            reason: MovementStrings.reasonInterest,
          ),
        ),
      );

      expect(find.text(MovementStrings.reasonInterest), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('Tapping opens explanation bottom sheet', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ReasonChip(
            reason: MovementStrings.reasonAvailableTime,
            explanation: 'این جلسه دقیقاً ۳۰ دقیقه طول می‌کشد و با زمان آزاد شما همخوانی دارد.',
          ),
        ),
      );

      await tester.tap(find.byType(ReasonChip));
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.reasonWhySuggestion), findsOneWidget);
      expect(find.textContaining('این جلسه دقیقاً ۳۰ دقیقه طول می‌کشد'), findsOneWidget);
    });
  });
}
