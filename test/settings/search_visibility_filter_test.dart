import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/settings/presentation/settings_search_delegate.dart';
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

  group('Search Visibility Filter Tests (SET-48)', () {
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

    testWidgets('Internal settings never appear in search results', (tester) async {
      final delegate = SettingsSearchDelegate(
        themeRepository: ThemeRepository(),
        localeRepository: LocaleRepository(),
      );

      // Find any internal setting in registry if exists
      final internalKeys = SettingsRegistry.all
          .where((d) => d.visibility == SettingVisibility.internal)
          .map((d) => d.labelFa)
          .toList();

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSearch(context: context, delegate: delegate),
                child: const Text('جست‌وجو'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('جست‌وجو'));
      await tester.pumpAndSettle();

      for (final label in internalKeys) {
        delegate.query = label;
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, label), findsNothing);
      }
    });

    testWidgets('Advanced settings are excluded when show_advanced_settings is false', (tester) async {
      final delegate = SettingsSearchDelegate(
        themeRepository: ThemeRepository(),
        localeRepository: LocaleRepository(),
      );

      expect(SettingsService.instance.get<bool>('show_advanced_settings'), isFalse);

      final advancedDesc = SettingsRegistry.all.firstWhere(
        (d) => d.visibility == SettingVisibility.advanced,
        orElse: () => SettingsRegistry.all.first,
      );

      if (advancedDesc.visibility == SettingVisibility.advanced) {
        await tester.pumpWidget(
          MaterialApp(
            theme: RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.light,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showSearch(context: context, delegate: delegate),
                  child: const Text('جست‌وجو'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('جست‌وجو'));
        await tester.pumpAndSettle();

        delegate.query = advancedDesc.labelFa;
        await tester.pumpAndSettle();

        expect(find.widgetWithText(ListTile, advancedDesc.labelFa), findsNothing);
      }
    });
  });
}
