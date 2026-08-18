import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_onboarding_controller.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritmo/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Cycle Period Duration Regression Tests (User Issue: 6-day period starting 3 days ago)', () {
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
          await db.execute('''
          CREATE TABLE cycle_day_logs (
            id TEXT PRIMARY KEY,
            logDate TEXT NOT NULL,
            flowLevel TEXT,
            symptoms TEXT,
            mood TEXT,
            notes TEXT,
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
      '6-day period starting 3 days ago is preserved as active (endDate == null), engine returns avgPeriodDuration = 6.0 and day 3 of 6',
      () async {
        final now = DateTime.now();
        final cleanToday = CycleDateContract.cleanDate(now);
        // Start date: 2 days before today => today is Day 3
        final startDate = cleanToday.subtract(const Duration(days: 2));

        final data = CycleOnboardingData(
          periodStatus: CyclePeriodStatusChoice.endedWithKnownStart,
          cycleLength: 28,
          periodDuration: 6,
          startDate: startDate,
          worshipConsent: true,
        );

        // 1. Save Onboarding
        await db.insert('app_settings', {
          'key': 'user_gender',
          'value': 'female',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        await CycleOnboardingController.instance.saveOnboarding(data);

        // 2. Verify Database row
        final periodRows = await db.query('cycle_periods');
        expect(periodRows.length, equals(1));
        expect(periodRows.first['startDate'], equals(CycleDateContract.toDayKey(startDate)));
        expect(periodRows.first['endDate'], isNull, reason: 'Active period must NOT be clamped to today');

        // 3. Query App Settings
        final settingsRows = await db.query('app_settings');
        final settingsMap = {
          for (final s in settingsRows) s['key'] as String: s['value'] as String,
        };
        final configuredPeriodDuration = CycleSettings.getPeriodDuration(settingsMap);
        expect(configuredPeriodDuration, equals(6));

        // 4. Run CycleEngine calculation
        final engine = CycleEngine();
        final output = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settingsMap, now: cleanToday),
        );

        expect(output.stats.avgPeriodDuration, equals(6.0), reason: 'Average period duration must remain 6.0, not 3.0');
        expect(output.currentPhase, equals(CyclePhase.menstrual));
        expect(output.dayOfCycle, equals(3));
        expect(output.dayOfPeriod, equals(3));

        // 5. Progress Ring Calculation in CycleOrbCard: currentDay / totalDays
        final activePeriodDay = output.dayOfPeriod;
        final totalDays = output.stats.avgPeriodDuration;
        final progress = (activePeriodDay / totalDays).clamp(0.05, 1.0);
        expect(progress, closeTo(0.5, 0.01), reason: 'Day 3 of 6 must be 50% progress ring, not 100% full');

        // 6. Calendar check for 6 days
        bool checkIsPeriodDay(DateTime date) {
          final cleanDate = CycleDateContract.cleanDate(date);
          for (final p in periodRows) {
            final pStart = CycleDateContract.parseDayKey(p['startDate'] as String)!;
            final endStr = p['endDate'] as String?;
            final end = endStr != null ? CycleDateContract.parseDayKey(endStr) : null;

            if (!cleanDate.isBefore(pStart)) {
              if (end != null) {
                if (!cleanDate.isAfter(end)) return true;
              } else {
                final pDur = CycleSettings.getPeriodDuration(settingsMap);
                if (cleanDate.difference(pStart).inDays < pDur) return true;
              }
            }
          }
          return false;
        }

        // Days 1 through 6 must all be period days
        for (int dayOffset = 0; dayOffset < 6; dayOffset++) {
          final dayToCheck = startDate.add(Duration(days: dayOffset));
          expect(
            checkIsPeriodDay(dayToCheck),
            isTrue,
            reason: 'Day ${dayOffset + 1} of 6 ($dayToCheck) must be marked as period day in calendar',
          );
        }

        // Day 7 must NOT be a period day
        final day7 = startDate.add(const Duration(days: 6));
        expect(
          checkIsPeriodDay(day7),
          isFalse,
          reason: 'Day 7 ($day7) must NOT be marked as period day',
        );
      },
    );
  });
}
