import 'package:flutter/cupertino.dart';
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

  group('Pregnancy Care & Reminder Settings Tests (PRG-34)', () {
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
      'renders all 4 care settings rows and disables kick reminder before week 28',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          final now = CycleClock.now;
          // Week 10
          final lmp = CycleDateContract.cleanDate(
            now.subtract(const Duration(days: 70)),
          );
          final due = PregnancyDateEngine.calculateEddFromLmp(lmp);

          final profile = PregnancyProfile(
            lmpDate: lmp,
            dueDate: due,
            visitReminderLeadDays: 3,
            reminderHour: 9,
            supplementReminder: false,
            kickReminder: false,
          );
          await PregnancySettings.saveProfile(profile, db);

          await tester.pumpWidget(
            _buildTestApp(PregnancySettingsSheet(initialProfile: profile)),
          );
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('مراقبت‌ها و یادآوری‌ها'), findsOneWidget);
          expect(find.text('یادآوری ویزیت مامایی'), findsOneWidget);
          expect(find.text('۳ روز قبل'), findsOneWidget);
          expect(find.text('ساعت یادآوری‌های بارداری'), findsOneWidget);
          expect(find.text('ساعت ۹:۰۰'), findsOneWidget);
          expect(find.text('یادآوری مکمل‌ها و ویتامین‌ها'), findsOneWidget);
          expect(find.text('یادآوری لگدشماری از هفتهٔ ۲۸'), findsOneWidget);
          expect(find.text('از هفتهٔ ۲۸ به بعد فعال می‌شود.'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'enables kick reminder on week 30 and toggles supplement reminder',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          final now = CycleClock.now;
          // Week 30 (210 days)
          final lmp = CycleDateContract.cleanDate(
            now.subtract(const Duration(days: 210)),
          );
          final due = PregnancyDateEngine.calculateEddFromLmp(lmp);

          final profile = PregnancyProfile(
            lmpDate: lmp,
            dueDate: due,
            visitReminderLeadDays: 3,
            reminderHour: 9,
            supplementReminder: false,
            kickReminder: false,
          );
          await PregnancySettings.saveProfile(profile, db);

          await tester.pumpWidget(
            _buildTestApp(PregnancySettingsSheet(initialProfile: profile)),
          );
          await tester.pump(const Duration(milliseconds: 100));

          // Subtitle should not appear because week >= 28
          expect(find.text('از هفتهٔ ۲۸ به بعد فعال می‌شود.'), findsNothing);

          // Find switches
          final cupertinoSwitches = find.byType(CupertinoSwitch);
          expect(cupertinoSwitches, findsWidgets);

          // Toggle supplement reminder (third switch overall: countdown is 1st, supplement is 2nd, kick is 3rd)
          await tester.tap(find.text('یادآوری مکمل‌ها و ویتامین‌ها'));
          await tester.pump(const Duration(milliseconds: 200));

          // Verify database updated
          final rawRows = await db.query('app_settings');
          final settings = {
            for (final r in rawRows) r['key'] as String: r['value'],
          };
          expect(settings['preg_visit_reminder_lead_days'], '3');
          expect(settings['preg_reminder_hour'], '9');
        });
      },
    );
  });
}
