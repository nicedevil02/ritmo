import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_settings_panel.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

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
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Section Hidden Tests (PRG-38)', () {
    late Database db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      final engine = CycleEngine();
      final registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'CycleScreen preserves pregnancy view even when preg_section_hidden is true',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          final now = CycleClock.now;
          final lmp = CycleDateContract.cleanDate(
            now.subtract(const Duration(days: 70)),
          );
          final due = PregnancyDateEngine.calculateEddFromLmp(lmp);

          final profile = PregnancyProfile(
            lmpDate: lmp,
            dueDate: due,
            sectionHidden: true,
          );
          await PregnancySettings.saveProfile(profile, db);
          await db.insert('app_settings', {
            'key': 'cycle_pregnancy_mode',
            'value': 'true',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          await db.insert('app_settings', {
            'key': 'preg_section_hidden',
            'value': 'true',
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          await tester.pumpWidget(_buildTestApp(const CycleScreen()));
          await tester.pump();
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 100));

          // CyclePregnancyModeView SHOULD be present inside Cycle module
          expect(find.byType(CyclePregnancyModeView), findsOneWidget);
        });
      },
    );

    testWidgets('CycleSettingsPanel shows unhide button and restores section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        bool reloaded = false;
        final settings = {
          'cycle_pregnancy_mode': 'true',
          'preg_section_hidden': 'true',
        };

        await tester.pumpWidget(
          _buildTestApp(
            CycleSettingsPanel(
              settings: settings,
              onDataReloadNeeded: () => reloaded = true,
              onOpenPasscodeSheet: () {},
              onTogglePregnancyMode: () {},
              onEditBaselineParameter: (k, t, min, max, d) async {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('نمایش مجدد بخش بارداری'), findsOneWidget);

        await tester.tap(find.text('نمایش مجدد بخش بارداری'));
        await tester.pump(const Duration(milliseconds: 300));
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));

        expect(reloaded, isTrue);

        final rawRows = await db.query('app_settings');
        final savedSettings = {
          for (final r in rawRows) r['key'] as String: r['value'],
        };
        expect(savedSettings['preg_section_hidden'], 'false');
      });
    });
  });
}
