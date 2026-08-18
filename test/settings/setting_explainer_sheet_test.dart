import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_explainer_sheet.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_field_builder.dart';
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

  group('Inline Why? Explainer Tests (SET-59)', () {
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

    test('Key settings have whyExplanationFa populated', () {
      final keys = [
        'gentleness_level',
        'daily_capacity_minutes',
        'sleep_time',
        'wake_time',
        'notif_quiet_enabled',
        'ai_local_processing_only',
      ];

      for (final k in keys) {
        final desc = SettingsRegistry.find(k);
        expect(desc, isNotNull, reason: 'Key $k should exist in registry');
        expect(desc!.whyExplanationFa, isNotNull, reason: 'Key $k must have whyExplanationFa');
        expect(desc.whyExplanationFa!.isNotEmpty, isTrue);
      }
    });

    testWidgets('SettingField shows why icon and opens SettingExplainerSheet', (tester) async {
      const key = 'gentleness_level';
      final desc = SettingsRegistry.find(key)!;

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SettingField(key),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('setting_why_button')), findsOneWidget);

      // Render SettingExplainerSheet directly
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingExplainerSheet(descriptor: desc),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('چرا این تنظیم وجود دارد؟'), findsOneWidget);
      expect(find.text(desc.whyExplanationFa!), findsOneWidget);
      expect(find.byKey(const ValueKey('explainer_sheet_close_button')), findsOneWidget);
    });
  });
}
