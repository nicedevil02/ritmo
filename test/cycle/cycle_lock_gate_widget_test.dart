// C-09, C-43: Widget tests for CycleLockGate
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_lock_gate.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await DatabaseHelper.instance.database;
  });

  group('CycleLockGate Widget Tests (C-09, C-43)', () {
    late Database db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      db = await DatabaseHelper.instance.database;
      await CycleLockService.instance.clearPin(db);
    });

    tearDown(() async {
      await CycleLockService.instance.clearPin(db);
    });

    testWidgets('Renders child directly when lock is explicitly disabled', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await CycleLockService.instance.setLockEnabled(false, db);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
            home: const Scaffold(
              body: CycleLockGate(child: Text('PROTECTED_CYCLE_CONTENT')),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });

      expect(find.text('PROTECTED_CYCLE_CONTENT'), findsOneWidget);
    });

    testWidgets('Renders PIN gate keypad when PIN is set', (tester) async {
      await tester.runAsync(() async {
        await CycleLockService.instance.setPin('1234', db);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
            home: const Scaffold(
              body: CycleLockGate(child: Text('PROTECTED_CYCLE_CONTENT')),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      });

      expect(find.text('PROTECTED_CYCLE_CONTENT'), findsNothing);
      expect(find.text('این بخش خصوصی است'), findsOneWidget);
    });

    testWidgets('Unlocks and reveals child when valid PIN is entered', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await CycleLockService.instance.setPin('1234', db);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
            home: const Scaffold(
              body: CycleLockGate(child: Text('PROTECTED_CYCLE_CONTENT')),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        expect(find.text('PROTECTED_CYCLE_CONTENT'), findsNothing);

        for (final d in ['۱', '۲', '۳', '۴']) {
          final btn = find.widgetWithText(InkWell, d);
          expect(btn, findsOneWidget);
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      expect(find.text('PROTECTED_CYCLE_CONTENT'), findsOneWidget);
    });

    testWidgets('Shows error feedback when incorrect PIN is entered', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await CycleLockService.instance.setPin('1234', db);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
            home: const Scaffold(
              body: CycleLockGate(child: Text('PROTECTED_CYCLE_CONTENT')),
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        for (int i = 0; i < 4; i++) {
          final btn = find.widgetWithText(InkWell, '۹');
          expect(btn, findsOneWidget);
          await tester.tap(btn);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await Future.delayed(const Duration(milliseconds: 300));
        await tester.pump();
      });

      expect(find.text('PROTECTED_CYCLE_CONTENT'), findsNothing);
      expect(find.textContaining('رمز عبور نادرست است'), findsOneWidget);
    });
  });
}
