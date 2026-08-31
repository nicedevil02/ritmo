// «زندگی» تیله تفکر ریتمو:
//   • نفس کشیدن: دم سریع، نگه‌داشتن کوتاه، بازدم کشیده (نامتقارن، مثل نفس واقعی)
//   • ادا و اطفار موقع نوشتن: تکان، کج کردن سر، چشمک، و یک پرش روی هر توکن
//   • ظاهر/مخفی شدن با انیمیشن: ورود کشسان، خروج «باد کردن ← جمع شدن ← افتادن»
//
// این فایل هیچ تغییری در ritmo_siri_orb.dart لازم ندارد.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart';

/// وضعیت زندگی تیله. جدا از RitmoOrbMode نگه داشته شده تا enum اصلی
/// دست‌نخورده بماند و switch های موجود نشکنند.
enum RitmoOrbLife {
  /// کاملاً پنهان (با انیمیشن جمع می‌شود و فضایش را هم آزاد می‌کند)
  hidden,

  /// حالت استراحت: فقط نفس می‌کشد
  breathing,

  /// در حال فکر کردن: نفس عمیق‌تر و کمی تندتر
  thinking,

  /// در حال نوشتن پیام: نفس + ادا و اطفار
  writing,
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
    this.reserveHeightFactor = 1.40,
    this.breathPeriod = const Duration(milliseconds: 4200),
    this.enterDuration = const Duration(milliseconds: 560),
    this.exitDuration = const Duration(milliseconds: 460),
    this.animateOnMount = true,
    this.semanticLabel = 'دستیار هوشمند ریتمو',
  });

  final RitmoOrbLife life;
  final double size;

  /// اگر روی نسخه قدیمی ritmo_siri_orb.dart هستی، این پارامتر را حذف کن
  /// و خط `palette: widget.palette,` را هم از build پایین بردار.
  final RitmoOrbPalette? palette;

  final bool glowEnabled;

  /// هر بار مقدارش عوض شود، تیله یک پرش کوچک و بشاش می‌کند.
  /// (در چت: روی هر ChatChunk یکی بالا ببر)
  final ValueListenable<int>? writingPulse;

  final VoidCallback? onTap;

  /// شدت ادا و اطفار. 0 = خنثی، 1 = پیش‌فرض، 1.6 = شیطون.
  final double anticsStrength;

  /// ارتفاعی که در layout رزرو می‌شود (ضریبی از size). موقع مخفی شدن
  /// همین ارتفاع هم نرم جمع می‌شود تا لیست پرش نکند.
  final double reserveHeightFactor;

  final Duration breathPeriod;
  final Duration enterDuration;
  final Duration exitDuration;
  final bool animateOnMount;
  final String semanticLabel;

  @override
  State<RitmoLivingOrb> createState() => _RitmoLivingOrbState();
}

