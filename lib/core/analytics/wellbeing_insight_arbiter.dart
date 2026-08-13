import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/analytics/life_balance_engine.dart';
import 'package:ritmo/core/analytics/mood_engine.dart';
import 'package:ritmo/core/analytics/reflection_engine.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_loop.dart';
import 'package:ritmo/core/analytics/wellbeing_triple_chain.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

enum WellbeingInsightKind {
  lastNightSleep,
  reflectionStreak,
  goldenWindow,
  moodEnergyLink,
  sleepNextDay,
  reflectionLink,
  sleepBank,
  bestBedtime,
  balanceTrend,
  indexDriver,
  tripleChain,
  loopOutcome,
  // قدم ۱: kindهای برنامهٔ خواب؛ تولیدکنندهٔ نامزدشان در فاز A می‌آید
  sleepPlanStep,
  sleepGoalMismatch,
}

/// گروه انحصار روایت‌ها: در هر روز حداکثر یک روایت از هر گروه به مرحلهٔ
/// نهایی می‌رسد (سند «مسیر خواب»، بخش ۳.ج — جلوگیری از سیل روایت‌های خواب).
enum InsightGroup { sleep, energyMood, reflection, balance, index }

enum WellbeingInsightMaturity { growing, ready }

enum WellbeingInsightAction {
  logSleep,
  logEnergy,
  logReflection,
  explainIndex,
  explainGoldenWindow,
  openSleepTarget,
}

class WellbeingInsight {
  const WellbeingInsight({
    required this.kind,
    required this.maturity,
    required this.title,
    required this.body,
    required this.score,
    required this.have,
    required this.need,
    this.action,
    this.actionLabel,
    this.timeWindow,
    this.group,
  });

  final WellbeingInsightKind kind;
  final WellbeingInsightMaturity maturity;
  final String title;
  final String body;
  final double score;
  final int have;
  final int need;
  final WellbeingInsightAction? action;
  final String? actionLabel;

  /// پنجرهٔ زمانی نمایش به «دقیقه از روز». اگر fromMin > toMin باشد، پنجره از
  /// نیمه‌شب می‌گذرد (مثل 1260→120 یعنی ۲۱:۰۰ تا ۰۲:۰۰). null یعنی بدون محدودیت.
  final ({int fromMin, int toMin})? timeWindow;

  /// گروه انحصار. اگر null باشد از روی [kind] تعیین می‌شود؛ loopOutcome هنگام
  /// ساخت، گروه روایت قبلی خودش را می‌گیرد.
  final InsightGroup? group;

  InsightGroup get effectiveGroup =>
      group ?? WellbeingInsightArbiter.groupOf(kind);

  String get id => kind.name;

  double get progress => need <= 0 ? 1.0 : (have / need).clamp(0.0, 1.0);
}

class WellbeingInsightSnapshot {
  const WellbeingInsightSnapshot({
    this.featured,
    this.ready = const [],
    this.growing = const [],
  });

  final WellbeingInsight? featured;
  final List<WellbeingInsight> ready;
  final List<WellbeingInsight> growing;
}

class WellbeingInsightInput {
  const WellbeingInsightInput({
    required this.now,
    this.horizonDays = 14,
    this.index,
    this.energy,
    this.mood,
    this.sleep,
    this.reflection,
    this.balance,
    this.energyLogCount = 0,
    this.moodLogCount = 0,
    this.sleepLogCount = 0,
    this.reflectionCount = 0,
    this.sleepLogs = const [],
    this.energyLogs = const [],
    this.moodLogs = const [],
    this.targetSleepHours = 7.5,
    this.loopPrevious,
  });

  final DateTime now;
  final int horizonDays;
  final WellbeingIndex? index;
  final EnergyAnalyticsOutput? energy;
  final MoodEngineOutput? mood;
  final SleepEngineOutput? sleep;
  final ReflectionEngineOutput? reflection;
  final LifeBalanceEngineOutput? balance;
  final int energyLogCount;
  final int moodLogCount;
  final int sleepLogCount;
  final int reflectionCount;
  final List<SleepLog> sleepLogs;
  final List<EnergyLog> energyLogs;
  final List<MoodLog> moodLogs;
  final double targetSleepHours;
  final WellbeingInsightLoopState? loopPrevious;
}

/// Picks at most one narrative for the Today tab.
class WellbeingInsightArbiter {
  const WellbeingInsightArbiter();

