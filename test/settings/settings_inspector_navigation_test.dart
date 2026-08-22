import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/dev/presentation/persona_telemetry_screen.dart';
import 'package:ritmo/features/settings/presentation/settings_inspector_screen.dart';
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

  group('Settings Inspector Diagnostic Tools Integration Tests', () {
    late Database db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT,
              updatedAt INTEGER,
              updated_at TEXT
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

    testWidgets('Displays diagnostic tool tiles in SettingsInspectorScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: SettingsInspectorScreen(),
          ),
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('ابزارهای تشخیصی و مانیتورینگ'), findsOneWidget);
      expect(find.text('تله‌متری هوش مصنوعی و پرسوناها'), findsOneWidget);
      expect(find.text('ممیزی سلامت پایگاه داده (Data Health)'), findsOneWidget);
      expect(find.text('مدیریت قالب‌های برنامهٔ روزانه'), findsOneWidget);
    });

    testWidgets('Tapping Persona Telemetry navigates to PersonaTelemetryScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: SettingsInspectorScreen(),
          ),
        ),
      );
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final telemetryTile = find.text('تله‌متری هوش مصنوعی و پرسوناها');
      expect(telemetryTile, findsOneWidget);
      await tester.tap(telemetryTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PersonaTelemetryScreen), findsOneWidget);
    });
  });
}
