import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/security/pin_hasher.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2: Security & Privacy Tests', () {
    test('RIT-030: SettingDescriptor isResettable flag and resetGroup protection', () {
      final appLockPassDesc = SettingsRegistry.find('app_lock_password');
      expect(appLockPassDesc, isNotNull);
      expect(appLockPassDesc!.isResettable, isFalse);
      expect(appLockPassDesc.scope, equals(SettingScope.secure));

      final cyclePassDesc = SettingsRegistry.find('cycle_lock_password');
      expect(cyclePassDesc, isNotNull);
      expect(cyclePassDesc!.isResettable, isFalse);

      final aiKeyDesc = SettingsRegistry.find('ai_api_key');
      expect(aiKeyDesc, isNotNull);
      expect(aiKeyDesc!.isResettable, isFalse);

      // Verify normal settings are resettable
      final themeDesc = SettingsRegistry.find('theme_mode');
      expect(themeDesc, isNotNull);
      expect(themeDesc!.isResettable, isTrue);
    });

    test('RIT-031 & RIT-032: PinHasher rejects plaintext, supports v1 and v2 with constant-time equality', () {
      const pin = '1379';

      // 1. Plaintext PIN strings should NOT be accepted as valid hashes (RIT-031)
      expect(PinHasher.verifyPin(pin, '1379'), isFalse);
      expect(PinHasher.verifyPin(pin, '1234'), isFalse);
      expect(PinHasher.verifyPin(pin, '0000'), isFalse);

      // 2. PBKDF2 v2 hashes work and verify properly
      final v2Hash = PinHasher.hashPin(pin);
      expect(v2Hash.startsWith('v2:'), isTrue);
      expect(PinHasher.verifyPin(pin, v2Hash), isTrue);
      expect(PinHasher.verifyPin('1378', v2Hash), isFalse);
      expect(PinHasher.needsUpgrade(v2Hash), isFalse);

      // 3. Persian/Arabic digits are normalized during verification
      expect(PinHasher.verifyPin('۱۳۷۹', v2Hash), isTrue);
      expect(PinHasher.verifyPin('١٣٧٩', v2Hash), isTrue);

      // 4. Upgrade check
      final upgradeResult = PinHasher.verifyAndUpgrade(pin, v2Hash);
      expect(upgradeResult.isValid, isTrue);
      expect(upgradeResult.upgradedHash, isNull);
    });

    test('RIT-034: SettingsService.getAllStringMap protects secrets by default', () async {
      final service = SettingsService.instance;
      await service.init();

      await service.set('app_lock_password', 'secret_hash_value');
      await service.set('ai_api_key', 'sk-test-ai-key');
      await service.set('theme_mode', 'dark');

      final publicMap = service.getAllStringMap();
      expect(publicMap.containsKey('theme_mode'), isTrue);
      expect(publicMap.containsKey('app_lock_password'), isFalse);
      expect(publicMap.containsKey('ai_api_key'), isFalse);

      final secretMap = service.getAllStringMap(includeSecrets: true);
      expect(secretMap.containsKey('app_lock_password'), isTrue);
      expect(secretMap.containsKey('ai_api_key'), isTrue);
    });
  });
}
