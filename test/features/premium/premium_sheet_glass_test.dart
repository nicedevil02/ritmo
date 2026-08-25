import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/premium/presentation/premium_upgrade_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Premium Upgrade Sheet Glassmorphism Tests', () {
    testWidgets('PremiumUpgradeSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: const Scaffold(
            body: PremiumUpgradeSheet(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('PremiumUpgradeSheet renders opaque container when glass is disabled', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
        glassBlurSigma: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: const Scaffold(
            body: PremiumUpgradeSheet(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
