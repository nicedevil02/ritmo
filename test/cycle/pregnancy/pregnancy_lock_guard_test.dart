import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_lock_gate.dart';
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

  group('Pregnancy Lock Guard Tests (PRG-40)', () {
    late Database db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'PregnancyLockGate renders child directly when preg_lock_enabled is false',
      (tester) async {
        await tester.runAsync(() async {
          final settings = {'preg_lock_enabled': 'false'};

          await tester.pumpWidget(
            _buildTestApp(
              PregnancyLockGate(
                settings: settings,
                child: const Text('محتوای محافظت‌شده بارداری'),
              ),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();

          expect(find.text('محتوای محافظت‌شده بارداری'), findsOneWidget);
          expect(find.text('بخش بارداری قفل است'), findsNothing);
        });
      },
    );

    testWidgets(
      'PregnancyLockGate blocks child and shows lock screen when preg_lock_enabled is true',
      (tester) async {
        await tester.runAsync(() async {
          final settings = {'preg_lock_enabled': 'true'};

          await tester.pumpWidget(
            _buildTestApp(
              PregnancyLockGate(
                settings: settings,
                child: const Text('محتوای محافظت‌شده بارداری'),
              ),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          await tester.pump();

          expect(find.text('محتوای محافظت‌شده بارداری'), findsNothing);
          expect(find.text('حریم خصوصی بارداری'), findsOneWidget);
        });
      },
    );

    testWidgets('Entering PIN unlocks PregnancyLockGate and reveals child', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await CycleLockService.instance.setPin('1234', db);
        final settings = {'preg_lock_enabled': 'true'};

        await tester.pumpWidget(
          _buildTestApp(
            PregnancyLockGate(
              settings: settings,
              child: const Text('محتوای محافظت‌شده بارداری'),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('محتوای محافظت‌شده بارداری'), findsNothing);
        expect(find.text('بخش بارداری قفل است'), findsOneWidget);

        // Tap 1, 2, 3, 4
        for (final d in ['۱', '۲', '۳', '۴']) {
          final btn = find.widgetWithText(InkWell, d);
          expect(btn, findsOneWidget);
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        expect(find.text('محتوای محافظت‌شده بارداری'), findsOneWidget);
      });
    });
  });
}
