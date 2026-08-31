// =============================================================================
//  Ritmo Living Orb — مدیرِ زندگیِ تیله
//
//  ورود : از دلِ کادرِ تایپ بالا می‌آید و شکفته می‌شود.
//  خروج : یک دمِ عمیق ← قطره می‌شود ← در کادرِ تایپ جذب می‌شود.
//
//  ادا و اطفار (همه از همین‌جا به داخلِ تیله مخابره می‌شود):
//    • jolt   : هر تکه متنِ مدل ← تکانِ ربان‌های داخل + پرشِ ریز
//    • squash : پریدن که کشیده، نشستن که پهن
//    • blink  : هر چند ثانیه یک چشمکِ واقعی + برق داخل
//    • nod    : کج کردنِ سر وقتی حرف می‌زند
// =============================================================================

import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_marble_core.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_absorb.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_halo.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart';

export 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart'
    show RitmoOrbLife;

class RitmoLivingOrb extends StatefulWidget {
  const RitmoLivingOrb({
    super.key,
    required this.life,
    this.size = 52.0,
    this.palette = RitmoOrbPalette.coral,
    this.glowEnabled = true,
    this.writingPulse,
    this.onTap,
    this.anticsStrength = 1.0,
    this.shellWobble = 1.0,
    this.bulgeStrength = 1.0,
    this.reserveHeightFactor = 1.55,
    this.breathPeriod = const Duration(milliseconds: 5200),
    this.enterDuration = const Duration(milliseconds: 760),
    this.exitDuration = const Duration(milliseconds: 900),
    this.animateOnMount = true,
    this.reactToSuccessFlare = true,
    this.absorbIntoInput = true,
    this.semanticLabel = '\u062f\u0633\u062a\u06cc\u0627\u0631 \u0647\u0648\u0634\u0645\u0646\u062f \u0631\u06cc\u062a\u0645\u0648',
  });

  final RitmoOrbLife life;
  final double size;
  final RitmoOrbPalette palette;
  final bool glowEnabled;

  /// هر بار که عددش بالا برود = یک تکه متن نوشته شد.
  final ValueNotifier<int>? writingPulse;

  final VoidCallback? onTap;

  /// شدت ادا و اطفار (۰ = خاموش، ۱ = عادی، ۲ = شیطون).
  final double anticsStrength;

  /// ارتعاشِ پوسته.
  final double shellWobble;

  /// برآمدگی‌های موضعیِ پوسته.
  final double bulgeStrength;

  final double reserveHeightFactor;
  final Duration breathPeriod;
  final Duration enterDuration;
  final Duration exitDuration;
  final bool animateOnMount;
  final bool reactToSuccessFlare;

  /// موقع رفتن، رنگ‌ها را به کادرِ تایپ تحویل بدهد.
  final bool absorbIntoInput;

  final String semanticLabel;

  @override
  State<RitmoLivingOrb> createState() => _RitmoLivingOrbState();
}

