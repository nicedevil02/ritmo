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
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_contract.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildCycleScreenApp() {
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

  group('Baseline Parameter Editor Tests (PRG-29)', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await CycleLockService.instance.setLockEnabled(false, db);
      await CycleLockService.instance.clearPin(db);

      await db.execute('''
        CREATE TABLE IF NOT EXISTS alarm_delivery_log (
          id TEXT PRIMARY KEY,
          channel TEXT,
          scheduledAt INTEGER,
          title TEXT,
          body TEXT
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_reminders (
          id TEXT PRIMARY KEY,
          routineId TEXT,
          state TEXT,
          scheduledTime INTEGER,
          updatedAt INTEGER
        );
      ''');

      // Insert a closed period so CycleScreen shows dashboard
      final now = CycleClock.now;
      final pStart = CycleDateContract.cleanDate(
        now.subtract(const Duration(days: 20)),
      );
      final pEnd = CycleDateContract.cleanDate(
        now.subtract(const Duration(days: 15)),
      );
      await db.insert(CyclePeriodContract.table, {
        CyclePeriodContract.colId: 'seed_period',
        CyclePeriodContract.colStartDate: CycleDateContract.toDayKey(pStart),
        CyclePeriodContract.colEndDate: CycleDateContract.toDayKey(pEnd),
        CyclePeriodContract.colFlowIntensity: 'MEDIUM',
        CyclePeriodContract.colIsPredicted: 0,
        CyclePeriodContract.colCreatedAt: CycleClock.nowMillisecondsSinceEpoch,
        CyclePeriodContract.colUpdatedAt: CycleClock.nowMillisecondsSinceEpoch,
      });

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'editing cycle_avg_length updates database and dual-writes aliases',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.runAsync(() async {
          await tester.pumpWidget(_buildCycleScreenApp());
          for (var i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 30));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Open settings panel
          final settingsBtn = find.byIcon(CupertinoIcons.gear_alt);
          expect(settingsBtn, findsOneWidget);
          await tester.tap(settingsBtn);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          // Tap on average cycle length row
          final lengthRow = find.text('متوسط طول چرخه (فاصله شروع دو پریود)');
          expect(lengthRow, findsOneWidget);
          await tester.ensureVisible(lengthRow);
          await tester.tap(lengthRow);
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));

          // Verify picker modal opened with title
          expect(find.text('طول کل چرخه بدنی'), findsOneWidget);

          // Tap plus icon to increment from 28 to 29
          final plusIconFinder = find.byIcon(CupertinoIcons.plus_circle_fill);
          if (plusIconFinder.evaluate().isNotEmpty) {
            await tester.tap(plusIconFinder.first);
            await tester.pump(const Duration(milliseconds: 100));
          }

          // Tap 'تأیید و ذخیره'
          final saveBtn = find.widgetWithText(ElevatedButton, 'تأیید و ذخیره');
          expect(saveBtn, findsOneWidget);
          await tester.ensureVisible(saveBtn);
          await tester.tap(saveBtn);
          for (var i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 30));
            await tester.pump(const Duration(milliseconds: 100));
          }

          // Verify database updated
          final rawSettings = await db.query('app_settings');
          final settings = {
            for (final row in rawSettings) row['key'] as String: row['value'],
          };

          expect(settings['cycle_avg_length'], isNotNull);
          expect(settings['user_cycle_length'], isNotNull);
        });
      },
    );
  });
}