class _RitmoLivingOrbState extends State<RitmoLivingOrb>
    with TickerProviderStateMixin {
  late final AnimationController _presence; // 0 پنهان .. 1 حاضر
  late final AnimationController _play;     // میزان درگیری ادا و اطفار
  late final AnimationController _depth;    // عمق نفس
  late final AnimationController _pop;      // پرش هر توکن

  final ValueNotifier<double> _clock = ValueNotifier<double>(0.0);

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  double _t = 0.0;
  double _breathPhase = 0.15; // در واحد «دور»، پیوسته
  double _anticPhase = 0.0;   // در واحد «دور»، پیوسته

  int? _lastPulse;
  late RitmoOrbLife _shownLife;

  @override
  void initState() {
    super.initState();
    final visible = widget.life != RitmoOrbLife.hidden;
    _shownLife = visible ? widget.life : RitmoOrbLife.breathing;

    _presence = AnimationController(
      vsync: this,
      duration: widget.enterDuration,
      reverseDuration: widget.exitDuration,
      value: (visible && !widget.animateOnMount) ? 1.0 : 0.0,
    )..addStatusListener(_onPresenceStatus);

    _play = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      value: widget.life == RitmoOrbLife.writing ? 1.0 : 0.0,
    );

    _depth = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: _depthFor(widget.life),
    );

    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
      value: 1.0,
    );

    _ticker = createTicker(_onTick);
    _bindPulse();

    if (visible && widget.animateOnMount) {
      _presence.forward();
    }
    _syncTicker();
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

    if (oldWidget.life != widget.life) {
      if (widget.life == RitmoOrbLife.hidden) {
        _presence.reverse();
      } else {
        _shownLife = widget.life;
        _presence.forward();
      }

      _play.animateTo(
        widget.life == RitmoOrbLife.writing ? 1.0 : 0.0,
        curve: Curves.easeOutCubic,
      );
      _depth.animateTo(
        _depthFor(widget.life),
        curve: Curves.easeOutCubic,
      );
      _syncTicker();
    }
  }

  @override
  void dispose() {
    widget.writingPulse?.removeListener(_handlePulse);
    _ticker?.dispose();
    _presence.removeStatusListener(_onPresenceStatus);
    _presence.dispose();
    _play.dispose();
    _depth.dispose();
    _pop.dispose();
    _clock.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- helpers

  void _onPresenceStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _syncTicker();
    }
  }

  void _bindPulse() {
    widget.writingPulse?.addListener(_handlePulse);
    _lastPulse = widget.writingPulse?.value;
  }

  void _handlePulse() {
    final value = widget.writingPulse?.value;
    if (value == null || value == _lastPulse) return;
    _lastPulse = value;
    if (widget.life == RitmoOrbLife.hidden) return;
    _pop.forward(from: 0.0);
  }

  double _depthFor(RitmoOrbLife life) {
    switch (life) {
      case RitmoOrbLife.hidden:
        return 0.35;
      case RitmoOrbLife.breathing:
        return 1.0;
      case RitmoOrbLife.thinking:
        return 0.80;
      case RitmoOrbLife.writing:
        return 0.55;
    }
  }

  RitmoOrbMode _modeFor(RitmoOrbLife life) {
    switch (life) {
      case RitmoOrbLife.writing:
        return RitmoOrbMode.streaming;
      case RitmoOrbLife.thinking:
        return RitmoOrbMode.thinking;
      case RitmoOrbLife.breathing:
      case RitmoOrbLife.hidden:
        return RitmoOrbMode.idle;
    }
  }

  void _syncTicker() {
    final ticker = _ticker;
    if (ticker == null) return;
    final needsTicker =
        widget.life != RitmoOrbLife.hidden || _presence.value > 0.0;
    if (needsTicker && !ticker.isActive) {
      _lastTick = Duration.zero;
      ticker.start();
    } else if (!needsTicker && ticker.isActive) {
      ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    if (dt <= 0.0 || dt > 0.5) return;

    final play = _play.value;
    final periodSec = widget.breathPeriod.inMilliseconds / 1000.0;
    final breathHz = (periodSec <= 0.0 ? 0.24 : 1.0 / periodSec) *
        (1.0 + 0.85 * play);

    // فازها پیوسته جلو می‌روند، پس تغییر حالت هیچ‌وقت پرش نمی‌دهد.
    _breathPhase += dt * breathHz;
    _anticPhase += dt * (0.85 + 1.35 * play);
    _t += dt;
    _clock.value = _t;
  }

  /// نفس نامتقارن: دم ۴۲٪، نگه‌داشتن ۱۰٪، بازدم ۴۸٪ → خروجی 0..1
  double _asymBreath(double phase) {
    final x = phase - phase.floorToDouble();
    if (x < 0.42) {
      return Curves.easeInOutSine.transform(x / 0.42);
    }
    if (x < 0.52) {
      return 1.0;
    }
    return 1.0 - Curves.easeInOutCubic.transform((x - 0.52) / 0.48);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final fullHeight = widget.size * widget.reserveHeightFactor;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_clock, _presence, _play, _depth, _pop]),
        builder: (context, _) {
          final double p = _presence.value.clamp(0.0, 1.0);
          final bool exiting = widget.life == RitmoOrbLife.hidden;

          if (p <= 0.001 && exiting) {
            return const SizedBox.shrink();
          }

          // ---------- نفس ----------
          final double breath01 = _asymBreath(_breathPhase);
          final double breath = breath01 * 2.0 - 1.0; // -1..1
          final double depth = _depth.value;

          // ---------- ادا و اطفار ----------
          final double play = _play.value * widget.anticsStrength;
          final double a = _anticPhase * math.pi * 2.0;

          final double sway = math.sin(a * 0.62);
          final double bob =
              math.sin(a * 0.95) * 0.55 + math.sin(a * 1.70 + 0.8) * 0.45;
          final double shimmy = math.sin(a * 2.90);

          // چشمک دوبل: دو تیغه باریک که هر چند ثانیه یک‌بار می‌آیند
          final double blinkA =
              math.pow(math.max(0.0, math.sin(a * 0.19)), 14.0).toDouble();
          final double blinkB =
              math.pow(math.max(0.0, math.sin(a * 0.19 + 0.55)), 18.0)
                  .toDouble();
          final double wink = (blinkA + 0.6 * blinkB).clamp(0.0, 1.0);

          // ---------- پرش روی هر توکن ----------
          final double pop = _pop.value >= 1.0
              ? 0.0
              : math.exp(-5.2 * _pop.value) *
                  math.sin(_pop.value * math.pi * 3.2);

          // ---------- حضور: ورود / خروج ----------
          double baseX;
          double baseY;
          double baseDy;
          double baseRot;
          double opacity;

          if (exiting) {
            // خروج: یک نفس عمیق و باد کردن، بعد جمع شدن و افتادن
            final double e = Curves.easeInCubic.transform(1.0 - p);
            final double bulge = math.sin(e * math.pi) * 0.14;
            baseX = (1.0 + bulge * 0.85) * (1.0 - e);
            baseY = (1.0 - bulge * 1.10) * (1.0 - e * 0.94);
            baseDy = 18.0 * e * e;
            baseRot = 0.24 * e * e;
            opacity = math.pow(1.0 - e, 1.5).toDouble();
          } else {
            // ورود: کشسان، با یک تاب کشیدگی نرم در میانه راه
            final double e = Curves.easeOutBack.transform(p);
            final double settle = math.sin(p * math.pi) * 0.10;
            baseX = 0.58 + 0.42 * e - settle * 0.70;
            baseY = 0.58 + 0.42 * e + settle;
            baseDy = 12.0 * (1.0 - Curves.easeOutCubic.transform(p));
            baseRot = 0.0;
            opacity = Curves.easeOut.transform(p);
          }

          // ---------- ترکیب ----------
          final double breathScale = 1.0 + 0.055 * breath * depth;

          final double sx = baseX *
              breathScale *
              (1.0 + play * (0.035 * shimmy + 0.050 * wink) + pop * 0.05);
          final double sy = baseY *
              breathScale *
              (1.0 + play * (-0.030 * shimmy - 0.070 * wink) + pop * 0.08);

          final double dy = baseDy -
              1.8 * breath * depth -
              play * 2.4 * bob -
              pop * 3.0;

          final double rot =
              baseRot + play * (0.055 * sway + 0.10 * wink);

          final Offset tilt = Offset(
            ((sway * 0.55 + shimmy * 0.20) * play + breath * 0.12 * depth)
                .clamp(-1.0, 1.0),
            ((bob * 0.35 - wink * 0.45) * play - breath * 0.18 * depth)
                .clamp(-1.0, 1.0),
          );

          final double squeeze = (1.0 +
                  0.050 * breath * depth +
                  play * 0.045 * shimmy +
                  pop * 0.060)
              .clamp(0.82, 1.18);

          // ---------- خود تیله ----------
          Widget orb = RitmoSiriOrb(
            size: widget.size,
            mode: _modeFor(_shownLife),
            palette: widget.palette ?? RitmoOrbPalette.coral,
            glowEnabled: widget.glowEnabled,
            isAnimated: true,
            tiltOffset: tilt,
            squeezeFactor: squeeze,
          );

          // هاله‌ای که همراه نفس روشن و خاموش می‌شود
          if (widget.glowEnabled) {
            final Color aura =
                widget.palette?.aura ?? const Color(0xFFFF7D91);
            final double glow =
                ((0.16 + 0.24 * breath01) * depth * opacity).clamp(0.0, 0.55);
            orb = DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: aura.withValues(alpha: glow),
                    blurRadius: widget.size * (0.30 + 0.20 * breath01),
                    spreadRadius: widget.size * 0.02 * breath01,
                  ),
                ],
              ),
              child: orb,
            );
          }

          Widget body = Transform.translate(
            offset: Offset(0.0, dy),
            child: Transform.rotate(
              angle: rot,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(sx, sy, 1.0),
                child: orb,
              ),
            ),
          );

          if (opacity < 0.999) {
            body = Opacity(opacity: opacity.clamp(0.0, 1.0), child: body);
          }

          if (widget.onTap != null) {
            body = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: body,
            );
          }

          // ارتفاع رزروشده هم نرم جمع می‌شود، ولی خود تیله فشرده نمی‌شود.
          final double reserved =
              fullHeight * Curves.easeInOutCubic.transform(p);

          return Semantics(
            label: widget.semanticLabel,
            child: SizedBox(
              height: reserved,
              child: OverflowBox(
                minHeight: fullHeight,
                maxHeight: fullHeight,
                alignment: Alignment.center,
                child: Center(child: body),
              ),
            ),
          );
        },
      ),
    );
  }
}