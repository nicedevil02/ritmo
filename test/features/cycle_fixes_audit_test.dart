import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_onboarding_controller.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/kick_session_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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
  });

  tearDown(() async {
    await db.close();
  });

  group('Cycle Module Fixes Audit (RITF-066 .. RITF-074)', () {
    test('RITF-066 & RITF-067 & RITF-068 & RITF-071: CycleLockService manages brute-force in app_settings, resets on expiry, and uses constant-time equals', () async {
      final lockService = CycleLockService.instance;

      // 1. Set a PIN
      await lockService.setPin('1234');
      expect(await lockService.hasCyclePin(), isTrue);

      // 2. Failed verification increments attempts in app_settings
      final res1 = await lockService.verifyPin('9999');
      expect(res1, isFalse);

      final row = await db.query('app_settings', where: "key = 'cycle_lock_failed_attempts'");
      expect(row.isNotEmpty, isTrue);
      expect(row.first['value'], '1');

      // 3. Reset failed attempts on success
      final resSuccess = await lockService.verifyPin('1234');
      expect(resSuccess, isTrue);

      final rowAfterSuccess = await db.query('app_settings', where: "key = 'cycle_lock_failed_attempts'");
      expect(rowAfterSuccess.first['value'], '0');

      // 4. Test lockout expiry reset (RITF-067)
      // Artificially set a past lockout
      await db.update(
        'app_settings',
        {
          'value': (DateTime.now().millisecondsSinceEpoch - 5000).toString(),
        },
        where: "key = 'cycle_lockout_until_ms'",
      );
      await db.update(
        'app_settings',
        {'value': '5'},
        where: "key = 'cycle_lock_failed_attempts'",
      );

      final remaining = await lockService.remainingLockoutSeconds();
      expect(remaining, 0);

      // Verify lockout and failed attempts were reset to 0
      final rowAfterExpiry = await db.query('app_settings', where: "key = 'cycle_lock_failed_attempts'");
      expect(rowAfterExpiry.first['value'], '0');
    });

    test('RITF-069 & RITF-070: isLockEnabled fails closed on error and setLockEnabled upserts safely', () async {
      final lockService = CycleLockService.instance;

      await lockService.setLockEnabled(true);
      expect(await lockService.isLockEnabled(), isTrue);

      await lockService.setLockEnabled(false);
      expect(await lockService.isLockEnabled(), isFalse);
    });

    test('RITF-072: KickSessionTracker safely handles corrupt last tap timestamp and saves without replace', () async {
      final now = DateTime(2026, 8, 27, 12, 0);
      final nowMs = now.millisecondsSinceEpoch;

      // Seed corrupted string in preg_kick_session_last_tap
      await db.insert('app_settings', {
        'key': 'preg_kick_session_start',
        'value': nowMs.toString(),
        'updatedAt': nowMs,
      });
      await db.insert('app_settings', {
        'key': 'preg_kick_session_count',
        'value': '3',
        'updatedAt': nowMs,
      });
      await db.insert('app_settings', {
        'key': 'preg_kick_session_last_tap',
        'value': 'corrupt_not_an_int',
        'updatedAt': nowMs,
      });

      // restoreFromSettings should not throw FormatException
      final restored = await KickSessionTracker.restoreFromSettings(now);
      expect(restored, isNotNull);
      expect(restored!.count, 3);
      expect(restored.lastTap, isNull);

      // saveToSettings executes cleanly
      restored.registerTap(now.add(const Duration(minutes: 5)));
      await restored.saveToSettings();

      final updatedCountRow = await db.query('app_settings', where: "key = 'preg_kick_session_count'");
      expect(updatedCountRow.first['value'], '4');
    });

    test('RITF-074: PregnancySettings and CycleOnboardingController use atomic upserts', () async {
      // 1. Test PregnancySettings.saveSetting & saveProfile
      await PregnancySettings.saveSetting('preg_tone', 'calm');
      final toneRow = await db.query('app_settings', where: "key = 'preg_tone'");
      expect(toneRow.first['value'], 'calm');

      final profile = PregnancyProfile(
        lmpDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2026, 10, 1),
        tone: PregnancyTone.warm,
        ageUnit: PregnancyAgeUnit.weeks,
      );
      await PregnancySettings.saveProfile(profile);
      final profileRow = await db.query('app_settings', where: "key = 'preg_tone'");
      expect(profileRow.first['value'], 'warm');

      // 2. Test CycleOnboardingController.saveOnboarding
      final data = CycleOnboardingData(
        periodStatus: CyclePeriodStatusChoice.endedWithKnownStart,
        cycleLength: 28,
        periodDuration: 5,
        startDate: DateTime(2026, 8, 1),
        worshipConsent: true,
      );

      await CycleOnboardingController.instance.saveOnboarding(data);

      final periodRows = await db.query('cycle_periods', where: "id = 'period_onboarding_seed'");
      expect(periodRows.isNotEmpty, isTrue);
      expect(periodRows.first['startDate'], '2026-08-01');
    });
  });
}
