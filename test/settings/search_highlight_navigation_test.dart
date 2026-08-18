import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/features/settings/presentation/groups/appearance_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/assistant_privacy_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/calendar_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/data_backup_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/identity_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/modules_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/notifications_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/security_group_screen.dart';
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

  group('Search Highlight Navigation Tests (SET-46)', () {
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

    test('All 8 group screens accept highlightKey without throwing', () {
      expect(() => const IdentityGroupScreen(highlightKey: 'user_name'), returnsNormally);
      expect(() => const ModulesGroupScreen(highlightKey: 'module_calendar_enabled'), returnsNormally);
      expect(() => const NotificationsGroupScreen(highlightKey: 'notif_master_enabled'), returnsNormally);
      expect(
        () => AppearanceGroupScreen(
          themeRepository: ThemeRepository(),
          localeRepository: LocaleRepository(),
          highlightKey: 'app_theme',
        ),
        returnsNormally,
      );
      expect(() => const AssistantPrivacyGroupScreen(highlightKey: 'ai_mode'), returnsNormally);
      expect(() => const DataBackupGroupScreen(highlightKey: 'auto_backup_enabled'), returnsNormally);
      expect(() => const SecurityGroupScreen(highlightKey: 'app_lock_enabled'), returnsNormally);
      expect(() => const CalendarGroupScreen(highlightKey: 'calendar_show_tasks'), returnsNormally);
    });

    testWidgets('SettingField with highlight=true mounts and animates smoothly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 200),
                  SettingField('calendar_show_tasks', highlight: true),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text('نمایش کارها در تقویم'), findsOneWidget);
    });
  });
}
