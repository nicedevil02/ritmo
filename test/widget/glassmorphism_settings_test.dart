import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

void main() {
  group('Glassmorphism Dynamic Settings & Fallback Tests', () {
    test('RitmoTheme.build incorporates glassBlurSigma and glassOpacityPercent', () {
      final theme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        glassBlurSigma: 28.0,
        glassOpacityPercent: 45,
      );

      final behavior = theme.extension<RitmoBehavior>();
      final materials = theme.extension<RitmoMaterials>();
      final colors = theme.extension<RitmoColors>();

      expect(behavior, isNotNull);
      expect(behavior!.glassBlurSigma, 28.0);
      expect(behavior.glassOpacityPercent, 45);
      expect(behavior.reduceTransparency, isFalse);

      expect(materials, isNotNull);
      expect(materials!.regular.sigma, 28.0);
      expect(materials.regular.tintAlpha, closeTo(0.45, 0.01));

      expect(colors, isNotNull);
      expect(colors!.glassTint.a, closeTo(0.45, 0.01));
    });

    test('RitmoTheme.build degrades gracefully when reduceTransparency is true', () {
      final theme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
      );

      final behavior = theme.extension<RitmoBehavior>();
      expect(behavior, isNotNull);
      expect(behavior!.reduceTransparency, isTrue);
    });

    testWidgets('RitmoGlassCard renders opaque surface when reduceTransparency is true', (tester) async {
      final darkThemeOpaque = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: darkThemeOpaque,
          home: const Scaffold(
            body: RitmoGlassCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      // BackdropFilter should NOT be present when glass is disabled
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('RitmoGlassCard renders BackdropFilter when glass is enabled', (tester) async {
      final darkThemeGlass = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 24.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: darkThemeGlass,
          home: const Scaffold(
            body: RitmoGlassCard(
              child: Text('Glass Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Glass Card Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });
}
