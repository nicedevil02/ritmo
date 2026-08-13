import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/mood_engine.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
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
    expect(
      snap.ready.any((c) => c.kind == WellbeingInsightKind.lastNightSleep),
      isFalse,
    );
  });

  test('sleep history without last night becomes a ready prompt', () {
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 4,
      sleep: SleepEngineOutput(
        avgDurationMinutes: 420,
        avgQuality: 3,
        sleepDebtMinutes: 30,
        sleepBalanceHours: -0.2,
        durationTrend: const [],
        qualityTrend: const [],
        correlationInsight: 'در حال یادگیری الگوی خواب شما 🌙',
      ),
    ));
    expect(snap.featured?.kind, WellbeingInsightKind.lastNightSleep);
    expect(snap.featured?.maturity, WellbeingInsightMaturity.ready);
    expect(snap.featured?.action, WellbeingInsightAction.logSleep);
  });

  test('ready mood correlation is featured when last night is already logged', () {
    final lastNight = SleepLog(
      date: '2026-08-12',
      reason: '',
      createdAt: 0,
      durationMinutes: 450,
      quality: SleepQuality.good,
    );
    final snap = arbiter.evaluate(WellbeingInsightInput(
      now: now,
      sleepLogCount: 8,
      moodLogCount: 30,
      energyLogCount: 30,
      sleep: SleepEngineOutput(
        lastNight: lastNight,
        avgDurationMinutes: 450,
        avgQuality: 4,
        sleepDebtMinutes: 0,
        sleepBalanceHours: 0.2,
        durationTrend: const [],
        qualityTrend: const [],
        correlationInsight: 'در حال یادگیری الگوی خواب شما 🌙',
      ),
      mood: MoodEngineOutput(
        dominantMood: Mood.happy,
        moodTrend: const [4, 5],
        moodByDaypart: const {},
        energyMoodCorrelation: 0.72,
        correlationInsight: 'همبستگی قوی و مثبتی بین انرژی بدنی و حال روحی شما دیده می‌شود',
      ),
    ));
    expect(snap.featured?.kind, WellbeingInsightKind.moodEnergyLink);
    expect(snap.featured?.maturity, WellbeingInsightMaturity.ready);
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
    expect(
      snap.ready.any((c) => c.kind == WellbeingInsightKind.moodEnergyLink),
      isFalse,
    );
    expect(snap.featured?.kind, WellbeingInsightKind.moodEnergyLink);
    expect(snap.featured?.maturity, WellbeingInsightMaturity.growing);
    expect(snap.featured?.have, 8);
    expect(snap.featured?.need, 30);
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
    expect({a?.kind, b?.kind}, containsAll([WellbeingInsightKind.goldenWindow, WellbeingInsightKind.balanceTrend]));
  });
}
