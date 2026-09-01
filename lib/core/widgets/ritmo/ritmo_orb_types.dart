// =============================================================================
//  Ritmo Orb — پایه‌های مشترکِ تیله
//  اینجا فقط «تعریف» است: رنگ، ردهٔ اندازه، بودجهٔ نقاشی، نور، توجه، انرژی.
//  هیچ ویجت و هیچ نقاشی‌ای اینجا نیست تا هر لایه بتواند بدون وابستگی به
//  نقاشِ قدیمی از این typeها استفاده کند.
// =============================================================================

import 'package:flutter/widgets.dart';

/// حالت کاریِ هوش مصنوعی (مقدارها عیناً مثل قبل تا هیچ switchی نشکند).
enum RitmoOrbMode { idle, thinking, streaming, compact }

/// صداقتِ تیله. تیله حق ندارد وقتی چیزی برای گفتن ندارد، مطمئن به نظر برسد.
enum RitmoOrbTruth {
  /// می‌داند چه می‌گوید.
  confident,

  /// جواب دارد ولی مطمئن نیست: اشباع کم، لبهٔ تخت، بدون نقطهٔ درخشان.
  unsure,

  /// بی‌شبکه یا خاموش: شیشه سرِ جایش است، جریانِ درون ایستاده.
  offline,
}

/// ردهٔ جزئیات بر اساس اندازهٔ واقعیِ روی صفحه. یک موجود، سه فاصله.
enum RitmoOrbTier { s, m, l }

/// ردهٔ مناسب برای یک اندازه.
RitmoOrbTier ritmoTierFor(double size) {
  if (size < 30.0) return RitmoOrbTier.s;
  if (size < 64.0) return RitmoOrbTier.m;
  return RitmoOrbTier.l;
}

/// سقفِ سخت‌گیرانهٔ هزینهٔ هر فریم. تستِ perf همین عددها را گارد می‌کند.
@immutable
class RitmoOrbBudget {
  const RitmoOrbBudget({
    required this.drawOps,
    required this.blurPasses,
    required this.shellSamples,
    required this.plumes,
    required this.frameInterval,
    required this.whiteBudget,
  });

  /// حداکثر تعداد فرمانِ نقاشی در هر فریم.
  final int drawOps;

  /// حداکثر تعداد پاسِ blur (هر blur یک render pass جداست).
  final int blurPasses;

  /// تعداد نمونهٔ محیطِ پوسته؛ ۰ = بیضیِ ساده.
  final int shellSamples;

  /// تعداد تودهٔ جریانِ درون.
  final int plumes;

  /// فاصلهٔ فریم‌ها بر حسب ثانیه؛ ۰ = هر فریم.
  final double frameInterval;

  /// جمعِ مجازِ آلفای سفید در کلِ فریم (ضدِ «ابرِ شیریِ بالا-چپ»).
  final double whiteBudget;

  static const RitmoOrbBudget small = RitmoOrbBudget(
    drawOps: 7,
    blurPasses: 0,
    shellSamples: 0,
    plumes: 0,
    frameInterval: 1.0 / 24.0,
    whiteBudget: 0.34,
  );

  static const RitmoOrbBudget medium = RitmoOrbBudget(
    drawOps: 15,
    blurPasses: 2,
    shellSamples: 24,
    plumes: 2,
    frameInterval: 1.0 / 40.0,
    whiteBudget: 0.62,
  );

  static const RitmoOrbBudget large = RitmoOrbBudget(
    drawOps: 26,
    blurPasses: 6,
    shellSamples: 32,
    plumes: 4,
    frameInterval: 0.0,
    whiteBudget: 0.92,
  );

  static RitmoOrbBudget of(RitmoOrbTier tier) {
    switch (tier) {
      case RitmoOrbTier.s:
        return small;
      case RitmoOrbTier.m:
        return medium;
      case RitmoOrbTier.l:
        return large;
    }
  }
}

