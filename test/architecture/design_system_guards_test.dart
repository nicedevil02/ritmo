import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ritmo Design System Architectural Guardrails', () {
    test('Guard 1: Canonical Sheet Scaffold and Primitives exist and export correctly', () {
      final unifiedScaffold = File('lib/core/widgets/sheet/ritmo_sheet_scaffold.dart');
      expect(unifiedScaffold.existsSync(), isTrue, reason: 'Canonical RitmoSheetScaffold must exist');

      final glassActionSheet = File('lib/core/widgets/ritmo/ritmo_glass_action_sheet.dart');
      expect(glassActionSheet.existsSync(), isTrue, reason: 'RitmoGlassActionSheet must exist with distinct name');

      final cardsDoc = File('docs/DESIGN_SYSTEM_CARDS.md');
      expect(cardsDoc.existsSync(), isTrue, reason: 'DESIGN_SYSTEM_CARDS.md must exist');

      final sheetsDoc = File('docs/DESIGN_SYSTEM_ACTION_SHEETS.md');
      expect(sheetsDoc.existsSync(), isTrue, reason: 'DESIGN_SYSTEM_ACTION_SHEETS.md must exist');
    });

    test('Guard 2: Responsive layout docs do not contain hardcoded file:/// absolute machine paths', () {
      final docFile = File('docs/ui/RESPONSIVE_LAYOUT.md');
      expect(docFile.existsSync(), isTrue);

      final content = docFile.readAsStringSync();
      expect(
        content.contains('file:///'),
        isFalse,
        reason: 'docs/ui/RESPONSIVE_LAYOUT.md contains broken machine-specific file:/// URLs',
      );
    });

    test('Guard 3: RitmoGlassSurface uses dynamic context.metrics and not static RitmoRadius.card', () {
      final glassFile = File('lib/core/widgets/ritmo/ritmo_glass_surface.dart');
      expect(glassFile.existsSync(), isTrue);

      final content = glassFile.readAsStringSync();
      expect(
        content.contains('RitmoRadius.card'),
        isFalse,
        reason: 'ritmo_glass_surface.dart must use context.metrics.radiusCard for density scaling',
      );
      expect(content.contains('context.metrics.radiusCard'), isTrue);
    });

    test('Guard 4: RitmoHeroCard uses dynamic context.metrics.spaceXl and optional padding', () {
      final heroFile = File('lib/core/widgets/ritmo/ritmo_hero_card.dart');
      expect(heroFile.existsSync(), isTrue);

      final content = heroFile.readAsStringSync();
      expect(
        content.contains('padding = const EdgeInsets.all(RitmoSpacing.xl)'),
        isFalse,
        reason: 'ritmo_hero_card.dart must not hardcode static RitmoSpacing.xl in default constructor argument',
      );
      expect(content.contains('context.metrics.spaceXl'), isTrue);
    });

    test('Guard 5: RitmoTheme exports canonical glass action sheet', () {
      final themeFile = File('lib/core/theme/ritmo_theme.dart');
      expect(themeFile.existsSync(), isTrue);

      final content = themeFile.readAsStringSync();
      expect(content.contains("export 'package:ritmo/core/widgets/ritmo/ritmo_glass_action_sheet.dart';"), isTrue);
    });
  });
}
