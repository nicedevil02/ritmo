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

  group('Search Context Safety Tests (SET-47)', () {
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

    testWidgets('SearchDelegate returns selected descriptor without navigating itself', (tester) async {
      final delegate = SettingsSearchDelegate(
        themeRepository: ThemeRepository(),
        localeRepository: LocaleRepository(),
      );

      SettingDescriptor? result;
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
                  result = await showSearch<SettingDescriptor?>(
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

      // Enter search query
      delegate.query = 'تقویم';
      await tester.pumpAndSettle();

      // Tap first result
      final firstResult = find.byType(ListTile).first;
      expect(firstResult, findsOneWidget);

      await tester.tap(firstResult);
      await tester.pumpAndSettle();

      // Ensure search closed and returned non-null descriptor safely
      expect(result, isNotNull);
      expect(result!.group, isNotNull);
    });
  });
}
