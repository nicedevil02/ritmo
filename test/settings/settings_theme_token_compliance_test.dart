import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/day_timeline_preview.dart';
import 'package:ritmo/features/settings/presentation/widgets/identity_header.dart';
import 'package:ritmo/features/settings/presentation/widgets/quick_settings_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_health_card.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_tile.dart';
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

  group('Settings Theme Token Compliance Tests (SET-63)', () {
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

    for (final palette in RitmoPalette.all) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        testWidgets('Renders all settings widgets seamlessly on ${palette.nameFa} in $brightness mode', (tester) async {
          final themeData = RitmoTheme.build(
            palette: palette,
            brightness: brightness,
            trueBlack: brightness == Brightness.dark,
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: themeData,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        IdentityHeader(onTap: () {}),
                        const DayTimelinePreview(),
                        const SettingsHealthCard(),
                        SettingsSection(
                          title: 'بخش نمونه',
                          children: [
                            SettingsTile(
                              title: 'عنوان کاشی',
                              subtitle: 'زیرعنوان کاشی',
                              isModified: true,
                              requiresRestart: true,
                              onTap: () {},
                            ),
                          ],
                        ),
                        const QuickSettingsSheet(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('بخش نمونه'), findsOneWidget);
          expect(find.text('عنوان کاشی'), findsOneWidget);
          expect(find.text('نیاز به راه‌اندازی مجدد'), findsOneWidget);
        });
      }
    }
  });
}
