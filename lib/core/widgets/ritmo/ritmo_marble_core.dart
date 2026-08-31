// =============================================================================
//  Ritmo Marble Core — خودِ تیله
//
//  لایه‌ها از پایین به بالا:
//    ۱) هالهٔ خیلی ملایمِ چسبیده به پوسته
//    ۲) جدارهٔ شیشه
//    ۳) عمق + ربان‌های تابیده (clip شده داخلِ پوسته)
//    ۴) سایه، تاجِ برآمدگی، برقِ سطح، لبهٔ نور
//
//  API عمداً هم‌شکلِ RitmoSiriOrb است تا جایگزینیِ درونِ RitmoLivingOrb یک‌خطی باشد.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_feather.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_shell.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_skin.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbMode, RitmoOrbPalette;

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
  });

  final double size;
  final RitmoOrbMode mode;
  final bool glowEnabled;
  final bool isAnimated;

  /// پارالاکسِ داخل تیله و جای برقِ سطح (۱-..۱).
  final Offset tiltOffset;

  /// کشیدگیِ حفط‌کنندهٔ مساحت (۱ = گرد).
  final double squeezeFactor;

  final RitmoOrbPalette palette;

  /// پررنگی کلیِ بافت داخل.
  final double intensity;

  /// سرعت جریان داخل.
  final double speed;

  final int seed;

  /// شدتِ ارتعاشِ پوسته (۰ = خاموش).
  final double shellWobble;

  /// شدتِ برآمدگی‌های موضعی (۰ = خاموش).
  final double bulgeStrength;

  /// تکانِ لحطه‌ای همزمان با تایپ کردنِ مدل (۰..۱).
  final double pulse;

  /// چشمک (۰..۱).
  final double wink;

  @override
  State<RitmoMarbleCore> createState() => _RitmoMarbleCoreState();
}

/// یک برآمدگی با چرخهٔ عمرِ خودش: ورم می‌کند، می‌ماند، می‌خوابد.
class _Bulge {
  _Bulge({
    required this.angle,
    required this.width,
    required this.born,
    required this.life,
    required this.peak,
  });

  final double angle;
  final double width;
  final double born;
  final double life;
  final double peak;

  double amountAt(double t) {
    final double u = (t - born) / life;
    if (u <= 0.0 || u >= 1.0) return 0.0;
    final double s = math.sin(u * math.pi);
    return peak * math.pow(s, 1.35).toDouble();
  }

  bool expired(double t) => t - born > life;
}

