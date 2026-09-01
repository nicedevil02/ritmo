// =============================================================================
//  Ritmo Orb Motion — امضای حرکتیِ هر حالت
//  قبلاً هر حالت چند جدولِ جدا داشت (عمق، رنگ، فرم، بازی) و هیچ‌کدام با دیگری
//  هماهنگ نبود. حالا یک امضا: هر حالت یک ردیف از [RitmoOrbSignature] است.
// =============================================================================

import 'package:flutter/widgets.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

export 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart'
    show
        RitmoAiStateService,
        RitmoOrbAttention,
        RitmoOrbAttentionSignal,
        RitmoOrbEnergy,
        RitmoOrbEnergySignal,
        RitmoOrbMode,
        RitmoOrbPalette,
        RitmoOrbTier,
        RitmoOrbTruth,
        ritmoTierFor;

/// حالتِ زندگیِ تیله (مقدارها عیناً مثل قبل).
enum RitmoOrbLife {
  hidden,
  dormant,
  breathing,
  listening,
  thinking,
  writing,
  celebrating,
}

/// حالتِ زندگی را به حالتِ کاریِ موتور ترجمه می‌کند.
RitmoOrbMode ritmoModeFor(RitmoOrbLife life) {
  switch (life) {
    case RitmoOrbLife.hidden:
    case RitmoOrbLife.dormant:
    case RitmoOrbLife.breathing:
    case RitmoOrbLife.listening:
      return RitmoOrbMode.idle;
    case RitmoOrbLife.thinking:
      return RitmoOrbMode.thinking;
    case RitmoOrbLife.writing:
    case RitmoOrbLife.celebrating:
      return RitmoOrbMode.streaming;
  }
}

/// منحنیِ نفس: دم ۳۳٪ – نگه‌داشت ۹٪ – بازدم ۴۴٪ – سکوت ۱۴٪.
/// تقارن نیست، پس ماشینی هم به نظر نمی‌رسد.
double ritmoBreathCurve(double phase) {
  final double p = phase - phase.floorToDouble();
  if (p < 0.33) {
    return Curves.easeInOutSine.transform(p / 0.33);
  }
  if (p < 0.42) {
    return 1.0;
  }
  if (p < 0.86) {
    return 1.0 - Curves.easeInOutSine.transform((p - 0.42) / 0.44);
  }
  return 0.0;
}

/// همهٔ چیزی که یک حالت را از حالتِ دیگر جدا می‌کند — در یک جا.
@immutable
class RitmoOrbSignature {
  const RitmoOrbSignature({
    required this.breathMs,
    required this.flow,
    required this.density,
    required this.rim,
    required this.wobble,
    required this.tremor,
    required this.plumes,
    required this.aura,
    required this.scale,
  });

  /// دورهٔ یک نفس کامل
  final double breathMs;

  /// سرعتِ جریانِ درون
  final double flow;

  /// تراکمِ رنگ
  final double density;

  /// روشناییِ لبه
  final double rim;

  /// نوسانِ پوسته
  final double wobble;

  /// لرزشِ ریزِ تمرکز (فقط در فکر کردن)
  final double tremor;

  /// تعداد تودهٔ جریان (سپس با بودجهٔ رده محدود می‌شود)
  final int plumes;

  /// قدرتِ هاله
  final double aura;

  /// مقیاسِ پایه (حضورِ فیزیکی)
  final double scale;

  static const RitmoOrbSignature _dormant = RitmoOrbSignature(
    breathMs: 7800,
    flow: 0.18,
    density: 0.18,
    rim: 0.30,
    wobble: 0.10,
    tremor: 0.0,
    plumes: 2,
    aura: 0.12,
    scale: 0.94,
  );

  static const RitmoOrbSignature _breathing = RitmoOrbSignature(
    breathMs: 5200,
    flow: 0.34,
    density: 0.42,
    rim: 0.48,
    wobble: 0.16,
    tremor: 0.0,
    plumes: 3,
    aura: 0.34,
    scale: 1.0,
  );

