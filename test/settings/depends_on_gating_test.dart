import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_field_builder.dart';
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

  group('Dependency Gating Tests (SET-44)', () {
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

    test('Registry contains all required dependency declarations', () {
      final quietStart = SettingsRegistry.find('notif_quiet_start');
      expect(quietStart?.dependsOn?.key, 'notif_quiet_enabled');

      final aiApiKey = SettingsRegistry.find('ai_api_key');
      expect(aiApiKey?.dependsOn?.key, 'ai_mode');
      expect(aiApiKey?.dependsOn?.expectedValue, 'personal_key');

      final aiModel = SettingsRegistry.find('ai_model');
      expect(aiModel?.dependsOn?.key, 'ai_mode');
      expect(aiModel?.dependsOn?.expectedValue, 'personal_key');

      final autoBackupFreq = SettingsRegistry.find('backup_frequency_days');
      expect(autoBackupFreq?.dependsOn?.key, 'auto_backup_enabled');

      final appBiometric = SettingsRegistry.find('app_biometric_enabled');
      expect(appBiometric?.dependsOn?.key, 'app_lock_enabled');

      final cycleBiometric = SettingsRegistry.find('cycle_biometric_enabled');
      expect(cycleBiometric?.dependsOn?.key, 'module_cycle_enabled');

      final cycleLock = SettingsRegistry.find('cycle_lock_password');
      expect(cycleLock?.dependsOn?.key, 'module_cycle_enabled');
    });

    testWidgets('Disabled dependency renders hint in SettingField', (tester) async {
      await tester.runAsync(() async {
        await SettingsService.instance.setChecked('notif_master_enabled', false);
        SettingsService.instance.cancelPendingSignals();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SettingField('notif_quiet_start'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('نیاز به روشن بودن'), findsWidgets);
    });
  });
}
