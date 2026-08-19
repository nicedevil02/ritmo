import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/groups/notification_privacy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  late Directory tempDir;
  Database? db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notif_privacy_test_');

    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => tempDir.path,
    );

    try {
      databaseFactory = databaseFactoryFfi;
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
        },
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db!);
      await SettingsService.instance.init();
    } catch (_) {}
  });

  tearDown(() async {
    SettingsService.instance.cancelPendingSignals();
    SettingsService.instance.resetForTesting();
    if (db != null) {
      await db!.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Notification Privacy Screen Widget Tests', () {
    testWidgets('renders title, live preview card, segments, and switches live preview on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.darkTheme,
          home: const NotificationPrivacyScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify title
      expect(find.text('حریم خصوصی اعلان‌ها'), findsOneWidget);

      // 2. Verify Live Preview card header
      expect(find.text('پیش‌نمایش زنده روی صفحهٔ قفل'), findsOneWidget);

      // 3. Default mode is 'redacted', so preview shows redacted text
      expect(find.text('ریتمو: یک یادآوری داری 🌸'), findsOneWidget);

      // 4. Verify Biometric switch
      expect(find.text('قفل اثرانگشت برای صندوق محرمانه'), findsOneWidget);

      // 5. Tap on 'قفل‌شده' (locked) segment and verify live preview updates
      await tester.tap(find.text('قفل‌شده'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('ریتمو: یادآوری خصوصی 🔒'), findsOneWidget);

      // 6. Tap on 'عادی' (none) segment and verify live preview updates to plain text
      await tester.tap(find.text('عادی'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('یادآوری ریتمو 🌸'), findsOneWidget);
    });
  });
}
