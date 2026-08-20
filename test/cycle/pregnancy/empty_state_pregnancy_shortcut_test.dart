import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
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

  group('EmptyState Pregnancy Shortcut Tests (PRG-16)', () {
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
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'tapping secondary pregnancy CTA in empty state opens PregnancyOnboardingShell directly',
      (tester) async {
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
            await tester.pump();
          }

          // 1. Verify both buttons exist in Empty State
          expect(find.text('راه‌اندازی چرخه'), findsOneWidget);
          final pregnancyCta = find.text('در حال حاضر باردار هستم');
          expect(pregnancyCta, findsOneWidget);

          // 2. Tap pregnancy CTA
          await tester.tap(pregnancyCta);
          for (var i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 20));
            await tester.pump();
          }

          // 3. Verify PregnancyOnboardingShell is opened directly
          expect(find.byType(PregnancyOnboardingShell), findsOneWidget);
          expect(find.text('راه‌اندازی بارداری'), findsOneWidget);
        });
      },
    );
  });
}
