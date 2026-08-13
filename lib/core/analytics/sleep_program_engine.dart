import 'dart:math' as math;

import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/time/ritmo_time.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/sleep/models/sleep_plan_day.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';

/// ورودی موتور برنامهٔ خواب — همهٔ داده‌ها از قبل خوانده شده‌اند؛ موتور pure است.
class SleepProgramInput {
  const SleepProgramInput({
    required this.program,
    required this.planDays,
    required this.sleepLogs,
    required this.target,
    required this.now,
  });

  final SleepProgram program;

  /// ردیف‌های اخیر برنامه (هر ترتیبی؛ موتور خودش مرتب می‌کند).
  final List<SleepPlanDay> planDays;

  /// لاگ‌های خواب از منبع واقعی (`bedtime_diagnostics`).
  final List<SleepLog> sleepLogs;
  final SleepTarget target;
  final DateTime now;
}

/// خروجی موتور — همان چیزی که کارت «پلهٔ امشب»، بلوک مسیر و میانبر شب می‌خوانند.
class SleepProgramState {
  const SleepProgramState({
    required this.status,
    required this.tonightDate,
    required this.tonightBedtimeMin,
    required this.tonightWakeMin,
    required this.goalBedtimeMin,
    required this.stepMinutes,
    required this.freeNightTonight,
    required this.holdTonight,
    required this.goalMismatch,
    required this.hitsLast7,
    required this.evaluatedLast7,
    required this.stepsRemaining,
    this.nightsLogged = 0,
    this.adherence7d,
    this.etaWeeksMin,
    this.etaWeeksMax,
    this.socialJetlagMin,
  });

  final SleepProgramStatus status;

  /// تعداد شب‌های ثبت‌شده در تاریخچه.
  final int nightsLogged;

  /// dayKey شبِ برنامهٔ امشب (قبل از ظهر = شبِ در جریانِ دیروز).
  final String tonightDate;

  /// پلهٔ امشب — دقیقه از روز.
  final int tonightBedtimeMin;
  final int tonightWakeMin;
  final int goalBedtimeMin;
  final int stepMinutes;
  final bool freeNightTonight;
  final bool holdTonight;
  final bool goalMismatch;
  final int hitsLast7;
  final int evaluatedLast7;
  final int stepsRemaining;
  final double? adherence7d;
  final int? etaWeeksMin;
  final int? etaWeeksMax;
  final int? socialJetlagMin;

  /// کارت «پلهٔ امشب» فقط در فاز active معنی دارد.
  bool get hasCard => status == SleepProgramStatus.active;

  /// پنجرهٔ نمایش کارت/میانبر: از ۹۰ دقیقه قبلِ پله تا ۳۰ دقیقه بعدش
  /// (مشتق از خودِ پله، نه ساعت ثابت — سند ۴.۱-ب). ممکن است از نیمه‌شب بگذرد.
  int get cardWindowFromMin => (((tonightBedtimeMin - 90) % 1440) + 1440) % 1440;
  int get cardWindowToMin => (tonightBedtimeMin + 30) % 1440;
}

