import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_header.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pregnancy EDD Source Badge Tests (PRG-33)', () {
    testWidgets('renders correct badge for ultrasound, doctor_edd, and lmp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = CycleClock.now;

      // 1. Test ultrasound
      await tester.pumpWidget(
        _buildTestApp(
          PregnancyHeader(
            currentWeek: 12,
            currentDayInWeek: 3,
            remainingDays: 193,
            pregTone: 'warm',
            eddSource: 'ultrasound',
            startDate: now,
            onShowPrivacy: () {},
            onShowSettings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('سونوگرافی 🩺'), findsOneWidget);
      expect(find.text('تایید پزشک 🩺'), findsNothing);

      // 2. Test doctor_edd
      await tester.pumpWidget(
        _buildTestApp(
          PregnancyHeader(
            currentWeek: 12,
            currentDayInWeek: 3,
            remainingDays: 193,
            pregTone: 'warm',
            eddSource: 'doctor_edd',
            startDate: now,
            onShowPrivacy: () {},
            onShowSettings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('تایید پزشک 🩺'), findsOneWidget);
      expect(find.text('سونوگرافی 🩺'), findsNothing);

      // 3. Test lmp (no badge)
      await tester.pumpWidget(
        _buildTestApp(
          PregnancyHeader(
            currentWeek: 12,
            currentDayInWeek: 3,
            remainingDays: 193,
            pregTone: 'warm',
            eddSource: 'lmp',
            startDate: now,
            onShowPrivacy: () {},
            onShowSettings: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('سونوگرافی 🩺'), findsNothing);
      expect(find.text('تایید پزشک 🩺'), findsNothing);
    });
  });
}
