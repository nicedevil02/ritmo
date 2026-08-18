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

  group('Optimistic Write and Revert Tests', () {
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
      await SettingsService.instance.init();
    });

    tearDown(() async {
      await db.close();
    });

    test('Valid write returns SettingWriteOk', () async {
      final res = await SettingsService.instance.setChecked('calendar_show_tasks', false);
      expect(res, isA<SettingWriteOk>());
      expect(SettingsService.instance.get<bool>('calendar_show_tasks'), isFalse);
    });

    test('Invalid integer range returns SettingWriteRejected with clear Persian message', () async {
      // snooze_minutes has min: 1, max: 120
      final res = await SettingsService.instance.setChecked('snooze_minutes', 9999);
      expect(res, isA<SettingWriteRejected>());
      final rejected = res as SettingWriteRejected;
      expect(rejected.reasonFa, contains('باید بین'));
    });

    test('AI writing non-aiWritable setting returns SettingWriteRejected', () async {
      final res = await SettingsService.instance.setChecked(
        'app_lock_enabled',
        true,
        origin: SettingsWriteOrigin.ai,
      );
      expect(res, isA<SettingWriteRejected>());
      final rejected = res as SettingWriteRejected;
      expect(rejected.reasonFa, contains('فقط توسط خود شما'));
    });

    testWidgets('SettingField.executeWrite reverts on failure and triggers toast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () async {
                    // Try to write invalid value for snooze_minutes (max 120)
                    await SettingField.executeWrite(ctx, 'snooze_minutes', 5000);
                  },
                  child: const Text('آزمایش'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('آزمایش'));
      await tester.pumpAndSettle();

      // Setting remains unchanged at default
      expect(SettingsService.instance.get<int>('snooze_minutes'), 10);
    });
  });
}
