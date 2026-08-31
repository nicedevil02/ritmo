// =============================================================================
//  Ritmo Orb Ribbon & Topographic Core (v4) — موتور سه‌بعدی تیلهٔ هولوگرافیک
//
//  • توده‌های حجیم و مواج مایع کریستالی با رنگ‌های اشباع و نئونی
//  • خطوط تراز کانتوری لیزری و موازی (Topographic Laser Striations)
//  • جریان ارگانیک و پیوسته با امواج بزیه و گرادیان‌های رنگین‌کمانی
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

enum RitmoPlumeTone { milk, blush, coral, ember, violet }

/// روبان هولوگرافیک سه‌بعدی درون تیله
@immutable
class RitmoPlume {
  const RitmoPlume({
    required this.tone,
    required this.anchor,
    required this.reach,
    required this.bow,
    required this.sweep,
    required this.depth,
    required this.shaft,
    required this.weight,
    required this.phase,
    required this.swayRate,
    required this.barbs,
  });

  final RitmoPlumeTone tone;
  final double anchor;
  final double reach;
  final double bow;
  final double sweep;
  final double depth;
  final double shaft;
  final double weight;
  final double phase;
  final double swayRate;
  final int barbs;
}

// چیدمان هندسی ۳ روبان حجیم و متقاطع با پهنای عریض و عمق سه‌بعدی
const List<List<double>> _kLayout = <List<double>>[
  // tone, anchor, reach, bow, sweep, depth, shaft, weight, prio
  <double>[2, 0.92, 0.90, -0.68, 0.85, 0.92, 0.44, 1.00, 1], // روبان اصلی مرجانی/سرخابی به فیروزه‌ای
  <double>[4, -1.85, 0.88, 0.72, -0.80, 0.65, 0.38, 0.95, 2], // روبان فیروزه‌ای/آبی به بنفش سلطنتی
  <double>[0, 2.70, 0.82, -0.50, 0.75, 0.40, 0.34, 0.85, 3], // روبان درخشان ابریشمی/هلویی در عمق
];

List<RitmoPlume> ritmoBuildPlumes({
  int seed = 11,
  int count = 7,
  bool detailed = true,
}) {
  final math.Random rng = math.Random(seed * 7919 + 13);
  final List<RitmoPlume> out = <RitmoPlume>[];

  for (final List<double> row in _kLayout) {
    final double weight = row[7];
    out.add(
      RitmoPlume(
        tone: RitmoPlumeTone.values[row[0].round()],
        anchor: row[1],
        reach: row[2],
        bow: row[3],
        sweep: row[4],
        depth: row[5],
        shaft: row[6],
        weight: weight,
        phase: rng.nextDouble() * math.pi * 2.0,
        swayRate: 0.38 + rng.nextDouble() * 0.42,
        barbs: detailed ? 26 + (weight * 10.0).round() : 14,
      ),
    );
  }

  out.sort((a, b) => a.depth.compareTo(b.depth));
  return out;
}

Offset _bez(Offset a, Offset c1, Offset c2, Offset b, double s) {
  final double u = 1.0 - s;
  final double tt = s * s;
  final double uu = u * u;
  final double uuu = uu * u;
  final double ttt = tt * s;

  return Offset(
    uuu * a.dx + 3 * uu * s * c1.dx + 3 * u * tt * c2.dx + ttt * b.dx,
    uuu * a.dy + 3 * uu * s * c1.dy + 3 * u * tt * c2.dy + ttt * b.dy,
  );
}

Offset _bezTan(Offset a, Offset c1, Offset c2, Offset b, double s) {
  final double u = 1.0 - s;
  return Offset(
    3 * u * u * (c1.dx - a.dx) + 6 * u * s * (c2.dx - c1.dx) + 3 * s * s * (b.dx - c2.dx),
    3 * u * u * (c1.dy - a.dy) + 6 * u * s * (c2.dy - c1.dy) + 3 * s * s * (b.dy - c2.dy),
  );
}

double _ribbonTaper(double s) {
  final double v = math.sin(s.clamp(0.0, 1.0) * math.pi);
  return math.pow(v < 0.0 ? 0.0 : v, 0.55).toDouble();
}

