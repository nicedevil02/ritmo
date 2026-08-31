// =============================================================================
//  Ritmo Orb Liquid Silk Vortex Engine (v5)
//
//  طراحی فوق‌پرمیوم ورتکس ابریشمی مایع نوری (Liquid Silk Vortex):
//    • امواج سیال، روان و ابریشمی از نور مایع بدون هیچ‌گونه خطوط سیمی یا کانتوری
//    • گرادیان‌های نئونی فوق‌اشباع (سرخابی نئونی، فیروزه‌ای الکتریک، بنفش سلطنتی و هلویی)
//    • درخشش حجیم زیرین (Volumetric Underglow) و خطوط براق ابریشمی روی تاج موج‌ها
//    • عملکرد ۱۲۰ فریم بر ثانیه خالص بدون افت فریم
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

enum RitmoPlumeTone { milk, blush, coral, ember, violet }

/// اطلاعات موج مایع ابریشمی درون تیله
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

// چیدمان ۴ جریان اصلی مایع ابریشمی برای ایجاد ورتکس سه‌بعدی متراکم
const List<List<double>> _kLayout = <List<double>>[
  // tone, anchor, reach, bow, sweep, depth, shaft, weight, prio
  <double>[2, 0.85, 0.94, -0.72, 0.85, 0.95, 0.48, 1.00, 1], // ۱. جریان اصلی سرخابی-مرجانی-فیروزه‌ای
  <double>[4, -1.95, 0.92, 0.78, -0.80, 0.75, 0.44, 0.95, 2], // ۲. جریان متقاطع فیروزه‌ای-نیلی-بنفش
  <double>[0, 2.55, 0.86, -0.58, 0.70, 0.50, 0.40, 0.88, 3], // ۳. جریان ابریشمی هلویی-سفید-ارغوانی
  <double>[1, -0.45, 0.78, 0.62, 0.65, 0.30, 0.36, 0.75, 4], // ۴. جریان ملایم عمقی بنفش-یاسی
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
        swayRate: 0.32 + rng.nextDouble() * 0.38,
        barbs: 0,
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

double _silkEnvelope(double s) {
  final double v = math.sin(s.clamp(0.0, 1.0) * math.pi);
  return math.pow(v < 0.0 ? 0.0 : v, 0.45).toDouble();
}

/// رندر ورتکس مایع ابریشمی درون تیله (Liquid Silk Vortex)
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

  // پالت‌های گرادیان هولوگرافیک و مایع ابریشمی
  const List<Color> stream1Colors = <Color>[
    Color(0xFFFF007A), // نئون سرخابی
    Color(0xFFFF2A6D), // صورتی داغ
    Color(0xFFFF6200), // نارنجی درخشان
    Color(0xFFFFB703), // کهربایی گرم
    Color(0xFF00F5D4), // فیروزه‌ای نئونی
    Color(0xFF00E5FF), // آبی الکتریک
  ];

  const List<Color> stream2Colors = <Color>[
    Color(0xFF00F5D4), // فیروزه‌ای
    Color(0xFF00B4D8), // آبی دریایی
    Color(0xFF0077B6), // کبالت
    Color(0xFF7209B7), // بنفش سلطنتی
    Color(0xFFB5179E), // سرخابی عمیق
    Color(0xFFF72585), // نئون فوشیا
  ];

  const List<Color> stream3Colors = <Color>[
    Color(0xFFFFFFFF), // سفید ابریشمی
    Color(0xFFFFC6FF), // صورتی پاستلی
    Color(0xFFFF758F), // مرجانی ملایم
    Color(0xFF9D4EDD), // ارغوانی
    Color(0xFF5A189A), // بنفش تیره
  ];

  const List<Color> stream4Colors = <Color>[
    Color(0xFF7B2CBF), // بنفش
    Color(0xFF3C096C), // یاسی تیره
    Color(0xFF240046), // ابسیدین بنفش
    Color(0xFF00F5D4), // درخشش فیروزه‌ای
  ];

  for (int pIdx = 0; pIdx < plumes.length; pIdx++) {
    final RitmoPlume p = plumes[pIdx];
    final double depth = p.depth.clamp(0.0, 1.0);
    final double front = 0.70 + 0.30 * depth;
    final double sway = math.sin(t * p.swayRate + p.phase);
    final double secondarySway = math.cos(t * p.swayRate * 0.85 + p.phase * 1.4);

    final double rootA = p.anchor + swirl * (0.50 + 0.50 * depth) + sway * 0.18;
    final Offset u = Offset(math.cos(rootA), math.sin(rootA));
    final Offset nrm = Offset(-u.dy, u.dx);
    final Offset par = parallax * (radius * 0.14 * (0.35 + 0.65 * depth));

    final Offset root = center - u * (radius * 0.22) + par;
    final double far = radius * p.reach * (1.0 + 0.06 * pu + 0.04 * sway);
    final Offset tip = center + u * far + par;

    final Offset ctrl1 = center +
        u * (far * 0.28) +
        nrm * (radius * 0.46 * p.bow * (1.0 + 0.14 * sway)) +
        par;
    final Offset ctrl2 = center +
        u * (far * 0.72) -
        nrm * (radius * 0.30 * p.bow * (1.0 + 0.20 * secondarySway)) +
        par;

    final List<Color> ramp = pIdx == 0
        ? stream1Colors
        : (pIdx == 1 ? stream2Colors : (pIdx == 2 ? stream3Colors : stream4Colors));

    // ۱. استخراج نقاط اسکلت، لبهٔ چپ و لبهٔ راست موج مایع
    const int segments = 28;
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
        1.5,
        radius * p.shaft * _silkEnvelope(s) * (1.0 + 0.22 * pu),
      );

      spine.add(pt);
      normals.add(nn);
      lft.add(pt + nn * halfWidth);
      rgt.add(pt - nn * halfWidth);
    }

    if (lft.length < 3) continue;

    // چندضلعی پیوستهٔ بدنهٔ مایع ابریشمی
    final Path silkPath = Path()..moveTo(lft.first.dx, lft.first.dy);
    for (int i = 1; i < lft.length; i++) {
      silkPath.lineTo(lft[i].dx, lft[i].dy);
    }
    for (int i = rgt.length - 1; i >= 0; i--) {
      silkPath.lineTo(rgt[i].dx, rgt[i].dy);
    }
    silkPath.close();

    // ۲. لایهٔ هالهٔ حجیم و نورانی زیرین (Volumetric Diffusion Layer)
    canvas.drawPath(
      silkPath,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          lft.first,
          tip,
          ramp.map((c) => c.withValues(alpha: (0.60 * front * gain).clamp(0.0, 0.88))).toList(),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, radius * 0.10)),
    );

    // ۳. بدنهٔ اشباع و مخملی مایع ابریشمی (Silky Fluid Body)
    canvas.drawPath(
      silkPath,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          lft.first,
          tip,
          ramp.map((c) => c.withValues(alpha: ((0.88 + 0.10 * e) * front * gain).clamp(0.0, 0.99))).toList(),
        ),
    );

    // ۴. سایهٔ عمیق پشتی برای جداسازی سه‌بعدی و حس پیچش مایع
    canvas.drawPath(
      Path()..addPolygon(rgt, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.0, radius * 0.026)
        ..color = const Color(0xFF04010A).withValues(
          alpha: (0.55 * front * gain).clamp(0.0, 0.80),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, radius * 0.012)),
    );

    // ۵. خط براق کریستالی روی لبهٔ پیشتاز موج مایع (Silk Crest Highlights)
    canvas.drawPath(
      Path()..addPolygon(lft, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.2, radius * 0.030)
        ..shader = ui.Gradient.linear(
          lft.first,
          lft.last,
          <Color>[
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(
              alpha: ((0.85 + 0.15 * e + 0.20 * pu) * front * gain).clamp(0.0, 1.0),
            ),
            const Color(0xFF00F5D4).withValues(
              alpha: ((0.70 + 0.15 * e) * front * gain).clamp(0.0, 0.95),
            ),
            Colors.white.withValues(alpha: 0.0),
          ],
          const <double>[0.0, 0.35, 0.70, 1.0],
        ),
    );

    // ۶. رشتهٔ نوری روان در مرکز مایع (Internal Fluid Filament)
    canvas.drawPath(
      Path()..addPolygon(spine, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.9, radius * 0.018)
        ..shader = ui.Gradient.linear(
          spine.first,
          spine.last,
          <Color>[
            Colors.transparent,
            Colors.white.withValues(
              alpha: ((0.75 + 0.25 * e + 0.25 * wk) * front * gain).clamp(0.0, 0.98),
            ),
            Colors.transparent,
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );
  }

  // ۷. کانون نوری درخشان در قلب ورتکس
  final Offset heart = center + parallax * (radius * 0.06);
  final double hr = radius * (0.42 + 0.08 * e + 0.08 * pu);
  canvas.drawCircle(
    heart,
    hr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        heart,
        hr,
        <Color>[
          Colors.white.withValues(alpha: (0.50 + 0.20 * e + 0.20 * pu) * gain),
          const Color(0xFFFF007A).withValues(alpha: (0.35 + 0.15 * e) * gain),
          const Color(0xFF00F5D4).withValues(alpha: (0.18 + 0.10 * e) * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.32, 0.65, 1.0],
      ),
  );
}

/// لایهٔ عمق و اتمسفر مایع پشت روبان‌ها
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

  // هالهٔ درخشان فیروزه‌ای در بالا-چپ
  final Offset cool = center - Offset(radius * 0.32, radius * 0.34) + shift;
  canvas.drawCircle(
    cool,
    radius * 0.98,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        cool,
        radius * 0.98,
        <Color>[
          const Color(0xFF00F5D4).withValues(alpha: (0.32 + 0.12 * e) * gain),
          const Color(0xFF7209B7).withValues(alpha: (0.14 + 0.06 * e) * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.48, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.16),
  );

  // هالهٔ گرم مرجانی-سرخابی در پایین-راست
  final Offset warm = center + Offset(radius * 0.30, radius * 0.30) + shift;
  canvas.drawCircle(
    warm,
    radius * 1.04,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        warm,
        radius * 1.04,
        <Color>[
          const Color(0xFFFF007A).withValues(alpha: (0.38 + 0.14 * e) * gain),
          const Color(0xFF3A0CA3).withValues(alpha: (0.22 + 0.08 * e) * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.52, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18),
  );
}
