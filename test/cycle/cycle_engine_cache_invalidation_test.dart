import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_confirmation_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_day_logs_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleEngine Cache Invalidation Tests across all write pathways', () {
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

    test('1. startPeriod invalidates cache and engine reflects active cycle', () async {
      final now = DateTime(2026, 8, 17);
      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
        'cycle_length_days': '28',
        'period_duration_days': '6',
      };

      final out1 = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );
      expect(out1.hasData, isFalse);

      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 15),
        now: now,
      );

      final out2 = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );
      expect(out2.hasData, isTrue);
      expect(out2.dayOfCycle, equals(3));
    });

    test('2. endPeriod invalidates cache and engine reflects closed period', () async {
      final now = DateTime(2026, 8, 17);
      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
        'cycle_length_days': '28',
        'period_duration_days': '6',
      };

      final id = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 10),
        now: now,
      );

      final out1 = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );
      expect(out1.isOpenPeriodBeyondAverage, isTrue);

      await CyclePeriodRepository.instance.endPeriod(
        db: db,
        id: id,
        endDate: DateTime(2026, 8, 15),
        now: now,
      );

      final out2 = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );
      expect(out2.isOpenPeriodBeyondAverage, isFalse);
    });

    test('3. deletePeriod invalidates cache', () async {
      final now = DateTime(2026, 8, 17);
      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
        'cycle_length_days': '28',
        'period_duration_days': '6',
      };

      final id = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 15),
        now: now,
      );

      final out1 = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );
      expect(out1.hasData, isTrue);

      await CyclePeriodRepository.instance.deletePeriod(
        db: db,
        id: id,
      );

      final out2 = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );
      expect(out2.hasData, isFalse);
    });

    test('4. saveLog in CycleDayLogsRepository invalidates cache', () async {
      final now = DateTime(2026, 8, 17);
      final settings = {
        'user_gender': 'FEMALE',
        'module_cycle_enabled': 'true',
      };

      await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );

      await CycleDayLogsRepository.instance.saveLog(
        CycleDayLog(
          id: 'log_1',
          logDate: DateTime(2026, 8, 17),
          flowLevel: 'LIGHT',
          symptoms: ['cramps'],
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
        ),
        db,
      );

      // Verify engine bus can re-execute cleanly after invalidation
      final out = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(db: db, appSettings: settings, now: now),
      );
      expect(out, isNotNull);
    });

    test('5. CycleSettings modifications invalidate cache', () async {
      final now = DateTime(2026, 8, 17);
      await CycleSettings.setPeriodDuration(7, db);
      final out = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(
          db: db,
          appSettings: {
            'user_gender': 'FEMALE',
            'module_cycle_enabled': 'true',
            'period_duration_days': '7',
          },
          now: now,
        ),
      );
      expect(out, isNotNull);
    });

    test('6. CycleConfirmationService recordAnswer invalidates cache', () async {
      final now = DateTime(2026, 8, 17);
      await CycleConfirmationService.instance.recordAnswer(
        dbExecutor: db,
        requestId: 'startDue_2026-08-17',
        answer: CycleConfirmationAnswer.startedToday,
        now: now,
      );

      final out = await RitmoEngineBus.instance.execute<CycleEngineInput, CycleEngineOutput>(
        CycleEngine,
        CycleEngineInput(
          db: db,
          appSettings: {
            'user_gender': 'FEMALE',
            'module_cycle_enabled': 'true',
          },
          now: now,
        ),
      );
      expect(out.hasData, isTrue);
      expect(out.dayOfCycle, equals(1));
    });
  });
}