  static const int minPairsForCorrelation = 30;
  static const int minEnergyForGoldenWindow = 20;
  static const double nearTieDelta = 0.12;

  WellbeingInsightSnapshot evaluate(WellbeingInsightInput input) {
    final candidates = <WellbeingInsight>[
      ..._loopOutcome(input),
      ..._tripleChain(input),
      ..._lastNight(input),
      ..._reflectionStreak(input),
      ..._goldenWindow(input),
      ..._moodEnergy(input),
      ..._sleepNextDay(input),
      ..._reflectionLink(input),
      ..._sleepBank(input),
      ..._bestBedtime(input),
      ..._balanceTrend(input),
      ..._indexDriver(input),
    ];

    final ready = candidates.where((c) => c.maturity == WellbeingInsightMaturity.ready).toList();
    final growing = candidates.where((c) => c.maturity == WellbeingInsightMaturity.growing).toList();
    return WellbeingInsightSnapshot(
      featured: pickFeatured(ready: ready, growing: growing, now: input.now),
      ready: ready,
      growing: growing,
    );
  }

  static Map<String, double> metricByKind(WellbeingInsightInput input) {
    final out = <String, double>{};
    // نکتهٔ فاز A: sleepPlanStep باید با adherence7d از SleepProgramEngine
    // پوشش داده شود، وگرنه WellbeingInsightLoop برای این kind فعال نمی‌شود.
    final balanceHours = input.sleep?.sleepBalanceHours;
    if (balanceHours != null) {
      out[WellbeingInsightKind.lastNightSleep.name] = balanceHours;
      out[WellbeingInsightKind.sleepBank.name] = balanceHours;
      out[WellbeingInsightKind.sleepNextDay.name] = balanceHours;
      out[WellbeingInsightKind.bestBedtime.name] = balanceHours;
      out[WellbeingInsightKind.tripleChain.name] = balanceHours;
    }
    final streak = input.reflection?.currentStreak;
    if (streak != null) {
      out[WellbeingInsightKind.reflectionStreak.name] = streak.toDouble();
      out[WellbeingInsightKind.reflectionLink.name] = streak.toDouble();
    }
    final energyAvg = input.energy?.avgLevel;
    if (energyAvg != null) {
      out[WellbeingInsightKind.goldenWindow.name] = energyAvg;
      out[WellbeingInsightKind.moodEnergyLink.name] = energyAvg;
    }
    final score = input.balance?.score;
    if (score != null) {
      out[WellbeingInsightKind.balanceTrend.name] = score.toDouble();
    }
    final index = input.index?.value;
    if (index != null) {
      out[WellbeingInsightKind.indexDriver.name] = index;
    }
    return out;
  }

  /// Visible for tests.
  WellbeingInsight? pickFeatured({
    required List<WellbeingInsight> ready,
    required List<WellbeingInsight> growing,
    required DateTime now,
  }) {
    final minuteOfDay = now.hour * 60 + now.minute;
    if (ready.isNotEmpty) {
      // نامزدهایی که timeWindow دارند فقط داخل پنجرهٔ خودشان رقابت می‌کنند.
      final inWindow = ready
          .where((c) => isInTimeWindow(c.timeWindow, minuteOfDay))
          .toList();
      if (inWindow.isNotEmpty) {
        final ranked = [...inWindow]..sort(_byScoreThenKind);
        // گروه انحصار: از هر گروه فقط قوی‌ترین نامزد به مرحلهٔ نهایی می‌رسد.
        final bestByGroup = <InsightGroup, WellbeingInsight>{};
        for (final c in ranked) {
          bestByGroup.putIfAbsent(c.effectiveGroup, () => c);
        }
        final finalists = bestByGroup.values.toList()..sort(_byScoreThenKind);
        final top = finalists.first.score;
        final tied = finalists.where((c) => top - c.score <= nearTieDelta).toList();
        if (tied.length == 1) return tied.first;
        final day = DateTime(now.year, now.month, now.day).difference(DateTime(now.year)).inDays;
        return tied[day % tied.length];
      }
      // همهٔ نامزدهای آماده بیرون از پنجرهٔ زمانی خودشان هستند.
    }

    final viableGrowing = growing
        .where((c) => c.have > 0 && isInTimeWindow(c.timeWindow, minuteOfDay))
        .toList()
      ..sort(_byScoreThenKind);
    return viableGrowing.isEmpty ? null : viableGrowing.first;
  }

