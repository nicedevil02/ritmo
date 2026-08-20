import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_settings_panel.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget _buildSettingsPanel({
  required Map<String, String> settings,
  required VoidCallback onOpenPregnancyOnboarding,
  required VoidCallback onTogglePregnancyMode,
}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(
      body: SingleChildScrollView(
        child: CycleSettingsPanel(
          settings: settings,
          onDataReloadNeeded: () {},
          onOpenPasscodeSheet: () {},
          onTogglePregnancyMode: onTogglePregnancyMode,
          onOpenPregnancyOnboarding: onOpenPregnancyOnboarding,
          onEditBaselineParameter: (a, b, c, d, e) async {},
        ),
      ),
    ),
  );
}

void main() {
  group('Settings Pregnancy Toggle Tests (PRG-25, PRG-26)', () {
    testWidgets('when pregnancy is inactive, shows activation row and triggers onboarding callback on tap', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var onboardingOpened = false;

      final settings = <String, String>{
        'cycle_pregnancy_mode': 'false',
        'preg_setup_done': 'false',
      };

      await tester.pumpWidget(_buildSettingsPanel(
        settings: settings,
        onOpenPregnancyOnboarding: () => onboardingOpened = true,
        onTogglePregnancyMode: () {},
      ));
      await tester.pumpAndSettle();

      final activationRow = find.text('فعالسازی حالت بارداری');
      expect(activationRow, findsOneWidget);
      expect(find.text('ویرایش و بازبینی راه‌اندازی بارداری'), findsNothing);
      expect(find.text('پایان دوره بارداری و بازگشت به چرخه'), findsNothing);

      await tester.ensureVisible(activationRow);
      await tester.tap(activationRow);
      await tester.pumpAndSettle();

      expect(onboardingOpened, true);
    });

    testWidgets('when pregnancy is active, shows edit row and return row', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var toggleCalled = false;

      final settings = <String, String>{
        'cycle_pregnancy_mode': 'true',
        'preg_setup_done': 'true',
      };

      await tester.pumpWidget(_buildSettingsPanel(
        settings: settings,
        onOpenPregnancyOnboarding: () {},
        onTogglePregnancyMode: () => toggleCalled = true,
      ));
      await tester.pumpAndSettle();

      final editRow = find.text('ویرایش و بازبینی راه‌اندازی بارداری');
      final returnRow = find.text('پایان دوره بارداری و بازگشت به چرخه');

      expect(editRow, findsOneWidget);
      expect(returnRow, findsOneWidget);
      expect(find.text('فعالسازی حالت بارداری'), findsNothing);

      await tester.ensureVisible(returnRow);
      await tester.tap(returnRow);
      await tester.pumpAndSettle();

      expect(toggleCalled, true);
    });
  });
}
