// =============================================================================
//  Ritmo Orb Presence — حضور زندهٔ تیلهٔ تفکر ریتمو
//
//  همهٔ حرکت‌ها فنری (spring) است، نه خطی. پس تغییر حالت هیچ‌وقت پرش ندارد:
//    • نفس نامتقارن: دم ۳۳٪ / نگه ۹٪ / بازدم ۴۴٪ / سکوت ۱۴٪
//    • شناوری لیساژو با فرکانس ناهم‌مقیاس → هیچ‌وقت تکرار نمی‌شود
//    • ادا و اطفار: تابِ رهبر ارکستر + ضربهٔ فنری روی هر توکن + چشمک نادر
//    • جشن کوتاه آخر پاسخ، بعد محو شدن با پژواک نور
//    • ورود: شکفتن  |  خروج: نفس عمیق ← جمع شدن ← فرو رفتن
//
//  ritmo_siri_orb.dart دست‌نخورده می‌ماند؛ فقط پارامترهای عمومی‌اش رانده می‌شوند.
// =============================================================================

import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_halo.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart';

/// حالت زندگی تیله. جدا از [RitmoOrbMode] تا enum اصلی دست‌نخورده بماند.
enum RitmoOrbLife {
  /// پنهان؛ با انیمیشن جمع می‌شود و ارتفاع رزروشده را هم آزاد می‌کند.
  hidden,

  /// استراحت: فقط نفس می‌کشد و آرام شنا می‌کند.
  breathing,

  /// «گوش می‌دهم»: نفس عمیق‌تر و رنگ کمی خنک‌تر.
  listening,

  /// در حال فکر کردن.
  thinking,

  /// در حال نوشتن: نفس + ادا و اطفار + پرش روی هر توکن.
  writing,

  /// پاسخ تمام شد: شکفتن گرم و کوتاه.
  celebrating,
}

