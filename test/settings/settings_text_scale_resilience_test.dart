import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/identity_header.dart';
import 'package:ritmo/features/settings/presentation/widgets/quick_settings_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_field_builder.dart';
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

  group('Text Scale & Layout Resilience Tests (SET-65)', () {
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

    final scales = [1.0, 1.3, 1.5, 1.6];
    final screenWidths = [320.0, 390.0, 414.0];

    for (final scale in scales) {
      for (final width in screenWidths) {
        testWidgets('Layout does not overflow at textScale $scale on width ${width}px', (tester) async {
          final recordedErrors = <FlutterErrorDetails>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            recordedErrors.add(details);
          };

          try {
            await tester.binding.setSurfaceSize(Size(width, 1000));

            await tester.pumpWidget(
              MaterialApp(
                theme: RitmoTheme.build(
                  palette: RitmoPalette.jadeNoir,
                  brightness: Brightness.light,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1000),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Scaffold(
                      body: SingleChildScrollView(
                        child: Column(
                          children: [
                            IdentityHeader(onTap: () {}),
                            SettingsSection(
                              title: 'بخش تست پایداری چیدمان با متن طولانی',
                              children: [
                                SettingsTile(
                                  title: 'عنوان بسیار طولانی و جامع برای بررسی شکست خطوط در مقیاس‌های بزرگ متنی',
                                  subtitle: 'توضیحات و زیرعنوان کاملاً مفصل برای حصول اطمینان از عدم سرریز پیکسلی',
                                  isModified: true,
                                  requiresRestart: true,
                                  onTap: () {},
                                ),
                                SettingField('gentleness_level'),
                                SettingField('notif_quiet_enabled'),
                                SettingField('daily_capacity_minutes'),
                              ],
                            ),
                            const QuickSettingsSheet(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));

            // Verify no RenderFlex overflows
            final overflowErrors = recordedErrors.where((e) => e.toString().contains('overflowed'));
            expect(overflowErrors, isEmpty, reason: 'RenderFlex overflow occurred at scale $scale, width $width');
          } finally {
            FlutterError.onError = originalOnError;
            await tester.binding.setSurfaceSize(null);
          }
        });
      }
    }
  });
}