  static const RitmoOrbSignature _listening = RitmoOrbSignature(
    breathMs: 4200,
    flow: 0.46,
    density: 0.52,
    rim: 0.70,
    wobble: 0.20,
    tremor: 0.0,
    plumes: 3,
    aura: 0.46,
    scale: 1.03,
  );

  static const RitmoOrbSignature _thinking = RitmoOrbSignature(
    breathMs: 3000,
    flow: 0.78,
    density: 0.74,
    rim: 0.40,
    wobble: 0.24,
    tremor: 0.25,
    plumes: 4,
    aura: 0.38,
    scale: 0.99,
  );

  static const RitmoOrbSignature _writing = RitmoOrbSignature(
    breathMs: 2400,
    flow: 1.0,
    density: 0.88,
    rim: 0.62,
    wobble: 0.18,
    tremor: 0.06,
    plumes: 4,
    aura: 0.56,
    scale: 1.01,
  );

  static const RitmoOrbSignature _celebrating = RitmoOrbSignature(
    breathMs: 1800,
    flow: 1.15,
    density: 1.0,
    rim: 0.95,
    wobble: 0.26,
    tremor: 0.0,
    plumes: 4,
    aura: 0.86,
    scale: 1.06,
  );

  static RitmoOrbSignature of(RitmoOrbLife life) {
    switch (life) {
      case RitmoOrbLife.hidden:
      case RitmoOrbLife.dormant:
        return _dormant;
      case RitmoOrbLife.breathing:
        return _breathing;
      case RitmoOrbLife.listening:
        return _listening;
      case RitmoOrbLife.thinking:
        return _thinking;
      case RitmoOrbLife.writing:
        return _writing;
      case RitmoOrbLife.celebrating:
        return _celebrating;
    }
  }

  static RitmoOrbSignature ofMode(RitmoOrbMode mode) {
    switch (mode) {
      case RitmoOrbMode.idle:
        return _breathing;
      case RitmoOrbMode.thinking:
        return _thinking;
      case RitmoOrbMode.streaming:
        return _writing;
      case RitmoOrbMode.compact:
        return _dormant;
    }
  }

  RitmoOrbSignature copyWith({
    double? breathMs,
    double? flow,
    double? density,
    double? rim,
    double? wobble,
    double? tremor,
    int? plumes,
    double? aura,
    double? scale,
  }) {
    return RitmoOrbSignature(
      breathMs: breathMs ?? this.breathMs,
      flow: flow ?? this.flow,
      density: density ?? this.density,
      rim: rim ?? this.rim,
      wobble: wobble ?? this.wobble,
      tremor: tremor ?? this.tremor,
      plumes: plumes ?? this.plumes,
      aura: aura ?? this.aura,
      scale: scale ?? this.scale,
    );
  }

  /// صداقت: وقتی مطمئن نیست کم‌رنگ‌تر و بی‌قرارتر است؛ وقتی آفلاین است، جریان
  /// درونش می‌ایستد. این فقط زیبایی نیست، اطلاعات است.
  RitmoOrbSignature withTruth(RitmoOrbTruth truth) {
    switch (truth) {
      case RitmoOrbTruth.confident:
        return this;
      case RitmoOrbTruth.unsure:
        return copyWith(
          flow: flow * 0.72,
          density: density * 0.80,
          rim: rim * 0.58,
          wobble: wobble * 1.20,
          tremor: tremor + 0.10,
          aura: aura * 0.60,
        );
      case RitmoOrbTruth.offline:
        return copyWith(
          breathMs: breathMs * 1.6,
          flow: 0.05,
          density: density * 0.35,
          rim: 0.26,
          wobble: wobble * 0.35,
          tremor: 0.0,
          plumes: 1,
          aura: 0.0,
          scale: 0.97,
        );
    }
  }

