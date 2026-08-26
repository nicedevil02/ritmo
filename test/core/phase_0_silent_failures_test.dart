import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/security/app_lock_service.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Phase 0 — Silent Failures & Error Resilience (RIT-001..RIT-006)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, v) async {
            await SchemaManager.createAll(db);
          },
        ),
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      SettingsService.instance.resetForTesting();
    });

    tearDown(() async {
      await db.close();
      SettingsService.instance.resetForTesting();
      DatabaseHelper.clearWarmupHooks();
    });

    test('RIT-001: App lock invariant auto-disables lock when password is empty', () async {
      // Seed app_lock_enabled = true in db without any password
      await db.insert('app_settings', {
        'key': 'app_lock_enabled',
        'value': 'true',
        'updatedAt': 1000,
      });

      await SettingsService.instance.init();

      // Invariant should have auto-disabled it to prevent user from being locked out
      expect(SettingsService.instance.get<bool>('app_lock_enabled'), isFalse);
    });

    test('RIT-001: App lock invariant preserves lock check in AppLockService', () async {
      await db.insert('app_settings', {
        'key': 'app_lock_enabled',
        'value': 'true',
        'updatedAt': 1000,
      });
      final isEnabled = await AppLockService.instance.isLockEnabled();
      expect(isEnabled, isFalse); // Because password was empty
    });

    test('RIT-002: Degraded state is flagged when init fails', () async {
      final invalidDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      await invalidDb.close(); // Closed DB will cause init error

      DatabaseHelper.instance.overrideDatabaseForTesting(invalidDb);
      await SettingsService.instance.init();

      expect(SettingsService.instance.isDegraded, isTrue);
      expect(SettingsService.instance.hasInitError, isTrue);
    });

    test('RIT-003: DatabaseHelper.ensureCriticalSchema creates essential schemas blocking', () async {
      await DatabaseHelper.ensureCriticalSchema(db);

      // Verify tables exist
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='routines'",
      );
      expect(tables, isNotEmpty);
    });

    test('RIT-005: Warmup hooks execute and catch async errors safely without crashing', () async {
      var hookExecuted = false;
      DatabaseHelper.registerWarmupHook(() async {
        hookExecuted = true;
        throw Exception('Simulated async warmup failure');
      });

      await DatabaseHelper.warmUp(db);
      expect(hookExecuted, isTrue);
    });
  });
}
