import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/profile/presentation/crash_reports_screen.dart';
import 'package:ritmo/features/settings/presentation/settings_screen.dart';
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

  group('Debug Affordances & Easter Egg Hardening Tests (SET-68)', () {
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
            CREATE TABLE routines (
              id INTEGER PRIMARY KEY,
              isArchived INTEGER
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

    testWidgets('Version tap counter resets after 2 second pause', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));

      try {
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
        await tester.pump(const Duration(milliseconds: 50));

        final versionFinder = find.textContaining('ریتمو — سبک زندگی');
        expect(versionFinder, findsOneWidget);

        // Tap 3 times
        for (int i = 0; i < 3; i++) {
          await tester.tap(versionFinder);
          await tester.pump(const Duration(milliseconds: 100));
        }

        // No crash screen yet
        expect(find.byType(CrashReportsScreen), findsNothing);

        // Wait 2.5 seconds (exceeding 2s reset window)
        await tester.pump(const Duration(milliseconds: 2500));

        // Tap 4 more times (total 7 if not reset, but reset makes it 4)
        for (int i = 0; i < 4; i++) {
          await tester.tap(versionFinder);
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Should still NOT open CrashReportsScreen because counter reset
        expect(find.byType(CrashReportsScreen), findsNothing);

        // Tap 3 more times without pause to complete 7 taps (4 + 3 = 7)
        for (int i = 0; i < 3; i++) {
          await tester.tap(versionFinder);
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Now CrashReportsScreen is opened
        expect(find.byType(CrashReportsScreen), findsOneWidget);
      } finally {
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('Debug seed button is not in SettingsScreen widget tree', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));

      try {
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
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.textContaining('تولید ۷ شب لاگ خواب'), findsNothing);
      } finally {
        await tester.binding.setSurfaceSize(null);
      }
    });
  });
}
