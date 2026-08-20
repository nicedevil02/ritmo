import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart';
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

  group('PregnancySettingsSheet Shell Tests (PRG-30)', () {
    testWidgets('renders all 6 section titles in exact order', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(const PregnancySettingsSheet()));
      await tester.pumpAndSettle();

      expect(find.text('تنظیمات بارداری'), findsOneWidget);
      expect(find.text('تاریخ و سن بارداری'), findsOneWidget);
      expect(find.text('لحن و نمایش'), findsOneWidget);
      expect(find.text('مراقبت‌ها و یادآوری‌ها'), findsOneWidget);
      expect(find.text('لگدشماری'), findsOneWidget);
      expect(find.text('حریم خصوصی'), findsOneWidget);
      expect(find.text('ناحیهٔ خطر'), findsOneWidget);
    });

    testWidgets('PregnancySettingsSheet.show opens the sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => PregnancySettingsSheet.show(ctx),
              child: const Text('باز کردن تنظیمات'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('باز کردن تنظیمات'));
      await tester.pumpAndSettle();

      expect(find.text('تنظیمات بارداری'), findsOneWidget);
      expect(find.text('ناحیهٔ خطر'), findsOneWidget);
    });
  });
}
