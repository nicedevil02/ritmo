import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_onboarding_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritmo/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleOnboardingController Tests', () {
    late Database db;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
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
          CREATE TABLE cycle_periods (
            id TEXT PRIMARY KEY,
            startDate TEXT NOT NULL,
            endDate TEXT,
            flowIntensity TEXT,
            isPredicted INTEGER DEFAULT 0,
            note TEXT,
            createdAt INTEGER,
            updatedAt INTEGER
          )
        ''');
        },
      );
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'saveOnboarding with past endedWithKnownStart (20 days ago, 6 duration) calculates correct closed endDate',
      () async {
        final now = DateTime.now();
        final startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 20));
        final expectedEnd = startDate.add(const Duration(days: 5));
        final data = CycleOnboardingData(
          periodStatus: CyclePeriodStatusChoice.endedWithKnownStart,
          cycleLength: 28,
          periodDuration: 6,
          startDate: startDate,
          worshipConsent: true,
        );

        await CycleOnboardingController.instance.saveOnboarding(data);

        final settings = await db.query('app_settings');
        final settingsMap = {
          for (final s in settings) s['key'] as String: s['value'] as String,
        };

        expect(settingsMap['module_cycle_enabled'], equals('true'));
        expect(settingsMap['cycle_setup_done'], equals('true'));
        expect(settingsMap['cycle_avg_length'], equals('28'));
        expect(settingsMap['user_cycle_length'], equals('28'));
        expect(settingsMap['cycle_avg_period'], equals('6'));
        expect(settingsMap['user_period_length'], equals('6'));
        expect(settingsMap['cycle_consent_worship'], equals('true'));

        final periods = await db.query('cycle_periods');
        expect(periods.length, equals(1));
        expect(
          periods.first['startDate'],
          equals(CycleDateContract.toDayKey(startDate)),
        );
        expect(
          periods.first['endDate'],
          equals(CycleDateContract.toDayKey(expectedEnd)),
        );
      },
    );

    test(
      'saveOnboarding with ongoing start date (3 days ago, 6 duration) keeps period OPEN (endDate == null)',
      () async {
        final now = DateTime.now();
        final startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 2)); // Day 3 of bleeding
        final data = CycleOnboardingData(
          periodStatus: CyclePeriodStatusChoice.endedWithKnownStart,
          cycleLength: 28,
          periodDuration: 6,
          startDate: startDate,
          worshipConsent: true,
        );

        await CycleOnboardingController.instance.saveOnboarding(data);

        final periods = await db.query('cycle_periods');
        expect(periods.length, equals(1));
        expect(
          periods.first['startDate'],
          equals(CycleDateContract.toDayKey(startDate)),
        );
        expect(
          periods.first['endDate'],
          isNull,
        ); // Must NOT be prematurely clamped to today
      },
    );

    test(
      'saveOnboarding with currentlyInPeriod keeps period OPEN (endDate == null)',
      () async {
        final now = DateTime.now();
        final startDate = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1));
        final data = CycleOnboardingData(
          periodStatus: CyclePeriodStatusChoice.currentlyInPeriod,
          cycleLength: 28,
          periodDuration: 6,
          startDate: startDate,
        );

        await CycleOnboardingController.instance.saveOnboarding(data);

        final periods = await db.query('cycle_periods');
        expect(periods.length, equals(1));
        expect(
          periods.first['startDate'],
          equals(CycleDateContract.toDayKey(startDate)),
        );
        expect(periods.first['endDate'], isNull);
      },
    );

    test('saveOnboarding with dontKnow inserts ZERO period rows', () async {
      final data = CycleOnboardingData(
        periodStatus: CyclePeriodStatusChoice.dontKnow,
        cycleLength: 30,
        periodDuration: 5,
      );

      await CycleOnboardingController.instance.saveOnboarding(data);

      final settings = await db.query('app_settings');
      final settingsMap = {
        for (final s in settings) s['key'] as String: s['value'] as String,
      };

      expect(settingsMap['module_cycle_enabled'], equals('true'));
      expect(settingsMap['cycle_setup_done'], equals('true'));

      final periods = await db.query('cycle_periods');
      expect(periods.isEmpty, isTrue);
    });

    test(
      'saveOnboarding with currentlyPregnant enables pregnancy mode and creates ZERO period rows',
      () async {
        final data = CycleOnboardingData(
          periodStatus: CyclePeriodStatusChoice.currentlyPregnant,
        );

        await CycleOnboardingController.instance.saveOnboarding(data);

        final settings = await db.query('app_settings');
        final settingsMap = {
          for (final s in settings) s['key'] as String: s['value'] as String,
        };

        expect(settingsMap['cycle_is_pregnant'], equals('true'));

        final periods = await db.query('cycle_periods');
        expect(periods.isEmpty, isTrue);
      },
    );

    test(
      'saveOnboarding saves all 6 consents and lock settings accurately',
      () async {
        final data = CycleOnboardingData(
          periodStatus: CyclePeriodStatusChoice.dontKnow,
          worshipConsent: true,
          energyConsent: true,
          sleepConsent: true,
          remindersConsent: true,
          dashboardConsent: true,
          calendarConsent: true,
          enableLock: true,
        );

        await CycleOnboardingController.instance.saveOnboarding(data);

        final settings = await db.query('app_settings');
        final settingsMap = {
          for (final s in settings) s['key'] as String: s['value'] as String,
        };

        expect(settingsMap['cycle_consent_worship'], equals('true'));
        expect(settingsMap['cycle_consent_energy'], equals('true'));
        expect(settingsMap['cycle_consent_sleep'], equals('true'));
        expect(settingsMap['cycle_consent_reminders'], equals('true'));
        expect(settingsMap['cycle_consent_dashboard'], equals('true'));
        expect(settingsMap['show_cycle_in_calendar'], equals('true'));
        expect(settingsMap['cycle_lock_enabled'], equals('true'));
        expect(settingsMap['cycle_biometric_enabled'], equals('true'));

        final loaded = await CycleOnboardingController.instance
            .loadInitialData();
        expect(loaded.worshipConsent, isTrue);
        expect(loaded.energyConsent, isTrue);
        expect(loaded.sleepConsent, isTrue);
        expect(loaded.remindersConsent, isTrue);
        expect(loaded.dashboardConsent, isTrue);
        expect(loaded.calendarConsent, isTrue);
        expect(loaded.enableLock, isTrue);
      },
    );
  });
}
