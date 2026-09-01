import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/sleep_tables.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/domain/engines/ritmo_cross_module_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/mv_reason_keys.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await SupplementarySportsTables.create(db);
    await SleepTables.create(db);

    // Create required auxiliary tables for test isolation
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS iran_cities (
        id TEXT PRIMARY KEY,
        nameFa TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prayer_times (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        fajr TEXT NOT NULL,
        sunrise TEXT NOT NULL,
        dhuhr TEXT NOT NULL,
        asr TEXT NOT NULL,
        maghrib TEXT NOT NULL,
        isha TEXT NOT NULL,
        midnightShari TEXT NOT NULL,
        sunset TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worship_day_contexts (
        date TEXT PRIMARY KEY,
        isTraveller INTEGER DEFAULT 0,
        fastingExempt INTEGER DEFAULT 0,
        prayerExempt INTEGER DEFAULT 0,
        exemptPrayers TEXT,
        reason TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worship_practices (
        id TEXT PRIMARY KEY,
        practiceType TEXT NOT NULL,
        isCustom INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cycle_entries (
        id TEXT PRIMARY KEY,
        startDate TEXT NOT NULL,
        endDate TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS energy_logs (
        id TEXT PRIMARY KEY,
        energyLevel TEXT NOT NULL,
        source TEXT,
        loggedAt INTEGER NOT NULL
      );
    ''');

    DatabaseHelper.instance.overrideDatabaseForTesting(db);
    RitmoCrossModuleEngine.instance.invalidateCache();
  });

  tearDown(() async {
    await db.close();
  });

  group('RitmoCrossModuleEngine Unit Tests', () {
    test('returns clean default snapshot when no module data exists', () async {
      final snapshot = await RitmoCrossModuleEngine.instance.getSnapshot();

      expect(snapshot.dateIso, isNotEmpty);
      expect(snapshot.isSleepDebtHigh, isFalse);
      expect(snapshot.isFasting, isFalse);
      expect(snapshot.cycleConsentGranted, isFalse);
      expect(snapshot.applicableReasonKeys, isEmpty);
    });

    test('detects sleep debt (< 6h) and attaches readinessLow reason key', () async {
      final todayIso = RitmoDate.dayKey(DateTime.now());

      // Insert sleep program
      await db.insert('sleep_programs', {
        'id': 'prog_1',
        'status': 'active',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Insert sleep plan day with 300 minutes (5 hours) of sleep
      await db.insert('sleep_plan_days', {
        'programId': 'prog_1',
        'date': todayIso,
        'plannedBedtimeMin': 1380, // 23:00
        'plannedWakeMin': 420,    // 07:00
        'actualBedtimeMin': 1440, // 00:00
        'actualWakeMin': 300,     // 05:00 (300 min = 5 hours)
      });

      final snapshot = await RitmoCrossModuleEngine.instance.getSnapshot();

      expect(snapshot.sleepMinutesLastNight, equals(300));
      expect(snapshot.isSleepDebtHigh, isTrue);
      expect(snapshot.applicableReasonKeys, contains(MvReasonKeys.readinessLow));
      expect(snapshot.applicableReasonKeys, contains(MvReasonKeys.fallbackMinimum));
    });

    test('respects cycle consent gate for menstrual phase adaptation', () async {
      final now = DateTime.now();

      // Insert active cycle entry (started 2 days ago)
      final startStr = now.subtract(const Duration(days: 2)).toIso8601String();
      await db.insert('cycle_entries', {
        'id': 'entry_1',
        'startDate': startStr,
        'endDate': null,
      });

      // 1. Without consent: cycle data must remain unread
      await db.insert('ss_user_profile', {
        'id': 'prof_1',
        'goal': 'GENERAL_FITNESS',
        'experienceLevel': 'INTERMEDIATE',
        'trainingLocation': 'HOME',
        'availableEquipment': '[]',
        'cycleConsentGranted': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      var snapshot = await RitmoCrossModuleEngine.instance.getSnapshot();
      expect(snapshot.cycleConsentGranted, isFalse);
      expect(snapshot.isMenstrualPhase, isFalse);

      // 2. With consent: cycle data is read and reasons applied
      await db.update('ss_user_profile', {'cycleConsentGranted': 1});
      RitmoCrossModuleEngine.instance.invalidateCache();

      snapshot = await RitmoCrossModuleEngine.instance.getSnapshot();
      expect(snapshot.cycleConsentGranted, isTrue);
      expect(snapshot.isMenstrualPhase, isTrue);
      expect(snapshot.applicableReasonKeys, contains(MvReasonKeys.readinessLow));
    });

    test('event bus invalidates cached snapshot reactively', () async {
      final snapshot1 = await RitmoCrossModuleEngine.instance.getSnapshot();
      expect(snapshot1.energyLevel, isNull);

      // Insert energy log
      await db.insert('energy_logs', {
        'id': 'e_1',
        'energyLevel': 'peak',
        'loggedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Fire EventBus event
      RitmoEventBus().publish(RitmoEvent(type: RitmoEventType.energyLogged.code));

      // Small async tick for stream subscriber
      await Future.delayed(const Duration(milliseconds: 50));

      final snapshot2 = await RitmoCrossModuleEngine.instance.getSnapshot();
      expect(snapshot2.energyLevel, equals(5));
    });
  });
}
