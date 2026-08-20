import 'package:flutter/material.dart';
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
    home: Scaffold(
      body: PregnancyOnboardingShell(
        onCompleted: onCompleted,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('PregnancyOnboardingShell Tests (PRG-13)', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('completes all 5 steps and saves valid profile to database', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool completed = false;

      await tester.runAsync(() async {
        await tester.pumpWidget(_buildShellApp(onCompleted: () => completed = true));
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        // Step 0: Method Selection
        expect(find.text('محاسبه تاریخ زایمان و سن بارداری'), findsOneWidget);
        expect(find.text('اولین روز آخرین قاعدگی (LMP)'), findsOneWidget);
        final nextButton = find.text('مرحله بعد');
        expect(nextButton, findsOneWidget);

        // Advance to Step 1
        await tester.tap(nextButton);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        // Step 1: Date Selection
        expect(find.text('تاریخ اولین روز آخرین قاعدگی'), findsOneWidget);
        expect(find.text('سن بارداری کنونی:'), findsOneWidget);

        // Advance to Step 2
        await tester.tap(nextButton);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        // Step 2: Medical Info
        expect(find.text('اطلاعات پایه پزشکی'), findsOneWidget);
        expect(find.text('بارداری دوقلو یا چندقلو'), findsOneWidget);

        // Advance to Step 3
        await tester.tap(nextButton);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        // Step 3: Tone & Units
        expect(find.text('سفارشی‌سازی نمایش و لحن'), findsOneWidget);
        expect(find.text('صمیمی و پرانرژی 🌸'), findsOneWidget);

        // Advance to Step 4
        await tester.tap(nextButton);
        for (var i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }

        // Step 4: Summary & Finish
        expect(find.text('یادآورها و تأیید نهایی'), findsOneWidget);
        final finishButton = find.text('شروع همراهی بارداری 🌸');
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
