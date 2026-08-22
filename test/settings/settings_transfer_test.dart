import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/settings/settings_transfer_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_import_diff_dialog.dart';
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

  group('Settings Transfer (Export & Import Diff) Tests (SET-55)', () {
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

    test('Export settings produces valid schema JSON', () {
      final jsonStr = SettingsTransferService.instance.exportSettingsJson();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map.containsKey('schemaVersion'), isTrue);
      expect(map.containsKey('exportedAt'), isTrue);
      expect(map.containsKey('settings'), isTrue);

      final settings = map['settings'] as Map<String, dynamic>;
      expect(settings.containsKey('notif_master_enabled'), isTrue);
    });

    test('Analyze import identifies changed and unchanged keys', () async {
      await SettingsService.instance.set('notif_master_enabled', true);
      await SettingsService.instance.set('snooze_minutes', 10);

      final importJson = jsonEncode({
        'schemaVersion': 1,
        'exportedAt': '2026-08-18T10:00:00Z',
        'settings': {
          'notif_master_enabled': true, // unchanged
          'snooze_minutes': 25, // changed
          'unknown_legacy_key': 123, // ignored
        },
      });

      final diff = SettingsTransferService.instance.analyzeImport(importJson);

      expect(diff.changed.any((c) => c.key == 'snooze_minutes' && c.newValue == 25), isTrue);
      expect(diff.unchanged.any((u) => u.key == 'notif_master_enabled'), isTrue);
      expect(diff.ignoredKeys.contains('unknown_legacy_key'), isTrue);

      // Apply import
      final applied = await SettingsTransferService.instance.applyImport(diff);
      expect(applied, equals(1));
      expect(SettingsService.instance.get<int>('snooze_minutes'), equals(25));
    });

    testWidgets('SettingsImportDiffDialog renders diff items and applies selection', (tester) async {
      await tester.runAsync(() async {
        await SettingsService.instance.set('snooze_minutes', 10);
      });

      const diff = SettingsDiffPreview(
        schemaVersion: 1,
        exportedAt: '2026-08-18T10:00:00Z',
        changed: [
          SettingDiffItem(
            key: 'snooze_minutes',
            labelFa: 'زمان تعویق پیش‌فرض',
            currentValue: 10,
            newValue: 20,
          ),
        ],
        unchanged: [],
        ignoredKeys: [],
        rawSettings: {'snooze_minutes': 20},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: SettingsImportDiffDialog(diff: diff),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('پیش‌نمای واردسازی تنظیمات'), findsOneWidget);
      expect(find.text('زمان تعویق پیش‌فرض'), findsOneWidget);

      // Tap confirm button inside tester.runAsync
      await tester.tap(find.byKey(const ValueKey('confirm_import_button')));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(SettingsService.instance.get<int>('snooze_minutes'), equals(20));
    });
  });
}
