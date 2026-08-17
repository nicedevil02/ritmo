// C-16: CycleEngine Cache & Invalidation Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleEngine Cache and Invalidation Tests', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

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
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            startDate TEXT NOT NULL,
            endDate TEXT,
            cycleLength INTEGER,
            periodDuration INTEGER,
            notes TEXT,
            suppressedPrayer INTEGER DEFAULT 1,
            fastDebtCreated INTEGER DEFAULT 0,
            createdAt INTEGER,
            updatedAt INTEGER
          )
        ''');
        },
      );

      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);

      await db.insert('app_settings', {
        'key': 'user_gender',
        'value': 'FEMALE',
      });
      await db.insert('app_settings', {
        'key': 'module_cycle_enabled',
        'value': 'true',
      });
      await db.insert('app_settings', {
        'key': 'cycle_avg_length',
        'value': '28',
      });
      await db.insert('app_settings', {
        'key': 'cycle_avg_period',
        'value': '6',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'C-16: Registering new period triggers invalidation and cache reflects new data',
      () async {
        final now = DateTime(2026, 8, 17);
        final settings = {
          'user_gender': 'FEMALE',
          'module_cycle_enabled': 'true',
          'cycle_avg_length': '28',
          'cycle_avg_period': '6',
        };

        final directOut = await engine.calculate(
          CycleEngineInput(db: db, appSettings: settings, now: now),
        );
        expect(directOut.hasData, isFalse);

        final out1 = await RitmoEngineBus.instance
            .execute<CycleEngineInput, CycleEngineOutput>(
              CycleEngine,
              CycleEngineInput(db: db, appSettings: settings, now: now),
            );
        expect(out1.hasData, isFalse);

        await CyclePeriodRepository.instance.startPeriod(
          DateTime(2026, 8, 15),
          dbExecutor: db,
          now: now,
        );

        final out2 = await RitmoEngineBus.instance
            .execute<CycleEngineInput, CycleEngineOutput>(
              CycleEngine,
              CycleEngineInput(db: db, appSettings: settings, now: now),
            );
        expect(out2.hasData, isTrue);
        expect(out2.dayOfCycle, equals(3));
        expect(out2.currentPhase, equals(CyclePhase.menstrual));
      },
    );
  });
}