  /// آیا [minuteOfDay] داخل پنجره است؟ پنجرهٔ عبوری از نیمه‌شب پشتیبانی می‌شود.
  static bool isInTimeWindow(
      ({int fromMin, int toMin})? window, int minuteOfDay) {
    if (window == null) return true;
    return window.fromMin <= window.toMin
        ? (minuteOfDay >= window.fromMin && minuteOfDay <= window.toMin)
        : (minuteOfDay >= window.fromMin || minuteOfDay <= window.toMin);
  }

  /// نگاشت kind به گروه انحصار.
  static InsightGroup groupOf(WellbeingInsightKind kind) {
    switch (kind) {
      case WellbeingInsightKind.lastNightSleep:
      case WellbeingInsightKind.sleepNextDay:
      case WellbeingInsightKind.sleepBank:
      case WellbeingInsightKind.bestBedtime:
      case WellbeingInsightKind.tripleChain:
      case WellbeingInsightKind.sleepPlanStep:
      case WellbeingInsightKind.sleepGoalMismatch:
        return InsightGroup.sleep;
      case WellbeingInsightKind.goldenWindow:
      case WellbeingInsightKind.moodEnergyLink:
        return InsightGroup.energyMood;
      case WellbeingInsightKind.reflectionStreak:
      case WellbeingInsightKind.reflectionLink:
        return InsightGroup.reflection;
      case WellbeingInsightKind.balanceTrend:
        return InsightGroup.balance;
      case WellbeingInsightKind.indexDriver:
      case WellbeingInsightKind.loopOutcome:
        // loopOutcome هنگام ساخت، گروه روایتِ مرجعش را می‌گیرد؛ این فقط fallback است
        return InsightGroup.index;
    }
  }

  static InsightGroup _groupOfKindName(String kindName) {
    final kind = WellbeingInsightKind.values.asNameMap()[kindName];
    return kind == null ? InsightGroup.index : groupOf(kind);
  }

  int _byScoreThenKind(WellbeingInsight a, WellbeingInsight b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.kind.name.compareTo(b.kind.name);
  }

