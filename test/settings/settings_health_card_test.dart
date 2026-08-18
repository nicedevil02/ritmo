import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_health_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_health_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('Settings Health Card & Diagnostic Tests (SET-53)', () {
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER
            )
          ''');
        },
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      SettingsService.instance.resetForTesting();
      await SettingsService.instance.init();
    });

    tearDown(() async {
      SettingsService.instance.cancelPendingSignals();
      await db.close();
    });

    test('SettingsHealthService detects conflicts and fixes them', () async {
      // Create conflict: biometric on, app lock off
      await SettingsService.instance.set('app_lock_enabled', false);
      await SettingsService.instance.set('app_biometric_enabled', true);

      final issues = SettingsHealthService.instance.inspect();
      expect(issues.any((i) => i.id == 'biometric_without_app_lock'), isTrue);

      await SettingsHealthService.instance.fixAll();

      final issuesAfter = SettingsHealthService.instance.inspect();
      expect(issuesAfter.any((i) => i.id == 'biometric_without_app_lock'), isFalse);
      expect(SettingsService.instance.get<bool>('app_lock_enabled'), isTrue);
    });

    testWidgets('SettingsHealthCard renders when issues exist and hides after autofix', (tester) async {
      // In default state, no conflict
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: SettingsHealthCard(),
          ),
        ),
      );
      await tester.pump();

      // Initially no health card
      expect(find.byKey(const ValueKey('settings_health_card')), findsNothing);

      // Introduce conflict inside tester.runAsync
      await tester.runAsync(() async {
        await SettingsService.instance.set('app_lock_enabled', false);
        await SettingsService.instance.set('app_biometric_enabled', true);
      });
      await tester.pump();

      // Card is now rendered
      expect(find.byKey(const ValueKey('settings_health_card')), findsOneWidget);
      expect(find.text('اصلاح خودکار'), findsOneWidget);

      // Tap autofix button inside tester.runAsync
      await tester.tap(find.byKey(const ValueKey('health_card_autofix_button')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      // Card disappears after issues are fixed
      expect(find.byKey(const ValueKey('settings_health_card')), findsNothing);
    });
  });
}
