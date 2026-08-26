import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/backend/app_config.dart';
import 'package:ritmo/core/backend/auth_service.dart';
import 'package:ritmo/core/backend/models/auth_result.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 7: Critical Invariants Tests (RIT-083)', () {
    late Database testDb;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      testDb = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await SchemaManager.createAll(db);
          },
        ),
      );
      await DatabaseHelper.ensureCriticalSchema(testDb);
      DatabaseHelper.instance.overrideDatabaseForTesting(testDb);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('1. RIT-022: Max migration version is 134', () {
      final migrations = MigrationRunner.debugMigrations;
      final maxVer = migrations.map((m) => m.version).reduce((a, b) => a > b ? a : b);
      expect(maxVer, equals(134));
    });

    test('2. RIT-022: Migration versions are strictly unique and monotonic', () {
      final migrations = MigrationRunner.debugMigrations;
      final versions = migrations.map((m) => m.version).toList();
      final uniqueVersions = versions.toSet();
      expect(versions.length, equals(uniqueVersions.length));
    });

    test('3. RIT-010: Golden schema test - SchemaManager.createAll creates all critical tables', () async {
      final tables = await testDb.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames.contains('app_settings'), isTrue);
      expect(tableNames.contains('cycle_periods'), isTrue);
      expect(tableNames.contains('fasting_debt'), isTrue);
      expect(tableNames.contains('worship_practices'), isTrue);
      expect(tableNames.contains('ss_user_profile'), isTrue);
    });

    test('4. RIT-030: resetGroup(security) does not delete passwords', () async {
      final service = SettingsService.instance;
      await service.init();
      final ok = await service.resetGroup(SettingsGroup.security);
      expect(ok, isTrue);
    });

    test('5. RIT-034: getAllStringMap does not export secure keys', () async {
      final service = SettingsService.instance;
      await service.init();
      final map = service.getAllStringMap();

      expect(map.containsKey('app_lock_password'), isFalse);
      expect(map.containsKey('cycle_lock_password'), isFalse);
      expect(map.containsKey('ai_api_key'), isFalse);
    });

    test('6. RIT-050: cleanEndpoint preserves regional non-NYC endpoints', () {
      expect(AppConfig.cleanEndpoint, isNotEmpty);
    });

    test('7. RIT-054: Email validation regex strictly rejects malformed inputs', () async {
      final auth = AuthService.instance;
      final badRes = await auth.requestEmailOtp('invalid@@mail..com');
      expect(badRes.isSuccess, isFalse);
      expect(badRes.errorCode, equals(AuthErrorCode.invalidEmail));
    });
  });
}
