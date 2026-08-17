// C-18, C-23, C-24: CycleEngine Overdue & Period Duration Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleEngine Overdue and Bounds Tests', () {
    late Database db;
    late CycleEngine engine;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
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
      });

      engine = CycleEngine();

      await db.insert('app_settings', {'key': 'user_gender', 'value': 'FEMALE'});
      await db.insert('app_settings', {'key': 'module_cycle_enabled', 'value': 'true'});
      await db.insert('app_settings', {'key': 'cycle_avg_length', 'value': '28'});
      await db.insert('app_settings', {'key': 'cycle_avg_period', 'value': '6'});
    });

    tearDown(() async {
      await db.close();
    });

    test('C-18: 60 days since start with L=28 yields daysOverdue == 32, missedCycles == 2, and dataStale phase', () async {
      await db.insert('cycle_periods', {
        'id': '1',
        'startDate': '2026-06-01',
        'endDate': '2026-06-06',
      });

      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
        'cycle_avg_length': '28',
      };

      // 60 days after June 1 is July 31
      final now = DateTime(2026, 7, 31);
      final output = await engine.calculate(CycleEngineInput(db: db, appSettings: settings, now: now));

      expect(output.daysOverdue, equals(32)); // 60 - 28 = 32
      expect(output.missedCycles, equals(2)); // floor(60 / 28) = 2
      expect(output.needsUserAttention, isTrue);
      expect(output.currentPhase, equals(CyclePhase.dataStale));
      expect(output.nextPeriodPrediction, isNull);
    });

    test('C-23: dayOfCycle counts continuously from cycle start without modulo reset in non-bleeding days', () async {
      await db.insert('cycle_periods', {
        'id': '1',
        'startDate': '2026-08-01',
        'endDate': '2026-08-06',
      });

      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
        'cycle_avg_length': '28',
      };

      final now = DateTime(2026, 8, 15); // 14 days after start -> day 15 of cycle
      final output = await engine.calculate(CycleEngineInput(db: db, appSettings: settings, now: now));

      expect(output.dayOfCycle, equals(15));
    });

    test('C-24: Distant endDate is clamped to maxPlausiblePeriodDays (15) and flags hasImplausiblePeriodData', () async {
      await db.insert('cycle_periods', {
        'id': '1',
        'startDate': '2026-08-01',
        'endDate': '2026-08-30', // 30 days of bleeding recorded
      });

      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
      };

      final now = DateTime(2026, 8, 20); // 19 days after start
      final output = await engine.calculate(CycleEngineInput(db: db, appSettings: settings, now: now));

      expect(output.dayOfPeriod, equals(15));
      expect(output.hasImplausiblePeriodData, isTrue);
    });
  });
}
