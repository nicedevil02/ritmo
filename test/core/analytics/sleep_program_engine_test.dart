import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/analytics/sleep_program_engine.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/sleep/models/sleep_plan_day.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';

void main() {
  const engine = SleepProgramEngine();
  // پنجشنبه ۱۳ اوت ۲۰۲۶، ساعت ۲۱:۰۰ (داخل پنجرهٔ عصر)
  final now = DateTime(2026, 8, 13, 21, 0);
  final target = SleepTarget(bedtime: '23:30', wake: '07:00', durationMinutes: 450);

  SleepProgram program({
    SleepProgramStatus status = SleepProgramStatus.active,
    int? freeNightWeekday,
  }) {
    return SleepProgram(
      id: 'sp_test',
      status: status,
      freeNightWeekday: freeNightWeekday,
      createdAt: 0,
      updatedAt: 0,
    );
  }

  SleepLog night(String date, int bedMin, {int? wakeMin}) {
    final day = DateTime.parse(date);
    return SleepLog(
      date: date,
      reason: '',
      createdAt: 0,
      bedtimeAt: day.add(Duration(minutes: bedMin)).millisecondsSinceEpoch,
      wakeAt: wakeMin != null
          ? day.add(Duration(minutes: wakeMin)).millisecondsSinceEpoch
          : null,
      durationMinutes: 450,
      quality: SleepQuality.good,
    );
  }

  SleepPlanDay plan(String date, int plannedMin, SleepPlanOutcome outcome) {
    return SleepPlanDay(
      programId: 'sp_test',
      date: date,
      plannedBedtimeMin: plannedMin,
      plannedWakeMin: 420,
      outcome: outcome,
    );
  }

  /// هفت شب معمولی با زمان خواب داده‌شده، تمام‌شده در ۱۲ اوت (دیشبِ now).
  List<SleepLog> sevenNights(int bedMin) {
    return [
      for (var i = 7; i >= 1; i--)
        night('2026-08-${(13 - i).toString().padLeft(2, '0')}', bedMin),
    ];
  }

  Future<SleepProgramState> run({
    SleepProgram? p,
    List<SleepPlanDay> plans = const [],
    List<SleepLog> logs = const [],
    DateTime? at,
  }) {
    return engine.calculate(SleepProgramInput(
      program: p ?? program(),
      planDays: plans,
      sleepLogs: logs,
      target: target,
      now: at ?? now,
    ));
  }

  group('فازها', () {
    test('کمتر از ۷ شب ⇒ listening و بدون کارت', () async {
      final state = await run(
        p: program(status: SleepProgramStatus.listening),
        logs: sevenNights(1410).take(6).toList(),
      );
      expect(state.status, SleepProgramStatus.listening);
      expect(state.hasCard, isFalse);
    });

    test('۷ شب ⇒ anchoring روی میانگین زمان خواب واقعی', () async {
      final state = await run(
        p: program(status: SleepProgramStatus.listening),
        logs: sevenNights(1410), // همهٔ شب‌ها ۲۳:۳۰
      );
      expect(state.status, SleepProgramStatus.anchoring);
      expect(state.tonightBedtimeMin, 1410);
    });

    test('با minNightsPerStep شب ارزیابی‌شده ⇒ active', () async {
      final state = await run(
        logs: sevenNights(1410),
        plans: [
          plan('2026-08-11', 1410, SleepPlanOutcome.hit),
          plan('2026-08-12', 1410, SleepPlanOutcome.hit),
        ],
      );
      expect(state.status, SleepProgramStatus.active);
    });

    test('paused دست‌نخورده می‌ماند', () async {
      final state = await run(
        p: program(status: SleepProgramStatus.paused),
        logs: sevenNights(1410),
      );
      expect(state.status, SleepProgramStatus.paused);
    });
  });

  group('لنگر دایره‌ای (نیمه‌شب)', () {
    test('circularMeanMinutes: 23:50 و 00:10 و 00:00 ⇒ 00:00 نه 12:00', () {
      expect(SleepProgramEngine.circularMeanMinutes([1430, 10, 0]), 0);
    });

    test('لنگرِ شب‌های دو طرف نیمه‌شب نزدیک نیمه‌شب است', () async {
      final logs = [
        night('2026-08-06', 1430),
        night('2026-08-07', 10),
        night('2026-08-08', 0),
        night('2026-08-09', 1435),
        night('2026-08-10', 5),
        night('2026-08-11', 0),
        night('2026-08-12', 1425),
      ];
      final state = await run(
        p: program(status: SleepProgramStatus.listening),
        logs: logs,
      );
      expect(state.status, SleepProgramStatus.anchoring);
      // باید نزدیک 00:00 باشد (۰ یا نزدیک 1440)، نه وسط روز
      final m = state.tonightBedtimeMin;
      expect(m <= 15 || m >= 1425, isTrue, reason: 'anchor was $m');
    });
  });

  group('پله‌ها در فاز active', () {
    test('۳ hit از ۵ ⇒ یک پله به سمت هدف (با عبور از نیمه‌شب)', () async {
      // پلهٔ فعلی 00:00 و هدف 23:30 ⇒ قدم بعدی 23:45 (زودتر)
      final state = await run(
        logs: sevenNights(1410),
        plans: [
          plan('2026-08-08', 0, SleepPlanOutcome.hit),
          plan('2026-08-09', 0, SleepPlanOutcome.hit),
          plan('2026-08-10', 0, SleepPlanOutcome.miss),
          plan('2026-08-11', 0, SleepPlanOutcome.hit),
          plan('2026-08-12', 0, SleepPlanOutcome.miss),
        ],
      );
      expect(state.status, SleepProgramStatus.active);
      expect(state.tonightBedtimeMin, 1425); // 23:45
      expect(state.holdTonight, isFalse);
    });

    test('۱ hit از ۵ ⇒ hold و بدون جلو رفتن', () async {
      final state = await run(
        logs: sevenNights(1410),
        plans: [
          plan('2026-08-08', 0, SleepPlanOutcome.miss),
          plan('2026-08-09', 0, SleepPlanOutcome.miss),
          plan('2026-08-10', 0, SleepPlanOutcome.hit),
          plan('2026-08-11', 0, SleepPlanOutcome.miss),
          plan('2026-08-12', 0, SleepPlanOutcome.miss),
        ],
      );
      expect(state.holdTonight, isTrue);
      expect(state.tonightBedtimeMin, 0);
    });

    test('فاصلهٔ کمتر از یک پله ⇒ snap روی هدف', () async {
      final state = await run(
        logs: sevenNights(1410),
        plans: [
          plan('2026-08-09', 1420, SleepPlanOutcome.hit),
          plan('2026-08-10', 1420, SleepPlanOutcome.hit),
          plan('2026-08-11', 1420, SleepPlanOutcome.hit),
          plan('2026-08-12', 1420, SleepPlanOutcome.miss),
        ],
      );
      expect(state.tonightBedtimeMin, 1410); // دقیقاً هدف 23:30
      expect(state.stepsRemaining, 0);
    });

    test('اگر ردیف امشب از قبل فریز شده باشد، همان برمی‌گردد', () async {
      final state = await run(
        logs: sevenNights(1410),
        plans: [
          plan('2026-08-11', 0, SleepPlanOutcome.hit),
          plan('2026-08-12', 0, SleepPlanOutcome.hit),
          plan('2026-08-13', 0, SleepPlanOutcome.pending), // امشب، فریزشده روی 00:00
        ],
      );
      expect(state.tonightDate, '2026-08-13');
      expect(state.tonightBedtimeMin, 0);
    });
  });

  group('پایبندی، ETA و ناسازگاری هدف', () {
    test('adherence7d فقط روی hit/miss هاست', () async {
      final state = await run(
        logs: sevenNights(1410),
        plans: [
          plan('2026-08-07', 1410, SleepPlanOutcome.hit),
          plan('2026-08-08', 1410, SleepPlanOutcome.hit),
          plan('2026-08-09', 1410, SleepPlanOutcome.hit),
          plan('2026-08-10', 1410, SleepPlanOutcome.miss),
          plan('2026-08-11', 1410, SleepPlanOutcome.freeNight),
          plan('2026-08-12', 1410, SleepPlanOutcome.noData),
        ],
      );
      expect(state.adherence7d, 0.75);
      expect(state.evaluatedLast7, 4);
      expect(state.hitsLast7, 3);
    });

    test('ETA بازه‌ای است و با پایبندی عقب‌تر می‌رود', () async {
      // پلهٔ فعلی 10:00، هدف 23:30 ⇒ ۶۳۰ دقیقه ⇒ ۴۲ پله
      final plans = [
        plan('2026-08-08', 600, SleepPlanOutcome.hit),
        plan('2026-08-09', 600, SleepPlanOutcome.hit),
        plan('2026-08-10', 600, SleepPlanOutcome.hit),
        plan('2026-08-11', 600, SleepPlanOutcome.miss),
        plan('2026-08-12', 600, SleepPlanOutcome.pending),
      ];
      final state = await run(logs: sevenNights(1410), plans: plans);
      // با ۳ hit از ۴ ⇒ پله جلو می‌رود: 600-15=585 ⇒ فاصله 645 ⇒ ۴۳ پله
      expect(state.tonightBedtimeMin, 585);
      expect(state.adherence7d, 0.75);
      expect(state.etaWeeksMin, isNotNull);
      expect(state.etaWeeksMax!, greaterThanOrEqualTo(state.etaWeeksMin!));
    });

    test('بدون شب ارزیابی‌شده ETA نداریم', () async {
      final state = await run(logs: sevenNights(1410), plans: const []);
      expect(state.etaWeeksMin, isNull);
    });

    test('۳ هفته پایبندی زیر ۰٫۴ با حداقل ۱۰ شب ⇒ goalMismatch', () async {
      final plans = [
        for (var i = 20; i >= 1; i--)
          plan(
            '2026-07-${(24 + i % 8).toString().padLeft(2, '0')}',
            1410,
            i % 5 == 0 ? SleepPlanOutcome.hit : SleepPlanOutcome.miss,
          ),
      ];
      final state = await run(logs: sevenNights(1410), plans: plans);
      expect(state.status, SleepProgramStatus.active);
      expect(state.goalMismatch, isTrue);
    });
  });

  group('شب آزاد و پنجرهٔ کارت', () {
    test('امشبِ پنجشنبه با freeNightWeekday=4 ⇒ شب آزاد', () async {
      final state = await run(
        p: program(freeNightWeekday: DateTime.thursday),
        logs: sevenNights(1410),
      );
      expect(state.freeNightTonight, isTrue);
    });

    test('روز دیگر هفته ⇒ شب آزاد نیست', () async {
      final state = await run(
        p: program(freeNightWeekday: DateTime.friday),
        logs: sevenNights(1410),
      );
      expect(state.freeNightTonight, isFalse);
    });

    test('پنجرهٔ کارت از خود پله مشتق می‌شود و نیمه‌شب را می‌پوشاند', () async {
      final state = await run(
        logs: sevenNights(1410),
        plans: [
          plan('2026-08-11', 0, SleepPlanOutcome.hit),
          plan('2026-08-12', 0, SleepPlanOutcome.hit),
          plan('2026-08-13', 0, SleepPlanOutcome.pending),
        ],
      );
      // پله 00:00 ⇒ پنجره ۲۲:۳۰ تا ۰۰:۳۰
      expect(state.cardWindowFromMin, 1410);
      expect(state.cardWindowToMin, 30);
    });

    test('قبل از ظهر، «امشب» همان شبِ در جریانِ دیروز است', () async {
      final state = await run(
        logs: sevenNights(1410),
        at: DateTime(2026, 8, 14, 0, 45), // ۰۰:۴۵ بامداد
      );
      expect(state.tonightDate, '2026-08-13');
    });
  });

  group('planHit', () {
    test('تلورانس ±۱۵ دقیقه نسبت به پله', () {
      expect(SleepProgramEngine.planHit(1410, 1410), isTrue);
      expect(SleepProgramEngine.planHit(1425, 1410), isTrue);
      expect(SleepProgramEngine.planHit(1395, 1410), isTrue);
      expect(SleepProgramEngine.planHit(1426, 1410), isFalse);
      // عبور از نیمه‌شب
      expect(SleepProgramEngine.planHit(10, 1435), isTrue);
      expect(SleepProgramEngine.planHit(30, 1435), isFalse);
    });
  });
}
