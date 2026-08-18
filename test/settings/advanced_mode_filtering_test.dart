import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/settings/presentation/settings_screen.dart';
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

  group('Advanced Mode Filtering Tests (SET-52)', () {
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
          await db.execute('''
            CREATE TABLE user_identities (
              id INTEGER PRIMARY KEY,
              name TEXT,
              title TEXT,
              avatarPath TEXT,
              gender TEXT,
              birthYear INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE routines (
              id INTEGER PRIMARY KEY,
              title TEXT,
              isArchived INTEGER DEFAULT 0
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

    testWidgets('Advanced setting is hidden when show_advanced_settings is false', (tester) async {
      final advancedDesc = SettingsRegistry.all.firstWhere(
        (d) => d.visibility == SettingVisibility.advanced,
        orElse: () => SettingsRegistry.all.first,
      );

      if (advancedDesc.visibility == SettingVisibility.advanced) {
        await SettingsService.instance.set('show_advanced_settings', false);

        await tester.pumpWidget(
          MaterialApp(
            theme: RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.light,
            ),
            home: Scaffold(
              body: SettingField(advancedDesc.key),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(advancedDesc.labelFa), findsNothing);

        // Turn advanced mode ON inside tester.runAsync
        await tester.runAsync(() async {
          await SettingsService.instance.set('show_advanced_settings', true);
        });
        await tester.pump();

        expect(find.text(advancedDesc.labelFa), findsOneWidget);
      }
    });

    testWidgets('Mode switcher in SettingsScreen toggles show_advanced_settings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: SettingsScreen(
            themeRepository: ThemeRepository(),
            localeRepository: LocaleRepository(),
            onFactoryReset: () async {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('mode_switch_simple')), findsOneWidget);
      expect(find.byKey(const ValueKey('mode_switch_advanced')), findsOneWidget);

      // Tap on 'حالت پیشرفته'
      await tester.tap(find.byKey(const ValueKey('mode_switch_advanced')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isTrue);

      // Tap back on 'حالت ساده'
      await tester.tap(find.byKey(const ValueKey('mode_switch_simple')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isFalse);
    });
  });
}
