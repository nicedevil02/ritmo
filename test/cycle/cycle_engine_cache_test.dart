// C-16: CycleEngine Cache & Invalidation Tests
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleEngine Cache and Invalidation Tests', () {
    late Database db;
    late CycleEngine engine;
    late EngineRegistry registry;

    setUp(() async {
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);

      engine = CycleEngine();
      registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
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
          db: db,
          startDate: DateTime(2026, 8, 15),
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
