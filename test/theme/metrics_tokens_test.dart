import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/tokens/ritmo_metrics.dart';
import 'package:ritmo/core/theme/ui_scale.dart';

void main() {
  group('RitmoMetrics ThemeExtension Tests', () {
    test('Token monotonicity across all density levels', () {
      final compact = RitmoMetrics.of(RitmoDensityLevel.compact);
      final comfortable = RitmoMetrics.of(RitmoDensityLevel.comfortable);
      final spacious = RitmoMetrics.of(RitmoDensityLevel.spacious);
      final xl = RitmoMetrics.of(RitmoDensityLevel.xl);

      final levels = [compact, comfortable, spacious, xl];

      for (var i = 0; i < levels.length - 1; i++) {
        final a = levels[i];
        final b = levels[i + 1];

        expect(a.densityFactor, lessThanOrEqualTo(b.densityFactor));
        expect(a.spaceXs, lessThanOrEqualTo(b.spaceXs));
        expect(a.spaceSm, lessThanOrEqualTo(b.spaceSm));
        expect(a.spaceMd, lessThanOrEqualTo(b.spaceMd));
        expect(a.spaceLg, lessThanOrEqualTo(b.spaceLg));
        expect(a.spaceXl, lessThanOrEqualTo(b.spaceXl));
        expect(a.spaceXxl, lessThanOrEqualTo(b.spaceXxl));
        expect(a.spaceXxxl, lessThanOrEqualTo(b.spaceXxxl));

        expect(a.radiusField, lessThanOrEqualTo(b.radiusField));
        expect(a.radiusCard, lessThanOrEqualTo(b.radiusCard));
        expect(a.radiusHero, lessThanOrEqualTo(b.radiusHero));
        expect(a.radiusSheet, lessThanOrEqualTo(b.radiusSheet));

        expect(a.iconSm, lessThanOrEqualTo(b.iconSm));
        expect(a.iconMd, lessThanOrEqualTo(b.iconMd));
        expect(a.iconLg, lessThanOrEqualTo(b.iconLg));
        expect(a.iconXl, lessThanOrEqualTo(b.iconXl));

        expect(a.touchTarget, lessThanOrEqualTo(b.touchTarget));
        expect(a.rowHeight, lessThanOrEqualTo(b.rowHeight));
        expect(a.navBarHeight, lessThanOrEqualTo(b.navBarHeight));
        expect(a.hourSlotHeight, lessThanOrEqualTo(b.hourSlotHeight));
      }
    });

    test('touchTarget is at least 48.0 for all density levels', () {
      for (final level in RitmoDensityLevel.values) {
        final m = RitmoMetrics.of(level);
        expect(m.touchTarget, greaterThanOrEqualTo(48.0));
      }
    });

    test('lerp performs real interpolation between density levels', () {
      final compact = RitmoMetrics.of(RitmoDensityLevel.compact);
      final xl = RitmoMetrics.of(RitmoDensityLevel.xl);

      final mid = compact.lerp(xl, 0.5);

      expect(
        mid.densityFactor,
        closeTo((compact.densityFactor + xl.densityFactor) / 2, 0.001),
      );
      expect(mid.spaceLg, closeTo((compact.spaceLg + xl.spaceLg) / 2, 0.001));
      expect(
        mid.touchTarget,
        closeTo((compact.touchTarget + xl.touchTarget) / 2, 0.001),
      );
      expect(
        mid.rowHeight,
        closeTo((compact.rowHeight + xl.rowHeight) / 2, 0.001),
      );
      expect(
        mid.navBarHeight,
        closeTo((compact.navBarHeight + xl.navBarHeight) / 2, 0.001),
      );
    });
  });
}
