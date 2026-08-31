// =============================================================================
//  Ritmo Orb Absorb v2 — جذب شدنِ گوی در کادرِ تایپ
//
//  درس‌های نسخهٔ قبل:
//    × blur پهن بود → روی متنِ بالا می‌زد و مثل «یک کادرِ اضافه» دیده می‌شد.
//    × بعد از جذب تقریباً ناپیدا می‌شد.
//
//  نسخهٔ جدید:
//    ✓ فقط ۸ پیکسل ارتفاعِ لی‌اوت می‌گیرد و حلقه را پایین‌تر از خودش می‌کشد
//      → هیچ چیزی به صفحهٔ چت نمی‌زند.
//    ✓ خطِ تیز (بدون blur) + یک bloom خیلی کوتاه.
//    ✓ بعد از جذب، یک حلقهٔ رنگین‌کمانی می‌ماند که آرام می‌چرخد.
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'
    show SchedulerBinding, SchedulerPhase;
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

/// اتوبوسِ پیام بینِ گوی و کادرِ تایپ.
class RitmoOrbAbsorb {
  RitmoOrbAbsorb._();

  static final RitmoOrbAbsorb instance = RitmoOrbAbsorb._();

  /// چقدر از گوی دارد فرو می‌رود (۰..۱).
  final ValueNotifier<double> level = ValueNotifier<double>(0.0);

  /// هر بار برخورد، یکی زیاد می‌شود.
  final ValueNotifier<int> impact = ValueNotifier<int>(0);

  /// حضورِ باقی‌مانده دورِ کادر (۰..۱).
  final ValueNotifier<double> residue = ValueNotifier<double>(0.0);

  final ValueNotifier<RitmoOrbPalette?> palette =
      ValueNotifier<RitmoOrbPalette?>(null);

  /// گوی دارد از کادر بالا می‌آید.
  final ValueNotifier<bool> lifting = ValueNotifier<bool>(false);

  void _safe(VoidCallback fn) {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      fn();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => fn());
  }

  /// گوی در حالِ فرو رفتن است.
  void report({required double sink, RitmoOrbPalette? tint}) {
    final double v = sink.clamp(0.0, 1.0);
    _safe(() {
      if (tint != null) palette.value = tint;
      if ((level.value - v).abs() > 0.004) level.value = v;
    });
  }

  /// لحظهٔ برخورد با کادر.
  void splash({RitmoOrbPalette? tint}) {
    _safe(() {
      if (tint != null) palette.value = tint;
      level.value = 0.0;
      residue.value = 1.0;
      lifting.value = false;
      impact.value = impact.value + 1;
    });
  }

  /// گوی دارد از کادر بیرون می‌آید.
  void lift() {
    _safe(() {
      lifting.value = true;
      residue.value = 0.0;
      level.value = 0.0;
    });
  }

  void reset() {
    _safe(() {
      level.value = 0.0;
      residue.value = 0.0;
      lifting.value = false;
    });
  }
}

/// مسیری که از وسطِ بالای کادر شروع و نیمهٔ راست را دور می‌زند.
Path _halfLoop(Rect r, double corner) {
  final double c = corner.clamp(0.0, math.min(r.width, r.height) / 2.0);
  return Path()
    ..moveTo(r.center.dx, r.top)
    ..lineTo(r.right - c, r.top)
    ..arcToPoint(
      Offset(r.right, r.top + c),
      radius: Radius.circular(c),
    )
    ..lineTo(r.right, r.bottom - c)
    ..arcToPoint(
      Offset(r.right - c, r.bottom),
      radius: Radius.circular(c),
    )
    ..lineTo(r.center.dx, r.bottom);
}

void _runner(
  Canvas canvas,
  Path path,
  double progress,
  Paint paint,
  double tailFraction,
) {
  for (final ui.PathMetric m in path.computeMetrics()) {
    final double total = m.length;
    if (total <= 0.5) continue;
    final double end = (progress * total).clamp(0.0, total);
    final double start = math.max(0.0, end - tailFraction * total);
    if (end - start < 0.6) continue;
    canvas.drawPath(m.extractPath(start, end), paint);
  }
}

