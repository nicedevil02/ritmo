import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_settings_panel.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildSettingsApp({
  required Map<String, String> settings,
  required VoidCallback onTogglePregnancyMode,
  VoidCallback? onOpenPregnancyOnboarding,
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
          onEditBaselineParameter: (k, t, min, max, def) async {},
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late CycleEngine engine;
  late EngineRegistry registry;

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

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

  group('SettingsPanel Pregnancy Onboarding Trigger Tests (PRG-15)', () {
    testWidgets(
      'calls onOpenPregnancyOnboarding when enabling pregnancy mode',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        bool onboardingTriggered = false;
        bool rawToggleTriggered = false;

        await tester.pumpWidget(
          _buildSettingsApp(
            settings: {'cycle_pregnancy_mode': 'false'},
            onTogglePregnancyMode: () => rawToggleTriggered = true,
            onOpenPregnancyOnboarding: () => onboardingTriggered = true,
          ),
        );
        await tester.pump();

        final toggle = find.text('فعالسازی حالت بارداری');
        expect(toggle, findsOneWidget);

        await tester.tap(toggle);
        await tester.pump();

        expect(onboardingTriggered, isTrue);
        expect(rawToggleTriggered, isFalse);
      },
    );

    testWidgets(
      'opens PregnancyOnboardingShell directly if onOpenPregnancyOnboarding is null',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _buildSettingsApp(
            settings: {'cycle_pregnancy_mode': 'false'},
            onTogglePregnancyMode: () {},
            onOpenPregnancyOnboarding: null,
          ),
        );
        await tester.pump();

        final toggle = find.text('فعالسازی حالت بارداری');
        expect(toggle, findsOneWidget);

        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(find.byType(PregnancyOnboardingShell), findsOneWidget);
      },
    );
  });
}
