import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/profile/presentation/theme_settings_screen.dart';

void main() {
  group(
    'Golden Tests — 5 Palettes x 3 Brightness States (light/dark/trueBlack), RTL',
    () {
      final themeRepo = ThemeRepository();

      for (final palette in RitmoPalette.all) {
        final paletteName = RitmoPalette.serializeId(palette.id);

        for (final brightness in Brightness.values) {
          final brightnessName =
              brightness == Brightness.dark ? 'dark' : 'light';

          testWidgets(
            'Golden: theme_settings_${paletteName}_$brightnessName',
            (tester) async {
              await tester.pumpWidget(
                MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: RitmoTheme.build(
                    palette: palette,
                    brightness: brightness,
                  ),
                  // اپ فارسی/RTL است؛ طبق RFC §۷.۴ هر Golden باید در همان جهت
                  // رندر شود، وگرنه متریک‌های فارسی و چیدمان واقعی سنجیده
                  // نمی‌شوند.
                  home: Directionality(
                    textDirection: TextDirection.rtl,
                    child: ThemeSettingsScreen(themeRepository: themeRepo),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                    'goldens/theme_settings_${paletteName}_$brightnessName.png'),
              );
            },
          );
        }

        // حالت تیره‌ی مطلق (trueBlack) — سومین حالت روشنایی در ماتریس.
        testWidgets(
          'Golden: theme_settings_${paletteName}_true_black',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: RitmoTheme.build(
                  palette: palette,
                  brightness: Brightness.dark,
                  trueBlack: true,
                ),
                home: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ThemeSettingsScreen(themeRepository: themeRepo),
                ),
              ),
            );
            await tester.pumpAndSettle();

            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile(
                  'goldens/theme_settings_${paletteName}_true_black.png'),
            );
          },
        );
      }
    },
  );
}