/// نواری که دقیقاً بالای کادرِ تایپ می‌نشیند و حلقه را دورِ آن می‌کشد.
class RitmoOrbAbsorbLip extends StatefulWidget {
  const RitmoOrbAbsorbLip({
    super.key,
    this.height = 8.0,
    this.gap = 6.0,
    this.frameHeight = 52.0,
    this.inset = 10.0,
    this.cornerRadius = 26.0,
    this.thickness = 1.7,
    this.bleed = 1.6,
    this.strength = 1.0,
    this.idleGlow = true,
  });

  /// ارتفاعِ لی‌اوتی — عمداً کوچک.
  final double height;

  /// فاصله تا بالای کادرِ تایپ.
  final double gap;

  /// ارتفاعِ خودِ کادرِ تایپ.
  final double frameHeight;

  /// پدینگِ افقیِ کادرِ تایپ.
  final double inset;

  final double cornerRadius;
  final double thickness;

  /// چقدر خط بیرون‌تر از لبهٔ کادر بنشیند.
  final double bleed;

  final double strength;
  final bool idleGlow;

  @override
  State<RitmoOrbAbsorbLip> createState() => _RitmoOrbAbsorbLipState();
}

class _RitmoOrbAbsorbLipState extends State<RitmoOrbAbsorbLip>
    with TickerProviderStateMixin {
  late final AnimationController _splash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 9000),
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  final RitmoOrbAbsorb _bus = RitmoOrbAbsorb.instance;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _seen = _bus.impact.value;
    _bus.impact.addListener(_onImpact);
    _spin.repeat();
    _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bus.impact.removeListener(_onImpact);
    _splash.dispose();
    _spin.dispose();
    _breath.dispose();
    super.dispose();
  }

  void _onImpact() {
    if (!mounted) return;
    if (_bus.impact.value == _seen) return;
    _seen = _bus.impact.value;
    _splash.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: double.infinity,
          height: widget.height,
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _splash,
              _spin,
              _breath,
              _bus.level,
              _bus.residue,
              _bus.palette,
            ]),
            builder: (BuildContext context, Widget? _) {
              return CustomPaint(
                painter: _LipPainter(
                  splash: reduce ? 0.0 : _splash.value,
                  spin: reduce ? 0.0 : _spin.value,
                  breath: reduce ? 0.5 : _breath.value,
                  level: _bus.level.value,
                  residue: _bus.residue.value,
                  palette: _bus.palette.value ?? RitmoOrbPalette.coral,
                  gap: widget.gap,
                  frameHeight: widget.frameHeight,
                  inset: widget.inset,
                  corner: widget.cornerRadius,
                  thickness: widget.thickness,
                  bleed: widget.bleed,
                  strength: widget.strength,
                  idleGlow: widget.idleGlow,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LipPainter extends CustomPainter {
  const _LipPainter({
    required this.splash,
    required this.spin,
    required this.breath,
    required this.level,
    required this.residue,
    required this.palette,
    required this.gap,
    required this.frameHeight,
    required this.inset,
    required this.corner,
    required this.thickness,
    required this.bleed,
    required this.strength,
    required this.idleGlow,
  });

  final double splash;
  final double spin;
  final double breath;
  final double level;
  final double residue;
  final RitmoOrbPalette palette;
  final double gap;
  final double frameHeight;
  final double inset;
  final double corner;
  final double thickness;
  final double bleed;
  final double strength;
  final bool idleGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    if (w <= 24.0) return;

    final double k = strength.clamp(0.0, 2.0);
    if (k <= 0.01) return;

    final Rect frame = Rect.fromLTWH(
      inset - bleed,
      size.height + gap - bleed,
      w - (inset - bleed) * 2.0,
      frameHeight + bleed * 2.0,
    );
    if (frame.width <= 8.0) return;

    final double r =
        (corner + bleed).clamp(0.0, math.min(frame.width, frame.height) / 2.0);
    final RRect ring = RRect.fromRectAndRadius(frame, Radius.circular(r));
    final Offset top = Offset(frame.center.dx, frame.top);

    final List<Color> ramp = <Color>[
      palette.hot,
      palette.core,
      palette.mid,
      palette.milk,
      palette.violet,
      palette.aura,
      palette.hot,
    ];

    // ── ۱) حلقهٔ ماندگار — تیز و دیده‌شدنی.
    if (idleGlow && residue > 0.01) {
      final double pulse = 0.72 + 0.28 * breath;
      final double a = (0.46 * residue * pulse * k).clamp(0.0, 0.85);
      final double phase = spin * math.pi * 2.0;

      final Paint core = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..shader = ui.Gradient.sweep(
          frame.center,
          <Color>[
            for (final Color c in ramp) c.withValues(alpha: a),
          ],
          const <double>[0.0, 0.17, 0.34, 0.5, 0.66, 0.83, 1.0],
          TileMode.clamp,
          phase,
          phase + math.pi * 2.0,
        );
      canvas.drawRRect(ring, core);

      // bloom خیلی کوتاه — حداکثر ۲ پیکسل، تا به متن نزند.
      canvas.drawRRect(
        ring,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness * 2.1
          ..color = palette.aura.withValues(alpha: a * 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );
    }

    // ── ۲) جمع شدنِ رنگ در نقطهٔ تماس.
    final double lv = level.clamp(0.0, 1.0);
    if (lv > 0.02) {
      final double spread = frame.width * (0.06 + 0.30 * lv);
      canvas.drawPath(
        Path()
          ..moveTo(top.dx - spread, frame.top)
          ..lineTo(top.dx + spread, frame.top),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = thickness * (1.0 + 0.9 * lv)
          ..shader = ui.Gradient.linear(
            Offset(top.dx - spread, frame.top),
            Offset(top.dx + spread, frame.top),
            <Color>[
              palette.core.withValues(alpha: 0.0),
              palette.milk.withValues(alpha: (0.80 * lv * k).clamp(0.0, 0.92)),
              palette.core.withValues(alpha: 0.0),
            ],
            const <double>[0.0, 0.5, 1.0],
          ),
      );
      canvas.drawCircle(
        top,
        thickness * (1.2 + 1.6 * lv),
        Paint()
          ..isAntiAlias = true
          ..color = palette.milk.withValues(alpha: (0.70 * lv).clamp(0.0, 0.9)),
      );
    }

    // ── ۳) دو دوندهٔ نور که دورِ کادر می‌دوند.
    if (splash > 0.001 && splash < 0.999) {
      final double p = Curves.easeOutCubic.transform(splash);
      final double fade = 1.0 - math.pow(splash, 2.4).toDouble();
      final Path half = _halfLoop(frame, r);

      final Paint runner = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = thickness * 1.35
        ..color = palette.milk.withValues(alpha: (0.92 * fade * k).clamp(0.0, 1.0));

      final Paint trail = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = thickness * 2.4
        ..color = palette.core.withValues(alpha: (0.34 * fade * k).clamp(0.0, 0.7))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

      _runner(canvas, half, p, trail, 0.42);
      _runner(canvas, half, p, runner, 0.20);

      canvas.save();
      canvas.translate(w, 0.0);
      canvas.scale(-1.0, 1.0);
      final Path mirrored = _halfLoop(
        Rect.fromLTRB(
          w - frame.right,
          frame.top,
          w - frame.left,
          frame.bottom,
        ),
        r,
      );
      _runner(canvas, mirrored, p, trail, 0.42);
      _runner(canvas, mirrored, p, runner, 0.20);
      canvas.restore();

      // جرقهٔ لحظهٔ برخورد.
      final double burst = math.max(0.0, 1.0 - splash * 3.4);
      if (burst > 0.01) {
        canvas.drawCircle(
          top,
          thickness * (2.0 + 7.0 * (1.0 - burst)),
          Paint()
            ..isAntiAlias = true
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness * 1.1 * burst
            ..color = palette.milk.withValues(alpha: 0.85 * burst),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LipPainter old) {
    return splash != old.splash ||
        spin != old.spin ||
        breath != old.breath ||
        level != old.level ||
        residue != old.residue ||
        palette != old.palette ||
        gap != old.gap ||
        frameHeight != old.frameHeight ||
        inset != old.inset ||
        corner != old.corner ||
        thickness != old.thickness ||
        bleed != old.bleed ||
        strength != old.strength ||
        idleGlow != old.idleGlow;
  }
}
