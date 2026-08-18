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
import 'package:ritmo/features/settings/presentation/groups/notification_privacy_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/notifications_group_screen.dart';
import 'package:ritmo/features/settings/presentation/groups/security_group_screen.dart';
import 'package:ritmo/features/settings/presentation/settings_screen.dart';
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

  group('Lifecycle and Dispose Tests (SET-66)', () {
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
            CREATE TABLE routines (
              id INTEGER PRIMARY KEY,
              isArchived INTEGER
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

    final screens = <String, Widget Function()>{
      'SettingsScreen': () => SettingsScreen(
            themeRepository: ThemeRepository(),
            localeRepository: LocaleRepository(),
            onFactoryReset: () {},
          ),
      'AppearanceGroupScreen': () => AppearanceGroupScreen(
            themeRepository: ThemeRepository(),
            localeRepository: LocaleRepository(),
          ),
      'AssistantPrivacyGroupScreen': () => const AssistantPrivacyGroupScreen(),
      'CalendarGroupScreen': () => const CalendarGroupScreen(),
      'DataBackupGroupScreen': () => const DataBackupGroupScreen(),
      'IdentityGroupScreen': () => const IdentityGroupScreen(),
      'ModulesGroupScreen': () => const ModulesGroupScreen(),
      'NotificationPrivacyScreen': () => const NotificationPrivacyScreen(),
      'NotificationsGroupScreen': () => const NotificationsGroupScreen(),
      'SecurityGroupScreen': () => const SecurityGroupScreen(),
    };

    for (final entry in screens.entries) {
      testWidgets('Mounts and cleanly disposes ${entry.key}', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.light,
            ),
            home: entry.value(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Unmount cleanly by replacing with a placeholder
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      });
    }
  });
}