/// پالت رنگیِ درون تیله.
@immutable
class RitmoOrbPalette {
  const RitmoOrbPalette({
    required this.hot,
    required this.core,
    required this.mid,
    required this.violet,
    required this.aura,
    required this.milk,
  });

  /// داغ‌ترین نقطهٔ جریان (قلب رنگ)
  final Color hot;

  /// بدنهٔ اصلی جریان
  final Color core;

  /// میانهٔ گرم (هلویی / کهربایی)
  final Color mid;

  /// جریان سرد پشتی (بنفش / یاسی)
  final Color violet;

  /// هالهٔ بیرونی تیله
  final Color aura;

  /// شیشهٔ شیری / بالشت سفید
  final Color milk;

  /// پالت پیش‌فرض: مرجانی – سرخابی – یاس
  static const RitmoOrbPalette coral = RitmoOrbPalette(
    hot: Color(0xFFFF2D55),
    core: Color(0xFFFF5A6A),
    mid: Color(0xFFFF9E7A),
    violet: Color(0xFFB07CFF),
    aura: Color(0xFFFF7D91),
    milk: Color(0xFFFFF7F7),
  );

  /// پالت سرد: فیروزه‌ای – نیلی – نعنایی
  static const RitmoOrbPalette aurora = RitmoOrbPalette(
    hot: Color(0xFF00D4FF),
    core: Color(0xFF4C8BFF),
    mid: Color(0xFF7BF1C8),
    violet: Color(0xFF8B5CF6),
    aura: Color(0xFF6FD8FF),
    milk: Color(0xFFF4FBFF),
  );

  /// پالت گرم: کهربا – طلایی – مسی
  static const RitmoOrbPalette ember = RitmoOrbPalette(
    hot: Color(0xFFFF6A00),
    core: Color(0xFFFF9500),
    mid: Color(0xFFFFD166),
    violet: Color(0xFFFF4D8D),
    aura: Color(0xFFFFA75C),
    milk: Color(0xFFFFF9F0),
  );

  RitmoOrbPalette copyWith({
    Color? hot,
    Color? core,
    Color? mid,
    Color? violet,
    Color? aura,
    Color? milk,
  }) {
    return RitmoOrbPalette(
      hot: hot ?? this.hot,
      core: core ?? this.core,
      mid: mid ?? this.mid,
      violet: violet ?? this.violet,
      aura: aura ?? this.aura,
      milk: milk ?? this.milk,
    );
  }

  /// اشباع را می‌کِشد بیرون. برای حالتِ «مطمئن نیستم» و «آفلاین».
  RitmoOrbPalette drained(double amount) {
    final double a = amount.clamp(0.0, 1.0);
    if (a <= 0.0) return this;
    return RitmoOrbPalette(
      hot: _drain(hot, a),
      core: _drain(core, a),
      mid: _drain(mid, a),
      violet: _drain(violet, a),
      aura: _drain(aura, a),
      milk: milk,
    );
  }

  static Color _drain(Color c, double amount) {
    final HSLColor h = HSLColor.fromColor(c);
    return h
        .withSaturation((h.saturation * (1.0 - amount)).clamp(0.0, 1.0))
        .withLightness((h.lightness * (1.0 - amount * 0.12) + amount * 0.06)
            .clamp(0.0, 1.0))
        .toColor();
  }

