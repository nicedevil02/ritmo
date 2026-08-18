import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/wellbeing/data/wellbeing_daily_repository.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/daily_rhythm_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/dynamic_energy_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/index_trend_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/mood_analytics_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/narrative_inbox_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/reflection_themes_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/sleep_overview_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_day_sheet.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_pulse_chart.dart';
import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/analytics/mood_engine.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(
      extensions: [
        RitmoColors.light,
      ],
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wellbeing Analytical Cards Smoke Tests', () {
    testWidgets('IndexTrendCard renders empty and rich states without overflow', (tester) async {
      await tester.pumpWidget(_wrap(
        const IndexTrendCard(records: [], horizonDays: 14),
      ));
      expect(find.text('روند شاخص حال و تعادل'), findsOneWidget);
      expect(find.textContaining('حداقل به ۳ روز ثبت نیاز است'), findsOneWidget);

      final richRecords = [
        const WellbeingDailyRecord(date: '2026-08-10', indexValue: 60, confidence: 0.8, computedAt: 1000),
        const WellbeingDailyRecord(date: '2026-08-11', indexValue: 70, confidence: 0.9, computedAt: 2000),
        const WellbeingDailyRecord(date: '2026-08-12', indexValue: 80, confidence: 0.85, computedAt: 3000),
      ];
      await tester.pumpWidget(_wrap(
        IndexTrendCard(records: richRecords, horizonDays: 14),
      ));
      expect(find.text('آخرین شاخص'), findsOneWidget);
      expect(find.text('میانگین بازه'), findsOneWidget);
    });

    testWidgets('DynamicEnergyCard renders empty and rich states with collapsible explanation', (tester) async {
      await tester.pumpWidget(_wrap(
        DynamicEnergyCard(output: null, onLogTap: () {}),
      ));
      expect(find.text('انرژی الانِ من'), findsOneWidget);

      final richOutput = EnergyAnalyticsOutput(
        currentDynamicEnergy: 0.75,
        currentDynamicEnergyExplanations: const ['سهم خواب دیشب: +۲۰٪', 'سهم ریتم زیستی: +۱۵٪'],
      );
      await tester.pumpWidget(_wrap(
        DynamicEnergyCard(output: richOutput, onLogTap: () {}),
      ));
      expect(find.text('انرژی در اوج ⚡'), findsOneWidget);
      expect(find.text('چرا این عدد؟'), findsOneWidget);

      await tester.tap(find.text('چرا این عدد؟'));
      await tester.pumpAndSettle();
      expect(find.textContaining('سهم خواب دیشب'), findsOneWidget);
    });

    testWidgets('DailyRhythmCard renders timeline and windows without overflow', (tester) async {
      final output = EnergyAnalyticsOutput(
        peakPerformanceWindow: '09:00 - 12:00',
        mostFatiguedWindow: '14:00 - 16:00',
        mostProductiveWeekday: 'Monday',
      );
      await tester.pumpWidget(_wrap(
        DailyRhythmCard(output: output),
      ));
      expect(find.text('ریتم شبانه‌روزی انرژی'), findsOneWidget);
      expect(find.textContaining('دوشنبه'), findsOneWidget);
    });

    testWidgets('MoodAnalyticsCard renders dominant mood, correlation and dayparts', (tester) async {
      final output = MoodEngineOutput(
        dominantMood: Mood.happy,
        moodTrend: const [4.0, 4.5, 4.2],
        correlationInsight: 'رابطهٔ مستقیم بین خواب خوب و انرژی بالا',
        moodByDaypart: const {
          'morning': Mood.happy,
          'afternoon': Mood.calm,
          'evening': Mood.neutral,
          'night': Mood.happy,
        },
      );
      await tester.pumpWidget(_wrap(
        MoodAnalyticsCard(output: output),
      ));
      expect(find.text('تحلیل حالِ این بازه'), findsOneWidget);
      expect(find.text('حال غالب: شاد'), findsOneWidget);
      expect(find.text('حال در بخش‌های روز'), findsOneWidget);
    });

    testWidgets('SleepOverviewCard renders 4 key metrics', (tester) async {
      final output = SleepEngineOutput(
        avgDurationMinutes: 480,
        avgQuality: 4.0,
        sleepDebtMinutes: 0,
        sleepBalanceHours: 0.0,
        consistencyScore: 85,
        durationTrend: const [],
        qualityTrend: const [],
        correlationInsight: '',
      );
      await tester.pumpWidget(_wrap(
        SleepOverviewCard(
          output: output,
          target: SleepTarget.defaultTarget(),
          sleepLogCount: 5,
        ),
      ));
      expect(find.text('خواب این بازه'), findsOneWidget);
      expect(find.text('میانگین مدت'), findsOneWidget);
      expect(find.text('بدهی خواب'), findsOneWidget);
      expect(find.text('یکنواختی خواب'), findsOneWidget);
    });

    testWidgets('ReflectionThemesCard renders top keyword chips', (tester) async {
      final themes = {'شکرگزاری': 12, 'خانواده': 9, 'ورزش': 7, 'کتاب': 5};
      await tester.pumpWidget(_wrap(
        ReflectionThemesCard(themes: themes, reflectionCount: 10),
      ));
      expect(find.text('موضوع‌های پرتکرار'), findsOneWidget);
      expect(find.text('شکرگزاری'), findsOneWidget);
      expect(find.text('(۱۲)'), findsOneWidget);
    });

    testWidgets('NarrativeInboxCard renders ready carousel and growing list', (tester) async {
      const readyInsight = WellbeingInsight(
        kind: WellbeingInsightKind.moodEnergyLink,
        maturity: WellbeingInsightMaturity.ready,
        title: 'همبستگی حال و انرژی',
        body: 'روزهایی که انرژی بالاتر است، حال روحی نیز بهتر ثبت شده است.',
        score: 1.2,
        have: 7,
        need: 7,
      );
      const growingInsight = WellbeingInsight(
        kind: WellbeingInsightKind.sleepPlanStep,
        maturity: WellbeingInsightMaturity.growing,
        title: 'الگوی خواب',
        body: 'ثبت ۳ شب دیگر برای تخمین ریتم لازم است.',
        score: 0.5,
        have: 4,
        need: 7,
      );
      const snapshot = WellbeingInsightSnapshot(
        ready: [readyInsight],
        growing: [growingInsight],
      );
      await tester.pumpWidget(_wrap(
        NarrativeInboxCard(snapshot: snapshot, onAction: (_) {}),
      ));
      expect(find.text('سایر بینش‌های امروز'), findsOneWidget);
      expect(find.text('الگوهای در حال یادگیری'), findsOneWidget);
    });

    testWidgets('WellbeingDaySheet renders all signal rows and actions', (tester) async {
      const day = WellbeingPulseDayData(
        dateStr: '2026-08-18',
        sleepHours: 7.5,
        energyLevel: 2.5,
        moodScore: 4.0,
        hasReflection: true,
      );
      await tester.pumpWidget(_wrap(
        const WellbeingDaySheet(day: day),
      ));
      expect(find.textContaining('خواب:'), findsOneWidget);
      expect(find.textContaining('انرژی:'), findsOneWidget);
      expect(find.textContaining('حال:'), findsOneWidget);
      expect(find.textContaining('بازتاب ثبت شده است'), findsOneWidget);
    });
  });
}
