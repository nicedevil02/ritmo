import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import '../../support/responsive_harness.dart';

void main() {
  group('R-12: RitmoBreakpoints Infrastructure Tests', () {
    test('1. widthClassOf(320) returns compact', () {
      expect(
        RitmoBreakpoints.widthClassOf(320),
        equals(RitmoWidthClass.compact),
      );
    });

    test('2. widthClassOf(359) returns compact (upper boundary)', () {
      expect(
        RitmoBreakpoints.widthClassOf(359),
        equals(RitmoWidthClass.compact),
      );
    });

    test('3. widthClassOf(360) returns regular (lower boundary)', () {
      expect(
        RitmoBreakpoints.widthClassOf(360),
        equals(RitmoWidthClass.regular),
      );
    });

    test('4. widthClassOf(600) returns expanded', () {
      expect(
        RitmoBreakpoints.widthClassOf(600),
        equals(RitmoWidthClass.expanded),
      );
    });

    test('5. heightClassOf(568) returns short', () {
      expect(
        RitmoBreakpoints.heightClassOf(568),
        equals(RitmoHeightClass.short),
      );
    });

    test('6. columnsFor(320, 160, 12) returns 1', () {
      expect(
        RitmoBreakpoints.columnsFor(
          availableWidth: 320,
          minTileWidth: 160,
          spacing: 12,
        ),
        equals(1),
      );
    });

    test('7. columnsFor(390, 160, 12) returns 2', () {
      expect(
        RitmoBreakpoints.columnsFor(
          availableWidth: 390,
          minTileWidth: 160,
          spacing: 12,
        ),
        equals(2),
      );
    });

    test('8. columnsFor(1200, 160, 12, maxColumns: 4) returns 4', () {
      expect(
        RitmoBreakpoints.columnsFor(
          availableWidth: 1200,
          minTileWidth: 160,
          spacing: 12,
          maxColumns: 4,
        ),
        equals(4),
      );
    });

    test('9. columnsFor(10, 160, 12) returns 1 (never zero or negative)', () {
      expect(
        RitmoBreakpoints.columnsFor(
          availableWidth: 10,
          minTileWidth: 160,
          spacing: 12,
        ),
        equals(1),
      );
    });

    testWidgets(
      '10. usableHeight computes height minus system paddings and insets',
      (tester) async {
        double? computedUsableHeight;

        await tester.pumpWidget(
          wrapResponsive(
            Builder(
              builder: (context) {
                computedUsableHeight = RitmoBreakpoints.usableHeight(context);
                return const SizedBox.shrink();
              },
            ),
            size: const Size(400, 800),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            keyboardInset: 300,
          ),
        );

        // 800 - 24 (top) - 16 (bottom) - 300 (keyboard) = 460
        expect(computedUsableHeight, equals(460.0));
      },
    );
  });

  group('Glass Theme Dynamic Updates Tests', () {
    test('RitmoTheme.build sets exact glassBlurSigma and glassOpacityPercent', () {
      final theme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        glassBlurSigma: 12.0,
        glassOpacityPercent: 65,
      );

      final behavior = theme.extension<RitmoBehavior>();
      expect(behavior, isNotNull);
      expect(behavior!.glassBlurSigma, 12.0);
      expect(behavior.glassOpacityPercent, 65);

      final colors = theme.extension<RitmoColors>();
      expect(colors, isNotNull);
      expect((colors!.glassTint.a * 100).round(), 65);
    });

    testWidgets('Dynamic theme updates glassBlurSigma and glassTint when notifier emits', (tester) async {
      final preferencesNotifier = ValueNotifier<ThemePreferences>(
        ThemePreferences.defaults.copyWith(
          glassBlurSigma: 25.0,
          glassOpacityPercent: 40,
        ),
      );

      await tester.pumpWidget(
        ValueListenableBuilder<ThemePreferences>(
          valueListenable: preferencesNotifier,
          builder: (context, prefs, _) {
            final palette = RitmoPalette.byId(prefs.paletteId);
            final theme = RitmoTheme.build(
              palette: palette,
              brightness: Brightness.dark,
              reduceTransparency: prefs.reduceTransparency,
              glassBlurSigma: prefs.glassBlurSigma,
              glassOpacityPercent: prefs.glassOpacityPercent,
            );

            return MaterialApp(
              theme: theme,
              home: Builder(
                builder: (ctx) {
                  return Scaffold(
                    body: Column(
                      children: [
                        Text('Blur: ${ctx.glassBlurSigma}'),
                        Text('Opacity: ${ctx.colors.glassTint.a}'),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      );

      expect(find.text('Blur: 25.0'), findsOneWidget);

      // Now change blur to 5.0 and opacity to 80%
      preferencesNotifier.value = preferencesNotifier.value.copyWith(
        glassBlurSigma: 5.0,
        glassOpacityPercent: 80,
      );
      await tester.pumpAndSettle();

      expect(find.text('Blur: 5.0'), findsOneWidget);
    });
  });
}

