// =============================================================================
//  Ritmo Marble Core — قلبِ تیله
//  هر فریم فقط برگِ CustomPaint عوض می‌شود؛ نه درختِ ویجت، نه setState.
//  حرکت از [RitmoOrbClock] می‌آید (یک ticker برای کلِ اپ) و هزینهٔ نقاشی با
//  [RitmoOrbBudget] سقف‌گذاری شده است.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_clock.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_feather.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_motion.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_shell.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_skin.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

class RitmoMarbleCore extends StatefulWidget {
  const RitmoMarbleCore({
    super.key,
    this.size = 42.0,
    this.mode = RitmoOrbMode.idle,
    this.glowEnabled = true,
    this.isAnimated = true,
    this.tiltOffset = Offset.zero,
    this.squeezeFactor = 1.0,
    this.palette = RitmoOrbPalette.coral,
    this.intensity = 1.0,
    this.speed = 1.0,
    this.seed = 11,
    this.shellWobble = 1.0,
    this.bulgeStrength = 1.0,
    this.pulse = 0.0,
    this.wink = 0.0,
    this.signature,
    this.tier,
    this.truth,
    this.attention,
    this.tokenPulse,
    this.energyAware = true,
    this.reactToFlare = true,
    this.stats,
  });

  final double size;
  final RitmoOrbMode mode;
  final bool glowEnabled;
  final bool isAnimated;
  final Offset tiltOffset;
  final double squeezeFactor;
  final RitmoOrbPalette palette;
  final double intensity;
  final double speed;
  final int seed;
  final double shellWobble;
  final double bulgeStrength;

  /// فشارِ لحظه‌ای (۰..۱) — مثلاً وقتی کاربر انگشتش را روی تیله نگه داشته.
  final double pulse;

  /// پلکِ آگاهانه (۰..۱). دیگر تصادفی نیست: فقط در پاسخ به کاربر.
  final double wink;

  /// امضای حرکت؛ اگر null باشد از [mode] ساخته می‌شود.
  final RitmoOrbSignature? signature;
  final RitmoOrbTier? tier;
  final RitmoOrbTruth? truth;
  final RitmoOrbAttention? attention;

  /// هر بار بالا رفتن = یک تکه متنِ تازه؛ تیله ریز ذوق می‌کند.
  final ValueListenable<int>? tokenPulse;
  final bool energyAware;
  final bool reactToFlare;

  /// فقط در تست: شمارشِ فرمان‌های نقاشی.
  final RitmoOrbPaintStats? stats;

  @override
  State<RitmoMarbleCore> createState() => _RitmoMarbleCoreState();
}

class _RitmoMarbleCoreState extends State<RitmoMarbleCore> {
  final ValueNotifier<double> _frame = ValueNotifier<double>(0.0);
  final RitmoShellCache _shell = RitmoShellCache();
  final RitmoSpring _blend = RitmoSpring(stiffness: 70.0, damping: 15.0);

  late RitmoOrbSignature _from;
  late RitmoOrbSignature _to;

  double _phase = 0.0;
  double _breath = 0.0;
  double _clockLast = 0.0;
  double _flare = 0.0;
  double _token = 0.0;
  double _nod = 0.0;
  bool _subscribed = false;
  bool _reduceMotion = false;
  bool _tickerOn = true;

  RitmoOrbTier get _tier => widget.tier ?? ritmoTierFor(widget.size);

  RitmoOrbTruth get _truth =>
      widget.truth ?? RitmoAiStateService.instance.truth.value;

  RitmoOrbAttention get _attention =>
      widget.attention ?? RitmoOrbAttentionSignal.instance.value;

  RitmoOrbSignature _baseSignature() =>
      widget.signature ?? RitmoOrbSignature.ofMode(widget.mode);

  @override
  void initState() {
    super.initState();
    _to = _baseSignature();
    _from = _to;
    _blend.snap(1.0);
    _phase = widget.seed * 0.37;
    _breath = (widget.seed % 7) / 7.0;
    RitmoAiStateService.instance.truth.addListener(_onExternal);
    RitmoOrbAttentionSignal.instance.addListener(_onExternal);
    RitmoOrbAttentionSignal.instance.acknowledge.addListener(_onNod);
    RitmoOrbEnergySignal.instance.addListener(_onExternal);
    if (widget.reactToFlare) {
      RitmoAiStateService.instance.flareTrigger.addListener(_onFlare);
    }
    widget.tokenPulse?.addListener(_onToken);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _tickerOn = TickerMode.of(context);
    _syncClock();
  }

