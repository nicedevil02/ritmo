import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/platform/alarm_platform.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

class MockAlarmPlatform implements AlarmPlatform {
  @override
  Future<bool> scheduleExactAlarm({
    required String id,
    required int timeMsUTC,
    required String title,
    required bool isEssential,
  }) async => true;

  @override
  Future<bool> cancelAlarm(String id) async => true;

  @override
  Future<bool> checkExactAlarmPermission() async => true;

  @override
  Future<bool> requestExactAlarmPermission() async => true;

  @override
  Future<bool> scheduleSilentTick({
    required String id,
    required int timeMsUTC,
  }) async => true;
}

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
    await CycleLockService.instance.setLockEnabled(false, db);
    await CycleLockService.instance.clearPin(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_reminders (
        id TEXT PRIMARY KEY,
        routineId TEXT,
        timeMsUTC INTEGER,
        title TEXT,
        isEssential INTEGER,
        state TEXT,
        createdAt INTEGER,
        updatedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alarm_delivery_log (
        id TEXT PRIMARY KEY,
        reminderId TEXT,
        routineId TEXT,
        expectedAt INTEGER,
        firedAt INTEGER,
        status TEXT,
        driftMs INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inbox_items (
        id TEXT PRIMARY KEY,
        category TEXT,
        sourceSystem TEXT,
        title TEXT,
        body TEXT,
        priority INTEGER,
        linkModule TEXT,
        linkEntityId TEXT,
        linkAction TEXT,
        payloadJson TEXT,
        status TEXT,
        createdAt INTEGER,
        expiresAt INTEGER,
        dedupeKey TEXT
      )
    ''');

    engine = CycleEngine();
    registry = EngineRegistry()..register(engine);
    RitmoEngineBus.init(registry);

    if (sl.isRegistered<AlarmPlatform>()) {
      sl.unregister<AlarmPlatform>();
    }
    sl.registerSingleton<AlarmPlatform>(MockAlarmPlatform());

    // Set pregnancy active without dates (broken state)
    await PregnancySettings.setPregnancyActive(true, db: db);
  });

  tearDown(() async {
    if (sl.isRegistered<AlarmPlatform>()) {
      sl.unregister<AlarmPlatform>();
    }
    await db.close();
  });

  group('Incomplete Pregnancy Repair Flow Tests (PRG-17)', () {
    testWidgets(
      'incomplete warning button opens PregnancyOnboardingShell and repairs state',
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
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Dismiss migration dialog if shown
          if (find.text('بعداً').evaluate().isNotEmpty) {
            await tester.tap(find.text('بعداً'));
            await Future.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // 1. Verify incomplete warning card is visible
          expect(find.text('اطلاعات بارداری ناقص است'), findsOneWidget);
          final completeCta = find.text('تکمیل راه‌اندازی بارداری');
          expect(completeCta, findsOneWidget);

          // 2. Tap CTA to open PregnancyOnboardingShell
          await tester.tap(completeCta);
          for (var i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 30));
            await tester.pump(const Duration(milliseconds: 50));
          }

          expect(find.byType(PregnancyOnboardingShell), findsOneWidget);

          // 3. Step 0 -> Step 1
          final nextBtn = find.widgetWithText(ElevatedButton, 'مرحله بعد');
          expect(nextBtn, findsOneWidget);
          await tester.tap(nextBtn);
          for (var i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Step 1: Tap LMP method to set initial valid dates
          final lmpMethod = find.text('اولین روز آخرین پریودم را می‌دانم');
          expect(lmpMethod, findsOneWidget);
          await tester.tap(lmpMethod);
          for (var i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Step 1 -> Step 2
          await tester.tap(find.widgetWithText(ElevatedButton, 'مرحله بعد'));
          for (var i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Step 2 -> Step 3
          await tester.tap(find.widgetWithText(ElevatedButton, 'مرحله بعد'));
          for (var i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Step 3 -> Step 4
          await tester.tap(find.widgetWithText(ElevatedButton, 'مرحله بعد'));
          for (var i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Step 4: Tap 'فعال‌سازی حالت بارداری'
          final saveBtn = find.widgetWithText(
            ElevatedButton,
            'فعال‌سازی حالت بارداری',
          );
          expect(saveBtn, findsOneWidget);
          await tester.tap(saveBtn);
          for (var i = 0; i < 30; i++) {
            await Future.delayed(const Duration(milliseconds: 50));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // 4. Verify settings in database are now repaired and usable
          final rows = await db.query('app_settings');
          final map = {for (final r in rows) r['key'] as String: r['value']};
          expect(PregnancySettings.isPregnancyUsable(map), isTrue);
          expect(PregnancySettings.isSetupDone(map), isTrue);
        });
      },
    );
  });
}
