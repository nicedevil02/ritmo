import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/features/cycle/logic/cycle_confirmation_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('CycleConfirmationService Tests', () {
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

    test('evaluatePendingRequest returns startDue request when isStartDueToday is true', () async {
      final now = DateTime(2026, 8, 19);
      final engineOutput = CycleEngineOutput(
        hasData: true,
        currentPhase: CyclePhase.luteal,
        dayOfCycle: 28,
        dayOfPeriod: 0,
        nextPeriodPrediction: now,
        isOverdue: false,
        daysOverdue: 0,
        isIrregular: false,
        dataMaturity: 'HIGH',
        trendPoints: const [],
        stats: CycleStats(
          avgCycleLength: 28,
          avgPeriodDuration: 5,
          recordedPeriods: 3,
        ),
        forecast: const [],
        isBleedingConfirmed: false,
        isOpenPeriodBeyondAverage: false,
        openPeriodDayCount: 0,
        actualPeriodStart: null,
        isStartDueToday: true,
        missedExpectedStarts: const [],
        awaitingStartConfirmation: true,
        awaitingEndConfirmation: false,
      );

      final settings = {
        'cycle_confirm_start_enabled': 'true',
      };

      final req = await CycleConfirmationService.instance.evaluatePendingRequest(
        dbExecutor: db,
        engineOutput: engineOutput,
        settings: settings,
        now: now,
      );

      expect(req, isNotNull);
      expect(req!.kind, equals(CycleConfirmationKind.startDue));
      expect(req.isAnswered, isFalse);
    });

    test('recordAnswer with startedToday creates actual cycle_period and marks confirmation answered', () async {
      final now = DateTime(2026, 8, 19);
      const reqId = 'req_start_1';
      final targetDateStr = CycleDateContract.toDayKey(now);

      await db.insert('cycle_confirmations', {
        'id': reqId,
        'kind': CycleConfirmationKind.startDue.name,
        'targetDate': targetDateStr,
        'askCount': 0,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      await CycleConfirmationService.instance.recordAnswer(
        dbExecutor: db,
        requestId: reqId,
        answer: CycleConfirmationAnswer.startedToday,
        now: now,
      );

      // Verify cycle_confirmations was synced and cleared for startDue
      final confs = await db.query('cycle_confirmations', where: 'id = ?', whereArgs: [reqId]);
      expect(confs.isEmpty, isTrue);

      // Verify actual cycle_period inserted with isPredicted = 0
      final periods = await db.query('cycle_periods', where: 'startDate = ?', whereArgs: [targetDateStr]);
      expect(periods.isNotEmpty, isTrue);
      expect(periods.first['isPredicted'], equals(0));
    });

    test('recordAnswer with endedToday sets endDate for open period', () async {
      final startDate = DateTime(2026, 8, 14);
      final endDate = DateTime(2026, 8, 19);
      const periodId = 'period_1';

      await db.insert('cycle_periods', {
        'id': periodId,
        'startDate': CycleDateContract.toDayKey(startDate),
        'endDate': null,
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'createdAt': startDate.millisecondsSinceEpoch,
        'updatedAt': startDate.millisecondsSinceEpoch,
      });

      const reqId = 'req_end_1';
      await db.insert('cycle_confirmations', {
        'id': reqId,
        'kind': CycleConfirmationKind.endDue.name,
        'targetDate': CycleDateContract.toDayKey(endDate),
        'askCount': 0,
        'createdAt': endDate.millisecondsSinceEpoch,
        'updatedAt': endDate.millisecondsSinceEpoch,
      });

      await CycleConfirmationService.instance.recordAnswer(
        dbExecutor: db,
        requestId: reqId,
        answer: CycleConfirmationAnswer.endedToday,
        now: endDate,
      );

      final updatedPeriods = await db.query('cycle_periods', where: 'id = ?', whereArgs: [periodId]);
      expect(updatedPeriods.first['endDate'], equals(CycleDateContract.toDayKey(endDate)));
    });

    test('recordAnswer with notStartedYet marks confirmed with resolvedDate and does not insert unconfirmed period', () async {
      final now = DateTime(2026, 8, 19);
      const reqId = 'req_not_started_1';
      final targetDateStr = CycleDateContract.toDayKey(now);

      await db.insert('cycle_confirmations', {
        'id': reqId,
        'kind': CycleConfirmationKind.startDue.name,
        'targetDate': targetDateStr,
        'askCount': 0,
        'createdAt': now.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      });

      await CycleConfirmationService.instance.recordAnswer(
        dbExecutor: db,
        requestId: reqId,
        answer: CycleConfirmationAnswer.notStartedYet,
      );

      final confs = await db.query('cycle_confirmations', where: 'id = ?', whereArgs: [reqId]);
      expect(confs.first['answeredAt'], isNotNull);
      expect(confs.first['answer'], equals(CycleConfirmationAnswer.notStartedYet.name));

      final periods = await db.query('cycle_periods');
      expect(periods.isEmpty, isTrue);
    });

    test('pruneOldRequests removes answered requests older than 180 days', () async {
      final oldTime = DateTime(2025, 1, 1).millisecondsSinceEpoch;
      final newTime = DateTime(2026, 8, 19).millisecondsSinceEpoch;

      await db.insert('cycle_confirmations', {
        'id': 'req_old',
        'kind': CycleConfirmationKind.startDue.name,
        'targetDate': '2025-01-01',
        'answer': CycleConfirmationAnswer.startedToday.name,
        'answeredAt': oldTime,
        'askCount': 1,
        'createdAt': oldTime,
        'updatedAt': oldTime,
      });

      await db.insert('cycle_confirmations', {
        'id': 'req_new',
        'kind': CycleConfirmationKind.startDue.name,
        'targetDate': '2026-08-19',
        'answer': CycleConfirmationAnswer.startedToday.name,
        'answeredAt': newTime,
        'askCount': 1,
        'createdAt': newTime,
        'updatedAt': newTime,
      });

      await CycleConfirmationService.instance.pruneOldRequests(
        dbExecutor: db,
        now: DateTime(2026, 8, 19),
      );

      final confs = await db.query('cycle_confirmations');
      expect(confs.length, equals(1));
      expect(confs.first['id'], equals('req_new'));
    });
  });
}
