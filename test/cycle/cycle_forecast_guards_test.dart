// C-43..C-48, F-43..F-50: Comprehensive Forecast & Source Guard Tests
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_view.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    CycleClock.nowProvider = () => DateTime(2026, 8, 1);
  });

  tearDown(() {
    CycleClock.resetNow();
  });

  group('Phase 5 Forecast Guard Tests (F-43..F-50)', () {
    test('F-43: Forecast Horizon Length — 6 regular cycles generate 12 cycles up to 336 days', () {
      final lastStart = DateTime(2026, 7, 1);
      final forecast = CycleEngine.computeMultiCycleForecast(
        lastPeriodStart: lastStart,
        avgCycleLength: 28.0,
        avgPeriodDuration: 6.0,
        cycleStdDev: 1.0,
        dataMaturity: 'ESTABLISHED',
        settings: {},
        horizonCycles: 12,
      );

      expect(forecast.length, equals(12));
      expect(forecast[0].predictedStart, equals(DateTime(2026, 7, 29)));
      expect(forecast[11].predictedStart, equals(DateTime(2026, 7, 1).add(const Duration(days: 12 * 28))));
    });

    test('F-44: Uncertainty Growth — sigmaDays expands monotonically and scales with anomaly variance', () {
      // 1. Regular data
      final regularForecast = CycleEngine.computeMultiCycleForecast(
        lastPeriodStart: DateTime(2026, 7, 1),
        avgCycleLength: 28.0,
        avgPeriodDuration: 6.0,
        cycleStdDev: 1.0,
        dataMaturity: 'ESTABLISHED',
        settings: {},
        horizonCycles: 6,
      );

      for (var i = 0; i < regularForecast.length - 1; i++) {
        expect(regularForecast[i + 1].sigmaDays, greaterThanOrEqualTo(regularForecast[i].sigmaDays));
      }

      // 2. Irregular data
      final irregularForecast = CycleEngine.computeMultiCycleForecast(
        lastPeriodStart: DateTime(2026, 7, 1),
        avgCycleLength: 28.0,
        avgPeriodDuration: 6.0,
        cycleStdDev: 4.5, // Irregular stddev
        dataMaturity: 'ESTABLISHED',
        settings: {},
        horizonCycles: 6,
      );

      expect(irregularForecast[0].sigmaDays, greaterThan(regularForecast[0].sigmaDays));
    });

    test('F-45: Confidence Damping — confidence strictly non-increasing and damped for low maturity', () {
      final lowMaturityForecast = CycleEngine.computeMultiCycleForecast(
        lastPeriodStart: DateTime(2026, 7, 1),
        avgCycleLength: 28.0,
        avgPeriodDuration: 6.0,
        cycleStdDev: 2.0,
        dataMaturity: 'LOW',
        settings: {},
        horizonCycles: 8,
      );

      for (var i = 0; i < lowMaturityForecast.length - 1; i++) {
        expect(lowMaturityForecast[i + 1].confidence, lessThanOrEqualTo(lowMaturityForecast[i].confidence));
      }

      // In low maturity data, no cycle should be high confidence
      for (final c in lowMaturityForecast) {
        expect(c.confidenceLevel, isNot(equals(PredictionConfidenceLevel.high)));
      }
    });

    test('F-46: Distant Month Marking — buildMonthMarks returns marks for 6th future month', () {
      final baseDate = DateTime(2026, 1, 1);
      final forecast = CycleEngine.computeMultiCycleForecast(
        lastPeriodStart: baseDate,
        avgCycleLength: 28.0,
        avgPeriodDuration: 6.0,
        cycleStdDev: 1.5,
        dataMaturity: 'ESTABLISHED',
        settings: {},
        horizonCycles: 12,
      );

      // Month in Jalali 6 months ahead: Mordad 1405 (around July/August 2026)
      final distantMonth = Jalali(1405, 5, 1);
      final marks = CycleCalendarView.buildMonthMarks(
        month: distantMonth,
        periods: [],
        loggedDayKeys: {},
        forecast: forecast,
      );

      final hasPredictedDay = marks.values.any((m) => m.kind == CycleDayKind.predictedPeriod);
      expect(hasPredictedDay, isTrue);
    });

    test('F-47: Priority of Coloring — actual recorded period takes precedence over prediction window', () {
      final recordedDay = DateTime(2026, 8, 10);
      final marks = CycleCalendarView.buildMonthMarks(
        month: Jalali.fromDateTime(recordedDay),
        periods: [
          {'startDate': '2026-08-08', 'endDate': '2026-08-14'},
        ],
        loggedDayKeys: {},
        forecast: [
          PredictedCycle(
            index: 1,
            predictedStart: DateTime(2026, 8, 10),
            predictedEnd: DateTime(2026, 8, 15),
            windowStart: DateTime(2026, 8, 7),
            windowEnd: DateTime(2026, 8, 17),
            sigmaDays: 2.0,
            periodDays: 6,
            confidence: 0.8,
            confidenceLevel: PredictionConfidenceLevel.high,
            basis: ForecastBasis.measured,
          ),
        ],
      );

      final mark = marks['2026-08-10'];
      expect(mark, isNotNull);
      expect(mark!.kind, equals(CycleDayKind.recordedPeriod));
    });

    test('F-48: Cache Fingerprint — changing cycle_length_days setting shifts predictedStart and alters fingerprint', () {
      final fp28 = CycleEngine.computeInputFingerprint(
        settings: {CycleSettings.keyCycleLength: '28'},
        now: DateTime(2026, 8, 1),
        horizonCycles: 12,
      );

      final fp31 = CycleEngine.computeInputFingerprint(
        settings: {CycleSettings.keyCycleLength: '31'},
        now: DateTime(2026, 8, 1),
        horizonCycles: 12,
      );

      expect(fp28, isNot(equals(fp31)));

      final f28 = CycleEngine.computeMultiCycleForecast(
        lastPeriodStart: DateTime(2026, 7, 1),
        avgCycleLength: 28.0,
        avgPeriodDuration: 6.0,
        cycleStdDev: 1.0,
        dataMaturity: 'ESTABLISHED',
        settings: {CycleSettings.keyCycleLength: '28'},
        horizonCycles: 6,
      );

      final f31 = CycleEngine.computeMultiCycleForecast(
        lastPeriodStart: DateTime(2026, 7, 1),
        avgCycleLength: 31.0,
        avgPeriodDuration: 6.0,
        cycleStdDev: 1.0,
        dataMaturity: 'ESTABLISHED',
        settings: {CycleSettings.keyCycleLength: '31'},
        horizonCycles: 6,
      );

      expect(f28.first.predictedStart, equals(DateTime(2026, 7, 29)));
      expect(f31.first.predictedStart, equals(DateTime(2026, 8, 1)));
    });

    test('F-49: DST and Day Boundary — CycleDateContract.daysBetween avoids 1-day drift across DST', () {
      // Crossing standard clock changes without 23h/25h truncation errors
      final d1 = DateTime(2026, 3, 20, 23, 0);
      final d2 = DateTime(2026, 3, 22, 1, 0);

      final diffDays = CycleDateContract.daysBetween(d1, d2);
      expect(diffDays, equals(2));
    });

    test('F-50: Source Code Quality & Structural Guards', () {
      final cycleDir = Directory('lib/features/cycle');
      final files = cycleDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

      for (final file in files) {
        final content = file.readAsStringSync();
        // Check for empty silent catch blocks
        expect(
          content.contains('catch (_) {}') || content.contains('catch (e) {}'),
          isFalse,
          reason: 'Silent catch block found in ${file.path}',
        );
      }

      // Check cycle_calendar_view.dart for forbidden methods
      final calendarViewFile = File('lib/features/cycle/presentation/widgets/cycle_calendar_view.dart');
      final calendarViewContent = calendarViewFile.readAsStringSync();
      expect(calendarViewContent.contains('DateTime.parse('), isFalse);
      expect(calendarViewContent.contains('toIso8601String('), isFalse);
      expect(calendarViewContent.contains('_checkIs'), isFalse);

      // Check cycle_engine.dart for deprecated setting keys
      final engineFile = File('lib/core/domain/engines/cycle_engine.dart');
      final engineContent = engineFile.readAsStringSync();
      expect(engineContent.contains("'cycle_avg_length'"), isFalse);
      expect(engineContent.contains("'cycle_avg_period'"), isFalse);
    });
  });
}
