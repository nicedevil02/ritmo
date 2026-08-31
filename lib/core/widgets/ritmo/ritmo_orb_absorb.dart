// =============================================================================
//  Ritmo Orb Absorb — جذب شدنِ تیله در کادرِ تایپ پیام
//
//  تیله موقع رفتن، پایین می‌رود و به کادر می‌خورد. این فایل همان برخورد را
//  می‌گیرد و رنگ‌ها را دورِ کادر می‌دواند؛ بعد یک ته‌رنگِ نفس‌کشنده می‌ماند:
//  تیله رفته، ولی حضورش در کادر زنده است.
//
//  همهٔ اعلان‌ها فازِ فریم را چک می‌کنند، پس هرگز «setState during build» نمی‌دهند.
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

class RitmoOrbAbsorb {
  RitmoOrbAbsorb._();

  static final RitmoOrbAbsorb instance = RitmoOrbAbsorb._();

  /// میزان نزدیک شدنِ تیله به کادر (۰..۱).
  final ValueNotifier<double> level = ValueNotifier<double>(0.0);

  /// هر بار یکی بالا می‌رود = یک برخورد/برخاستن.
  final ValueNotifier<int> impact = ValueNotifier<int>(0);

  /// ته‌رنگِ باقی‌مانده دورِ کادر روشن باشد یا نه.
  final ValueNotifier<bool> residue = ValueNotifier<bool>(false);

  RitmoOrbPalette palette = RitmoOrbPalette.coral;

  /// true = نور دارد از کادر برمی‌گردد داخلِ تیله (برگشتِ تیله).
  bool lifting = false;

  void _safe(VoidCallback fn) {
    final SchedulerBinding binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((Duration _) => fn());
    } else {
      fn();
    }
  }

  void report(double value, RitmoOrbPalette p) {
    palette = p;
    final double c = value.clamp(0.0, 1.0);
    if ((c - level.value).abs() < 0.005) return;
    _safe(() {
      level.value = c;
    });
  }

  /// تیله به کادر خورد: رنگ‌ها دورِ کادر پخش شوند.
  void splash(RitmoOrbPalette p) {
    palette = p;
    lifting = false;
    _safe(() {
      residue.value = true;
      impact.value = impact.value + 1;
    });
  }

  /// تیله دارد از کادر بلند می‌شود: نور برگردد به تیله.
  void lift(RitmoOrbPalette p) {
    palette = p;
    lifting = true;
    _safe(() {
      level.value = 0.0;
      residue.value = false;
      impact.value = impact.value + 1;
    });
  }

  void reset() {
    lifting = false;
    _safe(() {
      level.value = 0.0;
      residue.value = false;
    });
  }
}

Path _edgePath(double w, double topY, double corner, double inset) {
  final double half = w / 2.0;
  final double c = math.max(2.0, math.min(corner, half - inset - 2.0));
  final Path p = Path()..moveTo(half, topY);
  p.lineTo(w - inset - c, topY);
  p.arcToPoint(
    Offset(w - inset, topY + c),
    radius: Radius.circular(c),
    clockwise: true,
  );
  p.lineTo(w - inset, topY + c * 2.2);
  return p;
}

void _runner(
  Canvas canvas,
  Path path,
  double progress,
  Paint paint,
  double tailFraction,
) {
  for (final ui.PathMetric m in path.computeMetrics()) {
    final double len = m.length;
    if (len <= 0.5) continue;
    final double head = (progress * 1.10).clamp(0.0, 1.0) * len;
    final double tail = math.max(0.0, head - len * tailFraction);
    if (head - tail < 0.5) return;
    canvas.drawPath(m.extractPath(tail, head), paint);
    return;
  }
}

/// نوارِ نوریِ نازکی که دقیقاً بالای کادرِ تایپ پیام می‌نشیند.
class RitmoOrbAbsorbLip extends StatefulWidget {
  const RitmoOrbAbsorbLip({
    super.key,
    this.height = 18.0,
    this.inset = 12.0,
    this.cornerRadius = 26.0,
    this.strength = 1.0,
    this.idleGlow = true,
  });

  final double height;

  /// فاصلهٔ افقیِ کادرِ تایپ از لبهٔ صفحه (همان padding نوارِ پایین).
  final double inset;

  /// شعاع گوشهٔ کادرِ تایپ.
  final double cornerRadius;

  final double strength;

  /// ته‌رنگِ نفس‌کشنده بعد از جذب.
  final bool idleGlow;

  @override
  State<RitmoOrbAbsorbLip> createState() => _RitmoOrbAbsorbLipState();
}

