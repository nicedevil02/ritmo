import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/privacy_summary_card.dart';
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

  group('Privacy Summary & Audit Card Tests (SET-58)', () {
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

    test('calculateScore calculates accurate percentage', () async {
      // Default: app_lock=false, screen_security=false, ai_local=false, assistant_can_modify=true, purge=30
      // Purge=30 gives 25
      expect(PrivacySummaryCard.calculateScore(), equals(25));

      await SettingsService.instance.set('app_lock_enabled', true);
      expect(PrivacySummaryCard.calculateScore(), equals(50));

      await SettingsService.instance.set('screen_security_enabled', true);
      expect(PrivacySummaryCard.calculateScore(), equals(75));

      await SettingsService.instance.set('ai_local_processing_only', true);
      expect(PrivacySummaryCard.calculateScore(), equals(100));
    });

    test('applyMaxPrivacy sets all security settings and achieves 100% score', () async {
      await SettingsService.instance.set('app_lock_enabled', false);
      await SettingsService.instance.set('app_biometric_enabled', false);
      await SettingsService.instance.set('screen_security_enabled', false);
      await SettingsService.instance.set('ai_local_processing_only', false);
      await SettingsService.instance.set('assistant_can_modify_settings', true);
      await SettingsService.instance.set('ai_auto_purge_days', 0);

      expect(PrivacySummaryCard.calculateScore(), equals(0));

      await PrivacySummaryCard.applyMaxPrivacy();

      expect(PrivacySummaryCard.calculateScore(), equals(100));
      expect(SettingsService.instance.get<bool>('app_lock_enabled'), isTrue);
      expect(SettingsService.instance.get<bool>('screen_security_enabled'), isTrue);
      expect(SettingsService.instance.get<bool>('ai_local_processing_only'), isTrue);
      expect(SettingsService.instance.get<int>('ai_auto_purge_days'), equals(14));
    });

    testWidgets('PrivacySummaryCard renders score and max privacy button', (tester) async {
      await tester.runAsync(() async {
        await SettingsService.instance.set('app_lock_enabled', false);
        await SettingsService.instance.set('app_biometric_enabled', false);
        await SettingsService.instance.set('screen_security_enabled', false);
        await SettingsService.instance.set('ai_local_processing_only', false);
        await SettingsService.instance.set('assistant_can_modify_settings', true);
        await SettingsService.instance.set('ai_auto_purge_days', 0);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: PrivacySummaryCard(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('privacy_summary_card')), findsOneWidget);
      expect(find.text('نیاز به توجه'), findsOneWidget);
      expect(find.byKey(const ValueKey('max_privacy_button')), findsOneWidget);

      // Trigger max privacy in runAsync
      await tester.runAsync(() async {
        await PrivacySummaryCard.applyMaxPrivacy();
      });
      await tester.pump();

      expect(find.text('حفاظت عالی'), findsOneWidget);
      expect(find.text('۱۰۰٪'), findsOneWidget);
    });
  });
}
