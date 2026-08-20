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

  group('Pregnancy Tone and Age Unit Tests (PRG-32)', () {
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

    testWidgets(
      'renders Section 2 rows and editing tone/unit/countdown saves to db',
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
            eddSource: PregnancyEddSource.lmp,
            tone: PregnancyTone.warm,
            ageUnit: PregnancyAgeUnit.weeks,
            showCountdown: true,
          );
          await PregnancySettings.saveProfile(profile, db);

          await tester.pumpWidget(
            _buildTestApp(PregnancySettingsSheet(initialProfile: profile)),
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('لحن و نمایش'), findsOneWidget);
          expect(find.text('لحن همراهی و متن‌ها'), findsOneWidget);
          expect(find.text('گرما و صمیمانه'), findsOneWidget);
          expect(find.text('نمایش شمارش معکوس تا زایمان'), findsOneWidget);
          expect(find.text('واحد نمایش سن بارداری'), findsOneWidget);
          expect(find.text('هفته و روز'), findsOneWidget);

          // Tap tone row to open tone picker
          await tester.tap(find.text('لحن همراهی و متن‌ها'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('انتخاب لحن همراهی'), findsOneWidget);
          expect(find.text('آرام و علمی'), findsOneWidget);

          // Select calm tone
          await tester.tap(find.text('آرام و علمی'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          // Verify database updated
          final rawRows = await db.query('app_settings');
          final settings = {
            for (final r in rawRows) r['key'] as String: r['value'],
          };
          expect(settings['preg_tone'], 'neutral');

          // Tap age unit row to open age unit picker
          await tester.tap(find.text('واحد نمایش سن بارداری'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('واحد نمایش سن بارداری'), findsWidgets);
          expect(find.text('ماه و هفته'), findsOneWidget);

          // Select month unit
          await tester.tap(find.text('ماه و هفته'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          final rawRows2 = await db.query('app_settings');
          final settings2 = {
            for (final r in rawRows2) r['key'] as String: r['value'],
          };
          expect(settings2['preg_age_unit'], 'months');
        });
      },
    );

    testWidgets('PregnancyHeader renders calm title when tone is calm', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = CycleClock.now;
      final lmp = CycleDateContract.cleanDate(
        now.subtract(const Duration(days: 70)),
      );

      await tester.pumpWidget(
        _buildTestApp(
          PregnancyHeader(
            currentWeek: 10,
            currentDayInWeek: 0,
            remainingDays: 210,
            pregTone: 'calm',
            eddSource: 'lmp',
            startDate: lmp,
            onShowPrivacy: () {},
            onShowSettings: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('بارداری شما'), findsOneWidget);
      expect(find.text('دوران شیرین بارداری 🎀'), findsNothing);
    });
  });
}
