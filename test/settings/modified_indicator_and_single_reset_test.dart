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

  group('Modified Indicator and Single Reset Tests (SET-51)', () {
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

    test('isModifiedFromDefault and resetToDefault work accurately', () async {
      const key = 'auto_backup_enabled';
      final desc = SettingsRegistry.find(key)!;
      expect(desc.defaultValue, isFalse);

      expect(SettingsService.instance.isModifiedFromDefault(key), isFalse);

      await SettingsService.instance.set(key, true);
      expect(SettingsService.instance.isModifiedFromDefault(key), isTrue);

      final modified = SettingsService.instance.getModifiedKeys();
      expect(modified.contains(key), isTrue);

      await SettingsService.instance.resetToDefault(key);
      expect(SettingsService.instance.isModifiedFromDefault(key), isFalse);
      expect(SettingsService.instance.get<bool>(key), isFalse);
    });

    testWidgets('SettingField shows modified dot only when setting is modified from default', (tester) async {
      const key = 'auto_backup_enabled';

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SettingField(key),
          ),
        ),
      );
      await tester.pump();

      // At default, no modified dot
      expect(find.byKey(const ValueKey('setting_modified_dot')), findsNothing);

      // Modify the setting inside tester.runAsync
      await tester.runAsync(() async {
        await SettingsService.instance.set(key, true);
      });
      await tester.pump();

      // Now modified dot is visible
      expect(find.byKey(const ValueKey('setting_modified_dot')), findsOneWidget);

      // Reset back to default
      await tester.runAsync(() async {
        await SettingsService.instance.resetToDefault(key);
      });
      await tester.pump();

      expect(find.byKey(const ValueKey('setting_modified_dot')), findsNothing);
    });
  });
}