/// فنر تک‌بعدی با میرایی. راز حرکت پرمیوم همین است: وقتی وسط راه هدف را
/// عوض می‌کنی، سرعت فعلی حفظ می‌شود و حرکت هیچ پرشی ندارد.
class _Spring {
  _Spring({
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

  /// ضربهٔ لحظه‌ای به سرعت (برای پرش روی هر توکن).
  void kick(double impulse) {
    velocity += impulse;
  }

  /// گام‌های ریز تا افتادن فریم، حرکت را ناپایدار نکند.
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

/// میان‌یابی نرم بین دو پالت تا دمای رنگ درون تیله با حالتش عوض شود.
RitmoOrbPalette _lerpPalette(
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

class RitmoLivingOrb extends StatefulWidget {
  const RitmoLivingOrb({
    super.key,
    required this.life,
    this.size = 52.0,
    this.palette,
    this.glowEnabled = true,
    this.writingPulse,
    this.onTap,
    this.anticsStrength = 1.0,
    this.reserveHeightFactor = 1.55,
    this.breathPeriod = const Duration(milliseconds: 5200),
    this.enterDuration = const Duration(milliseconds: 720),
    this.exitDuration = const Duration(milliseconds: 760),
    this.animateOnMount = true,
    this.reactToSuccessFlare = true,
    this.semanticLabel = 'دستیار هوشمند ریتمو',
  });

  final RitmoOrbLife life;

  /// قطر خود تیله (فضای رزروشده = size × reserveHeightFactor).
  final double size;

  /// اگر null باشد [RitmoOrbPalette.coral] استفاده می‌شود.
  final RitmoOrbPalette? palette;

  final bool glowEnabled;

  /// هر بار مقدارش عوض شود، یک ضربهٔ فنری نرم به تیله زده می‌شود.
  final ValueListenable<int>? writingPulse;

  final VoidCallback? onTap;

  /// ۰ = خنثی، ۱ = پیش‌فرض، ۱٫۶ = شیطون.
  final double anticsStrength;

  /// ارتفاع رزروشده در layout (ضریبی از [size]) که موقع مخفی شدن نرم جمع می‌شود.
  final double reserveHeightFactor;

  final Duration breathPeriod;
  final Duration enterDuration;
  final Duration exitDuration;
  final bool animateOnMount;

  /// واکنش به `RitmoAiStateService.instance.triggerSuccessFlare()`.
  final bool reactToSuccessFlare;

  final String semanticLabel;

  @override
  State<RitmoLivingOrb> createState() => _RitmoLivingOrbState();
}

class _RitmoLivingOrbState extends State<RitmoLivingOrb>
    with TickerProviderStateMixin {
  static const double _kFallbackFrame = 1.0 / 60.0;

  late final AnimationController _presence;

  /// درگیری در ادا و اطفار (۰..۱)
  final _Spring _play = _Spring(initial: 0.0, stiffness: 46.0, damping: 14.0);

  /// عمق نفس
  final _Spring _depth = _Spring(initial: 1.0, stiffness: 34.0, damping: 12.5);

  /// پرش روی هر توکن
  final _Spring _hop = _Spring(initial: 0.0, stiffness: 168.0, damping: 12.5);

  /// چرخش آرام «سر» موقع نوشتن
  final _Spring _lean = _Spring(initial: 0.0, stiffness: 22.0, damping: 9.0);

  /// شکفتن جشن / بارقهٔ موفقیت
  final _Spring _bloom = _Spring(initial: 0.0, stiffness: 74.0, damping: 11.0);

  /// دمای رنگ: ‎-۱ خنک (فکر) .. ۰ پایه .. ‎+۱ گرم (جشن)
  final _Spring _hue = _Spring(initial: 0.0, stiffness: 26.0, damping: 10.5);

  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  double _breathPhase = 0.10;
  double _driftPhase = 0.0;
  double _swayPhase = 0.0;

  double _breath01 = 0.0;
  double _winkCountdown = 4.5;
  double _winkProgress = 1.0;
  int _pulseCount = 0;

  final math.Random _rng = math.Random(7);

  int? _lastPulse;
  int? _lastFlare;
  late RitmoOrbLife _shownLife;
  bool _reduceMotion = false;

  RitmoOrbPalette? _paletteCache;
  RitmoOrbPalette? _paletteBase;
  double _paletteHue = 999.0;

  @override
  void initState() {
    super.initState();

    final bool visible = widget.life != RitmoOrbLife.hidden;
    _shownLife = visible ? widget.life : RitmoOrbLife.breathing;

    _presence = AnimationController(
      vsync: this,
      duration: widget.enterDuration,
      reverseDuration: widget.exitDuration,
      value: (visible && !widget.animateOnMount) ? 1.0 : 0.0,
    )..addStatusListener(_onPresenceStatus);

    _play.snap(_playFor(_shownLife));
    _depth.snap(_depthFor(_shownLife));
    _hue.snap(_hueFor(_shownLife));

    _ticker = createTicker(_onTick);
    _bindPulse();

    _lastFlare = RitmoAiStateService.instance.flareTrigger.value;
    RitmoAiStateService.instance.flareTrigger.addListener(_handleFlare);

    if (visible && widget.animateOnMount) {
      _presence.forward();
    }
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void didUpdateWidget(RitmoLivingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.writingPulse != widget.writingPulse) {
      oldWidget.writingPulse?.removeListener(_handlePulse);
      _bindPulse();
    }

    _presence.duration = widget.enterDuration;
    _presence.reverseDuration = widget.exitDuration;

    if (oldWidget.life == widget.life) return;

    final bool wasHidden = oldWidget.life == RitmoOrbLife.hidden;

    if (widget.life == RitmoOrbLife.hidden) {
      // رنگ و عمق دست‌نخورده می‌ماند تا خروج، حال‌وهوای لحظهٔ قبل را نگه دارد.
      _play.target = 0.0;
      _lean.target = 0.0;
      _presence.reverse();
    } else {
      _shownLife = widget.life;

      if (wasHidden) {
        _hop.snap(0.0);
        _bloom.snap(0.0);
        _lean.snap(0.0);
        _breathPhase = 0.04; // ورود با یک دم تازه
        _winkCountdown = 4.5;
        _winkProgress = 1.0;
        _pulseCount = 0;
      }

      if (widget.life == RitmoOrbLife.celebrating) {
        _bloom.snap(0.0);
        _bloom.kick(3.1);
      }
      if (widget.life != RitmoOrbLife.writing) {
        _lean.target = 0.0;
      }

      _play.target = _playFor(widget.life);
      _depth.target = _depthFor(widget.life);
      _hue.target = _hueFor(widget.life);
      _presence.forward();
    }

    _syncTicker();
  }

  @override
  void dispose() {
    widget.writingPulse?.removeListener(_handlePulse);
    RitmoAiStateService.instance.flareTrigger.removeListener(_handleFlare);
    _ticker?.dispose();
    _presence.removeStatusListener(_onPresenceStatus);
    _presence.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _onPresenceStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _syncTicker();
  }

  void _bindPulse() {
    widget.writingPulse?.addListener(_handlePulse);
    _lastPulse = widget.writingPulse?.value;
  }

  void _handlePulse() {
    final int? v = widget.writingPulse?.value;
    if (v == null || v == _lastPulse) return;
    _lastPulse = v;
    if (_reduceMotion || widget.life == RitmoOrbLife.hidden) return;

    _pulseCount++;

    // هرچه تیله بیشتر در حرکت باشد، ضربهٔ بعدی ملایم‌تر می‌شود؛ نتیجه:
    // توکن‌های تند به‌جای رگبار، یک لرزش نرم و پیوسته می‌سازند.
    final double softener = 1.0 / (1.0 + _hop.value.abs() * 2.1);
    _hop.kick(2.30 * softener * widget.anticsStrength.clamp(0.0, 2.0));

    // هر چند توکن یک‌بار، سرش را کمی می‌چرخاند: حس رهبر ارکستر.
    if (_pulseCount % 7 == 0) {
      _lean.target = (_rng.nextDouble() * 2.0 - 1.0) * 0.85;
    }
  }

  void _handleFlare() {
    final int v = RitmoAiStateService.instance.flareTrigger.value;
    if (v == _lastFlare) return;
    _lastFlare = v;
    if (!widget.reactToSuccessFlare || _reduceMotion) return;
    if (widget.life == RitmoOrbLife.hidden) return;
    _bloom.snap(0.0);
    _bloom.kick(2.9);
  }

  void _syncTicker() {
    final Ticker? ticker = _ticker;
    if (ticker == null) return;
    final bool needs =
        widget.life != RitmoOrbLife.hidden || _presence.value > 0.0;
    if (needs && !ticker.isActive) {
      _lastTick = Duration.zero;
      ticker.start();
    } else if (!needs && ticker.isActive) {
      ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    if (dt <= 0.0) return;
    // اگر فریم افتاد، جهش نمی‌کنیم.
    if (dt > 0.25) dt = _kFallbackFrame;

    final double play = _play.value.clamp(0.0, 1.0);
    final double motion = _reduceMotion ? 0.0 : 1.0;

    final double periodSec =
        math.max(0.8, widget.breathPeriod.inMilliseconds / 1000.0);
    _breathPhase += dt * (1.0 + 0.55 * play) / periodSec;
    _breath01 = _breathCurve(_breathPhase - _breathPhase.floorToDouble());

    _driftPhase += dt * (0.055 + 0.030 * play) * motion;
    _swayPhase += dt * (0.095 + 0.150 * play) * motion;

    if (motion > 0.0) {
      _winkCountdown -= dt * (0.55 + 0.85 * play);
      if (_winkCountdown <= 0.0) {
        _winkCountdown = 5.0 + _rng.nextDouble() * 6.0;
        _winkProgress = 0.0;
      }
      if (_winkProgress < 1.0) {
        _winkProgress = math.min(1.0, _winkProgress + dt / 0.38);
      }
    }

    _play.step(dt);
    _depth.step(dt);
    _hop.step(dt);
    _lean.step(dt);
    _bloom.step(dt);
    _hue.step(dt);

    _frame.value = _frame.value + 1;
  }

  /// دم ۳۳٪ ← نگه ۹٪ ← بازدم کشیدهٔ ۴۴٪ ← سکوت ۱۴٪
  static double _breathCurve(double x) {
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

  static double _playFor(RitmoOrbLife life) {
    switch (life) {
      case RitmoOrbLife.hidden:
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

  static double _depthFor(RitmoOrbLife life) {
    switch (life) {
      case RitmoOrbLife.hidden:
        return 0.45;
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

  static double _hueFor(RitmoOrbLife life) {
    switch (life) {
      case RitmoOrbLife.listening:
        return -0.55;
      case RitmoOrbLife.thinking:
        return -1.0;
      case RitmoOrbLife.celebrating:
        return 1.0;
      case RitmoOrbLife.hidden:
      case RitmoOrbLife.breathing:
      case RitmoOrbLife.writing:
        return 0.0;
    }
  }

  static RitmoOrbMode _modeFor(RitmoOrbLife life) {
    switch (life) {
      case RitmoOrbLife.writing:
      case RitmoOrbLife.celebrating:
        return RitmoOrbMode.streaming;
      case RitmoOrbLife.listening:
      case RitmoOrbLife.thinking:
        return RitmoOrbMode.thinking;
      case RitmoOrbLife.breathing:
      case RitmoOrbLife.hidden:
        return RitmoOrbMode.idle;
    }
  }

  RitmoOrbPalette _resolvePalette() {
    final RitmoOrbPalette base = widget.palette ?? RitmoOrbPalette.coral;
    final double h = _hue.value.clamp(-1.0, 1.0);

    final bool stale = _paletteCache == null ||
        !identical(base, _paletteBase) ||
        (h - _paletteHue).abs() > 0.02;

    if (stale) {
      _paletteBase = base;
      _paletteHue = h;
      if (h < 0.0) {
        _paletteCache = _lerpPalette(base, RitmoOrbPalette.aurora, -h * 0.26);
      } else if (h > 0.0) {
        _paletteCache = _lerpPalette(base, RitmoOrbPalette.ember, h * 0.24);
      } else {
        _paletteCache = base;
      }
    }
    return _paletteCache!;
  }

  void _handleTap() {
    final VoidCallback? cb = widget.onTap;
    if (cb == null) return;
    if (!_reduceMotion) {
      _bloom.snap(0.0);
      _bloom.kick(2.2);
      unawaited(HapticFeedback.selectionClick());
    }
    cb();
  }

  @override
  Widget build(BuildContext context) {
    final double box = widget.size * widget.reserveHeightFactor;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_frame, _presence]),
        builder: (BuildContext context, Widget? _) {
          final double p = _presence.value.clamp(0.0, 1.0);
          final bool exiting = widget.life == RitmoOrbLife.hidden;

          // کاملاً رفته: صفر هزینه در layout و paint.
          if (exiting && p <= 0.0005) return const SizedBox.shrink();

          final double amp = _reduceMotion ? 0.30 : 1.0;
          final double play =
              (_play.value.clamp(0.0, 1.0)) * widget.anticsStrength;
          final double depth = _depth.value.clamp(0.0, 1.4);
          final double breath01 = _breath01;
          final double breath = breath01 * 2.0 - 1.0;

          // شناوری: دو موج ناهم‌مقیاس در هر محور → مسیر غیرتکراری
          final double d = _driftPhase * math.pi * 2.0;
          final double driftX =
              math.sin(d * 0.61) * 0.62 + math.sin(d * 0.23 + 1.9) * 0.38;
          final double driftY =
              math.sin(d * 0.44 + 0.7) * 0.58 + math.sin(d * 0.83 + 2.4) * 0.42;

          final double s = _swayPhase * math.pi * 2.0;
          final double sway =
              math.sin(s * 0.42) * 0.62 + math.sin(s * 0.67 + 1.1) * 0.38;
          final double lean = _lean.value.clamp(-1.0, 1.0);
          final double hop = _hop.value.clamp(-1.2, 1.2);
          final double wink =
              _winkProgress >= 1.0 ? 0.0 : math.sin(_winkProgress * math.pi);
          final double bloom = _bloom.value.clamp(0.0, 1.4);

          final double sx0;
          final double sy0;
          final double dy0;
          final double rot0;
          final double opacity;
          final double ripple;
          final double rippleAlpha;

          if (exiting) {
            // نفس عمیق (باد کردن) ← جمع شدن ← فرو رفتن
            final double e = Curves.easeInOutCubic.transform(1.0 - p);
            final double swell =
                math.sin(math.min(1.0, e / 0.34) * math.pi) * 0.12;
            final double collapse = e <= 0.34
                ? 0.0
                : Curves.easeInCubic.transform((e - 0.34) / 0.66);
            final double base = (1.0 + swell) * (1.0 - 0.88 * collapse);

            sx0 = base * (1.0 + swell * 0.55 - collapse * 0.12);
            sy0 = base * (1.0 - swell * 0.40 + collapse * 0.14);
            dy0 = widget.size * 0.26 * collapse * collapse;
            rot0 = 0.11 * collapse * collapse;
            opacity = math.pow(1.0 - collapse, 1.30).toDouble();
            ripple = Curves.easeOutQuart.transform(e);
            rippleAlpha = math.sin(e * math.pi) * 0.40;
          } else {
            // شکفتن: از کوچک، با یک کشیدگی نرم در میانهٔ راه
            final double e = Curves.easeOutCubic.transform(p);
            final double swell = math.sin(p * math.pi) * 0.085;
            final double base = 0.52 + 0.48 * e;

            sx0 = base * (1.0 + swell * 0.55);
            sy0 = base * (1.0 - swell * 0.30);
            dy0 = widget.size * 0.18 * (1.0 - Curves.easeOutQuart.transform(p));
            rot0 = 0.0;
            opacity = Curves.easeOutCubic.transform(math.min(1.0, p * 1.30));
            ripple = 1.0 - Curves.easeOutCubic.transform(p);
            rippleAlpha = math.sin(p * math.pi) * 0.34;
          }

          final double breathScale =
              1.0 + amp * 0.040 * breath * depth + amp * 0.075 * bloom;

          final double fx = sx0 *
              breathScale *
              (1.0 +
                  amp *
                      (play * 0.030 * sway +
                          play * 0.055 * wink +
                          0.030 * hop));
          final double fy = sy0 *
              breathScale *
              (1.0 +
                  amp *
                      (play * -0.026 * sway -
                          play * 0.085 * wink +
                          0.048 * hop));

          final double tx = amp *
              (widget.size * 0.030 * driftX +
                  widget.size * 0.035 * lean * play);
          final double ty = dy0 +
              amp *
                  (-widget.size * 0.026 * driftY -
                      widget.size * 0.020 * breath * depth -
                      widget.size * 0.055 * hop);

          final double angle = rot0 +
              amp * play * (0.045 * sway + 0.055 * lean) +
              amp * play * 0.030 * hop;

          final Offset tilt = Offset(
            (amp *
                    ((sway * 0.42 + lean * 0.45) * play +
                        driftX * 0.28 +
                        breath * 0.10 * depth))
                .clamp(-1.0, 1.0),
            (amp *
                    ((hop * 0.30 - wink * 0.42) * play +
                        driftY * 0.24 -
                        breath * 0.16 * depth))
                .clamp(-1.0, 1.0),
          );

          final double squeeze = (1.0 +
                  amp *
                      (0.045 * breath * depth +
                          play * 0.035 * sway +
                          0.060 * hop -
                          play * 0.055 * wink) +
                  amp * 0.050 * bloom)
              .clamp(0.80, 1.20);

          // جریان درون تیله هم با حال‌وهوا کند و تند می‌شود.
          final double innerSpeed =
              (0.70 + 0.55 * play + 0.22 * bloom).clamp(0.45, 1.60);
          final double innerIntensity =
              (0.93 + 0.07 * breath01 + 0.10 * bloom).clamp(0.60, 1.15);

          final RitmoOrbPalette pal = _resolvePalette();

          final Widget core = Transform.rotate(
            angle: angle,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(fx, fy, 1.0),
              child: RitmoSiriOrb(
                size: widget.size,
                mode: _modeFor(_shownLife),
                palette: pal,
                glowEnabled: widget.glowEnabled,
                isAnimated: !_reduceMotion,
                tiltOffset: tilt,
                squeezeFactor: squeeze,
                intensity: innerIntensity,
                speed: innerSpeed,
              ),
            ),
          );

          Widget body = SizedBox(
            width: box,
            height: box,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (widget.glowEnabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: RitmoOrbHaloPainter(
                          aura: pal.aura,
                          warm: pal.hot,
                          orbSize: widget.size,
                          breath01: breath01,
                          depth: depth,
                          opacity: opacity,
                          bloom: bloom,
                          ripple: ripple,
                          rippleAlpha: rippleAlpha,
                        ),
                      ),
                    ),
                  ),
                core,
              ],
            ),
          );

          body = Transform.translate(offset: Offset(tx, ty), child: body);

          if (opacity < 0.999) {
            body = Opacity(opacity: opacity.clamp(0.0, 1.0), child: body);
          }

          if (widget.onTap != null) {
            body = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              child: body,
            );
          }

          // ارتفاع رزروشده نرم باز و بسته می‌شود، ولی خود تیله فشرده نمی‌شود:
          // موقع رفتن، فضا کمی صبر می‌کند تا حرکت از layout جلو نزند.
          final double reveal = exiting
              ? Curves.easeOutCubic.transform(p)
              : Curves.easeInOutCubic.transform(p);

          return Semantics(
            container: true,
            label: widget.semanticLabel,
            child: SizedBox(
              height: box * reveal,
              child: OverflowBox(
                minHeight: box,
                maxHeight: box,
                alignment: Alignment.center,
                child: body,
              ),
            ),
          );
        },
      ),
    );
  }
}