/// رسم روبان‌های حجیم و خطوط تراز کانتوری درون تیله
void ritmoPaintPlumes({
  required Canvas canvas,
  required Offset center,
  required double radius,
  required List<RitmoPlume> plumes,
  required RitmoOrbPalette palette,
  required double t,
  required double energy,
  required double intensity,
  required double swirl,
  required Offset parallax,
  required bool detailed,
  double pulse = 0.0,
  double wink = 0.0,
}) {
  if (radius <= 1.0 || plumes.isEmpty) return;

  final double gain = intensity.clamp(0.4, 1.6);
  final double e = energy.clamp(0.0, 1.0);
  final double pu = pulse.clamp(0.0, 1.0);
  final double wk = wink.clamp(0.0, 1.0);

  // پالت‌های گرادیان هولوگرافیک اشباع و پرانرژی
  const List<Color> coralCyanRamp = <Color>[
    Color(0xFFFF007A), // نئون سرخابی
    Color(0xFFFF455B), // مرجانی داغ
    Color(0xFFFFB03A), // کهربایی درخشان
    Color(0xFF00F5D4), // فیروزه‌ای نئونی
    Color(0xFF00D2FF), // آبی آسمانی
  ];

  const List<Color> cyanVioletRamp = <Color>[
    Color(0xFF00F5D4), // فیروزه‌ای
    Color(0xFF00B4D8), // آبی دریایی
    Color(0xFF7209B7), // بنفش رویال
    Color(0xFFF72585), // سرخابی درخشان
  ];

  const List<Color> silkPeachRamp = <Color>[
    Color(0xFFFFFFFF), // ابریشم سفید
    Color(0xFFFFB3C6), // صورتی ملایم
    Color(0xFFFF758F), // مرجانی
    Color(0xFF8338EC), // ارغوانی
  ];

  for (int pIdx = 0; pIdx < plumes.length; pIdx++) {
    final RitmoPlume p = plumes[pIdx];
    final double depth = p.depth.clamp(0.0, 1.0);
    final double front = 0.65 + 0.35 * depth;
    final double sway = math.sin(t * p.swayRate + p.phase);
    final double secondarySway = math.cos(t * p.swayRate * 0.75 + p.phase * 1.3);

    final double rootA = p.anchor + swirl * (0.45 + 0.55 * depth) + sway * 0.16;
    final Offset u = Offset(math.cos(rootA), math.sin(rootA));
    final Offset nrm = Offset(-u.dy, u.dx);
    final Offset par = parallax * (radius * 0.12 * (0.30 + 0.70 * depth));

    final Offset root = center - u * (radius * 0.18) + par;
    final double far = radius * p.reach * (1.0 + 0.05 * pu + 0.03 * sway);
    final Offset tip = center + u * far + par;

    final Offset ctrl1 = center +
        u * (far * 0.30) +
        nrm * (radius * 0.42 * p.bow * (1.0 + 0.12 * sway)) +
        par;
    final Offset ctrl2 = center +
        u * (far * 0.70) -
        nrm * (radius * 0.26 * p.bow * (1.0 + 0.18 * secondarySway)) +
        par;

    // انتخاب پالت بر اساس لایه
    final List<Color> ramp = pIdx == 0
        ? coralCyanRamp
        : (pIdx == 1 ? cyanVioletRamp : silkPeachRamp);

    // ۱. محاسبه مسیر اسکلت و لبه‌های روبان
    const int segments = 22;
    final List<Offset> lft = <Offset>[];
    final List<Offset> rgt = <Offset>[];
    final List<Offset> spine = <Offset>[];
    final List<Offset> normals = <Offset>[];

    for (int i = 0; i <= segments; i++) {
      final double s = i / segments.toDouble();
      final Offset pt = _bez(root, ctrl1, ctrl2, tip, s);
      final Offset tg = _bezTan(root, ctrl1, ctrl2, tip, s);
      final double tl = tg.distance;
      if (tl < 0.0001) continue;

      final Offset nn = Offset(-tg.dy / tl, tg.dx / tl);
      final double halfWidth = math.max(
        1.2,
        radius * p.shaft * _ribbonTaper(s) * (1.0 + 0.20 * pu),
      );

      spine.add(pt);
      normals.add(nn);
      lft.add(pt + nn * halfWidth);
      rgt.add(pt - nn * halfWidth);
    }

    if (lft.length < 3) continue;

    // ساخت چندضلعی بدنه روبان
    final Path ribbonBody = Path()..moveTo(lft.first.dx, lft.first.dy);
    for (int i = 1; i < lft.length; i++) {
      ribbonBody.lineTo(lft[i].dx, lft[i].dy);
    }
    for (int i = rgt.length - 1; i >= 0; i--) {
      ribbonBody.lineTo(rgt[i].dx, rgt[i].dy);
    }
    ribbonBody.close();

    // ۲. هالهٔ درخشان حجیم زیر روبان (Subsurface Volumetric Glow)
    canvas.drawPath(
      ribbonBody,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          lft.first,
          tip,
          ramp.map((c) => c.withValues(alpha: (0.50 * front * gain).clamp(0.0, 0.85))).toList(),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, radius * 0.08)),
    );

    // ۳. پر کردن بدنهٔ روبان با گرادیان پررنگ، غلیظ و با کنتراست بالا
    canvas.drawPath(
      ribbonBody,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          lft.first,
          tip,
          ramp.map((c) => c.withValues(alpha: ((0.82 + 0.15 * e) * front * gain).clamp(0.0, 0.98))).toList(),
        ),
    );

    // لبهٔ سایه پشت روبان برای تفکیک ۳بعدی عمیق
    canvas.drawPath(
      Path()..addPolygon(rgt, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.8, radius * 0.022)
        ..color = const Color(0xFF0A0214).withValues(
          alpha: (0.45 * front * gain).clamp(0.0, 0.70),
        ),
    );

    // لبهٔ درخشان بالایی روبان
    canvas.drawPath(
      Path()..addPolygon(lft, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.0, radius * 0.026)
        ..color = Colors.white.withValues(
          alpha: (0.75 * front * gain).clamp(0.0, 0.95),
        ),
    );

    // ۴. رسم خطوط تراز کانتوری لیزری و متراکم (Topographic Laser Striations)
    final int numContours = math.max(10, p.barbs);
    final Path contourBatch = Path();

    for (int k = 0; k < numContours; k++) {
      final double uNorm = k / (numContours - 1).toDouble();
      final double linePos = 0.06 + 0.88 * uNorm;

      // موج لغزان کانتوری روی محور زمان
      final double waveShift = math.sin(linePos * 6.0 - t * 2.2 * p.swayRate + p.phase) * 0.045;
      final double sampleS = (linePos + waveShift).clamp(0.0, 1.0);

      final int spineIdx = (sampleS * (spine.length - 1)).round().clamp(0, spine.length - 1);
      final Offset pt = spine[spineIdx];
      final Offset nn = normals[spineIdx];

      final double currentWidth = math.max(
        1.2,
        radius * p.shaft * _ribbonTaper(sampleS) * (1.0 + 0.20 * pu),
      );

      final Offset pStart = pt - nn * (currentWidth * 0.96);
      final Offset pEnd = pt + nn * (currentWidth * 0.96);
      final Offset pDome = pt + nn * (currentWidth * 0.18 * p.sweep);

      contourBatch
        ..moveTo(pStart.dx, pStart.dy)
        ..quadraticBezierTo(pDome.dx, pDome.dy, pEnd.dx, pEnd.dy);
    }

    final double contourWidth = math.max(0.85, radius * 0.020);

    // هاله نرم خطوط تراز
    canvas.drawPath(
      contourBatch,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = contourWidth * 2.2
        ..shader = ui.Gradient.linear(
          lft.first,
          tip,
          ramp.map((c) => c.withValues(alpha: 0.35 * front * gain)).toList(),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, radius * 0.018)),
    );

    // خط تیز هولوگرافیک تراز
    canvas.drawPath(
      contourBatch,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = contourWidth
        ..color = Colors.white.withValues(
          alpha: ((0.75 + 0.20 * e + 0.20 * pu + 0.30 * wk) * front * gain).clamp(0.0, 0.98),
        ),
    );
  }

  // ۵. کانون نورانی مرکز کره
  final Offset heart = center + parallax * (radius * 0.05);
  final double hr = radius * (0.38 + 0.08 * e + 0.08 * pu);
  canvas.drawCircle(
    heart,
    hr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        heart,
        hr,
        <Color>[
          Colors.white.withValues(alpha: (0.45 + 0.20 * e + 0.20 * pu) * gain),
          const Color(0xFFFF007A).withValues(alpha: (0.28 + 0.14 * e) * gain),
          const Color(0xFF00F5D4).withValues(alpha: 0.15 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.35, 0.70, 1.0],
      ),
  );
}

