import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/settings_inspector_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('Settings Inspector & Zero Secrets Tests (SET-70)', () {
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

      // Seed some test data
      await db.insert('app_settings', {
        'key': 'theme_mode',
        'value': 'dark',
        'updated_at': DateTime.now().toIso8601String(),
      });
      // Insert an orphan key
      await db.insert('app_settings', {
        'key': 'legacy_orphan_key_abc',
        'value': 'orphan_payload_value',
        'updated_at': DateTime.now().toIso8601String(),
      });

      SettingsService.instance.resetForTesting();
      await SettingsService.instance.init();
    });

    tearDown(() async {
      SettingsService.instance.cancelPendingSignals();
      await db.close();
    });

    test('safeDisplayValue and safeExportValue strictly redact secure keys', () {
      final secureDesc = SettingsRegistry.find('app_lock_password');
      expect(secureDesc, isNotNull);
      const secretPasswordValue = 'secretPass1234';

      final displayStr = SettingsInspectorScreen.safeDisplayValue(secureDesc, secretPasswordValue);
      final exportStr = SettingsInspectorScreen.safeExportValue(secureDesc, secretPasswordValue);

      // Must never contain the secret plaintext
      expect(displayStr.contains(secretPasswordValue), isFalse);
      expect(exportStr.contains(secretPasswordValue), isFalse);

      expect(displayStr, equals('[محرمانه - غیرقابل نمایش]'));
      expect(exportStr, equals('[REDACTED_SECRET]'));

      final aiDesc = SettingsRegistry.find('ai_api_key');
      expect(aiDesc, isNotNull);
      const apiKeyVal = 'sk-proj-xyz987654321';
      expect(SettingsInspectorScreen.safeDisplayValue(aiDesc, apiKeyVal), equals('[محرمانه - غیرقابل نمایش]'));
      expect(SettingsInspectorScreen.safeExportValue(aiDesc, apiKeyVal), equals('[REDACTED_SECRET]'));
    });

    test('safeDisplayValue formats regular values properly', () {
      final themeDesc = SettingsRegistry.find('theme_mode');
      final displayStr = SettingsInspectorScreen.safeDisplayValue(themeDesc, 'dark');
      final exportStr = SettingsInspectorScreen.safeExportValue(themeDesc, 'dark');

      expect(displayStr, equals('dark'));
      expect(exportStr, equals('dark'));
    });

    testWidgets('SettingsInspectorScreen mounts and renders all 4 sections in debug mode', (tester) async {
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Check Section 1: Service Status
      expect(find.text('وضعیت سلامت سرویس'), findsOneWidget);
      expect(find.text('وضعیت بارگذاری'), findsOneWidget);
      expect(find.text('آماده و لود شده ✅'), findsOneWidget);

      // Check Section 2: Orphan Rows
      expect(find.textContaining('ردیف‌های یتیم'), findsOneWidget);

      // Check Section 3: Unwritten keys
      expect(find.textContaining('کلیدهای نوشته‌نشده'), findsOneWidget);

      // Check Section 4: All database rows
      expect(find.textContaining('تمام ردیف‌های پایگاه داده'), findsOneWidget);
      expect(find.text('theme_mode'), findsWidgets);
    });

    testWidgets('SettingsInspectorScreen clipboard dump has zero secrets and valid JSON structure', (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
            return null;
          }
          return null;
        },
      );

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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap copy diagnostic button
      final copyBtn = find.byIcon(CupertinoIcons.doc_on_clipboard);
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(copiedText, isNotNull);
      final jsonMap = jsonDecode(copiedText!) as Map<String, dynamic>;

      expect(jsonMap['report'], equals('Ritmo Settings Diagnostic Dump'));
      expect(jsonMap['service_status']['load_state'], equals('loaded'));

      // Verify no PIN or secret text anywhere in the JSON dump
      expect(copiedText!.contains('secretPass1234'), isFalse);
    });
  });
}
