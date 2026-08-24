import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';

void main() {
  Widget buildWithDensity(RitmoDensityLevel density, Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.light,
        density: density,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );
  }

  group('Ritmo Primitives Density Adaptation Tests', () {
    testWidgets('RitmoPrimaryButton adapts height to touchTarget in density', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWithDensity(
          RitmoDensityLevel.comfortable,
          RitmoPrimaryButton(label: 'تست', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();

      final comfortableBtn = tester.getSize(find.byType(RitmoPrimaryButton));
      expect(comfortableBtn.height, 48.0);

      await tester.pumpWidget(
        buildWithDensity(
          RitmoDensityLevel.xl,
          RitmoPrimaryButton(label: 'تست', onPressed: () {}),
        ),
      );
      await tester.pumpAndSettle();

      final xlBtn = tester.getSize(find.byType(RitmoPrimaryButton));
      expect(xlBtn.height, greaterThanOrEqualTo(60.0));
      expect(xlBtn.height, greaterThan(comfortableBtn.height));
    });

    testWidgets('RitmoCard default borderRadius adapts to density radiusCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWithDensity(
          RitmoDensityLevel.xl,
          const RitmoCard(child: Text('کارت')),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(RitmoCard),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(18.0));
    });
  });
}
