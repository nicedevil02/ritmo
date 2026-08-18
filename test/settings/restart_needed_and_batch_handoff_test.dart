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

  group('Restart Needed & Batch Handoff Tests (SET-60)', () {
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

    test('theme_true_black and locale have requiresRestart set to true', () {
      final trueBlackDesc = SettingsRegistry.find('theme_true_black');
      final localeDesc = SettingsRegistry.find('locale');

      expect(trueBlackDesc?.requiresRestart, isTrue);
      expect(localeDesc?.requiresRestart, isTrue);
    });

    test('setBatch applies valid entries atomically and increments revision once', () async {
      final initialRevision = SettingsService.instance.revision.value;

      final count = await SettingsService.instance.setBatch({
        'theme_mode': 'dark',
        'theme_true_black': true,
        'daily_capacity_minutes': 360,
        'invalid_key_should_be_skipped': 'value',
      });

      expect(count, 3);
      expect(SettingsService.instance.revision.value, initialRevision + 1);
      expect(SettingsService.instance.get<String>('theme_mode'), 'dark');
      expect(SettingsService.instance.get<bool>('theme_true_black'), isTrue);
      expect(SettingsService.instance.get<int>('daily_capacity_minutes'), 360);

      expect(SettingsService.instance.hasPendingRestartSettings, isTrue);
      expect(SettingsService.instance.pendingRestartKeys.contains('theme_true_black'), isTrue);

      SettingsService.instance.markRestartHandled();
      expect(SettingsService.instance.hasPendingRestartSettings, isFalse);
    });

    testWidgets('SettingField renders restart needed chip when modified', (tester) async {
      await tester.runAsync(() async {
        await SettingsService.instance.set('theme_true_black', true);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SettingField('theme_true_black'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('setting_restart_needed_chip')), findsOneWidget);
      expect(find.text('نیاز به راه‌اندازی مجدد'), findsOneWidget);
    });
  });
}
