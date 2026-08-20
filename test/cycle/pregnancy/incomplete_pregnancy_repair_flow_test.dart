import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildTestApp() {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: const CycleScreen(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Incomplete Pregnancy Repair Flow Tests (PRG-17)', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await CycleLockService.instance.setLockEnabled(false, db);
      await CycleLockService.instance.clearPin(db);

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);

      // Set pregnancy active without dates (broken state)
      await PregnancySettings.setPregnancyActive(true, db: db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('incomplete warning button opens PregnancyOnboardingShell and repairs state', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(_buildTestApp());
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // 1. Verify incomplete warning card is visible
        expect(find.text('اطلاعات بارداری ناقص است'), findsOneWidget);
        final completeCta = find.text('تکمیل راه‌اندازی بارداری');
        expect(completeCta, findsOneWidget);

        // 2. Tap CTA to open PregnancyOnboardingShell
        await tester.tap(completeCta);
        for (var i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 30));
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.byType(PregnancyOnboardingShell), findsOneWidget);

        // 3. Step 0 -> Step 1
        final nextBtn = find.widgetWithText(ElevatedButton, 'مرحله بعد');
        expect(nextBtn, findsOneWidget);
        await tester.tap(nextBtn);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Step 1 -> Step 2
        await tester.tap(find.widgetWithText(ElevatedButton, 'مرحله بعد'));
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Step 2 -> Step 3
        await tester.tap(find.widgetWithText(ElevatedButton, 'مرحله بعد'));
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Step 3 -> Step 4
        await tester.tap(find.widgetWithText(ElevatedButton, 'مرحله بعد'));
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Step 4: Tap 'شروع همراهی بارداری 🌸'
        final saveBtn = find.widgetWithText(ElevatedButton, 'شروع همراهی بارداری 🌸');
        expect(saveBtn, findsOneWidget);
        await tester.tap(saveBtn);
        for (var i = 0; i < 15; i++) {
          await Future.delayed(const Duration(milliseconds: 30));
          await tester.pump(const Duration(milliseconds: 50));
        }

        // 4. Verify CyclePregnancyModeView is now displayed
        expect(find.byType(CyclePregnancyModeView), findsOneWidget);
        expect(find.text('اطلاعات بارداری ناقص است'), findsNothing);
      });
    });
  });
}
