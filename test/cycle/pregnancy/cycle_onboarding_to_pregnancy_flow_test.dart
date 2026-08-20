import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_onboarding_controller.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/steps/step_2_cycle_status.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('CycleOnboarding to PregnancyOnboarding Flow Tests (PRG-14)', () {
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

    testWidgets('Step2CycleStatus triggers onNavigateToPregnancy callback when pregnancy shortcut is tapped', (tester) async {
      bool navigated = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fa'),
          home: Scaffold(
            body: Step2CycleStatus(
              data: CycleOnboardingData(startDate: DateTime(2026, 1, 1)),
              onDataChanged: (_) {},
              onNext: () {},
              onBack: () {},
              onNavigateToPregnancy: () => navigated = true,
              colors: kJadeNoirLight,
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final shortcut = find.textContaining('الان باردارم');
      expect(shortcut, findsOneWidget);

      await tester.tap(shortcut);
      await tester.pump();

      expect(navigated, isTrue);
    });

    testWidgets('PregnancyOnboardingShell.show renders the pregnancy onboarding wizard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fa'),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    PregnancyOnboardingShell.show(
                      ctx,
                      onCompleted: () {},
                    );
                  },
                  child: const Text('Open Pregnancy'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Pregnancy'));
      await tester.pumpAndSettle();

      expect(find.byType(PregnancyOnboardingShell), findsOneWidget);
      expect(find.text('راه‌اندازی همراهی بارداری'), findsOneWidget);
    });
  });
}