  @override
  void didUpdateWidget(RitmoMarbleCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tokenPulse != widget.tokenPulse) {
      oldWidget.tokenPulse?.removeListener(_onToken);
      widget.tokenPulse?.addListener(_onToken);
    }
    if (oldWidget.reactToFlare != widget.reactToFlare) {
      if (widget.reactToFlare) {
        RitmoAiStateService.instance.flareTrigger.addListener(_onFlare);
      } else {
        RitmoAiStateService.instance.flareTrigger.removeListener(_onFlare);
      }
    }
    final RitmoOrbSignature next = _baseSignature();
    if (next.breathMs != _to.breathMs ||
        next.flow != _to.flow ||
        next.density != _to.density ||
        next.rim != _to.rim) {
      _from = RitmoOrbSignature.lerp(_from, _to, _blend.value);
      _to = next;
      if (_subscribed) {
        _blend.snap(0.0);
        _blend.target = 1.0;
      } else {
        _blend.snap(1.0);
      }
    }
    if (oldWidget.isAnimated != widget.isAnimated ||
        oldWidget.size != widget.size ||
        oldWidget.tier != widget.tier) {
      _syncClock();
    }
    if (!_subscribed) _frame.value = _frame.value + 1.0;
  }

  @override
  void dispose() {
    RitmoOrbClock.instance.unsubscribe(_onTick);
    RitmoAiStateService.instance.truth.removeListener(_onExternal);
    RitmoAiStateService.instance.flareTrigger.removeListener(_onFlare);
    RitmoOrbAttentionSignal.instance.removeListener(_onExternal);
    RitmoOrbAttentionSignal.instance.acknowledge.removeListener(_onNod);
    RitmoOrbEnergySignal.instance.removeListener(_onExternal);
    widget.tokenPulse?.removeListener(_onToken);
    _frame.dispose();
    super.dispose();
  }

  void _syncClock() {
    final bool want = widget.isAnimated && !_reduceMotion && _tickerOn;
    if (want == _subscribed) return;
    if (want) {
      _clockLast = RitmoOrbClock.instance.time;
      RitmoOrbClock.instance.subscribe(
        _onTick,
        interval: RitmoOrbBudget.of(_tier).frameInterval,
      );
    } else {
      RitmoOrbClock.instance.unsubscribe(_onTick);
      _blend.snap(1.0);
      _flare = 0.0;
      _token = 0.0;
      _nod = 0.0;
      _frame.value = _frame.value + 1.0;
    }
    _subscribed = want;
  }

  void _onExternal() {
    if (!mounted) return;
    // تغییرِ صداقت/توجه/انرژی فقط برگ را دوباره می‌کشد.
    _frame.value = _frame.value + 1.0;
  }

  void _onNod() {
    _nod = 1.0;
    _onExternal();
  }

  void _onFlare() {
    _flare = 1.0;
    _onExternal();
  }

  void _onToken() {
    _token = 1.0;
    _onExternal();
  }

  void _onTick() {
    final double now = RitmoOrbClock.instance.time;
    double dt = now - _clockLast;
    _clockLast = now;
    if (dt <= 0.0 || dt > 0.25) dt = 1.0 / 60.0;

    final RitmoOrbSignature sig = _effective();
    _blend.step(dt);
    _phase += dt * (0.55 + 1.65 * sig.flow) * widget.speed;
    if (_phase > 6283.0) _phase -= 6283.0;
    _breath = (_breath + dt * 1000.0 / sig.breathMs) % 1.0;
    if (_flare > 0.0) _flare = (_flare - dt / 0.62).clamp(0.0, 1.0);
    if (_token > 0.0) _token = (_token - dt / 0.34).clamp(0.0, 1.0);
    if (_nod > 0.0) _nod = (_nod - dt / 0.45).clamp(0.0, 1.0);
    _frame.value = now;
  }

  RitmoOrbSignature _effective() {
    RitmoOrbSignature sig =
        RitmoOrbSignature.lerp(_from, _to, _blend.value).withTruth(_truth);
    if (widget.energyAware) {
      sig = sig.withEnergy(RitmoOrbEnergySignal.instance.value);
    }
    return sig;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _frame,
        builder: (BuildContext context, double _, Widget? child) {
          final RitmoOrbSignature sig = _effective();
          final RitmoOrbTruth truth = _truth;
          RitmoOrbPalette palette = widget.palette;
          if (widget.energyAware) {
            palette = ritmoEnergyPalette(
              palette,
              RitmoOrbEnergySignal.instance.value,
            );
          }
          if (truth == RitmoOrbTruth.unsure) {
            palette = palette.drained(0.42);
          } else if (truth == RitmoOrbTruth.offline) {
            palette = palette.drained(0.84);
          }
          return CustomPaint(
            size: Size.square(widget.size),
            isComplex: _tier == RitmoOrbTier.l,
            willChange: _subscribed,
            painter: _MarblePainter(
              palette: palette,
              tier: _tier,
              truth: truth,
              signature: sig,
              attention: _attention,
              rig: RitmoLightRig.resolve(
                tier: _tier,
                truth: truth,
                isDark: isDark,
                attention: _attention,
                tilt: widget.tiltOffset,
              ),
              shell: _shell,
              phase: _phase,
              breath: _breath,
              flare: _flare,
              token: _token,
              nod: math.max(_nod, widget.wink.clamp(0.0, 1.0)),
              pulse: widget.pulse.clamp(0.0, 1.0),
              tilt: widget.tiltOffset,
              squeeze: widget.squeezeFactor,
              intensity: widget.intensity.clamp(0.0, 1.6),
              shellWobble: widget.shellWobble,
              bulgeStrength: widget.bulgeStrength,
              isDark: isDark,
              stats: widget.stats,
            ),
          );
        },
      ),
    );
  }
}

