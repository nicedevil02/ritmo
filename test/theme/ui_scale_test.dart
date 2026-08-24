import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/tokens/ritmo_breakpoints.dart';
import 'package:ritmo/core/theme/ui_scale.dart';

void main() {
  group('RitmoUiScale Pure Logic Tests', () {
    test('factorFromPercent snaps to nearest step', () {
      expect(RitmoUiScale.factorFromPercent(85), 0.85);
      expect(
        RitmoUiScale.factorFromPercent(80),
        0.85,
      ); // under min clamps to 0.85
      expect(RitmoUiScale.factorFromPercent(90), 0.925);
      expect(RitmoUiScale.factorFromPercent(92), 0.925);
      expect(RitmoUiScale.factorFromPercent(100), 1.00);
      expect(RitmoUiScale.factorFromPercent(104), 1.00);
      expect(RitmoUiScale.factorFromPercent(108), 1.10);
      expect(RitmoUiScale.factorFromPercent(110), 1.10);
      expect(RitmoUiScale.factorFromPercent(120), 1.25);
      expect(RitmoUiScale.factorFromPercent(125), 1.25);
      expect(RitmoUiScale.factorFromPercent(135), 1.40);
      expect(RitmoUiScale.factorFromPercent(140), 1.40);
      expect(
        RitmoUiScale.factorFromPercent(150),
        1.40,
      ); // over max clamps to 1.40
    });

    test('percentFromFactor rounds accurately', () {
      expect(RitmoUiScale.percentFromFactor(0.85), 85);
      expect(RitmoUiScale.percentFromFactor(0.925), 93);
      expect(RitmoUiScale.percentFromFactor(1.00), 100);
      expect(RitmoUiScale.percentFromFactor(1.10), 110);
      expect(RitmoUiScale.percentFromFactor(1.25), 125);
      expect(RitmoUiScale.percentFromFactor(1.40), 140);
    });

    test(
      'effectiveTextScale respects followOs and clamps within supported bounds',
      () {
        // followOs == false
        final scale1 = RitmoUiScale.effectiveTextScale(
          osScale: 1.5,
          appPercent: 100,
          followOs: false,
        );
        expect(scale1, 1.0);

        // followOs == true with normal osScale
        final scale2 = RitmoUiScale.effectiveTextScale(
          osScale: 1.1,
          appPercent: 100,
          followOs: true,
        );
        expect(scale2, closeTo(1.1, 0.001));

        // clamped to supportedMaxTextScale
        final scaleMax = RitmoUiScale.effectiveTextScale(
          osScale: 2.0,
          appPercent: 140,
          followOs: true,
        );
        expect(scaleMax, RitmoBreakpoints.supportedMaxTextScale);

        // clamped to supportedMinTextScale
        final scaleMin = RitmoUiScale.effectiveTextScale(
          osScale: 0.5,
          appPercent: 85,
          followOs: true,
        );
        expect(scaleMin, RitmoBreakpoints.supportedMinTextScale);
      },
    );

    test(
      'parseDensity handles null, empty, and invalid strings gracefully',
      () {
        expect(RitmoUiScale.parseDensity(null), RitmoDensityLevel.comfortable);
        expect(RitmoUiScale.parseDensity(''), RitmoDensityLevel.comfortable);
        expect(
          RitmoUiScale.parseDensity('bogus'),
          RitmoDensityLevel.comfortable,
        );
        expect(RitmoUiScale.parseDensity('compact'), RitmoDensityLevel.compact);
        expect(
          RitmoUiScale.parseDensity('spacious'),
          RitmoDensityLevel.spacious,
        );
        expect(RitmoUiScale.parseDensity('xl'), RitmoDensityLevel.xl);
      },
    );

    test('labels match Persian design specifications', () {
      expect(RitmoUiScale.textLabelFor(85), 'خیلی کوچک');
      expect(RitmoUiScale.textLabelFor(92), 'کوچک');
      expect(RitmoUiScale.textLabelFor(100), 'معمولی (پیش‌فرض)');
      expect(RitmoUiScale.textLabelFor(110), 'بزرگ');
      expect(RitmoUiScale.textLabelFor(125), 'خیلی بزرگ');
      expect(RitmoUiScale.textLabelFor(140), 'بیشینه');

      expect(RitmoUiScale.densityLabelFor(RitmoDensityLevel.compact), 'فشرده');
      expect(
        RitmoUiScale.densityLabelFor(RitmoDensityLevel.comfortable),
        'معمولی',
      );
      expect(RitmoUiScale.densityLabelFor(RitmoDensityLevel.spacious), 'راحت');
      expect(RitmoUiScale.densityLabelFor(RitmoDensityLevel.xl), 'بزرگ');
    });

    test('stepIndexFromPercent and percentFromStepIndex bijective mapping', () {
      final expectedPercents = [85, 93, 100, 110, 125, 140];
      for (var i = 0; i < expectedPercents.length; i++) {
        final percent = expectedPercents[i];
        expect(RitmoUiScale.stepIndexFromPercent(percent), i);
        expect(RitmoUiScale.percentFromStepIndex(i), percent);
      }
      // Clamping and fallback verification
      expect(RitmoUiScale.percentFromStepIndex(-1), 85);
      expect(RitmoUiScale.percentFromStepIndex(10), 140);
      expect(RitmoUiScale.stepIndexFromPercent(92), 1); // 92 snaps to step 1 (93)
      expect(RitmoUiScale.stepIndexFromPercent(104), 2); // 104 snaps to step 2 (100)
    });
  });
}
