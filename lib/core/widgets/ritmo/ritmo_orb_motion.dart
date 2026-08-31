// =============================================================================
//  Ritmo Orb Motion — ریاضیاتِ حرکتِ تیله
//
//  همهٔ حرکت‌ها فنری است، نه خطی؛ پس تغییر حالت وسطِ راه هیچ‌وقت پرش ندارد.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbMode, RitmoOrbPalette;

/// حالت زندگیِ تیله. جدا از [RitmoOrbMode] تا enum اصلی دست‌نخورده بماند.
enum RitmoOrbLife {
  /// پنهان؛ پایین می‌رود، در کادرِ تایپ جذب می‌شود و ارتفاعش را آزاد می‌کند.
  hidden,

  /// خوابِ سبک: خیلی کوچک و کم‌رنگ، فقط نفس می‌کشد.
  dormant,

  /// استراحت: نفس می‌کشد و آرام شنا می‌کند.
  breathing,

  /// «گوش می‌دهم»: نفس عمیق‌تر، رنگ خنک‌تر.
  listening,

  /// در حال فکر کردن.
  thinking,

  /// در حال نوشتن: نفس + ادا و اطفار + پرش روی هر توکن.
  writing,

  /// پاسخ تمام شد: شکفتنِ گرم و کوتاه.
  celebrating,
}

/// فنر تک‌بعدی با میرایی. رازِ حرکتِ پرمیوم همین است: وقتی وسطِ راه
/// هدف را عوض کنی، سرعتِ فعلی حفط می‌شود.
class RitmoSpring {
  RitmoSpring({
    required double initial,
    this.stiffness = 120.0,
    this.damping = 20.0,
  })  : value = initial,
        target = initial;

  double value;
  double target;
  double velocity = 0.0;
  double stiffness;
  double damping;

  void snap(double v) {
    value = v;
    target = v;
    velocity = 0.0;
  }

  /// ضربهٔ لحطه‌ای به سرعت (برای پرش روی هر توکن).
  void kick(double impulse) {
    velocity += impulse;
  }

  /// گام‌های ریز تا افتادنِ فریم، حرکت را ناپایدار نکند.
  void step(double dt) {
    const double maxStep = 1.0 / 120.0;
    var remaining = dt;
    while (remaining > 0.0) {
      final double h = remaining > maxStep ? maxStep : remaining;
      remaining -= h;
      final double a = stiffness * (target - value) - damping * velocity;
      velocity += a * h;
      value += velocity * h;
    }
  }
}

/// دم ۳۳٪ ← نگه ۹٪ ← بازدمِ کشیدهٔ ۴۴٪ ← سکوت ۱۴٪
double ritmoBreathCurve(double x) {
  const double inhale = 0.33;
  const double hold = 0.09;
  const double exhale = 0.44;

  if (x < inhale) {
    return Curves.easeInOutSine.transform(x / inhale);
  }
  final double afterIn = x - inhale;
  if (afterIn < hold) {
    return 1.0;
  }
  final double afterHold = afterIn - hold;
  if (afterHold < exhale) {
    return 1.0 - Curves.easeInOutCubic.transform(afterHold / exhale);
  }
  return 0.0;
}

RitmoOrbPalette ritmoLerpPalette(
  RitmoOrbPalette a,
  RitmoOrbPalette b,
  double t,
) {
  return RitmoOrbPalette(
    hot: Color.lerp(a.hot, b.hot, t)!,
    core: Color.lerp(a.core, b.core, t)!,
    mid: Color.lerp(a.mid, b.mid, t)!,
    violet: Color.lerp(a.violet, b.violet, t)!,
    aura: Color.lerp(a.aura, b.aura, t)!,
    milk: Color.lerp(a.milk, b.milk, t)!,
  );
}

/// دمای رنگ: ‎-۱ خنک (فکر) .. ۰ پایه .. ‎+۱ گرم (جشن)
RitmoOrbPalette ritmoTintPalette(RitmoOrbPalette base, double hue) {
  final double h = hue.clamp(-1.0, 1.0);
  if (h < 0.0) {
    return ritmoLerpPalette(base, RitmoOrbPalette.aurora, -h * 0.26);
  }
  if (h > 0.0) {
    return ritmoLerpPalette(base, RitmoOrbPalette.ember, h * 0.24);
  }
  return base;
}

/// درگیری در ادا و اطفار.
double ritmoPlayFor(RitmoOrbLife life) {
  switch (life) {
    case RitmoOrbLife.hidden:
    case RitmoOrbLife.dormant:
    case RitmoOrbLife.breathing:
      return 0.0;
    case RitmoOrbLife.listening:
      return 0.20;
    case RitmoOrbLife.thinking:
      return 0.34;
    case RitmoOrbLife.writing:
      return 1.0;
    case RitmoOrbLife.celebrating:
      return 0.42;
  }
}

