import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/ui_scale.dart';

void main() {
  group('Theme Default Identity Test (Comfortable Pixel Parity)', () {
    test('RitmoTheme.build in comfortable density matches exact default design specs', () {
      final theme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.light,
        density: RitmoDensityLevel.comfortable,
      );

      expect(theme.appBarTheme.toolbarHeight, equals(56.0));
      expect(theme.appBarTheme.iconTheme?.size, equals(24.0));
      expect(theme.iconTheme.size, equals(24.0));
      expect(theme.chipTheme.padding, equals(const EdgeInsets.symmetric(horizontal: 12, vertical: 6)));
      expect(theme.inputDecorationTheme.contentPadding, equals(const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));
      expect(theme.listTileTheme.contentPadding, equals(const EdgeInsets.symmetric(horizontal: 16, vertical: 4)));

      // Button minimum sizes
      expect(theme.filledButtonTheme.style?.minimumSize?.resolve({}), equals(const Size(48, 48)));
      expect(theme.elevatedButtonTheme.style?.minimumSize?.resolve({}), equals(const Size(48, 48)));
      expect(theme.outlinedButtonTheme.style?.minimumSize?.resolve({}), equals(const Size(48, 48)));
      expect(theme.textButtonTheme.style?.minimumSize?.resolve({}), equals(const Size(48, 48)));

      // Radii
      final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect((dialogShape.borderRadius as BorderRadius).topLeft.x, equals(16.0));

      final sheetShape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect((sheetShape.borderRadius as BorderRadius).topLeft.x, equals(28.0));

      final filledButtonShape = theme.filledButtonTheme.style?.shape?.resolve({}) as RoundedRectangleBorder;
      expect((filledButtonShape.borderRadius as BorderRadius).topLeft.x, equals(14.0));

      // Visual density
      expect(theme.visualDensity, equals(const VisualDensity(horizontal: 0, vertical: 0)));
    });
  });
}
