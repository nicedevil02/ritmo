import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/sleep_program_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/features/sleep/logic/sleep_plan_insights.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/sleep/models/sleep_plan_day.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';

void main() {
  const engine = SleepProgramEngine();
  final now = DateTime(2026, 8, 13, 21, 0); // پنجشنبه
  final target =
      SleepTarget(bedtime: '23:30', wake: '07:00', durationMinutes: 450);

  SleepProgram program({
    SleepProgramStatus status = SleepProgramStatus.active,
    int? freeNightWeekday,
  }) =>
      SleepProgram(
        id: 'sp_test',
        status: status,
        freeNightWeekday: freeNightWeekday,
        createdAt: 0,
        updatedAt: 0,
      );

  SleepLog night(String date, int bedMin) {
    final day = DateTime.parse(date);
    return SleepLog(
      date: date,
      reason: '',
      createdAt: 0,
      bedtimeAt: day.add(Duration(minutes: bedMin)).millisecondsSinceEpoch,
      durationMinutes: 450,
      quality: SleepQuality.good,
    );
  }

  List<SleepLog> sevenNights(int bedMin) => [
        for (var i = 7; i >= 1; i--)
          night('2026-08-${(13 - i).toString().padLeft(2, '0')}', bedMin),
      ];

  SleepPlanDay plan(String date, int plannedMin, SleepPlanOutcome outcome) =>
      SleepPlanDay(
        programId: 'sp_test',
        date: date,
        plannedBedtimeMin: plannedMin,
        plannedWakeMin: 420,
        outcome: outcome,
      );

  Future<SleepProgramState> stateOf({
    SleepProgram? p,
    List<SleepPlanDay> plans = const [],
    List<SleepLog>? logs,
  }) =>
      engine.calculate(SleepProgramInput(
        program: p ?? program(),
        planDays: plans,
        sleepLogs: logs ?? sevenNights(1410),
        target: target,
        now: now,
      ));

  /// وضعیت فعال با ردیف فریزشدهٔ امشب روی ۰۰:۰۰
  Future<SleepProgramState> frozenState({int? freeNightWeekday}) => stateOf(
        p: program(freeNightWeekday: freeNightWeekday),
        plans: [
          plan('2026-08-11', 0, SleepPlanOutcome.hit),
          plan('2026-08-12', 0, SleepPlanOutcome.hit),
          plan('2026-08-13', 0, SleepPlanOutcome.pending),
        ],
      );

  test('فاز گوش دادن ⇒ نامزد growing با دعوت به ثبت', () async {
    final state = await stateOf(
      p: program(status: SleepProgramStatus.listening),
      logs: sevenNights(1410).take(4).toList(),
    );
    final cards = SleepPlanInsights.build(state: state, sleepLogCount: 4);

    expect(cards.length, 1);
    expect(cards.first.kind, WellbeingInsightKind.sleepPlanStep);
    expect(cards.first.maturity, WellbeingInsightMaturity.growing);
    expect(cards.first.action, WellbeingInsightAction.logSleep);
    expect(cards.first.have, 4);
    expect(cards.first.need, SleepProgramEngine.minNightsForListening);
  });

  test('برنامهٔ متوقف‌شده هیچ کارتی نمی‌سازد', () async {
    final state = await stateOf(p: program(status: SleepProgramStatus.paused));
    expect(SleepPlanInsights.build(state: state), isEmpty);
  });

  test('کارت پله پنجرهٔ زمانی خودش را دارد و عنوانش ساعت فارسی است', () async {
    final state = await frozenState();
    final card = SleepPlanInsights.build(state: state).first;

    expect(card.maturity, WellbeingInsightMaturity.ready);
    expect(card.timeWindow?.fromMin, 1350);
    expect(card.timeWindow?.toMin, 30);
    expect(card.title, contains('۰۰:۰۰'));
    expect(card.effectiveGroup, InsightGroup.sleep);
    expect(card.action, WellbeingInsightAction.openSleepTarget);
  });

  test('شب آزاد پیام بدون انتظار می‌دهد و دکمهٔ تنظیم ندارد', () async {
    final state = await frozenState(freeNightWeekday: DateTime.thursday);
    final card = SleepPlanInsights.build(state: state).first;

    expect(state.freeNightTonight, isTrue);
    expect(card.title, contains('آزاد'));
    expect(card.action, isNull);
  });

  test('همیشه حداکثر یک جملهٔ پشتیبان در متن کارت هست', () async {
    final state = await frozenState();
    final body = SleepPlanInsights.build(state: state).first.body;
    // دو جمله: متن اصلی + حداکثر یک پشتیبان
    expect('.'.allMatches(body).length, lessThanOrEqualTo(2));
  });

  test('داخل پنجره، پلهٔ امشب از یادآوری ثبت خواب جلو می‌زند', () async {
    final state = await frozenState();
    const base = WellbeingInsightSnapshot(ready: [
      WellbeingInsight(
        kind: WellbeingInsightKind.lastNightSleep,
        maturity: WellbeingInsightMaturity.ready,
        title: 'خواب دیشب ثبت نشده',
        body: '…',
        score: 1.35,
        have: 0,
        need: 1,
      ),
    ]);

    final atNight = SleepPlanInsights.merge(
      snapshot: base,
      state: state,
      now: DateTime(2026, 8, 13, 23, 10),
    );
    expect(atNight.featured?.kind, WellbeingInsightKind.sleepPlanStep);

    final atNoon = SleepPlanInsights.merge(
      snapshot: base,
      state: state,
      now: DateTime(2026, 8, 13, 12, 0),
    );
    expect(atNoon.featured?.kind, WellbeingInsightKind.lastNightSleep);
  });

  test('ناسازگاری هدف یک نامزد جداگانه می‌سازد', () async {
    final plans = [
      for (var i = 20; i >= 1; i--)
        plan(
          '2026-07-${(24 + i % 8).toString().padLeft(2, '0')}',
          1410,
          i % 5 == 0 ? SleepPlanOutcome.hit : SleepPlanOutcome.miss,
        ),
    ];
    final state = await stateOf(plans: plans);
    final cards = SleepPlanInsights.build(state: state);

    expect(state.goalMismatch, isTrue);
    expect(
      cards.map((c) => c.kind),
      contains(WellbeingInsightKind.sleepGoalMismatch),
    );
  });

  test('hhmm رقم فارسی و دورزدن نیمه‌شب را درست می‌دهد', () {
    expect(SleepPlanInsights.hhmm(1410), '۲۳:۳۰');
    expect(SleepPlanInsights.hhmm(0), '۰۰:۰۰');
    expect(SleepPlanInsights.hhmm(1470), '۰۰:۳۰');
    expect(SleepPlanInsights.hhmm(-30), '۲۳:۳۰');
  });
}