/// عمق نفس.
double ritmoDepthFor(RitmoOrbLife life) {
  switch (life) {
    case RitmoOrbLife.hidden:
      return 0.45;
    case RitmoOrbLife.dormant:
      return 0.78;
    case RitmoOrbLife.breathing:
      return 1.0;
    case RitmoOrbLife.listening:
      return 1.15;
    case RitmoOrbLife.thinking:
      return 0.82;
    case RitmoOrbLife.writing:
      return 0.52;
    case RitmoOrbLife.celebrating:
      return 0.95;
  }
}

double ritmoHueFor(RitmoOrbLife life) {
  switch (life) {
    case RitmoOrbLife.listening:
      return -0.55;
    case RitmoOrbLife.thinking:
      return -1.0;
    case RitmoOrbLife.celebrating:
      return 1.0;
    case RitmoOrbLife.hidden:
    case RitmoOrbLife.dormant:
    case RitmoOrbLife.breathing:
    case RitmoOrbLife.writing:
      return 0.0;
  }
}

/// اندازهٔ نسبیِ تیله در هر حالت.
double ritmoFormFor(RitmoOrbLife life) {
  switch (life) {
    case RitmoOrbLife.dormant:
      return 0.46;
    case RitmoOrbLife.hidden:
    case RitmoOrbLife.breathing:
    case RitmoOrbLife.listening:
    case RitmoOrbLife.thinking:
    case RitmoOrbLife.writing:
    case RitmoOrbLife.celebrating:
      return 1.0;
  }
}

RitmoOrbMode ritmoModeFor(RitmoOrbLife life) {
  switch (life) {
    case RitmoOrbLife.writing:
    case RitmoOrbLife.celebrating:
      return RitmoOrbMode.streaming;
    case RitmoOrbLife.listening:
    case RitmoOrbLife.thinking:
      return RitmoOrbMode.thinking;
    case RitmoOrbLife.breathing:
    case RitmoOrbLife.dormant:
    case RitmoOrbLife.hidden:
      return RitmoOrbMode.idle;
  }
}

/// شکلِ ورود/خروجِ تیله در یک لحطه.
@immutable
class RitmoOrbPose {
  const RitmoOrbPose({
    required this.sx,
    required this.sy,
    required this.dy,
    required this.rot,
    required this.opacity,
    required this.ripple,
    required this.rippleAlpha,
    required this.collapse,
  });

  final double sx;
  final double sy;
  final double dy;
  final double rot;
  final double opacity;
  final double ripple;
  final double rippleAlpha;

  /// ۰ = هنوز سرجا؛ ۱ = کاملاً جذب شده در کادر.
  final double collapse;

  /// پیشرفتِ جذب برای گزارش به کادرِ تایپ (مستقل از ساختنِ کل پوز).
  static double collapseOf(double p) {
    final double e = Curves.easeInOutCubic.transform(1.0 - p.clamp(0.0, 1.0));
    if (e <= 0.28) return 0.0;
    return Curves.easeInCubic.transform((e - 0.28) / 0.72);
  }

  /// خروج: یک نفسِ عمیق ← کشیده شدنِ قطره‌مانند ← فرو رفتن در کادر.
  factory RitmoOrbPose.sinking({required double p, required double size}) {
    final double e = Curves.easeInOutCubic.transform(1.0 - p);
    final double swell = math.sin(math.min(1.0, e / 0.28) * math.pi) * 0.10;
    final double collapse =
        e <= 0.28 ? 0.0 : Curves.easeInCubic.transform((e - 0.28) / 0.72);
    final double drop = collapse * collapse;
    final double base = (1.0 + swell) * (1.0 - 0.84 * collapse);

    return RitmoOrbPose(
      sx: base * (1.0 + swell * 0.50 - collapse * 0.30),
      sy: base * (1.0 - swell * 0.34 + collapse * 0.40),
      dy: size * 0.74 * drop,
      rot: 0.06 * drop,
      opacity: math.pow(1.0 - collapse, 1.55).toDouble(),
      ripple: Curves.easeOutQuart.transform(e),
      rippleAlpha: math.sin(e * math.pi) * 0.40,
      collapse: collapse,
    );
  }

  /// ورود: از دلِ کادرِ تایپ بالا می‌آید و شکفته می‌شود.
  factory RitmoOrbPose.rising({required double p, required double size}) {
    final double e = Curves.easeOutCubic.transform(p);
    final double swell = math.sin(p * math.pi) * 0.10;
    final double base = 0.46 + 0.54 * e;

    return RitmoOrbPose(
      sx: base * (1.0 + swell * 0.45 - 0.10 * (1.0 - e)),
      sy: base * (1.0 - swell * 0.28 + 0.16 * (1.0 - e)),
      dy: size * 0.60 * (1.0 - Curves.easeOutQuart.transform(p)),
      rot: 0.0,
      opacity: Curves.easeOutCubic.transform(math.min(1.0, p * 1.30)),
      ripple: 1.0 - Curves.easeOutCubic.transform(p),
      rippleAlpha: math.sin(p * math.pi) * 0.34,
      collapse: 0.0,
    );
  }
}