class _RitmoMarbleCoreState extends State<RitmoMarbleCore>
    with SingleTickerProviderStateMixin {
  static const double _kFallbackFrame = 1.0 / 60.0;

  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final List<_Bulge> _bulges = <_Bulge>[];

  late final math.Random _rng;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  double _t = 0.0;
  double _energy = 0.0;
  double _nextBulge = 1.3;
  bool _detailed = true;
  List<RitmoPlume> _plumes = const <RitmoPlume>[];

  @override
  void initState() {
    super.initState();
    _rng = math.Random(widget.seed * 131 + 7);
    _energy = _energyFor(widget.mode);
    _rebuildPlumes();
    _ticker = createTicker(_onTick);
    if (widget.isAnimated) _ticker!.start();
  }

  @override
  void didUpdateWidget(RitmoMarbleCore oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.seed != widget.seed ||
        (oldWidget.size >= 34.0) != (widget.size >= 34.0)) {
      _rebuildPlumes();
    }

    final Ticker? ticker = _ticker;
    if (ticker == null) return;
    if (widget.isAnimated && !ticker.isActive) {
      _last = Duration.zero;
      ticker.start();
    } else if (!widget.isAnimated && ticker.isActive) {
      ticker.stop();
      _frame.value = _frame.value + 1;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _rebuildPlumes() {
    _detailed = widget.size >= 34.0;
    _plumes = ritmoBuildPlumes(
      seed: widget.seed,
      count: _detailed ? 7 : 4,
      detailed: _detailed,
    );
  }

  static double _energyFor(RitmoOrbMode mode) {
    switch (mode) {
      case RitmoOrbMode.idle:
        return 0.26;
      case RitmoOrbMode.thinking:
        return 0.64;
      case RitmoOrbMode.streaming:
        return 1.0;
      case RitmoOrbMode.compact:
        return 0.34;
    }
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt <= 0.0) return;
    if (dt > 0.25) dt = _kFallbackFrame;

    final double target = _energyFor(widget.mode);
    _energy += (target - _energy) * (1.0 - math.exp(-dt * 3.4));

    final double sp = widget.speed.clamp(0.2, 3.0);
    final double kick = widget.pulse.clamp(0.0, 1.0);
    _t += dt * (0.70 + 0.90 * _energy + 0.55 * kick) * sp;

    final double bulge = widget.bulgeStrength.clamp(0.0, 2.0);
    if (bulge > 0.02 && _t >= _nextBulge) {
      _bulges.removeWhere((b) => b.expired(_t));
      if (_bulges.length < 2) {
        _bulges.add(
          _Bulge(
            angle: _rng.nextDouble() * math.pi * 2.0,
            width: 0.24 + _rng.nextDouble() * 0.24,
            born: _t,
            life: 1.15 + _rng.nextDouble() * 1.10,
            peak: (0.55 + _rng.nextDouble() * 0.45) * bulge,
          ),
        );
      }
      _nextBulge =
          _t + (2.30 + _rng.nextDouble() * 3.40) * (1.0 - 0.35 * _energy);
    } else if (_bulges.isNotEmpty) {
      _bulges.removeWhere((b) => b.expired(_t));
    }

    _frame.value = _frame.value + 1;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _frame,
        builder: (context, _, _) {
          final List<RitmoShellBulge> bulges = <RitmoShellBulge>[];
          for (int i = 0; i < _bulges.length; i++) {
            final double amount = _bulges[i].amountAt(_t);
            if (amount <= 0.01) continue;
            bulges.add(
              RitmoShellBulge(
                angle: _bulges[i].angle,
                width: _bulges[i].width,
                amount: amount,
              ),
            );
          }

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _MarblePainter(
                t: _t,
                energy: _energy,
                palette: widget.palette,
                intensity: widget.intensity,
                tilt: widget.tiltOffset,
                squeeze: widget.squeezeFactor,
                wobble: widget.shellWobble,
                pulse: widget.pulse,
                wink: widget.wink,
                bulges: bulges,
                plumes: _plumes,
                seed: widget.seed,
                isDark: isDark,
                detailed: _detailed,
                glowEnabled: widget.glowEnabled,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MarblePainter extends CustomPainter {
  const _MarblePainter({
    required this.t,
    required this.energy,
    required this.palette,
    required this.intensity,
    required this.tilt,
    required this.squeeze,
    required this.wobble,
    required this.pulse,
    required this.wink,
    required this.bulges,
    required this.plumes,
    required this.seed,
    required this.isDark,
    required this.detailed,
    required this.glowEnabled,
  });

  final double t;
  final double energy;
  final RitmoOrbPalette palette;
  final double intensity;
  final Offset tilt;
  final double squeeze;
  final double wobble;
  final double pulse;
  final double wink;
  final List<RitmoShellBulge> bulges;
  final List<RitmoPlume> plumes;
  final int seed;
  final bool isDark;
  final bool detailed;
  final bool glowEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    final double dim = math.min(size.width, size.height);
    if (dim <= 2.0) return;

    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double pu = pulse.clamp(0.0, 1.0);
    final double radius = dim * 0.5 * 0.88 * (1.0 + 0.018 * pu);
    final double e = energy.clamp(0.0, 1.0);
    final double sq = squeeze.clamp(0.80, 1.25);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(sq, 1.0 / sq);
    canvas.translate(-center.dx, -center.dy);

    final int samples = dim < 56.0 ? 46 : (dim < 130.0 ? 68 : 96);
    final Path shell = RitmoOrbShell.buildPath(
      center: center,
      radius: radius,
      t: t,
      wobble: wobble * (1.0 + 0.45 * pu),
      energy: e,
      bulges: bulges,
      samples: samples,
      seed: seed,
    );

    if (glowEnabled) {
      canvas.drawPath(
        shell,
        Paint()
          ..isAntiAlias = true
          ..color = palette.aura
              .withValues(alpha: 0.10 + 0.09 * e + 0.10 * pu)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
      );
    }

    ritmoPaintGlassBody(
      canvas: canvas,
      shell: shell,
      center: center,
      radius: radius,
      isDark: isDark,
    );

    canvas.save();
    canvas.clipPath(shell);

    ritmoPaintPillow(
      canvas: canvas,
      center: center,
      radius: radius,
      palette: palette,
      t: t,
      energy: e,
      intensity: intensity,
      parallax: tilt,
      pulse: pu,
    );

    ritmoPaintPlumes(
      canvas: canvas,
      center: center,
      radius: radius,
      plumes: plumes,
      palette: palette,
      t: t,
      energy: e,
      intensity: intensity,
      swirl: t * (0.055 + 0.075 * e),
      parallax: tilt,
      detailed: detailed,
      pulse: pu,
      wink: wink,
    );

    canvas.restore();

    ritmoPaintShellSkin(
      canvas: canvas,
      shell: shell,
      center: center,
      radius: radius,
      palette: palette,
      tilt: tilt,
      energy: e,
      intensity: intensity,
      t: t,
      bulges: bulges,
      isDark: isDark,
      detailed: detailed,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarblePainter old) {
    return t != old.t ||
        energy != old.energy ||
        squeeze != old.squeeze ||
        tilt != old.tilt ||
        wobble != old.wobble ||
        pulse != old.pulse ||
        wink != old.wink ||
        intensity != old.intensity ||
        detailed != old.detailed ||
        isDark != old.isDark ||
        glowEnabled != old.glowEnabled ||
        bulges.length != old.bulges.length ||
        palette != old.palette ||
        plumes != old.plumes;
  }
}
