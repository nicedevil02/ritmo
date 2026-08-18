import 'package:flutter/cupertino.dart';
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

  group('SettingField Tests for all SettingTypes', () {
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

    testWidgets('Renders Boolean SettingField correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const SettingField('module_today_routines')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsTile), findsOneWidget);
      expect(find.byType(CupertinoSwitch), findsOneWidget);
      expect(find.text('امروز و روتین‌ها'), findsOneWidget);
    });

    testWidgets('Renders Enumeration SettingField correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const SettingField('theme_mode')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsTile), findsOneWidget);
      expect(find.text('حالت روشنایی تم'), findsOneWidget);
    });

    testWidgets('Renders Integer SettingField correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const SettingField('snooze_minutes')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsTile), findsOneWidget);
      expect(find.text('زمان تعویق پیش‌فرض (دقیقه)'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.minus_circle), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.plus_circle), findsOneWidget);
    });

    testWidgets('Renders Text SettingField correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const SettingField('user_name')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsTile), findsOneWidget);
      expect(find.text('نام و نام خانوادگی'), findsOneWidget);
    });

    testWidgets('Renders Time SettingField correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(const SettingField('notif_quiet_start')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsTile), findsOneWidget);
      expect(find.text('شروع ساعات سکوت'), findsOneWidget);
    });
  });
}
