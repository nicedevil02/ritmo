import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_settings_panel.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildSettingsApp({
  required Map<String, String> settings,
  required VoidCallback onTogglePregnancyMode,
  required VoidCallback onOpenPregnancyOnboarding,
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
          onEditBaselineParameter: (k, t, min, max, d) async {},
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('SettingsPanel Pregnancy Onboarding Trigger Tests (PRG-15)', () {
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

    testWidgets('calls onOpenPregnancyOnboarding when enabling pregnancy mode and setup is not done', (tester) async {
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
          settings: {
            'cycle_pregnancy_mode': 'false',
          },
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
    });

    testWidgets('calls onTogglePregnancyMode directly when setup was already done before', (tester) async {
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
          settings: {
            'cycle_pregnancy_mode': 'false',
            'preg_setup_done': 'true',
            'preg_start_date': '2026-01-01',
            'preg_due_date': '2026-10-08',
          },
          onTogglePregnancyMode: () => rawToggleTriggered = true,
          onOpenPregnancyOnboarding: () => onboardingTriggered = true,
        ),
      );
      await tester.pump();

      final toggle = find.text('فعالسازی حالت بارداری');
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pump();

      expect(onboardingTriggered, isFalse);
      expect(rawToggleTriggered, isTrue);
    });

    testWidgets('calls onTogglePregnancyMode when deactivating active pregnancy mode', (tester) async {
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
          settings: {
            'cycle_pregnancy_mode': 'true',
            'preg_setup_done': 'true',
          },
          onTogglePregnancyMode: () => rawToggleTriggered = true,
          onOpenPregnancyOnboarding: () => onboardingTriggered = true,
        ),
      );
      await tester.pump();

      final toggle = find.text('بازگشت به حالت عادی چرخه قاعدگی');
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pump();

      expect(onboardingTriggered, isFalse);
      expect(rawToggleTriggered, isTrue);
    });
  });
}
