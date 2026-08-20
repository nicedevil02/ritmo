import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildShellApp({required VoidCallback onCompleted}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: PregnancyOnboardingShell(onCompleted: onCompleted)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('PregnancyOnboardingShell Tests (PRG-13)', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('completes all 5 steps and saves valid profile to database', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool completed = false;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _buildShellApp(onCompleted: () => completed = true),
        );
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        // Step 0: Tone
        expect(find.text('قراره کنارت باشیم تا روز تولد'), findsOneWidget);
        final nextButton = find.text('مرحله بعد');
        expect(nextButton, findsOneWidget);

        // Advance to Step 1: Dates
        await tester.tap(nextButton);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        expect(find.text('مبنای محاسبهٔ تاریخ'), findsOneWidget);

        // Advance to Step 2: Context
        await tester.tap(nextButton);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        expect(find.text('شرایط و اتصالات بارداری'), findsOneWidget);

        // Advance to Step 3: Privacy
        await tester.tap(nextButton);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        expect(find.text('حریم خصوصی و قفل'), findsOneWidget);

        // Advance to Step 4: Confirm
        await tester.tap(nextButton);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        expect(find.text('تأیید و راه‌اندازی بارداری'), findsOneWidget);
        final finishButton = find.text('فعال‌سازی حالت بارداری');
        expect(finishButton, findsOneWidget);

        // Tap finish
        await tester.tap(finishButton);
        for (var i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (completed) break;
        }

        await tester.pumpWidget(const SizedBox());

        expect(completed, isTrue);

        final rows = await db.query('app_settings');
        final settings = {for (final r in rows) r['key'] as String: r['value']};

        expect(PregnancySettings.isSetupDone(settings), isTrue);
        expect(PregnancySettings.isPregnancyUsable(settings), isTrue);
        expect(settings['cycle_pregnancy_mode'], equals('true'));
        expect(settings['pregnancy_mode'], equals('true'));
        expect(settings['cycle_is_pregnant'], equals('true'));
      });
    });
  });
}
