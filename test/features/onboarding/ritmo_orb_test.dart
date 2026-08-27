import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/onboarding/presentation/ritmo_orb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RitmoOrb Visual & Animation Tests', () {
    testWidgets('Renders app logo without any outer circular shape and animates without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: const Scaffold(
            body: Center(
              child: RitmoOrb(size: 160),
            ),
          ),
        ),
      );

      // Verify RitmoOrb is present
      expect(find.byType(RitmoOrb), findsOneWidget);

      // Verify Image.asset is present for the logo
      expect(find.byType(Image), findsOneWidget);

      // Verify no circular decoration is present in the orb
      final containers = tester.widgetList<Container>(find.descendant(
        of: find.byType(RitmoOrb),
        matching: find.byType(Container),
      ));

      for (final c in containers) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          expect(dec.shape, isNot(BoxShape.circle), reason: 'Should not have any BoxShape.circle containers');
          expect(dec.borderRadius, isNotNull, reason: 'Should use squircle rounded corners');
        }
      }

      // Advance animation frames (breathing + heartbeat)
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 2500));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Adapts to different sizes without layout overflow', (tester) async {
      for (final size in [70.0, 100.0, 130.0, 160.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.light,
            ),
            home: Scaffold(
              body: Center(
                child: RitmoOrb(size: size),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
