import 'package:ritmo/core/analytics/sleep_program_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';

/// تبدیل وضعیت موتور برنامهٔ خواب به نامزدهای روایت «حال و تعادل».
///
/// چرا جدا از `WellbeingInsightArbiter`؟ چون داور فقط به موتورهای تحلیلی
/// وصل است و برنامهٔ خواب حالت ماندگار دارد. با [merge] نامزدها به همان
/// `pickFeatured` داور سپرده می‌شوند؛ پس قاعدهٔ «از هر گروه فقط یک روایت»
/// و پنجرهٔ زمانی دقیقاً همان‌جا اعمال می‌شود و فایل داور دست‌نخورده می‌ماند.
class SleepPlanInsights {
  const SleepPlanInsights._();

  /// در پنجرهٔ شب، پلهٔ امشب از همهٔ روایت‌های خواب مهم‌تر است؛ بیرون از
  /// پنجره اصلاً رقابت نمی‌کند (timeWindow).
  static const double stepScore = 1.40;
  static const double freeNightScore = 1.32;

  /// ناسازگاری هدف پنجره ندارد (روزانه هم دیده می‌شود) ولی عمداً از
  /// یادآوری «خواب دیشب را ثبت کن» ضعیف‌تر است.
  static const double mismatchScore = 1.20;

  static const double listeningBaseScore = 0.46;

  static const List<String> _faDigits = [
    '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
  ];

  /// قالب ساعت فارسی از «دقیقه از روز»؛ ۱۴۱۰ ⇒ ۲۳:۳۰.
  static String hhmm(int minuteOfDay) {
    final m = ((minuteOfDay % 1440) + 1440) % 1440;
    return '${_pad(m ~/ 60)}:${_pad(m % 60)}';
  }

  static String _pad(int value) => value
      .toString()
      .padLeft(2, '0')
      .split('')
      .map((c) => _faDigits[int.parse(c)])
      .join();

  /// اختلاف علامت‌دار روی ساعت ۲۴ ساعته (کوتاه‌ترین مسیر).
  static int _signedDiff(int from, int to) {
    var d = (to - from) % 1440;
    if (d < 0) d += 1440;
    return d > 720 ? d - 1440 : d;
  }

  /// نامزدهای برنامهٔ خواب برای داور.
  static List<WellbeingInsight> build({
    required SleepProgramState state,
    int sleepLogCount = 0,
  }) {
    if (state.status == SleepProgramStatus.listening) {
      return [_listening(sleepLogCount)];
    }
    // paused/completed و هر حالت آینده‌ای: برنامه ساکت است.
    if (state.status != SleepProgramStatus.anchoring &&
        state.status != SleepProgramStatus.active) {
      return const [];
    }

    final out = <WellbeingInsight>[];
    if (state.hasCard) out.add(_stepCard(state));
    if (state.goalMismatch) out.add(_mismatch(state));
    return out;
  }

  /// نامزدهای خواب را به یک اسنپ‌شات موجود اضافه می‌کند و دوباره داوری می‌کند.
  static WellbeingInsightSnapshot merge({
    required WellbeingInsightSnapshot snapshot,
    required SleepProgramState? state,
    required DateTime now,
    int sleepLogCount = 0,
  }) {
    if (state == null) return snapshot;
    final extra = build(state: state, sleepLogCount: sleepLogCount);
    if (extra.isEmpty) return snapshot;

    final ready = <WellbeingInsight>[
      ...snapshot.ready,
      ...extra.where((c) => c.maturity == WellbeingInsightMaturity.ready),
    ];
    final growing = <WellbeingInsight>[
      ...snapshot.growing,
      ...extra.where((c) => c.maturity == WellbeingInsightMaturity.growing),
    ];
    return WellbeingInsightSnapshot(
      featured: const WellbeingInsightArbiter()
          .pickFeatured(ready: ready, growing: growing, now: now),
      ready: ready,
      growing: growing,
    );
  }

  // ────── نامزدها ──────

  static WellbeingInsight _listening(int nights) {
    final need = SleepProgramEngine.minNightsForListening;
    final have = nights > need ? need : nights;
    return WellbeingInsight(
      kind: WellbeingInsightKind.sleepPlanStep,
      maturity: WellbeingInsightMaturity.growing,
      title: 'مسیر خواب دارد گوش می‌دهد',
      body: '${RitmoNumber.faInt(have)} شب از ${RitmoNumber.faInt(need)} شب لازم ثبت شده. تا الگوی واقعی‌ات روشن نشود، هیچ ساعتی را به تو تحمیل نمی‌کنم.',
      score: listeningBaseScore + 0.3 * (have / need).clamp(0.0, 1.0),
      have: have,
      need: need,
      action: WellbeingInsightAction.logSleep,
      actionLabel: 'ثبت خواب دیشب',
    );
  }

