import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_day_logs_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleDayLogsRepository Tests (Phase 12)', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
      DatabaseHelper.instance.overrideDatabaseForTesting(db);
      final engine = CycleEngine();
      final registry = EngineRegistry()..register(engine);
      RitmoEngineBus.init(registry);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. saveLog saves daily log and getLogForDate retrieves it by logDate', () async {
      final logDate = DateTime(2026, 8, 17);
      final log = CycleDayLog(
        id: 'daylog_1',
        logDate: logDate,
        flowLevel: 'MEDIUM',
        symptoms: ['cramps', 'headache'],
        mood: 'TIRED',
        energyTag: 'LOW',
        note: 'Feeling tired today',
        createdAt: 1000,
        updatedAt: 1000,
      );

      await CycleDayLogsRepository.instance.saveLog(log, db);

      final retrieved = await CycleDayLogsRepository.instance.getLogForDate(logDate, db);
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('daylog_1'));
      expect(retrieved.logDate, equals(DateTime(2026, 8, 17)));
      expect(retrieved.flowLevel, equals('MEDIUM'));
      expect(retrieved.symptoms, equals(['cramps', 'headache']));
      expect(retrieved.mood, equals('TIRED'));
      expect(retrieved.energyTag, equals('LOW'));
      expect(retrieved.note, equals('Feeling tired today'));
    });

    test('2. saveLog updates existing day log idempotently', () async {
      final logDate = DateTime(2026, 8, 17);
      final initial = CycleDayLog(
        id: 'daylog_1',
        logDate: logDate,
        flowLevel: 'LIGHT',
        symptoms: ['bloating'],
        mood: 'CALM',
        createdAt: 1000,
        updatedAt: 1000,
      );
      await CycleDayLogsRepository.instance.saveLog(initial, db);

      final updated = CycleDayLog(
        id: 'daylog_1',
        logDate: logDate,
        flowLevel: 'HEAVY',
        symptoms: ['bloating', 'cramps'],
        mood: 'IRRITABLE',
        createdAt: 1000,
        updatedAt: 2000,
      );
      await CycleDayLogsRepository.instance.saveLog(updated, db);

      final retrieved = await CycleDayLogsRepository.instance.getLogForDate(logDate, db);
      expect(retrieved, isNotNull);
      expect(retrieved!.flowLevel, equals('HEAVY'));
      expect(retrieved.symptoms, equals(['bloating', 'cramps']));
      expect(retrieved.mood, equals('IRRITABLE'));
    });

    test('3. getLogsForRange retrieves logs ordered by logDate ASC', () async {
      await CycleDayLogsRepository.instance.saveLog(
        CycleDayLog(
          id: 'daylog_3',
          logDate: DateTime(2026, 8, 19),
          symptoms: [],
          createdAt: 1000,
          updatedAt: 1000,
        ),
        db,
      );
      await CycleDayLogsRepository.instance.saveLog(
        CycleDayLog(
          id: 'daylog_1',
          logDate: DateTime(2026, 8, 15),
          symptoms: [],
          createdAt: 1000,
          updatedAt: 1000,
        ),
        db,
      );
      await CycleDayLogsRepository.instance.saveLog(
        CycleDayLog(
          id: 'daylog_2',
          logDate: DateTime(2026, 8, 17),
          symptoms: [],
          createdAt: 1000,
          updatedAt: 1000,
        ),
        db,
      );

      final logs = await CycleDayLogsRepository.instance.getLogsForRange(
        DateTime(2026, 8, 14),
        DateTime(2026, 8, 18),
        db,
      );

      expect(logs.length, equals(2));
      expect(logs[0].id, equals('daylog_1'));
      expect(logs[1].id, equals('daylog_2'));
    });

    test('4. deleteLogForDate removes the log for specified date', () async {
      final logDate = DateTime(2026, 8, 17);
      await CycleDayLogsRepository.instance.saveLog(
        CycleDayLog(
          id: 'daylog_1',
          logDate: logDate,
          symptoms: [],
          createdAt: 1000,
          updatedAt: 1000,
        ),
        db,
      );

      await CycleDayLogsRepository.instance.deleteLogForDate(logDate, db);

      final retrieved = await CycleDayLogsRepository.instance.getLogForDate(logDate, db);
      expect(retrieved, isNull);
    });
  });
}