class _MarblePainter extends CustomPainter {
  _MarblePainter({
    required this.palette,
    required this.tier,
    required this.truth,
    required this.signature,
    required this.attention,
    required this.rig,
    required this.shell,
    required this.phase,
    required this.breath,
    required this.flare,
    required this.token,
    required this.nod,
    required this.pulse,
    required this.tilt,
    required this.squeeze,
    required this.intensity,
    required this.shellWobble,
    required this.bulgeStrength,
    required this.isDark,
    required this.stats,
  });

  final RitmoOrbPalette palette;
  final RitmoOrbTier tier;
  final RitmoOrbTruth truth;
  final RitmoOrbSignature signature;
  final RitmoOrbAttention attention;
  final RitmoLightRig rig;
  final RitmoShellCache shell;
  final double phase;
  final double breath;
  final double flare;
  final double token;
  final double nod;
  final double pulse;
  final Offset tilt;
  final double squeeze;
  final double intensity;
  final double shellWobble;
  final double bulgeStrength;
  final bool isDark;
  final RitmoOrbPaintStats? stats;

  @override
  void paint(Canvas canvas, Size size) {
    final double dim = size.shortestSide;
    if (dim <= 0.0) return;
    RitmoOrbPaintStats.active = stats;
    try {
      _paint(canvas, size, dim);
    } finally {
      RitmoOrbPaintStats.active = null;
    }
  }

