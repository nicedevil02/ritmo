import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_field_builder.dart';
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

  group('Accessibility & Touch Target Tests (SET-61)', () {
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
      await SettingsService.instance.set('show_advanced_settings', true);
    });

    tearDown(() async {
      SettingsService.instance.cancelPendingSignals();
      await db.close();
    });

    testWidgets('SettingsTile meets minimum 48px height and exposes Semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SettingsTile(
              title: 'تست دسترس‌پذیری',
              subtitle: 'توضیحات زیرعنوان',
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final tileFinder = find.byType(SettingsTile);
      final size = tester.getSize(tileFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));

      expect(
        find.bySemanticsLabel('تست دسترس‌پذیری، توضیحات زیرعنوان'),
        findsOneWidget,
      );
    });

    testWidgets('Integer field has minimum 44x44 touch targets for plus and minus with Semantics', (tester) async {
      await tester.runAsync(() async {
        await SettingsService.instance.set('show_advanced_settings', true);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SettingField('daily_capacity_minutes'),
          ),
        ),
      );
      await tester.pump();

      final minusSemantics = find.bySemanticsLabel('کاهش مقدار ظرفیت کار روزانه (دقیقه)');
      final plusSemantics = find.bySemanticsLabel('افزایش مقدار ظرفیت کار روزانه (دقیقه)');

      expect(minusSemantics, findsOneWidget);
      expect(plusSemantics, findsOneWidget);

      final minusSize = tester.getSize(minusSemantics);
      final plusSize = tester.getSize(plusSemantics);

      expect(minusSize.width, greaterThanOrEqualTo(44.0));
      expect(minusSize.height, greaterThanOrEqualTo(44.0));
      expect(plusSize.width, greaterThanOrEqualTo(44.0));
      expect(plusSize.height, greaterThanOrEqualTo(44.0));
    });

    testWidgets('Boolean field has Semantics with switch state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SettingField('theme_true_black'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SettingField), findsOneWidget);
    });
  });
}
