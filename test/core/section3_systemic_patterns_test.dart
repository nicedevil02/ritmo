import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/results/swallow.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/time/elapsed_clock.dart';
import 'package:ritmo/core/utils/ritmo_parsers.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Section 3: Systemic Patterns (P-A .. P-E)', () {
    late Database db;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});

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
      SettingsService.instance.resetForTesting();
    });

    tearDown(() async {
      await db.close();
    });

    test('P-A: tolerate and tolerateAsync gracefully catch and return fallback', () async {
      // Synchronous tolerate
      final resSync = tolerate<int>(() {
        throw StateError('Simulated unexpected failure');
      }, context: 'TestContext', fallback: 42);
      expect(resSync, equals(42));

      // Asynchronous tolerateAsync
      final resAsync = await tolerateAsync<String>(() async {
        throw FormatException('Simulated async format error');
      }, context: 'TestContextAsync', fallback: 'safe_fallback');
      expect(resAsync, equals('safe_fallback'));
    });

    test('P-B: UpsertHelper performs atomic SQLite upsert without destructive deletion', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Initial insert via UpsertHelper
      await UpsertHelper.upsert(db, 'app_settings', {
        'key': 'test_upsert_key',
        'value': 'initial_value',
        'updatedAt': now,
      }, conflictColumns: ['key']);

      final row1 = await db.query(
        'app_settings',
        where: "key = 'test_upsert_key'",
      );
      expect(row1.first['value'], equals('initial_value'));

      // 2. Atomic update on conflict without wipe
      await UpsertHelper.upsert(db, 'app_settings', {
        'key': 'test_upsert_key',
        'value': 'updated_value',
        'updatedAt': now + 1000,
      }, conflictColumns: ['key']);

      final row2 = await db.query(
        'app_settings',
        where: "key = 'test_upsert_key'",
      );
      expect(row2.length, equals(1));
      expect(row2.first['value'], equals('updated_value'));
    });

    test('P-C: ElapsedClock calculates background-resilient wall clock elapsed time', () {
      final start = DateTime.now().subtract(const Duration(minutes: 10));
      final clock = ElapsedClock(startedAt: start);

      expect(clock.elapsed.inMinutes, greaterThanOrEqualTo(10));
      expect(clock.isPaused, isFalse);

      // Simulated pause
      final pausedStart = DateTime.now().subtract(const Duration(minutes: 5));
      final pausedClock = ElapsedClock(
        startedAt: pausedStart,
        pausedAt: pausedStart.add(const Duration(minutes: 2)),
      );
      expect(pausedClock.isPaused, isTrue);
      expect(pausedClock.elapsed.inMinutes, equals(2));
    });

    test('P-D: RitmoParsers and safe SleepTarget getters handle malformed strings gracefully', () {
      // Integer parsing
      expect(RitmoParsers.tryParseInt(' ۱۲۳ '), equals(123));
      expect(RitmoParsers.tryParseInt('invalid', fallback: 10), equals(10));
      expect(RitmoParsers.tryParseInt(50, min: 60, max: 100), equals(60));

      // TimeOfDay parsing
      final tod = RitmoParsers.tryParseHhMm('۲۳:۴۵');
      expect(tod, isNotNull);
      expect(tod!.hour, equals(23));
      expect(tod.minute, equals(45));
      expect(RitmoParsers.tryParseHhMm('invalid'), isNull);

      // Safe SleepTarget getters with malformed time strings
      final safeTarget = SleepTarget(
        bedtime: 'invalid:format',
        wake: '',
        durationMinutes: 480,
      );
      expect(safeTarget.bedtimeHour, equals(23)); // Fallback to 23
      expect(safeTarget.bedtimeMinute, equals(30)); // Fallback to 30
      expect(safeTarget.wakeHour, equals(7)); // Fallback to 7
      expect(safeTarget.wakeMinute, equals(0)); // Fallback to 0
    });

    test('P-E: SettingsRegistry registers 12 systemic keys and migrates SP values to DB', () async {
      // 1. Verify all 12 keys exist in SettingsRegistry
      final requiredKeys = [
        'goals_view_mode',
        'onboarding_completed',
        'ss_default_rest_seconds',
        'ss_tts_enabled',
        'ss_metric_unit',
        'replan_suggest_count',
        'assistant_cloud_consent',
        'ai_deep_analysis_consent',
        'weekly_backup_enabled',
        'planner_draft_text',
        'ai_deep_analysis_result_v1',
        'systems_custom_order_banner_dismissed',
      ];

      for (final k in requiredKeys) {
        final desc = SettingsRegistry.find(k);
        expect(desc, isNotNull, reason: 'Key $k should be registered in SettingsRegistry');
      }

      // 2. Simulate legacy SharedPreferences values
      SharedPreferences.setMockInitialValues({
        'goals_view_mode': 'matrix',
        'onboarding_completed': true,
        'ss_default_rest_seconds': 90,
      });

      // 3. Initialize SettingsService to trigger automatic SP migration
      final settings = SettingsService.instance;
      await settings.init();

      expect(settings.get('goals_view_mode'), equals('matrix'));
      expect(settings.get('onboarding_completed'), equals(true));
      expect(settings.get('ss_default_rest_seconds'), equals(90));
    });
  });
}
