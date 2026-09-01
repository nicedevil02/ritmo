import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_settings.dart';
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

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updatedAt INTEGER
          );
        ''');
      },
    );
    DatabaseHelper.databaseInstance = db;
    SettingsService.instance.resetForTesting();
    RitmoOrbSettings.instance.debugReset();
  });

  tearDown(() async {
    await db.close();
  });

  group('ثبت کلیدهای حباب در SettingsRegistry', () {
    test('هر سه کلید در رجیستری با مشخصات صحیح ثبت شده‌اند', () {
      final descEnabled = SettingsRegistry.find('orb_enabled');
      expect(descEnabled, isNotNull);
      expect(descEnabled!.type, SettingType.boolean);
      expect(descEnabled.defaultValue, true);
      expect(descEnabled.scope, SettingScope.db);
      expect(descEnabled.group, SettingsGroup.assistant);
      expect(descEnabled.aiWritable, true);
      expect(descEnabled.searchTerms, containsAll(<String>['حباب', 'تیله', 'دستیار']));

      final descDock = SettingsRegistry.find('orb_dock_when_typing');
      expect(descDock, isNotNull);
      expect(descDock!.type, SettingType.boolean);
      expect(descDock.defaultValue, true);
      expect(descDock.scope, SettingScope.db);
      expect(descDock.group, SettingsGroup.assistant);
      expect(descDock.dependsOn?.key, 'orb_enabled');
      expect(descDock.aiWritable, true);
      expect(descDock.searchTerms, containsAll(<String>['حباب', 'کیبرد', 'لنگر']));

      final descEyes = SettingsRegistry.find('orb_eyes_enabled');
      expect(descEyes, isNotNull);
      expect(descEyes!.type, SettingType.boolean);
      expect(descEyes.defaultValue, true);
      expect(descEyes.scope, SettingScope.db);
      expect(descEyes.group, SettingsGroup.assistant);
      expect(descEyes.dependsOn?.key, 'orb_enabled');
      expect(descEyes.aiWritable, true);
      expect(descEyes.searchTerms, containsAll(<String>['حباب', 'چشم', 'پلک']));
    });
  });

  group('همگام‌سازی دوطرفه بین SettingsService و RitmoOrbSettings', () {
    test('تغییر از مسیر SettingsService بلافاصله ValueNotifier را به‌روز می‌کند', () async {
      await SettingsService.instance.init();
      await RitmoOrbSettings.instance.load();

      expect(RitmoOrbSettings.instance.enabled.value, true);
      expect(RitmoOrbSettings.instance.dockWhenTyping.value, true);
      expect(RitmoOrbSettings.instance.eyes.value, true);

      // تغییر از طریق SettingsService
      await SettingsService.instance.set('orb_enabled', false);
      expect(RitmoOrbSettings.instance.enabled.value, false);

      await SettingsService.instance.set('orb_dock_when_typing', false);
      expect(RitmoOrbSettings.instance.dockWhenTyping.value, false);

      await SettingsService.instance.set('orb_eyes_enabled', false);
      expect(RitmoOrbSettings.instance.eyes.value, false);
    });

    test('تغییر از مسیر RitmoOrbSettings بلافاصله ValueNotifier و SettingsService را به‌روز می‌کند', () async {
      await SettingsService.instance.init();
      await RitmoOrbSettings.instance.load();

      // تغییر از طریق RitmoOrbSettings API
      await RitmoOrbSettings.instance.setEnabled(false);
      expect(RitmoOrbSettings.instance.enabled.value, false);
      expect(SettingsService.instance.get<bool>('orb_enabled'), false);

      await RitmoOrbSettings.instance.setDockWhenTyping(false);
      expect(RitmoOrbSettings.instance.dockWhenTyping.value, false);
      expect(SettingsService.instance.get<bool>('orb_dock_when_typing'), false);

      await RitmoOrbSettings.instance.setEyes(false);
      expect(RitmoOrbSettings.instance.eyes.value, false);
      expect(SettingsService.instance.get<bool>('orb_eyes_enabled'), false);
    });
  });

  group('مهاجرت آرام از SharedPreferences به دیتابیس', () {
    test('کلیدهای قدیمی SharedPreferences هنگام راه‌اندازی اولیه به دیتابیس منتقل می‌شوند', () async {
      SharedPreferences.setMockInitialValues({
        'orb_enabled': false,
        'orb_dock_when_typing': false,
        'orb_eyes_enabled': false,
      });

      // هنگام راه‌اندازی، متد _migrateSharedPreferencesToDb اجرا می‌شود
      await SettingsService.instance.init();
      await RitmoOrbSettings.instance.load();

      expect(SettingsService.instance.get<bool>('orb_enabled'), false);
      expect(SettingsService.instance.get<bool>('orb_dock_when_typing'), false);
      expect(SettingsService.instance.get<bool>('orb_eyes_enabled'), false);

      expect(RitmoOrbSettings.instance.enabled.value, false);
      expect(RitmoOrbSettings.instance.dockWhenTyping.value, false);
      expect(RitmoOrbSettings.instance.eyes.value, false);
    });
  });
}
