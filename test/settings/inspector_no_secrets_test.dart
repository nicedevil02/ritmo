import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/settings_inspector_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('app_settings');
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

  tearDown(() {
    SettingsService.instance.cancelPendingSignals();
  });

  group('Settings Inspector & Zero Secrets Tests (SET-70)', () {
    test('safeDisplayValue and safeExportValue strictly redact secure keys', () {
      final secureDesc = SettingsRegistry.find('user_pin');
      const secretPinValue = '1234';

      final displayStr = SettingsInspectorScreen.safeDisplayValue(secureDesc, secretPinValue);
      final exportStr = SettingsInspectorScreen.safeExportValue(secureDesc, secretPinValue);

      // Must never contain the secret plaintext
      expect(displayStr.contains(secretPinValue), isFalse);
      expect(exportStr.contains(secretPinValue), isFalse);

      expect(displayStr, equals('[محرمانه - غیرقابل نمایش]'));
      expect(exportStr, equals('[REDACTED_SECRET]'));
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
          theme: ThemeData(extensions: [RitmoTheme.light]),
          home: const SettingsInspectorScreen(),
        ),
      );

      await tester.pumpAndSettle();

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
        (MethodCall methodCall) async {
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
          theme: ThemeData(extensions: [RitmoTheme.light]),
          home: const SettingsInspectorScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap copy diagnostic button
      final copyBtn = find.byIcon(CupertinoIcons.doc_on_clipboard);
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      expect(copiedText, isNotNull);
      final jsonMap = jsonDecode(copiedText!) as Map<String, dynamic>;

      expect(jsonMap['report'], equals('Ritmo Settings Diagnostic Dump'));
      expect(jsonMap['service_status']['load_state'], equals('loaded'));

      // Verify no PIN or secret text anywhere in the JSON dump
      expect(copiedText!.contains('1234'), isFalse);
    });
  });
}
