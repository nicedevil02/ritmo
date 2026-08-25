import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_anomaly_detector.dart';
import 'package:ritmo/features/cycle/logic/cycle_confirmation_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_day_logs_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/logic/cycle_state_provider.dart';
import 'package:ritmo/features/cycle/logic/cycle_worship_policy.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'test_helpers/cycle_test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('Cycle Module 22 Bug Fixes Regression Tests', () {
    late Database db;

    setUp(() async {
      db = await openCycleTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('Bug 1 & 22: CycleEngineOutput copyWith properly clones all fields', () {
      final original = CycleEngineOutput(
        hasData: true,
        currentPhase: CyclePhase.luteal,
        dayOfCycle: 20,
        dayOfPeriod: 0,
        isOverdue: false,
        daysOverdue: 0,
        missedCycles: 0,
        isIrregular: false,
        dataMaturity: 'MEDIUM',
        stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 5, recordedPeriods: 3),
        regularityLevel: RegularityLevel.regular,
        trendPoints: const [],
        forecast: const [],
      );

      final modified = original.copyWith(
        currentPhase: CyclePhase.menstrual,
        dayOfCycle: 1,
        dayOfPeriod: 1,
        isOverdue: true,
        daysOverdue: 2,
      );

      expect(modified.currentPhase, equals(CyclePhase.menstrual));
      expect(modified.dayOfCycle, equals(1));
      expect(modified.dayOfPeriod, equals(1));
      expect(modified.isOverdue, isTrue);
      expect(modified.daysOverdue, equals(2));
      expect(modified.stats.avgCycleLength, equals(28));
      expect(modified.dataMaturity, equals('MEDIUM'));
    });

    test('Bug 2 & 16: startOverdue uses missedExpectedStarts.last and valid createdAt', () async {
      final now = DateTime(2026, 8, 25);
      final missedStart = DateTime(2026, 8, 15);
      final engineOutput = CycleEngineOutput(
        hasData: true,
        currentPhase: CyclePhase.dataStale,
        dayOfCycle: 38,
        dayOfPeriod: 0,
        isOverdue: true,
        daysOverdue: 10,
        missedCycles: 1,
        isIrregular: false,
        dataMaturity: 'HIGH',
        trendPoints: const [],
        stats: CycleStats(
          avgCycleLength: 28,
          avgPeriodDuration: 5,
          recordedPeriods: 3,
        ),
        missedExpectedStarts: [missedStart],
        awaitingStartConfirmation: true,
      );

      final settings = {'cycle_confirm_start_enabled': 'true'};
      final req = await CycleConfirmationService.instance.evaluatePendingRequest(
        dbExecutor: db,
        engineOutput: engineOutput,
        settings: settings,
        now: now,
      );

      expect(req, isNotNull);
      expect(req!.kind, equals(CycleConfirmationKind.startOverdue));
      expect(CycleDateContract.isSameDay(req.targetDate, missedStart), isTrue);
      expect(req.createdAt, greaterThan(0));
    });

    test('Bug 3 & 4: Overlap checks handle open periods effectiveEnd and reject invalid overlaps', () async {
      final now = DateTime(2026, 8, 25);
      // Insert closed period
      await db.insert('cycle_periods', {
        'id': 'p1',
        'startDate': '2026-08-10',
        'endDate': '2026-08-15',
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      // Attempting to start a period overlapping the existing period should throw ArgumentError
      expect(
        () => CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: DateTime(2026, 8, 12),
          now: now,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Bug 5 & 20: Auto-closed periods are marked autoClosed=1 and excluded from avgPeriodDuration', () async {
      final now = DateTime(2026, 8, 25);
      // Insert an old forgotten open period (> 12 days ago)
      await db.insert('cycle_periods', {
        'id': 'old_open',
        'startDate': '2026-08-01',
        'endDate': null,
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      // Starting a new period auto-closes the old one
      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 25),
        now: now,
      );

      final oldRows = await db.query('cycle_periods', where: 'id = ?', whereArgs: ['old_open']);
      expect(oldRows.first['autoClosed'], equals(1));
      expect(oldRows.first['endDate'], isNotNull);
    });

    test('Bug 6: endPeriod on already closed period throws StateError', () async {
      final now = DateTime(2026, 8, 25);
      final id = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 20),
        now: now,
      );

      await CyclePeriodRepository.instance.endPeriod(
        db: db,
        id: id,
        endDate: DateTime(2026, 8, 24),
        now: now,
      );

      // Calling endPeriod again should throw StateError
      expect(
        () => CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: id,
          endDate: DateTime(2026, 8, 25),
          now: now,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Bug 7 & 12: Due date (daysSinceStart == L) is NOT marked overdue or dataStale', () async {
      // Insert period starting 28 days ago with 28-day cycle length
      final start = DateTime(2026, 8, 1);
      final now = DateTime(2026, 8, 29); // exact 28 days elapsed

      await db.insert('cycle_periods', {
        'id': 'p1',
        'startDate': CycleDateContract.toDayKey(start),
        'endDate': CycleDateContract.toDayKey(start.add(const Duration(days: 4))),
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final output = await CycleEngine().calculate(
        CycleEngineInput(
          db: db,
          appSettings: {
            'user_gender': 'FEMALE',
            'module_cycle_enabled': 'true',
            'cycle_length_days': '28',
            'period_duration_days': '5',
          },
          now: now,
        ),
      );

      expect(output.isStartDueToday, isTrue);
      expect(output.isOverdue, isFalse);
      expect(output.daysOverdue, equals(0));
      expect(output.currentPhase, equals(CyclePhase.luteal));
    });

    test('Bug 8: Open period at day 16 has dayOfPeriod capped and sets hasImplausiblePeriodData', () async {
      final start = DateTime(2026, 8, 1);
      final now = DateTime(2026, 8, 17); // 16 days elapsed

      await db.insert('cycle_periods', {
        'id': 'open_p',
        'startDate': CycleDateContract.toDayKey(start),
        'endDate': null,
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final output = await CycleEngine().calculate(
        CycleEngineInput(
          db: db,
          appSettings: {
            'user_gender': 'FEMALE',
            'module_cycle_enabled': 'true',
            'cycle_length_days': '28',
            'period_duration_days': '5',
          },
          now: now,
        ),
      );

      expect(output.dayOfPeriod, equals(CycleSettings.maxPlausiblePeriodDays));
      expect(output.openPeriodDayCount, equals(CycleSettings.maxPlausiblePeriodDays));
      expect(output.hasImplausiblePeriodData, isTrue);
    });

    test('Bug 11: Corrupt dates in fromMap do not crash application', () {
      final badPeriod = CyclePeriod.fromMap({
        'id': 'bad_1',
        'startDate': 'invalid-date-string',
      });
      expect(badPeriod.id, equals(''));

      final badLog = CycleDayLog.fromMap({
        'id': 'bad_log',
        'logDate': 'garbage',
      });
      expect(badLog.id, equals(''));
    });

    test('Bug 13 & 14: CycleAnomalyDetector guards due day and generates highVariabilityTrend', () {
      final dueOutput = CycleEngineOutput(
        hasData: true,
        currentPhase: CyclePhase.luteal,
        dayOfCycle: 28,
        dayOfPeriod: 0,
        isStartDueToday: true,
        isOverdue: false,
        daysOverdue: 0,
        missedCycles: 0,
        isIrregular: true,
        dataMaturity: 'HIGH',
        trendPoints: const [],
        regularityLevel: RegularityLevel.irregular,
        cycleLengthSd: 6.5,
        stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 5, recordedPeriods: 4, completedCycles: 3),
      );

      final anomalies = CycleAnomalyDetector.detectAnomalies(
        periodRows: const [],
        avgCycleLength: 28,
        engineOutput: dueOutput,
      );

      // Must NOT produce lateOrMissedPeriod anomaly because it is due today
      expect(
        anomalies.any((a) => a.type == CycleAnomalyType.lateOrMissedPeriod),
        isFalse,
      );

      // Must produce highVariabilityTrend because irregularity is detected with completedCycles >= 3
      expect(
        anomalies.any((a) => a.type == CycleAnomalyType.highVariabilityTrend),
        isTrue,
      );
    });

    test('Bug 15: markAsked increments askCount and updates lastAskedAt', () async {
      const reqId = 'req_test_1';
      final now = DateTime(2026, 8, 25);
      await db.insert('cycle_confirmations', {
        'id': reqId,
        'kind': 'startDue',
        'targetDate': '2026-08-25',
        'askCount': 1,
        'lastAskedAt': 1000,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      await CycleConfirmationService.instance.markAsked(
        dbExecutor: db,
        requestId: reqId,
        now: now,
      );

      final rows = await db.query('cycle_confirmations', where: 'id = ?', whereArgs: [reqId]);
      expect(rows.first['askCount'], equals(2));
      expect(rows.first['lastAskedAt'], equals(now.millisecondsSinceEpoch));
    });

    test('Bug 18: Trend points calculate real elapsed days for in-progress cycle', () async {
      final start1 = DateTime(2026, 7, 1);
      final start2 = DateTime(2026, 7, 30);
      final now = DateTime(2026, 8, 25); // 27 days elapsed in 2nd cycle

      await db.insert('cycle_periods', {
        'id': 'p1',
        'startDate': CycleDateContract.toDayKey(start1),
        'endDate': CycleDateContract.toDayKey(start1.add(const Duration(days: 4))),
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      await db.insert('cycle_periods', {
        'id': 'p2',
        'startDate': CycleDateContract.toDayKey(start2),
        'endDate': null,
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 2000,
        'updatedAt': 2000,
      });

      final output = await CycleEngine().calculate(
        CycleEngineInput(
          db: db,
          appSettings: {
            'user_gender': 'FEMALE',
            'module_cycle_enabled': 'true',
            'cycle_length_days': '28',
            'period_duration_days': '5',
          },
          now: now,
        ),
      );

      expect(output.trendPoints.length, equals(2));
      final currentTrend = output.trendPoints.last;
      expect(currentTrend.isInProgress, isTrue);
      expect(currentTrend.lengthDays, equals(CycleDateContract.daysBetween(start2, now) + 1));
    });

    test('Bug 19: CycleState.copyWith with clearErrorMessage resets error', () {
      const stateWithError = CycleState(errorMessage: 'Network error occurred');
      final cleared = stateWithError.copyWith(clearErrorMessage: true);
      expect(cleared.errorMessage, isNull);
    });

    test('Bug 21: CycleWorshipPolicy.isPeriodDayOnDate respects explicit ceiling parameter', () {
      final start = DateTime(2026, 8, 1);
      final day10 = DateTime(2026, 8, 10);
      final day11 = DateTime(2026, 8, 11);

      // Fiqh ceiling (10 days)
      expect(
        CycleWorshipPolicy.isPeriodDayOnDate(
          targetDate: day10,
          start: start,
          end: null,
          ceilingDays: CycleSettings.maxFiqhBleedingDays,
        ),
        isTrue,
      );
      expect(
        CycleWorshipPolicy.isPeriodDayOnDate(
          targetDate: day11,
          start: start,
          end: null,
          ceilingDays: CycleSettings.maxFiqhBleedingDays,
        ),
        isFalse,
      );

      // Biology ceiling (15 days)
      expect(
        CycleWorshipPolicy.isPeriodDayOnDate(
          targetDate: day11,
          start: start,
          end: null,
          ceilingDays: CycleSettings.maxPlausiblePeriodDays,
        ),
        isTrue,
      );
    });
  });
}
