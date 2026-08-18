// F-35..F-42: Cycle Forecast UI, Honesty & Empty State Tests
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_empty_state_banner.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_prediction_detail_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';

Widget _buildTestWrapper(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('CycleEmptyStateBanner Reasoned State Tests (F-39)', () {
    testWidgets('Renders pregnancy mode banner when pregnancy mode is active', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          CycleEmptyStateBanner(
            periodsCount: 5,
            isPregnancyMode: true,
            calendarMonth: Jalali(1405, 5, 1),
            forecast: const [],
          ),
        ),
      );

      expect(find.text('حالت بارداری فعال است'), findsOneWidget);
    });

    testWidgets('Renders zero data banner when periods count is 0', (tester) async {
      var recordTapped = false;
      await tester.pumpWidget(
        _buildTestWrapper(
          CycleEmptyStateBanner(
            periodsCount: 0,
            isPregnancyMode: false,
            calendarMonth: Jalali(1405, 5, 1),
            forecast: const [],
            onRecordFirstPeriod: () => recordTapped = true,
          ),
        ),
      );

      expect(find.text('هنوز دوره‌ای ثبت نشده است'), findsOneWidget);
      expect(find.text('ثبت اولین دوره'), findsOneWidget);

      await tester.tap(find.text('ثبت اولین دوره'));
      expect(recordTapped, isTrue);
    });

    testWidgets('Renders low data banner when periods count is < 3', (tester) async {
      await tester.pumpWidget(
        _buildTestWrapper(
          CycleEmptyStateBanner(
            periodsCount: 2,
            isPregnancyMode: false,
            calendarMonth: Jalali(1405, 5, 1),
            forecast: const [],
          ),
        ),
      );

      expect(find.text('پیش‌بینی با داده‌های اولیه'), findsOneWidget);
    });

    testWidgets('Renders horizon limit banner when viewing month beyond forecast', (tester) async {
      final forecast = [
        PredictedCycle(
          index: 1,
          predictedStart: DateTime(2026, 8, 1),
          predictedEnd: DateTime(2026, 8, 6),
          windowStart: DateTime(2026, 7, 30),
          windowEnd: DateTime(2026, 8, 8),
          sigmaDays: 2.0,
          periodDays: 6,
          confidence: 0.8,
          confidenceLevel: PredictionConfidenceLevel.high,
          basis: ForecastBasis.measured,
        ),
      ];

      // Month: 1406/1/1 (far beyond forecast)
      await tester.pumpWidget(
        _buildTestWrapper(
          CycleEmptyStateBanner(
            periodsCount: 5,
            isPregnancyMode: false,
            calendarMonth: Jalali(1406, 1, 1),
            forecast: forecast,
          ),
        ),
      );

      expect(find.text('فراتر از افق پیش‌بینی'), findsOneWidget);
    });
  });

  group('CyclePredictionDetailSheet Clinical Honesty Tests (F-38)', () {
    testWidgets('Displays disclaimer, basis, and uncertainty window correctly', (tester) async {
      final cycle = PredictedCycle(
        index: 1,
        predictedStart: DateTime(2026, 8, 15),
        predictedEnd: DateTime(2026, 8, 20),
        windowStart: DateTime(2026, 8, 12),
        windowEnd: DateTime(2026, 8, 22),
        sigmaDays: 2.0,
        periodDays: 6,
        confidence: 0.85,
        confidenceLevel: PredictionConfidenceLevel.high,
        basis: ForecastBasis.measured,
      );

      DateTime? recordedDate;

      await tester.pumpWidget(
        _buildTestWrapper(
          CyclePredictionDetailSheet(
            selectedDate: DateTime(2026, 8, 15),
            mark: CycleDayMark(
              kind: CycleDayKind.predictedPeriod,
              confidenceLevel: PredictionConfidenceLevel.high,
              predictedCycle: cycle,
            ),
            engineOutput: CycleEngineOutput(
              currentPhase: CyclePhase.follicular,
              dayOfCycle: 10,
              dayOfPeriod: 0,
              isIrregular: false,
              dataMaturity: 'ESTABLISHED',
              hasData: true,
              trendPoints: const [],
              stats: CycleStats(
                avgCycleLength: 28,
                avgPeriodDuration: 6,
                totalRecordedCycles: 5,
              ),
              forecast: [],
              predictionDisclaimer: 'این تاریخ‌ها صرفاً تخمین آماری هستند.',
            ),
            symptomForecasts: const [
              SymptomForecast(
                symptomKey: 'cramps',
                likelyCycleDay: 1,
                confidence: 0.9,
              ),
            ],
            onRecordPeriodFromDate: (d) => recordedDate = d,
          ),
        ),
      );

      expect(find.text('پیش‌بینی شروع دوره قاعدگی'), findsOneWidget);
      expect(find.text('این تاریخ‌ها صرفاً تخمین آماری هستند.'), findsOneWidget);
      expect(find.text('دل‌درد و انقباض'), findsOneWidget);
      expect(find.text('ثبت شروع قاعدگی از این روز'), findsOneWidget);

      await tester.tap(find.text('ثبت شروع قاعدگی از این روز'));
      expect(recordedDate, equals(DateTime(2026, 8, 15)));
    });
  });
}
