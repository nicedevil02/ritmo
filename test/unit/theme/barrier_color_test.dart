import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

void main() {
  group('Global Modal Barrier Transparency Tests', () {
    test('RitmoTheme sets modalBarrierColor and dialog barrierColor to transparent', () {
      final lightTheme = RitmoTheme.build(
        palette: RitmoPalette.copperDusk,
        brightness: Brightness.light,
      );
      final darkTheme = RitmoTheme.build(
        palette: RitmoPalette.copperDusk,
        brightness: Brightness.dark,
      );

      expect(lightTheme.bottomSheetTheme.modalBarrierColor, equals(Colors.transparent));
      expect(darkTheme.bottomSheetTheme.modalBarrierColor, equals(Colors.transparent));
      expect(lightTheme.dialogTheme.barrierColor, equals(Colors.transparent));
      expect(darkTheme.dialogTheme.barrierColor, equals(Colors.transparent));
    });
  });
}