  /// P4 — هم‌رنگی با انرژیِ روز. سقفِ اثر عمداً کوچک است: تیله قرار نیست روزِ بد
  /// را دراماتیک کند؛ فقط قدری آرام‌تر نفس می‌کشد.
  RitmoOrbSignature withEnergy(RitmoOrbEnergy energy) {
    if (energy.isNeutral) return this;
    final double heavy = ((energy.load - 0.5) * 2.0).clamp(0.0, 1.0);
    final double tired = ((0.5 - energy.vitality) * 2.0).clamp(0.0, 1.0);
    return copyWith(
      breathMs: breathMs *
          (1.0 + heavy * RitmoOrbEnergySignal.maxBreathShift),
      flow: flow * (1.0 - tired * 0.18),
      aura: aura * (1.0 - heavy * 0.20),
    );
  }

  static RitmoOrbSignature lerp(
    RitmoOrbSignature a,
    RitmoOrbSignature b,
    double t,
  ) {
    if (t <= 0.0) return a;
    if (t >= 1.0) return b;
    double mix(double x, double y) => x + (y - x) * t;
    return RitmoOrbSignature(
      breathMs: mix(a.breathMs, b.breathMs),
      flow: mix(a.flow, b.flow),
      density: mix(a.density, b.density),
      rim: mix(a.rim, b.rim),
      wobble: mix(a.wobble, b.wobble),
      tremor: mix(a.tremor, b.tremor),
      plumes: t < 0.5 ? a.plumes : b.plumes,
      aura: mix(a.aura, b.aura),
      scale: mix(a.scale, b.scale),
    );
  }
}

/// فنرِ بحرانی‌زدهٔ ساده. گسسته از زمانِ فریم، پس در ۳۰ و ۱۲۰ فریم یکسان است.
class RitmoSpring {
  RitmoSpring({
    this.stiffness = 180.0,
    this.damping = 22.0,
    double value = 0.0,
  })  : _value = value,
        target = value;

  final double stiffness;
  final double damping;

  double _value;
  double target;
  double velocity = 0.0;

  double get value => _value;

  void snap(double next) {
    _value = next;
    target = next;
    velocity = 0.0;
  }

  void kick(double impulse) => velocity += impulse;

  /// یک گام جلو. خروجی: هنوز در حرکت است یا نه.
  bool step(double dt) {
    double left = dt;
    const double maxStep = 1.0 / 120.0;
    while (left > 0.0) {
      final double h = left > maxStep ? maxStep : left;
      final double accel = (target - _value) * stiffness - velocity * damping;
      velocity += accel * h;
      _value += velocity * h;
      left -= h;
    }
    if ((target - _value).abs() < 0.0005 && velocity.abs() < 0.005) {
      _value = target;
      velocity = 0.0;
      return false;
    }
    return true;
  }
}

/// ژستِ ورود/خروجِ تیله.
@immutable
class RitmoOrbPose {
  const RitmoOrbPose({
    required this.scale,
    required this.opacity,
    required this.lift,
  });

  final double scale;
  final double opacity;

  /// جابجاییِ عمودی بر حسب ضریبی از اندازهٔ تیله (+ یعنی پایین‌تر).
  final double lift;

  static const RitmoOrbPose gone =
      RitmoOrbPose(scale: 0.72, opacity: 0.0, lift: 0.26);
  static const RitmoOrbPose present =
      RitmoOrbPose(scale: 1.0, opacity: 1.0, lift: 0.0);

  static RitmoOrbPose lerp(RitmoOrbPose a, RitmoOrbPose b, double t) {
    final double k = t.clamp(0.0, 1.0);
    return RitmoOrbPose(
      scale: a.scale + (b.scale - a.scale) * k,
      opacity: a.opacity + (b.opacity - a.opacity) * k,
      lift: a.lift + (b.lift - a.lift) * k,
    );
  }
}
