import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/hormonal_intelligence_engine.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';
import 'package:ritmo/features/cycle/logic/cycle_worship_policy.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleWorshipPolicy Tests (C-37)', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      await db.execute('''
        CREATE TABLE IF NOT EXISTS worship_debts (
          id TEXT PRIMARY KEY,
          totalCount INTEGER NOT NULL,
          remainingCount INTEGER NOT NULL,
          isArchived INTEGER DEFAULT 0,
          updatedAt INTEGER NOT NULL
        );
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'C-37: With cycle_consent_worship = false, prayer suspension is FALSE even during bleeding',
      () async {
        // Active period today
        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-08-17',
          'endDate': null,
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final settings = {
          'user_gender': 'female',
          'module_cycle_enabled': 'true',
          'cycle_consent_worship': 'false', // Worship consent revoked
        };

        for (final entry in settings.entries) {
          await db.insert('app_settings', {
            'key': entry.key,
            'value': entry.value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        final now = DateTime(2026, 8, 17);

        final isSuspendedPolicy = await CycleWorshipPolicy.isWorshipSuspended(
          dbExecutor: db,
          appSettings: settings,
          targetDate: now,
        );
        expect(isSuspendedPolicy, isFalse);

        final isSuspendedBridge = await CycleConsentBridge.isWorshipSuspended(
          targetDate: now,
        );
        expect(isSuspendedBridge, isFalse);

        final hormonalOutput = await HormonalIntelligenceEngine.evaluate(
          db: db,
          appSettings: settings,
          now: now,
        );
        expect(hormonalOutput.fiqhState.prayerSuspended, isFalse);
        expect(hormonalOutput.fiqhState.fastingSuspended, isFalse);
      },
    );

    test(
      'C-37: With cycle_consent_worship = true, active bleeding suspends worship up to 10 days',
      () async {
        // Period started 8 days ago
        await db.insert('cycle_periods', {
          'id': 'p1',
          'startDate': '2026-08-10',
          'endDate': null,
          'createdAt': 1000,
          'updatedAt': 1000,
        });

        final settings = {
          'user_gender': 'female',
          'module_cycle_enabled': 'true',
          'cycle_consent_worship': 'true',
        };

        final nowDay8 = DateTime(2026, 8, 17); // 8th day (<= 10 days)
        final isSuspended = await CycleWorshipPolicy.isWorshipSuspended(
          dbExecutor: db,
          appSettings: settings,
          targetDate: nowDay8,
        );
        expect(isSuspended, isTrue);

        final nowDay12 = DateTime(
          2026,
          8,
          22,
        ); // 13th day (> 10 days fiqh limit)
        final isSuspendedDay12 = await CycleWorshipPolicy.isWorshipSuspended(
          dbExecutor: db,
          appSettings: settings,
          targetDate: nowDay12,
        );
        expect(isSuspendedDay12, isFalse);
      },
    );

    test(
      'C-37: resolveFastingDebt updates both fasting_debt and worship_debts atomically',
      () async {
        await db.insert('fasting_debt', {
          'id': 'debt_1',
          'dateIso': '2026-08-17',
          'isResolved': 0,
          'updatedAt': 1000,
        });

        await db.insert('worship_debts', {
          'id': 'debt_cycle_fast_debt_1',
          'totalCount': 1,
          'remainingCount': 1,
          'isArchived': 0,
          'updatedAt': 1000,
        });

        await CycleWorshipPolicy.resolveFastingDebt(
          'debt_1',
          true,
          dbExecutor: db,
        );

        final fastingRows = await db.query(
          'fasting_debt',
          where: 'id = ?',
          whereArgs: ['debt_1'],
        );
        expect(fastingRows.first['isResolved'], equals(1));

        final worshipRows = await db.query(
          'worship_debts',
          where: 'id = ?',
          whereArgs: ['debt_cycle_fast_debt_1'],
        );
        expect(worshipRows.first['remainingCount'], equals(0));
        expect(worshipRows.first['isArchived'], equals(1));
      },
    );
  });
}