  List<WellbeingInsight> _loopOutcome(WellbeingInsightInput input) {
    final outcome = WellbeingInsightLoop.evaluate(
      previous: input.loopPrevious,
      now: input.now,
      currentMetrics: metricByKind(input),
    );
    if (outcome == null) return const [];
    final label = _kindLabel(outcome.previousKindName);
    // loopOutcome همان گروه روایتی را می‌گیرد که به آن اشاره می‌کند تا دو
    // روایت هم‌گروه در یک روز با هم ظاهر نشوند.
    final group = _groupOfKindName(outcome.previousKindName);
    if (outcome.improved) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.loopOutcome,
          maturity: WellbeingInsightMaturity.ready,
          title: 'روایت هفتهٔ قبل اثر داشت',
          body: 'بعد از دیدن «$label»، شاخص مرتبط بهتر شده. همین مسیر را یک هفتهٔ دیگر ادامه بده.',
          score: 1.42,
          have: outcome.days,
          need: WellbeingInsightLoop.minDaysBeforeOutcome,
          group: group,
        ),
      ];
    }
    return [
      WellbeingInsight(
        kind: WellbeingInsightKind.loopOutcome,
        maturity: WellbeingInsightMaturity.ready,
        title: 'هنوز اثر واضحی دیده نشد',
        body: 'هفتهٔ پیش «$label» را دیدی. تغییر شاخص هنوز از نویز روزمره بزرگ‌تر نیست — زود است نتیجه بگیریم.',
        score: 0.74,
        have: outcome.days,
        need: WellbeingInsightLoop.minDaysBeforeOutcome,
        group: group,
      ),
    ];
  }

  List<WellbeingInsight> _tripleChain(WellbeingInsightInput input) {
    if (input.sleepLogs.isEmpty || input.energyLogs.isEmpty || input.moodLogs.isEmpty) {
      return const [];
    }
    final hit = const WellbeingTripleChain().detect(
      sleepLogs: input.sleepLogs,
      energyLogs: input.energyLogs,
      moodLogs: input.moodLogs,
      targetSleepHours: input.targetSleepHours,
    );
    if (hit == null) return const [];
    return [
      WellbeingInsight(
        kind: WellbeingInsightKind.tripleChain,
        maturity: WellbeingInsightMaturity.ready,
        title: 'یک زنجیرهٔ سه‌تایی دیده شد',
        body:
            'در ${RitmoNumber.faInt(hit.hits)} ${hit.weekdayFa}های اخیر، کم‌خوابی شب قبل با انرژی پایین صبح و حال ضعیف‌تر بعدازظهر همراه بوده. (بر پایهٔ ${RitmoNumber.faInt(hit.hits)} از ${RitmoNumber.faInt(hit.opportunities)} بار)',
        score: 1.24,
        have: hit.hits,
        need: hit.opportunities,
        action: WellbeingInsightAction.logSleep,
        actionLabel: 'ثبت خواب',
      ),
    ];
  }

  List<WellbeingInsight> _lastNight(WellbeingInsightInput input) {
    final night = input.sleep?.lastNight;
    if (night == null) {
      if (input.sleepLogCount == 0) {
        return [
          WellbeingInsight(
            kind: WellbeingInsightKind.lastNightSleep,
            maturity: WellbeingInsightMaturity.growing,
            title: 'خواب هنوز وارد ریتم نشده',
            body: 'اولین ثبت خواب، شاخص و روایت امروز را روشن می‌کند.',
            score: 0.28,
            have: 0,
            need: 1,
            action: WellbeingInsightAction.logSleep,
            actionLabel: 'ثبت خواب دیشب',
          ),
        ];
      }
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.lastNightSleep,
          maturity: WellbeingInsightMaturity.ready,
          title: 'خواب دیشب هنوز ثبت نشده',
          body: 'شاخص امروز بدون دیشب ناقص می‌ماند. یک ثبت کوتاه کافی است.',
          score: 1.35,
          have: 0,
          need: 1,
          action: WellbeingInsightAction.logSleep,
          actionLabel: 'ثبت خواب دیشب',
        ),
      ];
    }

    final hours = night.durationHours;
    final short = hours < 6.0;
    return [
      WellbeingInsight(
        kind: WellbeingInsightKind.lastNightSleep,
        maturity: WellbeingInsightMaturity.ready,
        title: short ? 'خواب دیشب کوتاه‌تر از معمول بود' : 'خواب دیشب ثبت شد',
        body: short
            ? 'دیشب ${RitmoNumber.faHours(hours)} خوابیدی (${night.quality.label}). یک استراحت کوتاه امروز می‌تواند کسری را کم کند.'
            : 'دیشب ${RitmoNumber.faHours(hours)} با کیفیت ${night.quality.label}. همین برای شاخص امروز کافی است.',
        score: short ? 1.18 : 0.96,
        have: 1,
        need: 1,
        action: short ? WellbeingInsightAction.openSleepTarget : null,
        actionLabel: short ? 'تنظیم هدف خواب' : null,
      ),
    ];
  }

  List<WellbeingInsight> _reflectionStreak(WellbeingInsightInput input) {
    final streak = input.reflection?.currentStreak ?? 0;
    final forgiven = input.reflection?.forgivenThisWeek ?? false;
    if (streak >= 2) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.reflectionStreak,
          maturity: WellbeingInsightMaturity.ready,
          title: forgiven ? 'زنجیره با بخشش هفتگی زنده ماند' : 'استریک بازتاب زنده است',
          body: forgiven
              ? 'یک روز در ۷ روز اخیر جا ماند، ولی شمرده نشد. زنجیره ${RitmoNumber.faInt(streak)} روزه است — امروز را از دست نده.'
              : '${RitmoNumber.faInt(streak)} روز پیاپی نوشته‌ای. امروز را از دست نده تا زنجیره نشکند.',
          score: forgiven ? 1.16 : 1.12,
          have: streak,
          need: streak,
          action: WellbeingInsightAction.logReflection,
          actionLabel: 'ثبت بازتاب امروز',
        ),
      ];
    }
    if (input.reflectionCount > 0 || streak == 1) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.reflectionStreak,
          maturity: WellbeingInsightMaturity.growing,
          title: 'استریک بازتاب در حال شکل‌گیری است',
          body: streak == 1
              ? 'دیروز نوشتی. یک ثبت امروز زنجیره را به دو روز می‌رساند.'
              : 'با ${RitmoNumber.faInt(input.reflectionCount)} بازتاب در این بازه، هنوز زنجیرهٔ پیوسته‌ای ساخته نشده.',
          score: 0.42 + (streak == 1 ? 0.2 : 0),
          have: streak,
          need: 2,
          action: WellbeingInsightAction.logReflection,
          actionLabel: 'ثبت بازتاب',
        ),
      ];
    }
    return const [];
  }

  List<WellbeingInsight> _goldenWindow(WellbeingInsightInput input) {
    final samples = input.energy?.sampleCount ?? input.energyLogCount;
    final window = input.energy?.peakPerformanceWindow;
    if (samples >= minEnergyForGoldenWindow && window != null && window.isNotEmpty) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.goldenWindow,
          maturity: WellbeingInsightMaturity.ready,
          title: 'پنجرهٔ طلایی انرژی',
          body: 'معمولاً در بازهٔ $window بیشترین انرژی را داری. کار سخت امروز را به این بازه ببر.',
          score: 1.08,
          have: samples,
          need: minEnergyForGoldenWindow,
          action: WellbeingInsightAction.explainGoldenWindow,
          actionLabel: 'یعنی چی؟',
        ),
      ];
    }
    if (samples > 0 && samples < minEnergyForGoldenWindow) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.goldenWindow,
          maturity: WellbeingInsightMaturity.growing,
          title: 'پنجرهٔ طلایی هنوز خاموش است',
          body: 'با ${RitmoNumber.faInt(samples)} ثبت از ${RitmoNumber.faInt(minEnergyForGoldenWindow)} ثبت لازم، بازهٔ اوج انرژی قابل اعتماد نیست.',
          score: 0.25 + 0.4 * (samples / minEnergyForGoldenWindow),
          have: samples,
          need: minEnergyForGoldenWindow,
          action: WellbeingInsightAction.logEnergy,
          actionLabel: 'ثبت انرژی الان',
        ),
      ];
    }
    return const [];
  }

  List<WellbeingInsight> _moodEnergy(WellbeingInsightInput input) {
    final corr = input.mood?.energyMoodCorrelation;
    final insight = input.mood?.correlationInsight ?? '';
    if (corr != null && !_isPlaceholder(insight)) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.moodEnergyLink,
          maturity: WellbeingInsightMaturity.ready,
          title: 'حال و انرژی',
          body: insight,
          score: 1.0 + corr.abs() * 0.25,
          have: minPairsForCorrelation,
          need: minPairsForCorrelation,
          action: WellbeingInsightAction.logEnergy,
          actionLabel: 'ثبت انرژی الان',
        ),
      ];
    }
    final have = input.moodLogCount < input.energyLogCount ? input.moodLogCount : input.energyLogCount;
    if (have > 0 && have < minPairsForCorrelation) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.moodEnergyLink,
          maturity: WellbeingInsightMaturity.growing,
          title: 'الگوی حال و انرژی در حال یادگیری است',
          body: 'با ${RitmoNumber.faInt(have)} جفت از ${RitmoNumber.faInt(minPairsForCorrelation)} جفت لازم، همبستگی هنوز خاموش است.',
          score: 0.22 + 0.35 * (have / minPairsForCorrelation),
          have: have,
          need: minPairsForCorrelation,
          action: WellbeingInsightAction.logEnergy,
          actionLabel: 'یک ثبت دیگر',
        ),
      ];
    }
    return const [];
  }

  List<WellbeingInsight> _sleepNextDay(WellbeingInsightInput input) {
    final energyCorr = input.sleep?.sleepEnergyCorrelation;
    final moodCorr = input.sleep?.sleepMoodCorrelation;
    final insight = input.sleep?.correlationInsight ?? '';
    final ready = (energyCorr != null || moodCorr != null) && !_isPlaceholder(insight);
    if (ready) {
      final strength = [energyCorr?.abs() ?? 0, moodCorr?.abs() ?? 0].reduce((a, b) => a > b ? a : b);
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.sleepNextDay,
          maturity: WellbeingInsightMaturity.ready,
          title: 'خواب و روز بعد',
          body: insight,
          score: 1.02 + strength * 0.2,
          have: minPairsForCorrelation,
          need: minPairsForCorrelation,
          action: WellbeingInsightAction.logSleep,
          actionLabel: 'ثبت خواب',
        ),
      ];
    }
    final have = input.sleepLogCount;
    if (have > 0 && have < minPairsForCorrelation) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.sleepNextDay,
          maturity: WellbeingInsightMaturity.growing,
          title: 'الگوی خواب هنوز در حال یادگیری است',
          body: 'با ${RitmoNumber.faInt(have)} شب از ${RitmoNumber.faInt(minPairsForCorrelation)} شب لازم، اثر خواب روی روز بعد قابل گفتن نیست.',
          score: 0.2 + 0.35 * (have / minPairsForCorrelation),
          have: have,
          need: minPairsForCorrelation,
          action: WellbeingInsightAction.logSleep,
          actionLabel: 'ثبت خواب',
        ),
      ];
    }
    return const [];
  }

  List<WellbeingInsight> _reflectionLink(WellbeingInsightInput input) {
    final corr = input.reflection?.reflectionMoodCorrelation;
    final insight = input.reflection?.correlationInsight ?? '';
    if (corr != null && !_isPlaceholder(insight)) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.reflectionLink,
          maturity: WellbeingInsightMaturity.ready,
          title: 'بازتاب و حال',
          body: insight,
          score: 0.94 + corr.abs() * 0.2,
          have: minPairsForCorrelation,
          need: minPairsForCorrelation,
          action: WellbeingInsightAction.logReflection,
          actionLabel: 'ثبت بازتاب',
        ),
      ];
    }
    final have = input.reflection?.activeCount ?? input.reflectionCount;
    if (have > 0 && have < minPairsForCorrelation) {
      return [
        WellbeingInsight(
          kind: WellbeingInsightKind.reflectionLink,
          maturity: WellbeingInsightMaturity.growing,
          title: 'همبستگی بازتاب هنوز خاموش است',
          body: 'با ${RitmoNumber.faInt(have)} بازتاب از ${RitmoNumber.faInt(minPairsForCorrelation)} بازتاب لازم، الگوی خودمراقبتی قابل اعتماد نیست.',
          score: 0.18 + 0.3 * (have / minPairsForCorrelation),
          have: have,
          need: minPairsForCorrelation,
          action: WellbeingInsightAction.logReflection,
          actionLabel: 'ثبت بازتاب',
        ),
      ];
    }
    return const [];
  }

  List<WellbeingInsight> _sleepBank(WellbeingInsightInput input) {
    if (input.sleepLogCount == 0 || input.sleep == null) return const [];
    final balance = input.sleep!.sleepBalanceHours;
    if (balance.abs() < 0.75) return const [];
    final deficit = balance < 0;
    return [
      WellbeingInsight(
        kind: WellbeingInsightKind.sleepBank,
        maturity: WellbeingInsightMaturity.ready,
        title: deficit ? 'کسری خواب جمع شده' : 'ذخیرهٔ خواب مثبت است',
        body: deficit
            ? 'کسری حدود ${RitmoNumber.faHours(balance.abs())} است. یک خواب جبرانی کوتاه بهتر از یک شب خیلی طولانی است.'
            : 'ذخیرهٔ حدود ${RitmoNumber.faHours(balance)} در روزهای اخیر ساخته شده؛ ریتمت جا افتاده.',
        score: deficit ? 1.06 : 0.88,
        have: input.sleepLogCount,
        need: input.sleepLogCount,
        action: WellbeingInsightAction.openSleepTarget,
        actionLabel: 'تنظیم هدف خواب',
      ),
    ];
  }

  List<WellbeingInsight> _bestBedtime(WellbeingInsightInput input) {
    final window = input.sleep?.bestBedtimeWindow;
    if (window == null || window.isEmpty) return const [];
    return [
      WellbeingInsight(
        kind: WellbeingInsightKind.bestBedtime,
        maturity: WellbeingInsightMaturity.ready,
        title: 'ساعت خواب بهتر در گذشته',
        body: 'شب‌هایی که حوالی $window خوابیدی، روز بعد معمولاً بهتر بوده. این همبستگی است، نه نسخه.',
        score: 0.92,
        have: 4,
        need: 4,
        action: WellbeingInsightAction.openSleepTarget,
        actionLabel: 'تنظیم هدف خواب',
      ),
    ];
  }

  List<WellbeingInsight> _balanceTrend(WellbeingInsightInput input) {
    final trend = input.balance?.trend;
    if (trend == null) return const [];
    final thisWeek = trend[1];
    final lastWeek = trend[2];
    if (thisWeek == null || lastWeek == null) return const [];
    final delta = thisWeek - lastWeek;
    if (delta.abs() < 5) return const [];
    final up = delta > 0;
    return [
      WellbeingInsight(
        kind: WellbeingInsightKind.balanceTrend,
        maturity: WellbeingInsightMaturity.ready,
        title: up ? 'توزیع تلاش متعادل‌تر شده' : 'توزیع تلاش نامتوازن‌تر شده',
        body: up
            ? 'امتیاز تعادل این هفته ${RitmoNumber.faInt(thisWeek)} است؛ هفتهٔ قبل ${RitmoNumber.faInt(lastWeek)} بود.'
            : 'امتیاز تعادل این هفته ${RitmoNumber.faInt(thisWeek)} است و نسبت به ${RitmoNumber.faInt(lastWeek)} هفتهٔ قبل افت کرده.',
        score: 0.9,
        have: LifeBalanceEngine.minCompletionsForBalance,
        need: LifeBalanceEngine.minCompletionsForBalance,
      ),
    ];
  }

  List<WellbeingInsight> _indexDriver(WellbeingInsightInput input) {
    final index = input.index;
    if (index == null || !index.hasValue || index.contributions.isEmpty) {
      return const [];
    }
    return [
      WellbeingInsight(
        kind: WellbeingInsightKind.indexDriver,
        maturity: WellbeingInsightMaturity.ready,
        title: 'چرا این عدد',
        body: _indexSentence(index),
        score: 0.78,
        have: index.contributions.length,
        need: 1,
        action: WellbeingInsightAction.explainIndex,
        actionLabel: 'جزئیات شاخص',
      ),
    ];
  }

  String _indexSentence(WellbeingIndex index) {
    WellbeingContribution? maxPos;
    WellbeingContribution? maxNeg;
    final waterfall = index.waterfall;
    for (final c in index.contributions) {
      final diff = waterfall[c.signal] ?? 0.0;
      if (diff > 0 && (maxPos == null || diff > (waterfall[maxPos.signal] ?? 0.0))) {
        maxPos = c;
      }
      if (diff < 0 && (maxNeg == null || diff < (waterfall[maxNeg.signal] ?? 0.0))) {
        maxNeg = c;
      }
    }
    String name(WellbeingSignal s) {
      switch (s) {
        case WellbeingSignal.sleep:
          return 'خواب';
        case WellbeingSignal.energy:
          return 'انرژی';
        case WellbeingSignal.mood:
          return 'حال';
        case WellbeingSignal.reflection:
          return 'بازتاب';
      }
    }

    if (maxPos != null && maxNeg != null) {
      return 'بیشترین اثر مثبت از ${name(maxPos.signal)} بوده و بیشترین افت از ${name(maxNeg.signal)}.';
    }
    if (maxPos != null) {
      return 'بیشترین اثر مثبت شاخص از ${name(maxPos.signal)} آمده است.';
    }
    if (maxNeg != null) {
      return 'بیشترین افت شاخص از ${name(maxNeg.signal)} آمده است.';
    }
    return 'سیگنال‌ها نزدیک پایه هستند و هیچ‌کدام شاخص را جابه‌جا نکرده.';
  }

  bool _isPlaceholder(String text) {
    return text.contains('کافی نیست') ||
        text.contains('در حال یادگیری') ||
        text.contains('در حال تحلیل');
  }

  String _kindLabel(String kindName) {
    switch (kindName) {
      case 'lastNightSleep':
        return 'خواب دیشب';
      case 'reflectionStreak':
        return 'استریک بازتاب';
      case 'goldenWindow':
        return 'پنجرهٔ طلایی';
      case 'moodEnergyLink':
        return 'حال و انرژی';
      case 'sleepNextDay':
        return 'خواب و روز بعد';
      case 'reflectionLink':
        return 'بازتاب و حال';
      case 'sleepBank':
        return 'ذخیرهٔ خواب';
      case 'bestBedtime':
        return 'ساعت خواب بهتر';
      case 'balanceTrend':
        return 'توزیع تلاش';
      case 'indexDriver':
        return 'چرا این عدد';
      case 'tripleChain':
        return 'زنجیرهٔ سه‌تایی';
      case 'sleepPlanStep':
        return 'پلهٔ امشب';
      case 'sleepGoalMismatch':
        return 'بازبینی هدف خواب';
      default:
        return 'روایت امروز';
    }
  }
}
