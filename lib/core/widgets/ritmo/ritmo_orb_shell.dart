// =============================================================================
//  Ritmo Orb Shell — هندسهٔ پوستهٔ زندهٔ تیله
//
//  • ارتعاشِ ریز و همیشگی: سه هارمونیکِ ناهم‌مقیاس ⇒ هیچ‌وقت تکرار نمی‌شود
//  • برآمدگیِ موضعی: هر چند ثانیه یک قسمت از پوسته ورم می‌کند و آرام می‌خوابد
//  • مسیر با Catmull-Rom نرم می‌شود تا هیچ گوشهٔ تیزی دیده نشود
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// یک برآمدگیِ موضعی روی پوسته.
@immutable
class RitmoShellBulge {
  const RitmoShellBulge({
    required this.angle,
    required this.width,
    required this.amount,
  });

  /// زاویهٔ مرکز برآمدگی (رادیان).
  final double angle;

  /// پهنای زاویه‌ای: کوچک = قله‌ای، بزرگ = تپه‌ای.
  final double width;

  /// شدت فعلی ۰..۱.
  final double amount;
}

double _wrapAngle(double a) {
  double x = a;
  while (x > math.pi) {
    x -= math.pi * 2.0;
  }
  while (x < -math.pi) {
    x += math.pi * 2.0;
  }
  return x;
}

class RitmoOrbShell {
  const RitmoOrbShell._();

  static double _ph(int seed, int k) {
    final double x = math.sin(seed * 12.9898 + k * 78.233) * 43758.5453;
    return (x - x.floorToDouble()) * math.pi * 2.0;
  }

  /// شعاعِ پوسته در یک زاویه: ارتعاش + برآمدگی‌ها.
  static double radiusAt({
    required double angle,
    required double radius,
    required double t,
    required double wobble,
    required double energy,
    required List<RitmoShellBulge> bulges,
    required int seed,
  }) {
    final double w = wobble.clamp(0.0, 2.0);
    final double e = energy.clamp(0.0, 1.0);

    double m = 1.0;
    m += 0.0082 * w * math.sin(3.0 * angle + t * 1.30 + _ph(seed, 1));
    m += 0.0056 * w * math.sin(5.0 * angle - t * 1.02 + _ph(seed, 2));
    m += 0.0036 * w * math.sin(7.0 * angle + t * 1.74 + _ph(seed, 3));
    m += 0.0042 * w * e * math.sin(11.0 * angle - t * 2.45 + _ph(seed, 4));

    for (int i = 0; i < bulges.length; i++) {
      final RitmoShellBulge b = bulges[i];
      if (b.amount <= 0.001) continue;
      final double d = _wrapAngle(angle - b.angle);
      final double s = b.width <= 0.02 ? 0.02 : b.width;
      m += b.amount * 0.135 * math.exp(-(d * d) / (2.0 * s * s));
    }
    return radius * m;
  }

  /// مسیرِ بستهٔ پوسته.
  static Path buildPath({
    required Offset center,
    required double radius,
    required double t,
    required double wobble,
    required double energy,
    required List<RitmoShellBulge> bulges,
    required int samples,
    required int seed,
  }) {
    final int n = samples.clamp(24, 160);
    final List<Offset> pts = List<Offset>.generate(n, (i) {
      final double a = (i / n) * math.pi * 2.0;
      final double r = radiusAt(
        angle: a,
        radius: radius,
        t: t,
        wobble: wobble,
        energy: energy,
        bulges: bulges,
        seed: seed,
      );
      return center + Offset(math.cos(a) * r, math.sin(a) * r);
    });

    final Path path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < n; i++) {
      final Offset p0 = pts[(i - 1 + n) % n];
      final Offset p1 = pts[i];
      final Offset p2 = pts[(i + 1) % n];
      final Offset p3 = pts[(i + 2) % n];
      final Offset c1 = p1 + (p2 - p0) * (1.0 / 6.0);
      final Offset c2 = p2 - (p3 - p1) * (1.0 / 6.0);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    path.close();
    return path;
  }

  /// نقطهٔ قلهٔ یک برآمدگی.
  static Offset crestOf({
    required Offset center,
    required double radius,
    required RitmoShellBulge bulge,
  }) {
    final Offset dir = Offset(math.cos(bulge.angle), math.sin(bulge.angle));
    return center + dir * (radius * (1.0 + 0.135 * bulge.amount));
  }
}

/// جدارهٔ شیشه‌ایِ تیله (پیش از کشیدنِ بافتِ داخل).
void ritmoPaintGlassBody({
  required Canvas canvas,
  required Path shell,
  required Offset center,
  required double radius,
  required bool isDark,
}) {
  if (radius <= 1.0) return;

  const List<Color> darkRamp = <Color>[
    Color(0xFFFDFDFF),
    Color(0xFFE4E8F2),
    Color(0xFFAEB6C8),
    Color(0xFF666F86),
  ];
  const List<Color> lightRamp = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFFEFAFA),
    Color(0xFFF2EEF4),
    Color(0xFFDBD6E2),
  ];
  final List<Color> ramp = isDark ? darkRamp : lightRamp;
  final Offset focal = center + Offset(-radius * 0.30, -radius * 0.34);

  canvas.drawPath(
    shell,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        focal,
        radius * 1.38,
        ramp,
        const <double>[0.0, 0.42, 0.78, 1.0],
      ),
  );
}
