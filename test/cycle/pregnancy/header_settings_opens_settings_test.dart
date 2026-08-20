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
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_header.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart';
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

  group('Header Settings and Danger Zone Tests (PRG-37)', () {
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

    testWidgets('PregnancyHeader onShowSettings callback fires on settings tap', (tester) async {
      bool settingsOpened = false;

      await tester.pumpWidget(
        _buildTestApp(
          PregnancyHeader(
            currentWeek: 20,
            currentDayInWeek: 3,
            remainingDays: 140,
            pregTone: 'warm',
            eddSource: 'lmp',
            startDate: DateTime(2026, 1, 1),
            onShowPrivacy: () {},
            onShowSettings: () => settingsOpened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final settingsBtn = find.byTooltip('تنظیمات و گزینه‌ها');
      expect(settingsBtn, findsOneWidget);

      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      expect(settingsOpened, isTrue);
    });

    testWidgets('PregnancySettingsSheet Section 6 provides exit with confirmation', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        bool exitCalled = false;

        final now = CycleClock.now;
        final lmp = CycleDateContract.cleanDate(now.subtract(const Duration(days: 70)));
        final due = PregnancyDateEngine.calculateEddFromLmp(lmp);

        final profile = PregnancyProfile(lmpDate: lmp, dueDate: due);
        await PregnancySettings.saveProfile(profile, db);
        await db.insert('app_settings', {
          'key': 'cycle_pregnancy_mode',
          'value': 'true',
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await tester.pumpWidget(
          _buildTestApp(
            PregnancySettingsSheet(
              initialProfile: profile,
              onExitPregnancy: () => exitCalled = true,
              onEndPregnancy: () {},
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('ناحیهٔ خطر'), findsOneWidget);
        expect(find.text('خروج از حالت بارداری'), findsOneWidget);
        expect(find.text('پایان دوره بارداری'), findsOneWidget);

        // Tap on exit pregnancy
        await tester.tap(find.text('خروج از حالت بارداری'));
        await tester.pump(const Duration(milliseconds: 300));

        // Confirm dialog appears
        expect(find.text('آیا مطمئن هستید که می‌خواهید حالت بارداری را غیرفعال کنید و به چرخهٔ عادی بازگردید؟'), findsOneWidget);
        expect(find.text('بله، بازگشت به چرخه'), findsOneWidget);

        // Confirm
        await tester.tap(find.text('بله، بازگشت به چرخه'));
        await tester.pump(const Duration(milliseconds: 300));
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));

        expect(exitCalled, isTrue);

        // Check app_settings
        final rawRows = await db.query('app_settings');
        final settings = {for (final r in rawRows) r['key'] as String: r['value']};
        expect(settings['cycle_pregnancy_mode'], 'false');
      });
    });

    testWidgets('PregnancySettingsSheet Section 6 triggers onEndPregnancy', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool endCalled = false;

      final now = CycleClock.now;
      final lmp = CycleDateContract.cleanDate(now.subtract(const Duration(days: 70)));
      final due = PregnancyDateEngine.calculateEddFromLmp(lmp);

      final profile = PregnancyProfile(lmpDate: lmp, dueDate: due);

      await tester.pumpWidget(
        _buildTestApp(
          PregnancySettingsSheet(
            initialProfile: profile,
            onEndPregnancy: () => endCalled = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('پایان دوره بارداری'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(endCalled, isTrue);
    });
  });
}