  static WellbeingInsight _stepCard(SleepProgramState state) {
    final window = (
      fromMin: state.cardWindowFromMin,
      toMin: state.cardWindowToMin,
    );
    final have = state.hitsLast7;
    final need = state.evaluatedLast7 == 0 ? 1 : state.evaluatedLast7;

    if (state.freeNightTonight) {
      return WellbeingInsight(
        kind: WellbeingInsightKind.sleepPlanStep,
        maturity: WellbeingInsightMaturity.ready,
        title: 'امشب شب آزاد توست',
        body: 'برنامه امشب هیچ انتظاری از تو ندارد؛ هر وقت خوابت آمد بخواب. مسیر فردا شب از همان پلهٔ قبلی ادامه پیدا می‌کند.',
        score: freeNightScore,
        have: have,
        need: need,
        timeWindow: window,
      );
    }

    final time = hhmm(state.tonightBedtimeMin);
    final support = _support(state);

    final String title;
    final String lead;
    if (state.status == SleepProgramStatus.anchoring) {
      title = 'لنگر مسیر خواب: $time';
      lead =
          'فعلاً چیزی را جلو نمی‌بریم؛ چند شب روی همین ساعت می‌مانیم تا پایه محکم شود.';
    } else if (state.holdTonight) {
      title = 'امشب همان پلهٔ قبلی: $time';
      lead =
          'هفتهٔ گذشته این پله سخت بود، پس جلوتر نمی‌رویم. همین را یک شب دیگر تکرار کنیم کافی است.';
    } else {
      final diff = _signedDiff(state.tonightBedtimeMin, state.goalBedtimeMin);
      title = 'پلهٔ امشب: $time';
      lead = diff == 0
          ? 'امشب دقیقاً روی هدف خودت هستی؛ کافی است همین را نگه داری.'
          : '${RitmoNumber.faInt(state.stepMinutes)} دقیقه ${diff < 0 ? 'زودتر' : 'دیرتر'} از پلهٔ قبلی. اگر تا نیم‌ساعت بعد هم خوابت نبرد، شب از دست نرفته.';
    }

    return WellbeingInsight(
      kind: WellbeingInsightKind.sleepPlanStep,
      maturity: WellbeingInsightMaturity.ready,
      title: title,
      body: support == null ? lead : '$lead $support',
      score: stepScore,
      have: have,
      need: need,
      timeWindow: window,
      action: WellbeingInsightAction.openSleepTarget,
      actionLabel: 'مسیر خواب',
    );
  }

  /// یک کارت، یک پیام: حداکثر یک جملهٔ پشتیبان (اول ETA، بعد جت‌لگ اجتماعی).
  static String? _support(SleepProgramState state) {
    final etaMin = state.etaWeeksMin;
    final etaMax = state.etaWeeksMax;
    if (etaMin != null && etaMax != null) {
      final goal = hhmm(state.goalBedtimeMin);
      final lo = RitmoNumber.faInt(etaMin.round());
      final hi = RitmoNumber.faInt(etaMax.round());
      return etaMin.round() == etaMax.round()
          ? 'با این روند، رسیدن به $goal حدود $lo هفته زمان می‌برد.'
          : 'با این روند، رسیدن به $goal حدود $lo تا $hi هفته زمان می‌برد.';
    }
    final jetlag = state.socialJetlagMin;
    if (jetlag != null && jetlag.round() >= 60) {
      return 'آخر هفته‌ها حدود ${RitmoNumber.faInt(jetlag.round())} دقیقه دیرتر می‌خوابی؛ همین فاصله اول هفته را سخت می‌کند.';
    }
    return null;
  }

  static WellbeingInsight _mismatch(SleepProgramState state) {
    return WellbeingInsight(
      kind: WellbeingInsightKind.sleepGoalMismatch,
      maturity: WellbeingInsightMaturity.ready,
      title: 'شاید هدف خواب کمی دور است',
      body:
          'در سه هفتهٔ اخیر بیشتر شب‌ها به پله نرسیده‌ای. این معمولاً یعنی هدف با زندگی این روزهایت جور نیست، نه اینکه تو کم گذاشته‌ای. یک هدف نزدیک‌تر مسیر را زنده نگه می‌دارد.',
      score: mismatchScore,
      have: state.hitsLast7,
      need: state.evaluatedLast7 == 0 ? 1 : state.evaluatedLast7,
      action: WellbeingInsightAction.openSleepTarget,
      actionLabel: 'بازبینی هدف خواب',
    );
  }
}