class _RitmoLivingOrbState extends State<RitmoLivingOrb>
    with TickerProviderStateMixin {
  static const double _kFallbackFrame = 1.0 / 60.0;

  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final math.Random _rng = math.Random(7);

  final RitmoSpring _play = RitmoSpring(initial: 0.0, stiffness: 46.0, damping: 14.0);
  final RitmoSpring _depth = RitmoSpring(initial: 1.0, stiffness: 34.0, damping: 12.5);
  final RitmoSpring _hop = RitmoSpring(initial: 0.0, stiffness: 172.0, damping: 11.6);
  final RitmoSpring _lean = RitmoSpring(initial: 0.0, stiffness: 22.0, damping: 9.0);
  final RitmoSpring _bloom = RitmoSpring(initial: 0.0, stiffness: 74.0, damping: 11.0);
  final RitmoSpring _hue = RitmoSpring(initial: 0.0, stiffness: 26.0, damping: 10.5);
  final RitmoSpring _form = RitmoSpring(initial: 1.0, stiffness: 30.0, damping: 11.0);

  late final AnimationController _presence;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  double _breathPhase = 0.10;
  double _driftPhase = 0.0;
  double _swayPhase = 0.0;
  double _winkCountdown = 3.4;
  double _winkProgress = 1.0;
  double _jolt = 0.0;
  double _tick = 0.0;
  int _pulseCount = 0;
  bool _reduceMotion = false;
  bool _splashed = false;

  RitmoOrbPalette? _paletteBase;
  RitmoOrbPalette _paletteOut = RitmoOrbPalette.coral;
  double _paletteHue = 999.0;

  @override
  void initState() {
    super.initState();

    final bool visible = widget.life != RitmoOrbLife.hidden;
    _presence = AnimationController(
      vsync: this,
      duration: widget.enterDuration,
      reverseDuration: widget.exitDuration,
      value: visible && !widget.animateOnMount ? 1.0 : 0.0,
    );
    if (visible && widget.animateOnMount) unawaited(_presence.forward());

    _applyLife(widget.life, snap: true);
    widget.writingPulse?.addListener(_handlePulse);
    if (widget.reactToSuccessFlare) {
      RitmoAiStateService.instance.flareTrigger.addListener(_handleFlare);
    }

    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(RitmoLivingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.enterDuration != widget.enterDuration) {
      _presence.duration = widget.enterDuration;
    }
    if (oldWidget.exitDuration != widget.exitDuration) {
      _presence.reverseDuration = widget.exitDuration;
    }

    if (oldWidget.writingPulse != widget.writingPulse) {
      oldWidget.writingPulse?.removeListener(_handlePulse);
      widget.writingPulse?.addListener(_handlePulse);
    }
    if (oldWidget.reactToSuccessFlare != widget.reactToSuccessFlare) {
      final ValueNotifier<int> flare = RitmoAiStateService.instance.flareTrigger;
      if (widget.reactToSuccessFlare) {
        flare.addListener(_handleFlare);
      } else {
        flare.removeListener(_handleFlare);
      }
    }

    if (oldWidget.life != widget.life) {
      _applyLife(widget.life);

      final bool wasHidden = oldWidget.life == RitmoOrbLife.hidden;
      final bool isHidden = widget.life == RitmoOrbLife.hidden;

      if (isHidden && !wasHidden) {
        _splashed = false;
        unawaited(_presence.reverse());
      } else if (!isHidden && wasHidden) {
        _splashed = false;
        if (widget.absorbIntoInput) {
          final RitmoOrbAbsorb bus = RitmoOrbAbsorb.instance;
          bus.report(sink: 0.0, tint: _resolvePalette());
          bus.lift();
        }
        unawaited(_presence.forward());
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void dispose() {
    widget.writingPulse?.removeListener(_handlePulse);
    RitmoAiStateService.instance.flareTrigger.removeListener(_handleFlare);
    _ticker?.dispose();
    _presence.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _applyLife(RitmoOrbLife life, {bool snap = false}) {
    _play.target = ritmoPlayFor(life);
    _depth.target = ritmoDepthFor(life);
    _hue.target = ritmoHueFor(life);
    _form.target = ritmoFormFor(life);

    if (snap) {
      _play.snap(_play.target);
      _depth.snap(_depth.target);
      _hue.snap(_hue.target);
      _form.snap(_form.target);
      return;
    }

    if (life == RitmoOrbLife.celebrating) {
      _bloom.kick(3.1);
      _lean.kick(1.9);
    } else if (life == RitmoOrbLife.writing) {
      _hop.kick(1.5 * widget.anticsStrength.clamp(0.0, 2.0));
    } else if (life == RitmoOrbLife.listening) {
      _lean.target = 0.55;
    } else {
      _lean.target = 0.0;
    }
  }

  /// هر تکه متنی که مدل می‌نویسد = یک ادا.
  void _handlePulse() {
    if (!mounted) return;
    final double antics = widget.anticsStrength.clamp(0.0, 2.0);
    if (antics <= 0.01) return;

    // هرچه تیله هنوز در حال پریدن است، ضربهٔ بعدی ملایم‌تر می‌شود.
    final double softener = 1.0 / (1.0 + _hop.value.abs() * 1.7);
    _hop.kick(3.10 * softener * antics);
    _jolt = math.min(1.0, _jolt + 0.85 * antics);

    _pulseCount++;
    if (_pulseCount % 4 == 0) {
      _lean.target = (_rng.nextDouble() * 2.0 - 1.0) * 1.05 * antics;
    }
    if (_pulseCount % 11 == 0 && _winkProgress >= 1.0) {
      _winkProgress = 0.0;
      _winkCountdown = 4.0 + _rng.nextDouble() * 5.0;
    }
  }

  void _handleFlare() {
    if (!mounted) return;
    _bloom.kick(2.9);
    _lean.kick(1.6);
    _jolt = 1.0;
  }

  void _handleTap() {
    _bloom.kick(2.2);
    _hop.kick(2.4);
    _jolt = 1.0;
    unawaited(HapticFeedback.selectionClick());
    widget.onTap?.call();
  }

  RitmoOrbPalette _resolvePalette() {
    final RitmoOrbPalette base = widget.palette;
    final double h = _hue.value.clamp(-1.0, 1.0);
    if (!identical(base, _paletteBase) || (h - _paletteHue).abs() > 0.02) {
      _paletteBase = base;
      _paletteHue = h;
      _paletteOut = ritmoTintPalette(base, h);
    }
    return _paletteOut;
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt <= 0.0) return;
    if (dt > 0.25) dt = _kFallbackFrame;

    _tick += dt;

    _play.step(dt);
    _depth.step(dt);
    _hop.step(dt);
    _lean.step(dt);
    _bloom.step(dt);
    _hue.step(dt);
    _form.step(dt);

    final double play = _play.value.clamp(0.0, 1.0);
    final double motion = _reduceMotion ? 0.35 : 1.0;
    final double periodSec =
        math.max(0.8, widget.breathPeriod.inMilliseconds / 1000.0);

    _breathPhase += dt * (1.0 + 0.55 * play) / periodSec;
    if (_breathPhase > 1000.0) _breathPhase -= 1000.0;
    _driftPhase += dt * (0.055 + 0.030 * play) * motion;
    _swayPhase += dt * (0.095 + 0.150 * play) * motion;

    if (_jolt > 0.0) {
      _jolt = math.max(0.0, _jolt - dt / 0.40);
    }

    if (_winkProgress < 1.0) {
      _winkProgress += dt / 0.34;
    } else {
      _winkCountdown -= dt * (0.55 + 0.95 * play);
      if (_winkCountdown <= 0.0) {
        _winkCountdown = 4.2 + _rng.nextDouble() * 5.5;
        _winkProgress = 0.0;
      }
    }

    _reportAbsorb();
    _frame.value = _frame.value + 1;
  }

  /// تحویلِ رنگ به کادرِ تایپ. فقط در تیک، هرگز در build.
  void _reportAbsorb() {
    if (!widget.absorbIntoInput) return;
    if (widget.life != RitmoOrbLife.hidden) return;

    final RitmoOrbAbsorb bus = RitmoOrbAbsorb.instance;
    final RitmoOrbPalette pal = _resolvePalette();
    final double p = _presence.value;
    final double collapse = RitmoOrbPose.collapseOf(p);

    if (p <= 0.0005) {
      bus.report(sink: 0.0, tint: pal);
      return;
    }

    bus.report(sink: collapse, tint: pal);
    if (!_splashed && collapse >= 0.50) {
      _splashed = true;
      bus.splash(tint: pal);
      unawaited(HapticFeedback.lightImpact());
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_frame, _presence]),
        builder: (BuildContext context, Widget? _) => _compose(),
      ),
    );
  }

  Widget _compose() {
    final double p = _presence.value;
    final bool exiting = widget.life == RitmoOrbLife.hidden;
    if (exiting && p <= 0.0005) return const SizedBox.shrink();

    final double amp = _reduceMotion ? 0.30 : 1.0;
    final double antics = widget.anticsStrength.clamp(0.0, 2.0) * amp;
    final double play = _play.value.clamp(0.0, 1.0);
    final double depth = _depth.value.clamp(0.0, 1.4);
    final double bloom = _bloom.value.clamp(0.0, 3.2);
    final double form = _form.value.clamp(0.30, 1.06);
    final double hop = _hop.value * amp;
    final double lean = _lean.value * amp;
    final double jolt = _jolt.clamp(0.0, 1.0);

    final RitmoOrbPose pose = exiting
        ? RitmoOrbPose.sinking(p: p, size: widget.size)
        : RitmoOrbPose.rising(p: p, size: widget.size);

    final double breath01 = ritmoBreathCurve(_breathPhase % 1.0).clamp(0.0, 1.0);
    final double breathScale =
        1.0 + amp * 0.040 * breath01 * depth + amp * 0.075 * bloom;

    final double wink = _winkProgress < 1.0
        ? math.sin(_winkProgress.clamp(0.0, 1.0) * math.pi)
        : 0.0;

    final double d = _driftPhase;
    final double driftX =
        math.sin(d * 0.61) * 0.62 + math.sin(d * 0.23 + 1.9) * 0.38;
    final double driftY =
        math.sin(d * 0.44 + 0.7) * 0.58 + math.sin(d * 0.83 + 2.4) * 0.42;
    final double sway = math.sin(_swayPhase * 0.42) * 0.62 +
        math.sin(_swayPhase * 0.67 + 1.1) * 0.38;

    // squash & stretch: بالا که می‌پرد کشیده، پایین که می‌نشیند پهن.
    final double stretch = (hop * 0.090 * antics).clamp(-0.15, 0.15);

    final double squeeze = (1.0 +
            amp * 0.055 * play * math.sin(_swayPhase * 2.1) +
            0.045 * hop * antics -
            amp * 0.070 * wink)
        .clamp(0.80, 1.20);

    final double fx = pose.sx *
        breathScale *
        form *
        (1.0 - stretch * 0.80) *
        (1.0 + 0.055 * wink * antics);
    final double fy = pose.sy *
        breathScale *
        form *
        (1.0 + stretch) *
        (1.0 - 0.165 * wink * antics);

    // تکانِ ریزِ تایپ کردن — مثل سر تکان دادن وقتی حرف می‌زند.
    final double chatter = widget.life == RitmoOrbLife.writing
        ? math.sin(_tick * 7.4) * 0.012 * antics
        : 0.0;

    final double dx = amp * (driftX * widget.size * 0.020) +
        lean * widget.size * 0.038 * antics;
    final double dy = pose.dy -
        hop * widget.size * 0.078 * antics +
        amp * driftY * widget.size * 0.016 -
        chatter * widget.size;
    final double rot = pose.rot +
        amp * sway * 0.020 * (0.40 + play) +
        lean * 0.062 * antics +
        chatter * 0.9;

    final RitmoOrbPalette pal = _resolvePalette();
    final double opacity = pose.opacity.clamp(0.0, 1.0);

    final Widget core = RitmoMarbleCore(
      size: widget.size,
      mode: ritmoModeFor(widget.life),
      palette: pal,
      glowEnabled: widget.glowEnabled,
      tiltOffset: Offset(
        (driftX * 0.55 + lean * 0.60).clamp(-1.0, 1.0),
        (driftY * 0.55 - hop * 0.28).clamp(-1.0, 1.0),
      ),
      squeezeFactor: squeeze,
      intensity: (0.93 + 0.07 * breath01 + 0.10 * bloom + 0.12 * jolt)
          .clamp(0.60, 1.25),
      speed: (0.70 + 0.55 * play + 0.22 * bloom).clamp(0.45, 1.60),
      shellWobble: widget.shellWobble * (0.85 + 0.50 * play) * amp,
      bulgeStrength: _reduceMotion ? 0.0 : widget.bulgeStrength,
      pulse: jolt * antics.clamp(0.0, 1.0),
      wink: wink,
    );

    final double box = widget.size * widget.reserveHeightFactor;

    final Widget stack = SizedBox(
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
                    orbSize: widget.size * form,
                    breath01: breath01,
                    depth: depth,
                    opacity: opacity,
                    bloom: bloom + jolt * 0.55,
                    ripple: pose.ripple,
                    rippleAlpha: pose.rippleAlpha,
                  ),
                ),
              ),
            ),
          Transform.rotate(
            angle: rot,
            child: Transform(
              transform: Matrix4.diagonal3Values(fx, fy, 1.0),
              alignment: Alignment.center,
              child: core,
            ),
          ),
        ],
      ),
    );

    Widget out = Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(opacity: opacity, child: stack),
    );

    if (widget.onTap != null) {
      out = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: out,
      );
    }

    out = Semantics(container: true, label: widget.semanticLabel, child: out);

    final double reveal = exiting
        ? Curves.easeOutCubic.transform(p)
        : Curves.easeInOutCubic.transform(p);

    return SizedBox(
      height: box * reveal * (0.30 + 0.70 * form),
      child: OverflowBox(
        minHeight: box,
        maxHeight: box,
        alignment: Alignment.center,
        child: out,
      ),
    );
  }
}
