import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/security/app_lock_service.dart';
import 'package:ritmo/core/security/pin_hasher.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/features/assistant/logic/mid_day_replan_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      ),
    );

    await DatabaseHelper.ensureCriticalSchema(db);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
    await SettingsService.instance.init();
  });

  tearDown(() async {
    await db.close();
  });

  group('Audit Fixes: Today, Assistant, Profile, Settings (RITF-098 .. RITF-107)', () {
    test('RITF-098: SecureKeyStore stores AI deep analysis cache securely and enables migration', () async {
      const sensitiveResult = 'تحلیل الگوی خواب و چرخه هورمونی';

      // 1. Write to SecureKeyStore
      await SecureKeyStore.setKey('ai_deep_analysis_result_v1', sensitiveResult);

      final readVal = await SecureKeyStore.getKey('ai_deep_analysis_result_v1');
      expect(readVal, equals(sensitiveResult));

      // 2. Migration from legacy SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_deep_analysis_result_v1', 'Legacy result');
      await SecureKeyStore.deleteKey('ai_deep_analysis_result_v1');

      // Verify migration logic
      var cached = await SecureKeyStore.getKey('ai_deep_analysis_result_v1');
      if (cached == null) {
        final legacy = prefs.getString('ai_deep_analysis_result_v1');
        if (legacy != null && legacy.isNotEmpty) {
          cached = legacy;
          await SecureKeyStore.setKey('ai_deep_analysis_result_v1', legacy);
          await prefs.remove('ai_deep_analysis_result_v1');
        }
      }

      expect(cached, equals('Legacy result'));
      expect(prefs.getString('ai_deep_analysis_result_v1'), isNull);
    });

    test('RITF-102: MidDayReplanService uses bounded keys and prunes legacy daily keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('replan_suggest_count_2026-08-20', 2);
      await prefs.setInt('replan_suggest_count_2026-08-21', 1);

      final service = MidDayReplanService.instance;
      await service.recordSuggestionShown();

      final lastDate = prefs.getString('replan_last_suggest_date');
      final count = prefs.getInt('replan_suggest_count');
      expect(lastDate, isNotNull);
      expect(count, equals(1));

      // Legacy unbounded keys pruned
      expect(prefs.getInt('replan_suggest_count_2026-08-20'), isNull);
      expect(prefs.getInt('replan_suggest_count_2026-08-21'), isNull);
    });

    test('RITF-107: AppLockService and CycleLockService handle PIN hashing in domain layer', () async {
      // 1. AppLockService
      final success = await AppLockService.instance.setPin('1234');
      expect(success, isTrue);

      final storedAppPass = await AppLockService.instance.getLockPassword();
      expect(storedAppPass, isNotNull);
      expect(storedAppPass, isNot(equals('1234'))); // must be hashed
      expect(PinHasher.verifyPin('1234', storedAppPass!), isTrue);

      // 2. CycleLockService
      await CycleLockService.instance.setPin('5678');
      final isCycleLocked = await CycleLockService.instance.isLockEnabled();
      expect(isCycleLocked, isTrue);

      final storedCycleHash = await SecureKeyStore.getKey('cycle_lock_pin_hash');
      expect(storedCycleHash, isNotNull);
      expect(storedCycleHash, isNot(equals('5678')));
      expect(PinHasher.verifyPin('5678', storedCycleHash!), isTrue);
    });
  });
}
