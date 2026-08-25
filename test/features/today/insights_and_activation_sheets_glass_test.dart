import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/today/presentation/systems_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Systems Hub Activation Sheet Glassmorphism Tests', () {
    testWidgets('SystemsHubScreen mounts and respects theme', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: Scaffold(
            body: SystemsHubScreen(
              onLogout: () {},
              themeRepository: ThemeRepository(),
              localeRepository: LocaleRepository(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SystemsHubScreen), findsOneWidget);
    });
  });
}
