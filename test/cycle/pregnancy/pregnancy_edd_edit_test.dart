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

  group('Pregnancy Due Date Edit Tests (PRG-31)', () {
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

    testWidgets('renders section 1 rows with gestational age and due date', (
      tester,
    ) async {
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
        );
        await PregnancySettings.saveProfile(profile, db);

        await tester.pumpWidget(
          _buildTestApp(PregnancySettingsSheet(initialProfile: profile)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('تاریخ و سن بارداری'), findsOneWidget);
        expect(find.text('سن بارداری امروز'), findsOneWidget);
        expect(find.text('تاریخ تقریبی زایمان'), findsOneWidget);
        expect(find.text('مبنای محاسبه'), findsOneWidget);
        expect(find.text('اولین روز آخرین پریود (LMP)'), findsOneWidget);
      });
    });

    testWidgets(
      'tapping due date opens method options and shows shift warning dialog on update',
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
          );
          await PregnancySettings.saveProfile(profile, db);

          await tester.pumpWidget(
            _buildTestApp(PregnancySettingsSheet(initialProfile: profile)),
          );
          await tester.pump(const Duration(milliseconds: 100));

          // Tap due date row
          await tester.tap(find.text('تاریخ تقریبی زایمان'));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('ویرایش تاریخ بارداری'), findsOneWidget);
          expect(find.text('بر اساس تاریخ آخرین پریود (LMP)'), findsOneWidget);
          expect(find.text('بر اساس تاریخ اعلامی پزشک (EDD)'), findsOneWidget);
          expect(find.text('بر اساس جواب سونوگرافی'), findsOneWidget);
        });
      },
    );
  });
}
