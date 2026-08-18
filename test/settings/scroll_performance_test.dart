import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/settings/presentation/settings_screen.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';
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

  group('Scroll Performance and Layout Tests (SET-45)', () {
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

    testWidgets('SettingsSection uses Column instead of shrinkWrap ListView', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: SettingsSection(
              title: 'تست بخش',
              children: [
                Text('ردیف ۱'),
                Text('ردیف ۲'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsNothing);
      expect(find.text('تست بخش'), findsOneWidget);
      expect(find.text('ردیف ۱'), findsOneWidget);
      expect(find.text('ردیف ۲'), findsOneWidget);
    });

    testWidgets('SettingsScreen does not contain nested shrinkWrap ListViews', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: SettingsScreen(
            themeRepository: ThemeRepository(),
            localeRepository: LocaleRepository(),
            onFactoryReset: () {},
          ),
        ),
      );
      await tester.pump();

      // No nested ListView inside SettingsScreen
      expect(find.byType(ListView), findsNothing);
      expect(find.text('دسته‌بندی‌های تنظیمات'), findsOneWidget);
    });
  });
}