class _RitmoOrbAbsorbLipState extends State<RitmoOrbAbsorbLip>
    with TickerProviderStateMixin {
  late final AnimationController _splash;
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _splash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );

    final RitmoOrbAbsorb bus = RitmoOrbAbsorb.instance;
    bus.impact.addListener(_onImpact);
    bus.residue.addListener(_onResidue);
    if (bus.residue.value) _onResidue();
  }

  @override
  void dispose() {
    RitmoOrbAbsorb.instance.impact.removeListener(_onImpact);
    RitmoOrbAbsorb.instance.residue.removeListener(_onResidue);
    _splash.dispose();
    _breath.dispose();
    super.dispose();
  }

  void _onImpact() {
    if (!mounted) return;
    _splash.forward(from: 0.0);
  }

  void _onResidue() {
    if (!mounted) return;
    final bool on = RitmoOrbAbsorb.instance.residue.value && widget.idleGlow;
    if (on && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!on && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final RitmoOrbAbsorb bus = RitmoOrbAbsorb.instance;

    return IgnorePointer(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _splash,
              _breath,
              bus.level,
              bus.residue,
            ]),
            builder: (BuildContext context, Widget? _) {
              return CustomPaint(
                painter: _LipPainter(
                  level: bus.level.value,
                  splash: _splash.value,
                  breath: Curves.easeInOutSine.transform(_breath.value),
                  residue: bus.residue.value && widget.idleGlow,
                  lifting: bus.lifting,
                  palette: bus.palette,
                  inset: widget.inset,
                  corner: widget.cornerRadius,
                  strength: widget.strength,
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
    required this.level,
    required this.splash,
    required this.breath,
    required this.residue,
    required this.lifting,
    required this.palette,
    required this.inset,
    required this.corner,
    required this.strength,
  });

  final double level;
  final double splash;
  final double breath;
  final bool residue;
  final bool lifting;
  final RitmoOrbPalette palette;
  final double inset;
  final double corner;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 8.0 || h <= 1.0) return;

    final double s = strength.clamp(0.0, 2.0);
    if (s <= 0.01) return;

    final double topY = h - 0.5;
    final Offset hit = Offset(w / 2.0, topY);
    final double lv = level.clamp(0.0, 1.0);

    // ۱) نور قبل از برخورد دارد جمع می‌شود
    if (lv > 0.01) {
      final double rr = math.max(2.0, w * (0.10 + 0.26 * lv));
      canvas.drawCircle(
        hit,
        rr,
        Paint()
          ..isAntiAlias = true
          ..shader = ui.Gradient.radial(
            hit,
            rr,
            <Color>[
              palette.hot.withValues(alpha: (0.30 * lv * s).clamp(0.0, 0.45)),
              palette.aura.withValues(alpha: (0.14 * lv * s).clamp(0.0, 0.25)),
              palette.aura.withValues(alpha: 0.0),
            ],
            const <double>[0.0, 0.48, 1.0],
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.85),
      );
    }

    // ۲) دویدنِ رنگ دورِ کادر
    final double p = splash.clamp(0.0, 1.0);
    if (p > 0.002 && p < 0.998) {
      final double travel = lifting ? 1.0 - p : p;
      final double fade =
          math.sin(math.min(1.0, p * 1.12) * math.pi).clamp(0.0, 1.0);
      final Path edge = _edgePath(w, topY, corner, inset);

      final Paint runner = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.4, h * 0.17)
        ..color = Color.lerp(palette.hot, palette.milk, 0.22)!
            .withValues(alpha: (0.58 * fade * s).clamp(0.0, 0.85))
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, math.max(1.5, h * 0.24));

      _runner(canvas, edge, travel, runner, 0.32);
      canvas.save();
      canvas.translate(w, 0.0);
      canvas.scale(-1.0, 1.0);
      _runner(canvas, edge, travel, runner, 0.32);
      canvas.restore();

      // شکوفهٔ لحطهٔ برخورد
      final double burst = math.max(0.0, 1.0 - p * 3.2);
      if (burst > 0.01 && !lifting) {
        final double rr = math.max(2.0, w * (0.14 + 0.34 * (1.0 - burst)));
        canvas.drawCircle(
          hit,
          rr,
          Paint()
            ..isAntiAlias = true
            ..shader = ui.Gradient.radial(
              hit,
              rr,
              <Color>[
                palette.milk.withValues(alpha: 0.34 * burst * s),
                palette.hot.withValues(alpha: 0.18 * burst * s),
                palette.hot.withValues(alpha: 0.0),
              ],
              const <double>[0.0, 0.45, 1.0],
            )
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.70),
        );
      }
    }

    // ۳) ته‌رنگِ ماندگار: تیله رفته، حضورش مانده
    if (!residue) return;

    final double br = 0.45 + 0.55 * breath.clamp(0.0, 1.0);
    final Path edge = _edgePath(w, topY, corner, inset);
    final Paint glow = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.0, h * 0.11)
      ..color = palette.aura
          .withValues(alpha: ((0.09 + 0.08 * br) * s).clamp(0.0, 0.28))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, h * 0.32));

    canvas.drawPath(edge, glow);
    canvas.save();
    canvas.translate(w, 0.0);
    canvas.scale(-1.0, 1.0);
    canvas.drawPath(edge, glow);
    canvas.restore();

    final double rr = math.max(2.0, w * 0.15);
    canvas.drawCircle(
      hit,
      rr,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          hit,
          rr,
          <Color>[
            palette.hot.withValues(alpha: (0.10 * br * s).clamp(0.0, 0.18)),
            palette.hot.withValues(alpha: 0.0),
          ],
          const <double>[0.0, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.60),
    );
  }

  @override
  bool shouldRepaint(_LipPainter old) {
    return level != old.level ||
        splash != old.splash ||
        breath != old.breath ||
        residue != old.residue ||
        lifting != old.lifting ||
        strength != old.strength ||
        inset != old.inset ||
        corner != old.corner ||
        palette != old.palette;
  }
}