/// لایهٔ عمق و اتمسفر پشت روبان‌ها
void ritmoPaintPillow({
  required Canvas canvas,
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required double t,
  required double energy,
  required double intensity,
  required Offset parallax,
  double pulse = 0.0,
}) {
  if (radius <= 1.0) return;
  final double gain = intensity.clamp(0.4, 1.6);
  final double e = energy.clamp(0.0, 1.0);
  final Offset shift = parallax * (radius * 0.06);

  // هالهٔ اتمسفریک فیروزه‌ای در بالا-چپ
  final Offset cool = center - Offset(radius * 0.30, radius * 0.32) + shift;
  canvas.drawCircle(
    cool,
    radius * 0.95,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        cool,
        radius * 0.95,
        <Color>[
          const Color(0xFF00F5D4).withValues(alpha: (0.25 + 0.10 * e) * gain),
          const Color(0xFF7209B7).withValues(alpha: 0.10 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.50, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.15),
  );

  // هالهٔ گرم مرجانی-سرخابی در پایین-راست
  final Offset warm = center + Offset(radius * 0.28, radius * 0.28) + shift;
  canvas.drawCircle(
    warm,
    radius * 1.00,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        warm,
        radius * 1.00,
        <Color>[
          const Color(0xFFFF007A).withValues(alpha: (0.30 + 0.12 * e) * gain),
          const Color(0xFF3A0CA3).withValues(alpha: 0.18 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.55, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18),
  );
}
