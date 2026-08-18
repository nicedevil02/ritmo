import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/ai_settings_guard.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/ai_write_history_sheet.dart';
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

  group('AI Settings Guard & Transparency Tests (SET-56)', () {
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
            CREATE TABLE ai_settings_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              setting_key TEXT NOT NULL,
              old_value TEXT,
              new_value TEXT,
              reason TEXT,
              timestamp INTEGER NOT NULL
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

    test('AiSettingsGuard respects permissions and forbidden list', () async {
      final aiWritableDesc = SettingsRegistry.all.firstWhere(
        (d) => d.aiWritable,
        orElse: () => SettingsRegistry.all.first,
      );

      // When master assistant permission is true
      await SettingsService.instance.set('assistant_can_modify_settings', true);
      expect(AiSettingsGuard.instance.canAiModify(aiWritableDesc.key), isTrue);

      // When forbidden key is set
      await SettingsService.instance.set('ai_forbidden_keys', aiWritableDesc.key);
      expect(AiSettingsGuard.instance.canAiModify(aiWritableDesc.key), isFalse);

      // Clear forbidden key, turn off assistant permission
      await SettingsService.instance.set('ai_forbidden_keys', '');
      await SettingsService.instance.set('assistant_can_modify_settings', false);
      expect(AiSettingsGuard.instance.canAiModify(aiWritableDesc.key), isFalse);
    });

    test('Record AI change and rollback restores previous value', () async {
      await SettingsService.instance.set('assistant_can_modify_settings', true);
      await SettingsService.instance.set('ai_forbidden_keys', '');
      await SettingsService.instance.set('notif_quiet_enabled', false);

      // Apply AI change
      final ok = await AiSettingsGuard.instance.recordAndApplyChange(
        key: 'notif_quiet_enabled',
        newValue: true,
        reasonFa: 'هماهنگی با ساعت خواب کاربر',
      );

      expect(ok, isTrue);
      expect(SettingsService.instance.get<bool>('notif_quiet_enabled'), isTrue);

      final history = await AiSettingsGuard.instance.getHistory();
      expect(history.length, equals(1));
      expect(history.first.key, equals('notif_quiet_enabled'));

      // Rollback
      final rolledBack = await AiSettingsGuard.instance.rollbackChange(history.first.id);
      expect(rolledBack, isTrue);
      expect(SettingsService.instance.get<bool>('notif_quiet_enabled'), isFalse);
    });

    testWidgets('AiWriteHistorySheet renders history items and supports rollback', (tester) async {
      await tester.runAsync(() async {
        await AiSettingsGuard.instance.recordAiChange(
          key: 'notif_quiet_enabled',
          oldValue: false,
          newValue: true,
          reason: 'بهینه‌سازی زمان سکوت شبانه',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: AiWriteHistorySheet(),
          ),
        ),
      );
      await tester.pump();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      expect(find.text('تاریخچه تغییرات دستیار هوشمند'), findsOneWidget);
      expect(find.text('بهینه‌سازی زمان سکوت شبانه'), findsOneWidget);
      expect(find.text('بازگردانی'), findsOneWidget);
    });
  });
}