/// موتور برنامهٔ خواب — فاز A سند «مسیر خواب» (بخش ۲).
///
/// - کمتر از ۷ شب ⇒ listening (فقط گوش دادن، بدون کارت)
/// - بعد از آن ⇒ anchoring روی میانگین دایره‌ایِ زمان خواب واقعی
/// - با حداقل minNightsPerStep شبِ ارزیابی‌شده ⇒ active و پله‌های ۱۵دقیقه‌ای
class SleepProgramEngine
    implements CachedEngine<SleepProgramInput, SleepProgramState> {
  const SleepProgramEngine();

  /// کمتر از این تعداد شب ⇒ فاز گوش دادن.
  static const int minNightsForListening = 7;
  static const int hitToleranceMinutes = 15;
  static const int stepReviewWindow = 5;
  static const int stepAdvanceHits = 3;
  static const int stepHoldMaxHits = 1;
  static const double goalMismatchAdherence = 0.4;
  static const int goalMismatchMinEvaluated = 10;
  static const int goalMismatchWindowDays = 21;

  @override
  Future<SleepProgramState> calculate(SleepProgramInput input) async {
    final now = input.now;
    final program = input.program;
    final target = input.target;

    // «امشب»: قبل از ظهر، شبِ در جریان متعلق به دیروز است (کنوانسیون شب N).
    final todayDate = RitmoDate.dayKey(now);
    final tonightDate = now.hour < 12
        ? RitmoDate.dayKey(now.subtract(const Duration(days: 1)))
        : todayDate;

    final goalBedtimeMin = target.bedtimeHour * 60 + target.bedtimeMinute;
    final goalWakeMin = target.wakeHour * 60 + target.wakeMinute;

    final logsByDate = <String, SleepLog>{
      for (final l in input.sleepLogs) l.date: l,
    };
    final totalNights = logsByDate.length;

    final plans = [...input.planDays]..sort((a, b) => a.date.compareTo(b.date));
    final evaluated = plans.where((p) => p.isEvaluated).toList();

    // لنگر: میانگین دایره‌ایِ ۷ شب اخیر (امن در برابر نیمه‌شب)
    var anchorMin = goalBedtimeMin;
    final bedtimeMins = <int>[];
    final sortedDates = logsByDate.keys.toList()..sort();
    for (final d in sortedDates.reversed) {
      final log = logsByDate[d]!;
      if (log.bedtimeAt != null) {
        final bt = DateTime.fromMillisecondsSinceEpoch(log.bedtimeAt!);
        bedtimeMins.add(bt.hour * 60 + bt.minute);
      }
      if (bedtimeMins.length >= 7) break;
    }
    if (bedtimeMins.isNotEmpty) {
      anchorMin = circularMeanMinutes(bedtimeMins);
    }

    // فاز — paused/completed تصمیم کاربر است و موتور دست نمی‌زند
    final SleepProgramStatus status;
    if (program.status == SleepProgramStatus.paused ||
        program.status == SleepProgramStatus.completed) {
      status = program.status;
    } else if (totalNights < minNightsForListening) {
      status = SleepProgramStatus.listening;
    } else if (evaluated.length < program.minNightsPerStep) {
      status = SleepProgramStatus.anchoring;
    } else {
      status = SleepProgramStatus.active;
    }

    // پلهٔ امشب
    var holdTonight = false;
    final int tonightBedtimeMin;
    if (plans.isNotEmpty && plans.last.date == tonightDate) {
      // پلهٔ امشب قبلاً فریز شده — وسط عصر تغییرش نمی‌دهیم
      tonightBedtimeMin = plans.last.plannedBedtimeMin;
    } else if (status != SleepProgramStatus.active) {
      tonightBedtimeMin = plans.isEmpty ? anchorMin : plans.last.plannedBedtimeMin;
    } else {
      final lastPlanned =
          plans.isEmpty ? anchorMin : plans.last.plannedBedtimeMin;
      final recent = evaluated.reversed.take(stepReviewWindow).toList();
      final hits =
          recent.where((p) => p.outcome == SleepPlanOutcome.hit).length;
      if (recent.length >= 3 && hits <= stepHoldMaxHits) {
        holdTonight = true;
        tonightBedtimeMin = lastPlanned;
      } else if (hits >= stepAdvanceHits) {
        tonightBedtimeMin =
            stepToward(lastPlanned, goalBedtimeMin, program.stepMinutes);
      } else {
        tonightBedtimeMin = lastPlanned;
      }
    }

    // پایبندی ۷ روز اخیر (فقط شب‌های hit/miss)
    final since7 = RitmoDate.dayKey(now.subtract(const Duration(days: 7)));
    final last7 = plans
        .where((p) => p.isEvaluated && p.date.compareTo(since7) >= 0)
        .toList();
    final hits7 = last7.where((p) => p.outcome == SleepPlanOutcome.hit).length;
    final adherence7d = last7.isEmpty ? null : hits7 / last7.length;

    // ناسازگاری هدف: ۲۱ روز اخیر با حداقل ۱۰ شب ارزیابی‌شده و پایبندی < ۰٫۴
    final since21 = RitmoDate.dayKey(
        now.subtract(const Duration(days: goalMismatchWindowDays)));
    final last21 = plans
        .where((p) => p.isEvaluated && p.date.compareTo(since21) >= 0)
        .toList();
    final hits21 =
        last21.where((p) => p.outcome == SleepPlanOutcome.hit).length;
    final goalMismatch = status == SleepProgramStatus.active &&
        last21.length >= goalMismatchMinEvaluated &&
        (hits21 / last21.length) < goalMismatchAdherence;

    // ETA: (فاصله ÷ پله) ÷ پایبندی، با بازهٔ ±۲۰٪ — هیچ تاریخ دقیقی وعده نمی‌دهیم
    final remainingMin =
        RitmoTime.absMinuteDiff(goalBedtimeMin, tonightBedtimeMin);
    final stepsRemaining =
        remainingMin == 0 ? 0 : (remainingMin / program.stepMinutes).ceil();
    int? etaWeeksMin;
    int? etaWeeksMax;
    if (stepsRemaining > 0 && adherence7d != null && adherence7d > 0.1) {
      final etaDays = stepsRemaining / adherence7d;
      etaWeeksMin = math.max(1, (etaDays * 0.8 / 7).round());
      etaWeeksMax = math.max(etaWeeksMin, (etaDays * 1.2 / 7).round());
    }

    // شب آزاد امشب؟ (freeNightWeekday به‌صورت ISO: ۱=دوشنبه … ۷=یکشنبه)
    final tonightDt = RitmoDate.tryParseDayKey(tonightDate) ?? now;
    final freeNightTonight = program.freeNightWeekday != null &&
        tonightDt.weekday == program.freeNightWeekday;

    // social jetlag: میانگین بیداری آخرهفته (جمعه/شنبه) در برابر وسط هفته
    int? socialJetlagMin;
    final weekdayWake = <int>[];
    final weekendWake = <int>[];
    for (final log in input.sleepLogs) {
      if (log.wakeAt == null) continue;
      final d = RitmoDate.tryParseDayKey(log.date);
      if (d == null) continue;
      final wt = DateTime.fromMillisecondsSinceEpoch(log.wakeAt!);
      final m = wt.hour * 60 + wt.minute;
      if (d.weekday == DateTime.friday || d.weekday == DateTime.saturday) {
        weekendWake.add(m);
      } else {
        weekdayWake.add(m);
      }
    }
    if (weekdayWake.length >= 2 && weekendWake.length >= 2) {
      socialJetlagMin = RitmoTime.absMinuteDiff(
        circularMeanMinutes(weekendWake),
        circularMeanMinutes(weekdayWake),
      );
    }

    return SleepProgramState(
      status: status,
      tonightDate: tonightDate,
      tonightBedtimeMin: tonightBedtimeMin,
      tonightWakeMin: goalWakeMin,
      goalBedtimeMin: goalBedtimeMin,
      stepMinutes: program.stepMinutes,
      freeNightTonight: freeNightTonight,
      holdTonight: holdTonight,
      goalMismatch: goalMismatch,
      hitsLast7: hits7,
      evaluatedLast7: last7.length,
      stepsRemaining: stepsRemaining,
      nightsLogged: totalNights,
      adherence7d: adherence7d,
      etaWeeksMin: etaWeeksMin,
      etaWeeksMax: etaWeeksMax,
      socialJetlagMin: socialJetlagMin,
    );
  }

  /// «زدن پله»: فاصله از پلهٔ امشب تا ±۱۵ دقیقه (نه هدف نهایی — سند بخش ۲).
  static bool planHit(int actualBedtimeMin, int plannedBedtimeMin) =>
      RitmoTime.absMinuteDiff(actualBedtimeMin, plannedBedtimeMin) <=
      hitToleranceMinutes;

  /// یک قدم به سمت هدف — روی کوتاه‌ترین مسیر ساعت ۲۴ساعته، بدون رد شدن از هدف.
  static int stepToward(int currentMin, int goalMin, int stepMinutes) {
    final diff = RitmoTime.signedMinuteDiff(goalMin, currentMin);
    if (diff == 0) return currentMin;
    if (diff.abs() <= stepMinutes) return ((goalMin % 1440) + 1440) % 1440;
    final next = currentMin + diff.sign * stepMinutes;
    return ((next % 1440) + 1440) % 1440;
  }

  /// میانگین دایره‌ای دقیقه‌های روز — امن در برابر نیمه‌شب
  /// (میانگین ۲۳:۵۰ و ۰۰:۱۰ می‌شود ~۰۰:۰۰، نه ۱۲:۰۰).
  static int circularMeanMinutes(List<int> minutesOfDay) {
    if (minutesOfDay.isEmpty) return 0;
    var sumSin = 0.0;
    var sumCos = 0.0;
    for (final m in minutesOfDay) {
      final angle = m / 1440.0 * 2 * math.pi;
      sumSin += math.sin(angle);
      sumCos += math.cos(angle);
    }
    var meanAngle = math.atan2(sumSin, sumCos);
    if (meanAngle < 0) meanAngle += 2 * math.pi;
    return (meanAngle / (2 * math.pi) * 1440).round() % 1440;
  }

  @override
  Duration get ttl => const Duration(minutes: 5);

  @override
  String fingerprint(SleepProgramInput input) {
    final dayStamp = input.now.toIso8601String().substring(0, 10);
    return '$dayStamp|${input.program.id}|${input.program.status.name}|'
        '${input.planDays.length}|${input.sleepLogs.length}|'
        '${input.target.durationMinutes}|${input.now.hour}';
  }

  @override
  void invalidate() {}

  @override
  bool canRun(SleepProgramInput input) => true;

  @override
  List<Type> dependencies() => [];
}
