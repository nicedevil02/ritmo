import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/quick_settings_sheet.dart';
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

  group('Quick Settings Sheet Tests (SET-57)', () {
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

    testWidgets('QuickSettingsSheet renders all 6 quick controls and toggles them', (tester) async {
      await SettingsService.instance.set('notif_quiet_enabled', false);
      await SettingsService.instance.set('theme_mode', 'light');

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: QuickSettingsSheet(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('تنظیمات سریع'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_quiet_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_persistent_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_theme_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_oled_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_biometric_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_haptic_tile')), findsOneWidget);

      // Tap quiet tile inside tester.runAsync
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('quick_quiet_tile')));
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(SettingsService.instance.get<bool>('notif_quiet_enabled'), isTrue);

      // Tap theme tile inside tester.runAsync
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('quick_theme_tile')));
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(SettingsService.instance.get<String>('theme_mode'), equals('dark'));
    });
  });
}
