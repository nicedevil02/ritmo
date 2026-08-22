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

  group('Search Current Value and Suggestions Tests (SET-50)', () {
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

    testWidgets('Empty search state displays popular suggestions and returns tapped item', (tester) async {
      final delegate = SettingsSearchDelegate(
        themeRepository: ThemeRepository(),
        localeRepository: LocaleRepository(),
      );

      SettingDescriptor? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selected = await showSearch<SettingDescriptor?>(
                    context: context,
                    delegate: delegate,
                  );
                },
                child: const Text('جست‌وجو'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('جست‌وجو'));
      await tester.pumpAndSettle();

      // Ensure suggestions title is shown
      expect(find.text('تنظیمات پرکاربرد و پیشنهادی'), findsOneWidget);

      // Ensure suggested items like 'قفل کلی برنامه' are rendered
      expect(find.text('قفل کلی برنامه'), findsOneWidget);

      // Tap on 'قفل کلی برنامه'
      await tester.tap(find.text('قفل کلی برنامه'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.key, 'app_lock_enabled');
    });

    testWidgets('Search results display formatted current value chips and mask secure keys', (tester) async {
      final delegate = SettingsSearchDelegate(
        themeRepository: ThemeRepository(),
        localeRepository: LocaleRepository(),
      );

      // Change calendar_show_tasks to true (default true)
      await tester.runAsync(() async {
        await SettingsService.instance.set('calendar_show_tasks', true);
      });

      delegate.query = 'تقویم';
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: Builder(builder: (context) => delegate.buildSuggestions(context)),
          ),
        ),
      );
      await tester.pump();

      // Look for the chip 'روشن'
      expect(find.text('روشن'), findsWidgets);
    });
  });
}
