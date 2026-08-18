import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
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
      await db.close();
    });

    testWidgets('Toggling notif_master_enabled immediately gates child notification settings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SettingField('notif_master_enabled'),
                  SettingField('notif_quiet_start'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially notif_master_enabled is true
      expect(SettingsService.instance.get<bool>('notif_master_enabled'), isTrue);

      // Now turn off notif_master_enabled
      await SettingsService.instance.setChecked('notif_master_enabled', false);
      await tester.pumpAndSettle();

      // notif_quiet_start now displays dependency requirement hint
      expect(find.textContaining('نیاز به روشن بودن'), findsWidgets);
    });
  });
}
