import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/persian_text.dart';
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

  group('Persian Search Normalization Tests (SET-49)', () {
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

    test('normalizeFa handles Arabic characters, half-spaces, and diacritics', () {
      expect(normalizeFa('پشتيبان‌گيري'), 'پشتیبان گیری');
      expect(normalizeFa('پشتیبان گیری'), 'پشتیبان گیری');
      expect(normalizeFa('تنظيماتِ حِساب'), 'تنظیمات حساب');
    });

    testWidgets('Search matches Arabic Yeh, Latin keywords, and half-space variations', (tester) async {
      final delegate = SettingsSearchDelegate(
        themeRepository: ThemeRepository(),
        localeRepository: LocaleRepository(),
      );

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

      // 1. Arabic Yeh and zwnj: «پشتيبان‌گيري»
      delegate.query = 'پشتيبان‌گيري';
      await tester.pumpAndSettle();
      expect(find.text('پشتیبان‌گیری خودکار'), findsOneWidget);

      // 2. English keyword: «backup»
      delegate.query = 'backup';
      await tester.pumpAndSettle();
      expect(find.text('پشتیبان‌گیری خودکار'), findsOneWidget);

      // 3. Common Persian shorthand: «نوتیف»
      delegate.query = 'نوتیف';
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsWidgets);
    });
  });
}
