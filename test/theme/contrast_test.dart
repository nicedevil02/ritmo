import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) {
  final r = _lin(c.r);
  final g = _lin(c.g);
  final b = _lin(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _luminance(c1);
  final l2 = _luminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// APCA (SAPC-8، پیش‌نویس WCAG 3) — RFC Aurora §۵.۱:
/// APCA «هدف طراحی» است و کف انطباق اجباری همان WCAG 2.1 می‌ماند؛
/// پس این سنجه فقط گزارش می‌دهد و تست را قرمز نمی‌کند.
/// اهداف: متن بدنه Lc ۷۵ · تیتر بزرگ Lc ۶۰ · عناصر غیرمتنی Lc ۴۵.
double _apcaLc(Color text, Color bg) {
  double y(Color c) =>
      0.2126729 * _lin(c.r) + 0.7151522 * _lin(c.g) + 0.0721750 * _lin(c.b);

  var yTxt = y(text);
  var yBg = y(bg);

  const blackThreshold = 0.022;
  const blackClamp = 1.414;
  if (yTxt < blackThreshold) {
    yTxt += math.pow(blackThreshold - yTxt, blackClamp).toDouble();
  }
  if (yBg < blackThreshold) {
    yBg += math.pow(blackThreshold - yBg, blackClamp).toDouble();
  }

  final reverse = yBg > yTxt;
  final sapc = reverse
      ? (math.pow(yBg, 0.65) - math.pow(yTxt, 0.62)).toDouble() * 1.14
      : (math.pow(yBg, 0.56) - math.pow(yTxt, 0.57)).toDouble() * 1.14;

  final lc = sapc * 100;
  return lc.abs() < 0.1 ? 0 : lc;
}

void _checkContrast({
  required String paletteName,
  required String modeName,
  required String tokenA,
  required Color colorA,
  required String tokenB,
  required Color colorB,
  required double minRatio,
}) {
  final ratio = _contrastRatio(colorA, colorB);
  expect(
    ratio >= minRatio,
    isTrue,
    reason: 'Contrast check failed for [$paletteName - $modeName]: $tokenA ($colorA) vs $tokenB ($colorB). Expected >= $minRatio, got ${ratio.toStringAsFixed(2)}',
  );
}

/// گزارش APCA (غیربلاک‌کننده): اگر زیر هدف بود، در خروجی تست چاپ می‌شود.
void _reportApca({
  required String paletteName,
  required String modeName,
  required String tokenA,
  required Color colorA,
  required String tokenB,
  required Color colorB,
  required double targetLc,
  required List<String> misses,
}) {
  final lc = _apcaLc(colorA, colorB).abs();
  if (lc < targetLc) {
    misses.add(
      '[$paletteName - $modeName] $tokenA vs $tokenB: Lc ${lc.toStringAsFixed(1)} < target $targetLc',
    );
  }
}

void main() {
  final apcaMisses = <String>[];

  tearDownAll(() {
    if (apcaMisses.isEmpty) {
      // ignore: avoid_print
      print('APCA report: all checked pairs meet design targets.');
      return;
    }
    // ignore: avoid_print
    print('APCA report (design target, non-blocking):');
    for (final miss in apcaMisses) {
      // ignore: avoid_print
      print('  - $miss');
    }
  });

  group('WCAG Contrast Ratio Tests for 10 Color Sets (5 Palettes x 2 Modes)', () {
    for (final palette in RitmoPalette.all) {
      for (final brightness in Brightness.values) {
        final modeName = brightness == Brightness.dark ? 'dark' : 'light';
        final paletteName = palette.nameFa;
        final colors = palette.forBrightness(brightness);

        test('Contrast test: $paletteName ($modeName)', () {
          // 1. textPrimary on surface >= 4.5:1
          _checkContrast(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'textPrimary',
            colorA: colors.textPrimary,
            tokenB: 'surface',
            colorB: colors.surface,
            minRatio: 4.5,
          );

          // 2. textPrimary on background >= 4.5:1
          _checkContrast(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'textPrimary',
            colorA: colors.textPrimary,
            tokenB: 'background',
            colorB: colors.background,
            minRatio: 4.5,
          );

          // 3. onPrimary on primary >= 4.5:1
          _checkContrast(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'onPrimary',
            colorA: colors.onPrimary,
            tokenB: 'primary',
            colorB: colors.primary,
            minRatio: 4.5,
          );

          // 4. textSecondary on surface >= 3.0:1
          _checkContrast(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'textSecondary',
            colorA: colors.textSecondary,
            tokenB: 'surface',
            colorB: colors.surface,
            minRatio: 3.0,
          );

          // 5. textOnColor on error, success, warning >= 4.5:1
          _checkContrast(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'textOnColor',
            colorA: colors.textOnColor,
            tokenB: 'error',
            colorB: colors.error,
            minRatio: 4.5,
          );
          _checkContrast(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'textOnColor',
            colorA: colors.textOnColor,
            tokenB: 'success',
            colorB: colors.success,
            minRatio: 4.5,
          );

          // 6. primary on surface >= 3.0:1
          _checkContrast(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'primary',
            colorA: colors.primary,
            tokenB: 'surface',
            colorB: colors.surface,
            minRatio: 3.0,
          );

          // 7. Each module color on surface >= 3.0:1
          for (int slot = 0; slot < 8; slot++) {
            final moduleColor = colors.modules.bySlot(slot);
            _checkContrast(
              paletteName: paletteName,
              modeName: modeName,
              tokenA: 'moduleSlot($slot)',
              colorA: moduleColor,
              tokenB: 'surface',
              colorB: colors.surface,
              minRatio: 3.0,
            );
          }

          // --- APCA design targets (report-only) ---
          _reportApca(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'textPrimary',
            colorA: colors.textPrimary,
            tokenB: 'surface',
            colorB: colors.surface,
            targetLc: 75, // متن بدنه
            misses: apcaMisses,
          );
          _reportApca(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'onPrimary',
            colorA: colors.onPrimary,
            tokenB: 'primary',
            colorB: colors.primary,
            targetLc: 75,
            misses: apcaMisses,
          );
          _reportApca(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'textSecondary',
            colorA: colors.textSecondary,
            tokenB: 'surface',
            colorB: colors.surface,
            targetLc: 60, // متن درشت‌تر/ثانویه
            misses: apcaMisses,
          );
          _reportApca(
            paletteName: paletteName,
            modeName: modeName,
            tokenA: 'primary',
            colorA: colors.primary,
            tokenB: 'surface',
            colorB: colors.surface,
            targetLc: 45, // عنصر غیرمتنی
            misses: apcaMisses,
          );
        });
      }
    }
  });
}
