import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/danger_zone.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_field_builder.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_degraded_banner.dart';
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

  group('Degraded Mode Tests (SET-42)', () {
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          // Intentionally do NOT create app_settings table to force degraded init
        },
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      // Init will catch error and enter degraded state
      await SettingsService.instance.init();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: RitmoTheme.build(
          palette: RitmoPalette.jadeNoir,
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('Degraded mode displays SettingsDegradedBanner', (tester) async {
      expect(SettingsService.instance.isDegraded, isTrue);

      await tester.pumpWidget(
        createTestWidget(
          Column(
            children: [
              const SettingsDegradedBanner(),
              SettingField('calendar_show_tasks'),
              DangerZone(onFactoryReset: () {}),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner is visible with warning and retry button
      expect(find.byType(SettingsDegradedBanner), findsOneWidget);
      expect(find.text('خطا در بارگذاری تنظیمات'), findsOneWidget);
      expect(find.text('تلاش مجدد'), findsOneWidget);

      // DangerZone is completely hidden in degraded mode
      expect(find.text('منطقهٔ خطر'), findsNothing);
      expect(find.text('بازنشانی کارخانه‌ای — پاک کردن همهٔ داده‌ها'), findsNothing);
    });
  });
}
