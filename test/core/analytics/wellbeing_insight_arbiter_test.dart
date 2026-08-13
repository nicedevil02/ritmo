import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/mood_engine.dart';
import 'package:ritmo/core/analytics/reflection_engine.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_loop.dart';
import 'package:ritmo/core/analytics/wellbeing_triple_chain.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

void main() {
  const arbiter = WellbeingInsightArbiter();
  final now = DateTime(2026, 8, 13);

  WellbeingInsight insight({
    required WellbeingInsightKind kind,
    required WellbeingInsightMaturity maturity,
    required double score,
    int have = 1,
    int need = 1,
  }) {
    return WellbeingInsight(
      kind: kind,
      maturity: maturity,
      title: kind.name,
      body: kind.name,
      score: score,
      have: have,
      need: need,
    );
  }

  SleepEngineOutput sleepOut({SleepLog? lastNight, double balance = 0.2}) {
    return SleepEngineOutput(
      lastNight: lastNight,
      avgDurationMinutes: 450,
      avgQuality: 4,
      sleepDebtMinutes: 0,
      sleepBalanceHours: balance,
      durationTrend: const [],
      qualityTrend: const [],
      correlationInsight: 'در حال یادگیری الگوی خواب شما 🌙',
    );
  }

  final loggedNight = SleepLog(
    date: '2026-08-12',
    reason: '',
    createdAt: 0,
    durationMinutes: 450,
    quality: SleepQuality.good,
  );

  test('empty input yields no featured narrative', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(now: now));
    expect(snap.featured, isNull);
    expect(snap.ready, isEmpty);
  });

  test('never-used sleep stays growing and does not monopolize', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 0,
      sleep: SleepEngineOutput(
        avgDurationMinutes: 0,
        avgQuality: 0,
        sleepDebtMinutes: 0,
        sleepBalanceHours: 0,
        durationTrend: const [],
        qualityTrend: const [],
        correlationInsight: 'در حال یادگیری الگوی خواب شما 🌙',
      ),
    ));
    expect(snap.featured, isNull);
    expect(
      snap.growing.any((c) => c.kind == WellbeingInsightKind.lastNightSleep),
      isTrue,
    );
  });

  test('sleep history without last night becomes a ready prompt', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 4,
      sleep: sleepOut(lastNight: null, balance: -0.2),
    ));
    expect(snap.featured?.kind, WellbeingInsightKind.lastNightSleep);
    expect(snap.featured?.action, WellbeingInsightAction.logSleep);
  });

  test('ready mood correlation is featured when last night is already logged', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 8,
      moodLogCount: 30,
      energyLogCount: 30,
      sleep: sleepOut(lastNight: loggedNight),
      mood: MoodEngineOutput(
        dominantMood: Mood.happy,
        moodTrend: const [4, 5],
        moodByDaypart: const {},
        energyMoodCorrelation: 0.72,
        correlationInsight: 'همبستگی قوی و مثبتی بین انرژی بدنی و حال روحی شما دیده می‌شود',
      ),
    ));
    expect(snap.featured?.kind, WellbeingInsightKind.moodEnergyLink);
  });

  test('placeholder correlation text stays growing, not ready', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      moodLogCount: 8,
      energyLogCount: 8,
      mood: MoodEngineOutput(
        moodTrend: const [3, 3],
        moodByDaypart: const {},
        energyMoodCorrelation: null,
        correlationInsight: 'داده‌های ثبت‌شده برای تحلیل همبستگی هنوز کافی نیست.',
      ),
    ));
    expect(snap.featured?.kind, WellbeingInsightKind.moodEnergyLink);
    expect(snap.featured?.maturity, WellbeingInsightMaturity.growing);
  });

  test('forgiven streak names the weekly token', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 3,
      reflectionCount: 5,
      sleep: sleepOut(lastNight: loggedNight),
      reflection: ReflectionEngineOutput(
        currentStreak: 5,
        longestStreak: 3,
        entryCount: 5,
        completionRate: 0.5,
        avgMoodScore: 4,
        moodTrend: const [4],
        themeFrequency: const {},
        correlationInsight: 'در حال تحلیل همبستگی خودمراقبتی شما 🧐',
        forgivenThisWeek: true,
        forgivenessAvailable: false,
      ),
    ));
    expect(snap.featured?.kind, WellbeingInsightKind.reflectionStreak);
    expect(snap.featured?.title, contains('بخشش'));
  });

  test('improved loop outcome after 7 days outranks other ready stories', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 8,
      sleep: sleepOut(lastNight: loggedNight, balance: 1.2),
      loopPrevious: const WellbeingInsightLoopState(
        kindName: 'sleepBank',
        date: '2026-08-06',
        metric: 0.2,
      ),
    ));
    expect(snap.featured?.kind, WellbeingInsightKind.loopOutcome);
    expect(snap.featured?.title, contains('اثر داشت'));
  });

  test('loop outcome stays silent before seven days', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 8,
      sleep: sleepOut(lastNight: loggedNight, balance: 1.2),
      loopPrevious: const WellbeingInsightLoopState(
        kindName: 'sleepBank',
        date: '2026-08-10',
        metric: 0.2,
      ),
    ));
    expect(
      snap.ready.any((c) => c.kind == WellbeingInsightKind.loopOutcome),
      isFalse,
    );
  });

  test('triple chain is ready only with enough complete weekday triples', () {
    SleepLog night(String date) => SleepLog(
          date: date,
          reason: '',
          createdAt: 0,
          durationMinutes: 300,
          quality: SleepQuality.poor,
        );
    EnergyLog morning(DateTime day) => EnergyLog(
          id: 'e${day.millisecondsSinceEpoch}',
          energyLevel: EnergyLevel.low,
          source: 'TEST',
          loggedAt: DateTime(day.year, day.month, day.day, 8).millisecondsSinceEpoch,
        );
    MoodLog afternoon(DateTime day) => MoodLog(
          id: 'm${day.millisecondsSinceEpoch}',
          mood: Mood.sad,
          valence: 2,
          loggedAt: DateTime(day.year, day.month, day.day, 16).millisecondsSinceEpoch,
        );

    final nextDays = [
      DateTime(2026, 7, 16),
      DateTime(2026, 7, 23),
      DateTime(2026, 7, 30),
      DateTime(2026, 8, 6),
    ];
    final hit = const WellbeingTripleChain().detect(
      sleepLogs: ['2026-07-15', '2026-07-22', '2026-07-29', '2026-08-05'].map(night).toList(),
      energyLogs: nextDays.map(morning).toList(),
      moodLogs: nextDays.map(afternoon).toList(),
      targetSleepHours: 7.5,
    );
    expect(hit, isNotNull);
    expect(hit!.hits, 4);
    expect(hit.rate, 1.0);

    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 4,
      energyLogCount: 4,
      moodLogCount: 4,
      sleep: sleepOut(lastNight: loggedNight),
      sleepLogs: ['2026-07-15', '2026-07-22', '2026-07-29', '2026-08-05'].map(night).toList(),
      energyLogs: nextDays.map(morning).toList(),
      moodLogs: nextDays.map(afternoon).toList(),
      targetSleepHours: 7.5,
    ));
    expect(snap.featured?.kind, WellbeingInsightKind.tripleChain);
  });

  test('pickFeatured prefers ready over growing', () {
    final featured = arbiter.pickFeatured(
      ready: [
        insight(kind: WellbeingInsightKind.indexDriver, maturity: WellbeingInsightMaturity.ready, score: 0.78),
      ],
      growing: [
        insight(kind: WellbeingInsightKind.goldenWindow, maturity: WellbeingInsightMaturity.growing, score: 0.9, have: 10, need: 20),
      ],
      now: now,
    );
    expect(featured?.kind, WellbeingInsightKind.indexDriver);
  });

  test('near-tied ready insights rotate by calendar day', () {
    final ready = [
      insight(kind: WellbeingInsightKind.goldenWindow, maturity: WellbeingInsightMaturity.ready, score: 1.08),
      insight(kind: WellbeingInsightKind.balanceTrend, maturity: WellbeingInsightMaturity.ready, score: 1.00),
    ];
    final a = arbiter.pickFeatured(ready: ready, growing: const [], now: DateTime(2026, 1, 1));
    final b = arbiter.pickFeatured(ready: ready, growing: const [], now: DateTime(2026, 1, 2));
    expect(a?.kind, isNot(b?.kind));
  });
}
