import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

void main() {
  group('RitmoTheme.build Wiring Tests', () {
    test('RitmoTheme.build includes RitmoMetrics in extensions', () {
      final themeComfortable = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.light,
        density: RitmoDensityLevel.comfortable,
      );

      final metricsComfortable = themeComfortable.extension<RitmoMetrics>();
      expect(metricsComfortable, isNotNull);
      expect(metricsComfortable!.density, RitmoDensityLevel.comfortable);
      expect(metricsComfortable.touchTarget, 48.0);
      expect(themeComfortable.visualDensity.horizontal, 0.0);

      final themeXl = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        density: RitmoDensityLevel.xl,
      );

      final metricsXl = themeXl.extension<RitmoMetrics>();
      expect(metricsXl, isNotNull);
      expect(metricsXl!.density, RitmoDensityLevel.xl);
      expect(metricsXl.touchTarget, 60.0);
      expect(themeXl.visualDensity.horizontal, closeTo(1.92, 0.01));
    });

    test('Component themes reflect RitmoMetrics tokens', () {
      final themeCompact = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.light,
        density: RitmoDensityLevel.compact,
      );
      final mCompact = themeCompact.extension<RitmoMetrics>()!;

      expect(themeCompact.appBarTheme.iconTheme?.size, mCompact.iconLg);
      expect(themeCompact.appBarTheme.toolbarHeight, mCompact.rowHeight);
      expect(themeCompact.iconTheme.size, mCompact.iconLg);

      final themeSpacious = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        density: RitmoDensityLevel.spacious,
      );
      final mSpacious = themeSpacious.extension<RitmoMetrics>()!;

      expect(themeSpacious.appBarTheme.iconTheme?.size, mSpacious.iconLg);
      expect(themeSpacious.appBarTheme.toolbarHeight, mSpacious.rowHeight);
      expect(themeSpacious.iconTheme.size, mSpacious.iconLg);
    });
  });
}