  static RitmoOrbPalette lerp(RitmoOrbPalette a, RitmoOrbPalette b, double t) {
    if (t <= 0.0) return a;
    if (t >= 1.0) return b;
    return RitmoOrbPalette(
      hot: Color.lerp(a.hot, b.hot, t)!,
      core: Color.lerp(a.core, b.core, t)!,
      mid: Color.lerp(a.mid, b.mid, t)!,
      violet: Color.lerp(a.violet, b.violet, t)!,
      aura: Color.lerp(a.aura, b.aura, t)!,
      milk: Color.lerp(a.milk, b.milk, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RitmoOrbPalette &&
        other.hot == hot &&
        other.core == core &&
        other.mid == mid &&
        other.violet == violet &&
        other.aura == aura &&
        other.milk == milk;
  }

  @override
  int get hashCode => Object.hash(hot, core, mid, violet, aura, milk);
}

/// میان‌یابیِ پالت.
RitmoOrbPalette ritmoLerpPalette(
  RitmoOrbPalette a,
  RitmoOrbPalette b,
  double t,
) =>
    RitmoOrbPalette.lerp(a, b, t);

/// رنگِ تمِ اپ را به پالت می‌زند، بدون اینکه هویتِ تیله را از بین ببرد.
RitmoOrbPalette ritmoTintPalette(
  RitmoOrbPalette base,
  Color tint, {
  double amount = 0.32,
}) {
  final double a = amount.clamp(0.0, 1.0);
  if (a <= 0.0) return base;
  return RitmoOrbPalette(
    hot: Color.lerp(base.hot, tint, a * 0.55)!,
    core: Color.lerp(base.core, tint, a)!,
    mid: Color.lerp(base.mid, tint, a * 0.45)!,
    violet: Color.lerp(base.violet, tint, a * 0.35)!,
    aura: Color.lerp(base.aura, tint, a * 0.70)!,
    milk: base.milk,
  );
}

/// انرژیِ روزِ کاربر. صرفاً یک نجوای رنگی است، نه ادعای سلامت.
@immutable
class RitmoOrbEnergy {
  const RitmoOrbEnergy({this.load = 0.5, this.vitality = 0.5});

  /// سنگینیِ روز (۰ سبک … ۱ خیلی پر)
  final double load;

  /// انرژیِ باقی‌ماندهٔ کاربر (۰ ته‌کشیده … ۱ سرحال)
  final double vitality;

  static const RitmoOrbEnergy neutral = RitmoOrbEnergy();

  bool get isNeutral => load == 0.5 && vitality == 0.5;

  @override
  bool operator ==(Object other) =>
      other is RitmoOrbEnergy &&
      other.load == load &&
      other.vitality == vitality;

  @override
  int get hashCode => Object.hash(load, vitality);
}

/// P4 — کانالِ انرژیِ روز. تا وقتی موتور بینش‌ها چیزی نگوید، مقدار neutral است
/// و هیچ اثری روی تیله ندارد؛ یعنی تیله از خودش چیزی درنمی‌آورد.
class RitmoOrbEnergySignal extends ValueNotifier<RitmoOrbEnergy> {
  RitmoOrbEnergySignal._() : super(RitmoOrbEnergy.neutral);

  static final RitmoOrbEnergySignal instance = RitmoOrbEnergySignal._();

  /// سقفِ اثر: حتی در سنگین‌ترین روز هم تیله بیشتر از این تغییر نمی‌کند.
  static const double maxHueShift = 0.18;
  static const double maxBreathShift = 0.22;

  void report({required double load, required double vitality}) {
    value = RitmoOrbEnergy(
      load: load.clamp(0.0, 1.0),
      vitality: vitality.clamp(0.0, 1.0),
    );
  }

  void clear() => value = RitmoOrbEnergy.neutral;
}

/// پالت را با انرژیِ روز هم‌رنگ می‌کند: روزِ سنگین = خنک‌تر و آرام‌تر.
RitmoOrbPalette ritmoEnergyPalette(
  RitmoOrbPalette base,
  RitmoOrbEnergy energy,
) {
  if (energy.isNeutral) return base;
  final double cool =
      ((energy.load - 0.5) * 2.0).clamp(0.0, 1.0) * RitmoOrbEnergySignal.maxHueShift;
  final double tired =
      ((0.5 - energy.vitality) * 2.0).clamp(0.0, 1.0) * 0.14;
  RitmoOrbPalette out = base;
  if (cool > 0.0) {
    out = RitmoOrbPalette(
      hot: Color.lerp(out.hot, out.violet, cool)!,
      core: Color.lerp(out.core, out.violet, cool * 0.8)!,
      mid: Color.lerp(out.mid, out.violet, cool * 0.5)!,
      violet: out.violet,
      aura: Color.lerp(out.aura, out.violet, cool)!,
      milk: out.milk,
    );
  }
  return tired > 0.0 ? out.drained(tired) : out;
}

/// جایی که تیله دارد نگاه می‌کند. مختصات محلی: -۱ تا ۱.
@immutable
class RitmoOrbAttention {
  const RitmoOrbAttention({this.focus = Offset.zero, this.strength = 0.0});

  final Offset focus;

  /// ۰ = حواسش جای دیگری است، ۱ = خیره شده.
  final double strength;

  static const RitmoOrbAttention rest = RitmoOrbAttention();

  RitmoOrbAttention lerpTo(RitmoOrbAttention other, double t) {
    final double k = t.clamp(0.0, 1.0);
    return RitmoOrbAttention(
      focus: Offset.lerp(focus, other.focus, k)!,
      strength: strength + (other.strength - strength) * k,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RitmoOrbAttention &&
      other.focus == focus &&
      other.strength == strength;

  @override
  int get hashCode => Object.hash(focus, strength);
}

/// کانالِ توجه. جانشینِ چشمک و کجیِ تصادفی: هر حرکتِ سر، دلیل دارد.
class RitmoOrbAttentionSignal extends ValueNotifier<RitmoOrbAttention> {
  RitmoOrbAttentionSignal._() : super(RitmoOrbAttention.rest);

  static final RitmoOrbAttentionSignal instance = RitmoOrbAttentionSignal._();

  /// هر بار بالا رفتن = یک تأییدِ آگاهانه (سرِ تکان دادن)، نه چشمکِ الکی.
  final ValueNotifier<int> acknowledge = ValueNotifier<int>(0);

  /// به یک نقطه نگاه کن؛ مثلاً محلِ کرسرِ کادرِ تایپ یا ستونِ متنِ در حال نوشتن.
  void look(Offset focus, {double strength = 0.75}) {
    value = RitmoOrbAttention(
      focus: Offset(focus.dx.clamp(-1.0, 1.0), focus.dy.clamp(-1.0, 1.0)),
      strength: strength.clamp(0.0, 1.0),
    );
  }

  void relax() => value = RitmoOrbAttention.rest;

  void nod() => acknowledge.value++;
}

/// یک منبعِ نور برای همهٔ لایه‌ها. هر هایلایتی که با این زاویه نخواند، غلط است.
@immutable
class RitmoLightRig {
  const RitmoLightRig({
    required this.dir,
    required this.key,
    required this.fill,
    required this.rim,
    required this.ground,
    required this.whiteBudget,
  });

  /// جهتِ نور در فضای -۱ تا ۱ (پیش‌فرض: بالا-چپ).
  final Offset dir;
  final double key;
  final double fill;
  final double rim;
  final double ground;
  final double whiteBudget;

  static const Offset defaultDir = Offset(-0.34, -0.42);

  Alignment get keyAlign => Alignment(dir.dx, dir.dy);

  /// کاستیک همیشه در ربعِ مقابلِ نور می‌نشیند. قانونِ نشکستنی.
  Alignment get causticAlign => Alignment(-dir.dx * 1.15, -dir.dy * 1.15);

  /// زمینِ تاریکِ کره، مقابلِ نور.
  Alignment get groundAlign => Alignment(-dir.dx * 0.9, -dir.dy * 0.9);

  /// زاویهٔ نور برای چرخاندنِ گرادیانِ لبه.
  double get angle => dir.direction;

  factory RitmoLightRig.resolve({
    required RitmoOrbTier tier,
    required RitmoOrbTruth truth,
    required bool isDark,
    RitmoOrbAttention attention = RitmoOrbAttention.rest,
    Offset tilt = Offset.zero,
  }) {
    // نور با توجه و شیب کمی می‌چرخد: سر که بچرخد، هایلایت هم با آن می‌رود.
    final Offset aimed = Offset(
      defaultDir.dx + attention.focus.dx * 0.16 * attention.strength + tilt.dx * 0.10,
      defaultDir.dy + attention.focus.dy * 0.16 * attention.strength + tilt.dy * 0.10,
    );
    final double budget = RitmoOrbBudget.of(tier).whiteBudget;
    switch (truth) {
      case RitmoOrbTruth.confident:
        return RitmoLightRig(
          dir: aimed,
          key: 1.0,
          fill: isDark ? 0.34 : 0.46,
          rim: isDark ? 0.72 : 0.88,
          ground: isDark ? 0.38 : 0.20,
          whiteBudget: budget,
        );
      case RitmoOrbTruth.unsure:
        return RitmoLightRig(
          dir: aimed,
          key: 0.62,
          fill: isDark ? 0.30 : 0.40,
          rim: isDark ? 0.40 : 0.52,
          ground: isDark ? 0.34 : 0.18,
          whiteBudget: budget * 0.72,
        );
      case RitmoOrbTruth.offline:
        return RitmoLightRig(
          dir: defaultDir,
          key: 0.44,
          fill: isDark ? 0.24 : 0.34,
          rim: isDark ? 0.26 : 0.34,
          ground: isDark ? 0.42 : 0.24,
          whiteBudget: budget * 0.55,
        );
    }
  }
}

/// کیفِ سفید: هر لایه فقط تا سقفِ بودجه سفید برمی‌دارد. اگر تمام شد، تمام است.
class RitmoWhitePurse {
  RitmoWhitePurse(this.budget);

  final double budget;
  double _spent = 0.0;

  double get spent => _spent;

  double take(double request) {
    final double left = (budget - _spent).clamp(0.0, 1.0);
    final double give = request < left ? request : left;
    _spent += give;
    return give < 0.0 ? 0.0 : give;
  }
}

/// شمارندهٔ هزینهٔ نقاشی. در تولید null است و هیچ هزینه‌ای ندارد؛ تست با آن
/// سقفِ [RitmoOrbBudget] را گارد می‌کند.
class RitmoOrbPaintStats {
  int drawOps = 0;
  int blurPasses = 0;
  double white = 0.0;

  void reset() {
    drawOps = 0;
    blurPasses = 0;
    white = 0.0;
  }

  @override
  String toString() =>
      'ops=$drawOps blurs=$blurPasses white=${white.toStringAsFixed(2)}';

  @visibleForTesting
  static RitmoOrbPaintStats? active;
}

/// ثبتِ یک فرمانِ نقاشی در شمارندهٔ فعال.
void ritmoCountPaint({int ops = 1, int blurs = 0, double white = 0.0}) {
  final RitmoOrbPaintStats? stats = RitmoOrbPaintStats.active;
  if (stats == null) return;
  stats.drawOps += ops;
  stats.blurPasses += blurs;
  stats.white += white;
}

/// سرویسِ وضعیتِ زندهٔ هوش مصنوعی (API قبلی + کانالِ صداقت).
class RitmoAiStateService {
  RitmoAiStateService._();

  static final RitmoAiStateService instance = RitmoAiStateService._();

  final ValueNotifier<RitmoOrbMode> orbMode =
      ValueNotifier<RitmoOrbMode>(RitmoOrbMode.idle);
  final ValueNotifier<int> flareTrigger = ValueNotifier<int>(0);
  final ValueNotifier<RitmoOrbTruth> truth =
      ValueNotifier<RitmoOrbTruth>(RitmoOrbTruth.confident);

  void setMode(RitmoOrbMode mode) {
    if (orbMode.value != mode) orbMode.value = mode;
  }

  void setTruth(RitmoOrbTruth value) {
    if (truth.value != value) truth.value = value;
  }

  void triggerSuccessFlare() => flareTrigger.value++;
}
