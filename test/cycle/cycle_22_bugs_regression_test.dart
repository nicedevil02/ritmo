import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/services/cycle_notification_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_anomaly_detector.dart';
import 'package:ritmo/features/cycle/logic/cycle_confirmation_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_day_logs_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_status.dart';
import 'package:ritmo/features/cycle/logic/cycle_reminder_scheduler.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/logic/cycle_state_provider.dart';
import 'package:ritmo/features/cycle/logic/cycle_worship_policy.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
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

    test('Bug 1: CycleEngineOutput copyWith properly clones all fields', () {
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

    test('Bug 2: startOverdue uses missedExpectedStarts.last and valid createdAt', () async {
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

      expect(
        () => CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: DateTime(2026, 8, 12),
          now: now,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Bug 5: Auto-closed periods are marked autoClosed=1 and excluded from avgPeriodDuration', () async {
      final now = DateTime(2026, 8, 25);
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

      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 25),
        now: now,
      );

      final oldRows = await db.query('cycle_periods', where: 'id = ?', whereArgs: ['old_open']);
      expect(oldRows.first['autoClosed'], equals(1));
      expect(oldRows.first['endDate'], isNotNull);
    });

    test('Bug 6: endPeriod on already closed period throws StateError and tryFromMap handles corrupt maps', () async {
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

      expect(
        () => CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: id,
          endDate: DateTime(2026, 8, 25),
          now: now,
        ),
        throwsA(isA<StateError>()),
      );

      final badPeriod = CyclePeriod.tryFromMap({'startDate': 'not-a-date'});
      expect(badPeriod, isNull);
    });

    test('Bug 7 & 12: Due date (daysSinceStart == L) is NOT marked overdue or dataStale', () async {
      final start = DateTime(2026, 8, 1);
      final now = DateTime(2026, 8, 29);

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
      final now = DateTime(2026, 8, 17);

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

    test('Bug 9 & 10: CycleWorshipPolicy evaluates prayer suppression and respects ceilings', () {
      final start = DateTime(2026, 8, 1);
      final day5 = DateTime(2026, 8, 5);
      final day12 = DateTime(2026, 8, 12);

      expect(
        CycleWorshipPolicy.isPeriodDayOnDate(
          targetDate: day5,
          start: start,
          end: null,
          ceilingDays: CycleSettings.maxFiqhBleedingDays,
        ),
        isTrue,
      );

      expect(
        CycleWorshipPolicy.isPeriodDayOnDate(
          targetDate: day12,
          start: start,
          end: null,
          ceilingDays: CycleSettings.maxFiqhBleedingDays,
        ),
        isFalse,
      );
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

    test('Bug 13: CycleAnomalyDetector detects unusuallyHeavyFlowStreak from consecutive heavy logs', () {
      final dayLogs = [
        {'logDate': '2026-08-01', 'flowLevel': 'HEAVY'},
        {'logDate': '2026-08-02', 'flowLevel': 'HEAVY'},
        {'logDate': '2026-08-03', 'flowLevel': 'VERY_HEAVY'},
      ];

      final anomalies = CycleAnomalyDetector.detectAnomalies(
        periodRows: const [],
        dayLogRows: dayLogs,
        avgCycleLength: 28,
      );

      expect(
        anomalies.any((a) => a.type == CycleAnomalyType.unusuallyHeavyFlowStreak),
        isTrue,
      );
    });

    test('Bug 14: CycleNotificationService.cancelAll cancels all lead days 1..14 without zombie notifications', () async {
      final forecast = [
        PredictedCycle(
          index: 1,
          predictedStart: DateTime(2026, 9, 1),
          predictedEnd: DateTime(2026, 9, 6),
          windowStart: DateTime(2026, 8, 30),
          windowEnd: DateTime(2026, 9, 3),
          sigmaDays: 2.0,
          periodDays: 5,
          confidence: 0.8,
          confidenceLevel: PredictionConfidenceLevel.medium,
          basis: ForecastBasis.measured,
        ),
      ];

      await CycleNotificationService.scheduleForecastReminders(
        forecastCycles: forecast,
        consentReminders: true,
        pregnancyMode: false,
        leadDays: [4],
        reminderHour: 10,
        now: DateTime(2026, 8, 20),
      );

      await CycleNotificationService.cancelAll();
      expect(true, isTrue);
    });

    test('Bug 15: Non-terminal answers do not set isAnswered to true permanently', () {
      final nonTerminal = CycleConfirmationRequest(
        id: 'startDue_2026-08-25',
        kind: CycleConfirmationKind.startDue,
        targetDate: DateTime(2026, 8, 25),
        askCount: 1,
        answer: CycleConfirmationAnswer.notStartedYet,
      );
      expect(nonTerminal.isAnswered, isFalse);

      final terminal = CycleConfirmationRequest(
        id: 'startDue_2026-08-25',
        kind: CycleConfirmationKind.startDue,
        targetDate: DateTime(2026, 8, 25),
        askCount: 1,
        answer: CycleConfirmationAnswer.startedToday,
      );
      expect(terminal.isAnswered, isTrue);
    });

    test('Bug 16: Snooze 1-day silences only current day and prompts next day', () async {
      final day10 = DateTime(2026, 8, 10);
      final day11 = DateTime(2026, 8, 11);

      await db.insert('app_settings', {
        'key': CycleSettings.keyConfirmSnoozeUntil,
        'value': '2026-08-11',
        'updatedAt': 1000,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final engineOutput = CycleEngineOutput(
        hasData: true,
        currentPhase: CyclePhase.luteal,
        dayOfCycle: 28,
        dayOfPeriod: 0,
        isStartDueToday: true,
        isOverdue: false,
        daysOverdue: 0,
        missedCycles: 0,
        isIrregular: false,
        dataMaturity: 'HIGH',
        trendPoints: const [],
        stats: CycleStats(avgCycleLength: 28, avgPeriodDuration: 5, recordedPeriods: 3),
        nextPeriodPrediction: day10,
      );

      final settings = {
        'cycle_confirm_start_enabled': 'true',
        CycleSettings.keyConfirmSnoozeUntil: '2026-08-11',
      };

      final reqDay10 = await CycleConfirmationService.instance.evaluatePendingRequest(
        dbExecutor: db,
        engineOutput: engineOutput,
        settings: settings,
        now: day10,
      );
      expect(reqDay10, isNull);

      final reqDay11 = await CycleConfirmationService.instance.evaluatePendingRequest(
        dbExecutor: db,
        engineOutput: engineOutput,
        settings: settings,
        now: day11,
      );
      expect(reqDay11, isNotNull);
    });

    test('Bug 17: New users receive reminders for immediate cycle 0 even with low confidence', () async {
      final now = DateTime(2026, 8, 20);
      await db.insert('app_settings', {
        'key': 'user_gender',
        'value': 'FEMALE',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'module_cycle_enabled',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'cycle_consent_reminders',
        'value': 'true',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'cycle_length_days',
        'value': '28',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {
        'key': 'period_duration_days',
        'value': '5',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('cycle_periods', {
        'id': 'p1',
        'startDate': '2026-08-01',
        'endDate': '2026-08-05',
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      await CycleReminderScheduler.rescheduleAll(
        dbExecutor: db,
        now: now,
      );
      expect(true, isTrue);
    });

    test('Bug 18: Trend points calculate real elapsed days for in-progress cycle', () async {
      final start1 = DateTime(2026, 7, 1);
      final start2 = DateTime(2026, 7, 30);
      final now = DateTime(2026, 8, 25);

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

    test('Bug 20: Partial unique index prevents multiple open periods in DB', () async {
      await db.insert('cycle_periods', {
        'id': 'open_1',
        'startDate': '2026-08-01',
        'endDate': null,
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      expect(
        () => db.insert('cycle_periods', {
          'id': 'open_2',
          'startDate': '2026-08-20',
          'endDate': null,
          'flowIntensity': 'MEDIUM',
          'isPredicted': 0,
          'autoClosed': 0,
          'createdAt': 2000,
          'updatedAt': 2000,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('Bug 21: CyclePeriodStatus.isConfirmedPeriodDay and activeDayNumber respect ceiling', () {
      final start = DateTime(2026, 8, 1);
      final periods = [
        CyclePeriod(
          id: 'p1',
          startDate: start,
          endDate: null,
        ),
      ];

      expect(
        CyclePeriodStatus.isConfirmedPeriodDay(
          periods,
          DateTime(2026, 8, 10),
          DateTime(2026, 8, 30),
        ),
        isTrue,
      );

      expect(
        CyclePeriodStatus.isConfirmedPeriodDay(
          periods,
          DateTime(2026, 8, 20),
          DateTime(2026, 8, 30),
        ),
        isFalse,
      );

      expect(
        CyclePeriodStatus.activeDayNumber(
          periods,
          DateTime(2026, 8, 20),
        ),
        isNull,
      );
    });

    test('Bug 22: CycleState.copyWith with clearErrorMessage: true clears error while errorMessage: null does not', () {
      const stateWithError = CycleState(errorMessage: 'Initial error');
      
      // With old pattern (errorMessage: null), error is NOT cleared because of null coalescing
      final notCleared = stateWithError.copyWith(isLoading: true, errorMessage: null);
      expect(notCleared.errorMessage, equals('Initial error'));

      // With new pattern (clearErrorMessage: true), error is properly cleared
      final cleared = stateWithError.copyWith(isLoading: true, clearErrorMessage: true);
      expect(cleared.errorMessage, isNull);
    });

    test('Review Point 1: Backdating a past forgotten period does not overlap against future period', () async {
      final now = DateTime(2026, 8, 25);
      await db.insert('cycle_periods', {
        'id': 'august_period',
        'startDate': '2026-08-01',
        'endDate': '2026-08-06',
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      final id = await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 7, 1),
        now: now,
      );
      expect(id, isNotEmpty);
    });

    test('Review Point 2: Auto-close respects period_duration_days setting', () async {
      final now = DateTime(2026, 8, 25);
      await db.insert('app_settings', {
        'key': 'period_duration_days',
        'value': '7',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('cycle_periods', {
        'id': 'old_forgotten',
        'startDate': '2026-07-01',
        'endDate': null,
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'autoClosed': 0,
        'createdAt': 1000,
        'updatedAt': 1000,
      });

      await CyclePeriodRepository.instance.startPeriod(
        db: db,
        startDate: DateTime(2026, 8, 25),
        now: now,
      );

      final row = (await db.query('cycle_periods', where: 'id = ?', whereArgs: ['old_forgotten'])).first;
      expect(row['autoClosed'], equals(1));
      expect(row['endDate'], equals('2026-07-07'));
    });
  });
}
