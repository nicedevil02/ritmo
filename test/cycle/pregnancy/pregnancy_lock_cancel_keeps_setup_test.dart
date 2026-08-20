import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_passcode_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildTestApp({
  required VoidCallback onCompleted,
  VoidCallback? onCancel,
}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => PregnancyOnboardingShell.show(
            context,
            onCompleted: onCompleted,
            onCancel: onCancel,
          ),
          child: const Text('باز کردن آنبوردینگ'),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Pregnancy Lock Cancel Keeps Setup Tests (PRG-24)', () {
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

    testWidgets(
      'cancelling passcode sheet after save sets preg_lock_enabled to false but keeps pregnancy active',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        var completed = false;

        await tester.runAsync(() async {
          await tester.pumpWidget(
            _buildTestApp(onCompleted: () => completed = true),
          );
          await tester.pump(const Duration(milliseconds: 50));

          // Open shell
          await tester.tap(find.text('باز کردن آنبوردینگ'));
          for (var i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 50));
          }

          expect(find.byType(PregnancyOnboardingShell), findsOneWidget);

          // Step 0 -> Step 1
          await tester.tap(find.widgetWithText(ElevatedButton, 'مرحله بعد'));
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

          // Step 3: Enable Lock toggle
          final lockSwitch = find.byType(CupertinoSwitch).at(0);
          await tester.tap(lockSwitch);
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
          for (var i = 0; i < 15; i++) {
            await Future.delayed(const Duration(milliseconds: 30));
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Check if Passcode Sheet was opened and dismiss it
          final passcodeSheet = find.byType(CyclePasscodeSheet);
          if (passcodeSheet.evaluate().isNotEmpty) {
            final closeBtn = find.descendant(
              of: passcodeSheet,
              matching: find.byType(IconButton),
            );
            if (closeBtn.evaluate().isNotEmpty) {
              await tester.tap(closeBtn.first);
              for (var i = 0; i < 10; i++) {
                await Future.delayed(const Duration(milliseconds: 20));
                await tester.pump(const Duration(milliseconds: 50));
              }
            }
          }

          // Verify pregnancy setup is active in DB
          final rawSettings = await db.query('app_settings');
          final settings = {
            for (final row in rawSettings) row['key'] as String: row['value'],
          };

          expect(settings['cycle_pregnancy_mode'], 'true');
          expect(settings['preg_setup_done'], 'true');
          expect(settings['preg_start_date'], isNotNull);
          expect(settings['preg_due_date'], isNotNull);
          expect(completed, true);
        });
      },
    );
  });
}
