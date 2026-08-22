import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/package_info_plus'),
      (call) async => <String, dynamic>{
        'appName': 'Ritmo',
        'packageName': 'com.ritmo.app',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
  });

  group('AppMode and SettingsMode Synchronization Tests', () {
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
      await AppModeService.instance.load();
    });

    tearDown(() async {
      SettingsService.instance.cancelPendingSignals();
      await db.close();
    });

    test('AppModeService.set(AppMode.simple) automatically sets show_advanced_settings to false', () async {
      // First enable advanced settings
      await SettingsService.instance.set('show_advanced_settings', true);
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isTrue);

      // Now switch AppMode to simple
      await AppModeService.instance.set(AppMode.simple);

      // Verify that AppMode is simple and show_advanced_settings is false
      expect(AppModeService.instance.isSimple, isTrue);
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isFalse);
    });

    test('SettingsService.set(app_mode, simple) automatically sets show_advanced_settings to false', () async {
      // First enable advanced settings
      await SettingsService.instance.set('show_advanced_settings', true);
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isTrue);

      // Now set app_mode to simple via SettingsService
      await SettingsService.instance.set('app_mode', 'simple');

      // Verify that show_advanced_settings was set to false
      expect(SettingsService.instance.get<String>('app_mode'), 'simple');
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isFalse);
    });

    test('AppModeService.set(AppMode.full) automatically sets show_advanced_settings to true', () async {
      // First set to simple
      await AppModeService.instance.set(AppMode.simple);
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isFalse);

      // Now switch to full
      await AppModeService.instance.set(AppMode.full);
      expect(AppModeService.instance.isSimple, isFalse);
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isTrue);
    });

    test('SettingsService.set(app_mode, full) automatically sets show_advanced_settings to true', () async {
      // First set to simple
      await SettingsService.instance.set('app_mode', 'simple');
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isFalse);

      // Now set to full
      await SettingsService.instance.set('app_mode', 'full');
      expect(SettingsService.instance.get<String>('app_mode'), 'full');
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isTrue);
    });

    test('SettingsService.set(show_advanced_settings, false) syncs app_mode to simple', () async {
      await SettingsService.instance.set('show_advanced_settings', true);
      expect(SettingsService.instance.get<String>('app_mode'), 'full');

      await SettingsService.instance.set('show_advanced_settings', false);
      expect(SettingsService.instance.get<String>('app_mode'), 'simple');
    });

    test('SettingsService.init with app_mode=simple in DB sets show_advanced_settings to false', () async {
      // Setup DB with app_mode=simple and show_advanced_settings=true
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('app_settings', {'key': 'app_mode', 'value': 'simple', 'updatedAt': now});
      await db.insert('app_settings', {'key': 'show_advanced_settings', 'value': 'true', 'updatedAt': now});

      // Reset and re-init SettingsService
      SettingsService.instance.resetForTesting();
      await SettingsService.instance.init();

      // Verify show_advanced_settings was initialized to false because app_mode is simple
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isFalse);
    });

    test('SettingsService.init with app_mode=full in DB sets show_advanced_settings to true', () async {
      // Setup DB with app_mode=full and show_advanced_settings=false
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('app_settings', {'key': 'app_mode', 'value': 'full', 'updatedAt': now});
      await db.insert('app_settings', {'key': 'show_advanced_settings', 'value': 'false', 'updatedAt': now});

      // Reset and re-init SettingsService
      SettingsService.instance.resetForTesting();
      await SettingsService.instance.init();

      // Verify show_advanced_settings was initialized to true because app_mode is full
      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isTrue);
    });
  });
}