  void _paint(Canvas canvas, Size size, double dim) {
    final RitmoOrbBudget budget = RitmoOrbBudget.of(tier);
    final RitmoWhitePurse purse = RitmoWhitePurse(rig.whiteBudget);

    final double breathAmp = ritmoBreathCurve(breath);
    final double pump = 0.030 * breathAmp +
        0.045 * token +
        0.055 * flare -
        0.040 * pulse -
        0.030 * nod;
    final Offset center = Offset(
      size.width / 2.0 + tilt.dx * dim * 0.028,
      size.height / 2.0 + tilt.dy * dim * 0.028,
    );
    final double radius =
        (dim / 2.0) * 0.955 * signature.scale * (1.0 + pump);
    if (radius <= 0.0) return;

    final double sx = squeeze.clamp(0.72, 1.28);
    final double sy = (1.0 / sx).clamp(0.72, 1.28);
    final double rimLight = signature.rim * (0.72 + 0.28 * breathAmp);
    final Offset drift = Offset(
      attention.focus.dx * radius * 0.16 * attention.strength,
      attention.focus.dy * radius * 0.16 * attention.strength,
    );

    ritmoPaintGlassBody(
      canvas,
      center: center,
      radius: radius,
      rig: rig,
      isDark: isDark,
      tier: tier,
    );

    if (tier == RitmoOrbTier.s) {
      // در ۱۹ پیکسل کسی جریانِ مایع نمی‌بیند؛ یک دلِ رنگی و یک لبهٔ خوانا کافی است.
      ritmoPaintFlow(
        canvas,
        plumes: ritmoBuildPlumes(
          center: center,
          radius: radius,
          phase: phase,
          count: 1,
          density: signature.density,
          drift: drift * 0.4,
        ),
        center: center,
        radius: radius,
        palette: palette,
        tier: tier,
        intensity: intensity,
        density: signature.density,
        rig: rig,
      );
      ritmoPaintRim(
        canvas,
        center: center,
        radius: radius,
        palette: palette,
        rig: rig,
        purse: purse,
        tier: tier,
        isDark: isDark,
        brightness: rimLight,
      );
      return;
    }

    // پوسته: نوسانِ نرم + برجستگی در جهتِ توجه.
    final List<RitmoShellBulge> bulges = <RitmoShellBulge>[];
    if (attention.strength > 0.08) {
      bulges.add(RitmoShellBulge(
        angle: attention.focus.direction,
        width: 1.15,
        amount: 0.055 * attention.strength * bulgeStrength,
      ));
    }
    if (token > 0.05) {
      bulges.add(RitmoShellBulge(
        angle: phase * 0.6,
        width: 0.85,
        amount: 0.035 * token * bulgeStrength,
      ));
    }

    final Path body = shell.resolve(
      center: center,
      radius: radius * 0.995,
      samples: budget.shellSamples,
      phase: phase * 0.55,
      wobble: signature.wobble * shellWobble * 0.16,
      squashX: sx,
      squashY: sy,
      bulges: bulges,
    );

    final int plumeCount = math.min(signature.plumes, budget.plumes);
    final double tremor = signature.tremor > 0.0
        ? 1.0 + signature.tremor * 0.035 * math.sin(phase * 7.3)
        : 1.0;

    canvas.save();
    canvas.clipPath(body);
    if (truth != RitmoOrbTruth.offline || plumeCount > 0) {
      ritmoPaintFlow(
        canvas,
        plumes: ritmoBuildPlumes(
          center: center,
          radius: radius * tremor,
          phase: phase,
          count: plumeCount,
          density: signature.density,
          drift: drift,
        ),
        center: center,
        radius: radius,
        palette: palette,
        tier: tier,
        intensity: intensity,
        density: signature.density,
        rig: rig,
      );
    }
    if (tier == RitmoOrbTier.l) {
      ritmoPaintPillow(
        canvas,
        center: center,
        radius: radius,
        palette: palette,
        rig: rig,
        purse: purse,
        phase: phase,
      );
    }
    ritmoPaintCaustic(
      canvas,
      center: center,
      radius: radius,
      palette: palette,
      rig: rig,
      purse: purse,
    );
    canvas.restore();

    ritmoPaintSheen(
      canvas,
      center: center,
      radius: radius,
      rig: rig,
      purse: purse,
      tier: tier,
      allowSpecular: truth == RitmoOrbTruth.confident,
    );

    ritmoPaintRim(
      canvas,
      center: center,
      radius: radius,
      palette: palette,
      rig: rig,
      purse: purse,
      tier: tier,
      isDark: isDark,
      brightness: rimLight,
    );

    if (flare > 0.02) {
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, radius * 0.10 * flare)
        ..color = palette.hot.withValues(alpha: 0.42 * flare)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.12);
      canvas.drawCircle(center, radius * (1.02 + 0.12 * (1.0 - flare)), ring);
      ritmoCountPaint(blurs: 1);
    }
  }

  @override
  bool shouldRepaint(_MarblePainter old) =>
      old.phase != phase ||
      old.breath != breath ||
      old.flare != flare ||
      old.token != token ||
      old.nod != nod ||
      old.pulse != pulse ||
      old.palette != palette ||
      old.tier != tier ||
      old.truth != truth ||
      old.attention != attention ||
      old.tilt != tilt ||
      old.squeeze != squeeze ||
      old.intensity != intensity ||
      old.isDark != isDark ||
      old.signature.flow != signature.flow ||
      old.signature.density != signature.density ||
      old.signature.rim != signature.rim ||
      old.signature.scale != signature.scale;
}
