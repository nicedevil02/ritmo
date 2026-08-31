// =============================================================================
//  Ritmo Orb Ribbon & Fluid Core (v5) — گرداب مایع ابریشمی و کوانتومی
//
//  • کانسپت Liquid Silk Quantum Vortex: مایع روان، شفاف، ابریشمی و بدون خطوط راه‌راه
//  • توده‌های سیال و ارگانیک با گرادیان‌های نئونی فوق‌العاده زنده و اشباع
//  • انحناهای نرم بزیه، هستهٔ نورانی کروی و غبار نوری فوتونیک شناور
//  • رندرینگ ۱۲۰ فریم بر ثانیه بدون افت فریم و با نهایت ظرافت بصری
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

enum RitmoPlumeTone { milk, blush, coral, ember, violet }

/// روبان یا جریان مایع ابریشمی درون تیله
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

// ۴ جریان سیال و مواج با انحناهای ارگانیک متقاطع
const List<List<double>> _kLayout = <List<double>>[
  // tone, anchor, reach, bow, sweep, depth, shaft, weight, prio
  <double>[2, 0.85, 0.92, -0.72, 0.90, 0.95, 0.46, 1.00, 1], // جریان اصلی: نئون سرخابی/مرجانی به فیروزه‌ای
  <double>[4, -1.95, 0.88, 0.78, -0.85, 0.72, 0.42, 0.95, 2], // جریان دوم: فیروزه‌ای الکتریک به بنفش سلطنتی
  <double>[0, 2.60, 0.82, -0.55, 0.80, 0.48, 0.36, 0.85, 3], // جریان سوم: ابریشم سفید و هلویی درخشان
  <double>[1, -0.45, 0.75, 0.60, 0.70, 0.30, 0.30, 0.75, 4], // جریان عمقی: ارغوانی و کهربایی نرم
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
        barbs: detailed ? 16 : 8,
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
  return math.pow(v < 0.0 ? 0.0 : v, 0.60).toDouble();
}

/// رسم جریان‌های مواج مایع ابریشمی درون تیله (Liquid Silk Quantum Vortex)
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

  // پالت‌های گرادیان هولوگرافیک، اشباع و فوق‌العاده زنده
  const List<Color> magentaCyanRamp = <Color>[
    Color(0xFFFF007F), // نئون سرخابی تند
    Color(0xFFFF3366), // مرجانی پرحرارت
    Color(0xFFFF9900), // کهربایی گرم
    Color(0xFF00F5D4), // فیروزه‌ای نئونی
    Color(0xFF00D2FF), // آبی نئونی
  ];

  const List<Color> cyanVioletRamp = <Color>[
    Color(0xFF00F5D4), // فیروزه‌ای
    Color(0xFF00A8E8), // آبی لاجوردی
    Color(0xFF7209B7), // بنفش رویال
    Color(0xFFB5179E), // ارغوانی
    Color(0xFFF72585), // سرخابی درخشان
  ];

  const List<Color> silkPeachRamp = <Color>[
    Color(0xFFFFFFFF), // سفید ابریشمی
    Color(0xFFFFB3C6), // صورتی مرواریدی
    Color(0xFFFF758F), // مرجانی لطیف
    Color(0xFF7928CA), // بنفش کریستالی
  ];

  const List<Color> deepAmberVioletRamp = <Color>[
    Color(0xFFFFBE0B), // طلایی کهربایی
    Color(0xFFFB5607), // نارنجی تند
    Color(0xFFFF006E), // ماژنتا
    Color(0xFF8338EC), // بنفش الکتریک
  ];

  // ۱. رسم جریان‌های مواج مایع ابریشمی
  for (int pIdx = 0; pIdx < plumes.length; pIdx++) {
    final RitmoPlume p = plumes[pIdx];
    final double depth = p.depth.clamp(0.0, 1.0);
    final double front = 0.70 + 0.30 * depth;
    final double sway = math.sin(t * p.swayRate + p.phase);
    final double secondarySway = math.cos(t * p.swayRate * 0.8 + p.phase * 1.4);

    final double rootA = p.anchor + swirl * (0.45 + 0.55 * depth) + sway * 0.18;
    final Offset u = Offset(math.cos(rootA), math.sin(rootA));
    final Offset nrm = Offset(-u.dy, u.dx);
    final Offset par = parallax * (radius * 0.14 * (0.35 + 0.65 * depth));

    final Offset root = center - u * (radius * 0.22) + par;
    final double far = radius * p.reach * (1.0 + 0.06 * pu + 0.03 * sway);
    final Offset tip = center + u * far + par;

    final Offset ctrl1 = center +
        u * (far * 0.32) +
        nrm * (radius * 0.45 * p.bow * (1.0 + 0.14 * sway)) +
        par;
    final Offset ctrl2 = center +
        u * (far * 0.68) -
        nrm * (radius * 0.30 * p.bow * (1.0 + 0.20 * secondarySway)) +
        par;

    final List<Color> ramp = pIdx == 0
        ? magentaCyanRamp
        : (pIdx == 1
            ? cyanVioletRamp
            : (pIdx == 2 ? silkPeachRamp : deepAmberVioletRamp));

    // محاسبه نقاط بزیه در طول منحنی
    const int segments = 24;
    final List<Offset> lft = <Offset>[];
    final List<Offset> rgt = <Offset>[];
    final List<Offset> spine = <Offset>[];

    for (int i = 0; i <= segments; i++) {
      final double s = i / segments.toDouble();
      final Offset pt = _bez(root, ctrl1, ctrl2, tip, s);
      final Offset tg = _bezTan(root, ctrl1, ctrl2, tip, s);
      final double tl = tg.distance;
      if (tl < 0.0001) continue;

      final Offset nn = Offset(-tg.dy / tl, tg.dx / tl);
      final double halfWidth = math.max(
        1.5,
        radius * p.shaft * _ribbonTaper(s) * (1.0 + 0.22 * pu),
      );

      spine.add(pt);
      lft.add(pt + nn * halfWidth);
      rgt.add(pt - nn * halfWidth);
    }

    if (lft.length < 3) continue;

    // ایجاد حجم پیوسته مایع
    final Path ribbonBody = Path()..moveTo(lft.first.dx, lft.first.dy);
    for (int i = 1; i < lft.length; i++) {
      ribbonBody.lineTo(lft[i].dx, lft[i].dy);
    }
    for (int i = rgt.length - 1; i >= 0; i--) {
      ribbonBody.lineTo(rgt[i].dx, rgt[i].dy);
    }
    ribbonBody.close();

    // الف) هالهٔ حجیم و پف‌دار نور در زیر مایع (Subsurface Volumetric Light)
    canvas.drawPath(
      ribbonBody,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          lft.first,
          tip,
          ramp.map((c) => c.withValues(alpha: (0.60 * front * gain).clamp(0.0, 0.85))).toList(),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, radius * 0.12)),
    );

    // ب) پر کردن بدنه مایع با رنگ‌های اشباع، براق و پرکنتراست
    canvas.drawPath(
      ribbonBody,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          lft.first,
          tip,
          ramp.map((c) => c.withValues(alpha: ((0.85 + 0.12 * e) * front * gain).clamp(0.0, 0.98))).toList(),
        ),
    );

    // ج) لبهٔ صیقلی بالایی مایع (Silk Glaze Sheen)
    canvas.drawPath(
      Path()..addPolygon(lft, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.2, radius * 0.032)
        ..shader = ui.Gradient.linear(
          lft.first,
          lft.last,
          <Color>[
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: (0.90 * front * gain).clamp(0.0, 0.98)),
            ramp[1].withValues(alpha: (0.75 * front * gain).clamp(0.0, 0.90)),
            Colors.white.withValues(alpha: 0.20),
          ],
          const <double>[0.0, 0.35, 0.70, 1.0],
        ),
    );

    // د) خط نرم گرادیان در لبهٔ پایینی برای حجم سه‌بعدی
    canvas.drawPath(
      Path()..addPolygon(rgt, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.9, radius * 0.024)
        ..color = const Color(0xFF0C0318).withValues(
          alpha: (0.40 * front * gain).clamp(0.0, 0.65),
        ),
    );

    // ه) رشته‌های نازک و رقصان مایع (Liquid Wisps)
    if (detailed && spine.length >= 8) {
      final Path wispPath = Path()..moveTo(spine[2].dx, spine[2].dy);
      for (int i = 3; i < spine.length - 2; i += 2) {
        wispPath.quadraticBezierTo(
          spine[i].dx,
          spine[i].dy,
          spine[i + 1].dx,
          spine[i + 1].dy,
        );
      }
      canvas.drawPath(
        wispPath,
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.7, radius * 0.016)
          ..color = Colors.white.withValues(
            alpha: (0.45 * front * gain).clamp(0.0, 0.75),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, radius * 0.010)),
      );
    }
  }

  // ۲. کانون نورانی و مذاب مرکز تیله (Glowing Plasma Core)
  final Offset heart = center + parallax * (radius * 0.06);
  final double hr = radius * (0.42 + 0.10 * e + 0.10 * pu);
  canvas.drawCircle(
    heart,
    hr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        heart,
        hr,
        <Color>[
          Colors.white.withValues(alpha: (0.65 + 0.25 * e + 0.25 * pu + 0.35 * wk) * gain),
          const Color(0xFFFF007F).withValues(alpha: (0.40 + 0.18 * e) * gain),
          const Color(0xFF00F5D4).withValues(alpha: (0.22 + 0.10 * e) * gain),
          const Color(0xFF7209B7).withValues(alpha: 0.08 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.30, 0.60, 0.85, 1.0],
      ),
  );

  // ۳. غبار نوری فوتونیک شناور درون گرداب (Floating Photonic Stardust)
  if (detailed) {
    const int dotCount = 6;
    for (int d = 0; d < dotCount; d++) {
      final double ang = t * (0.25 + d * 0.08) + d * (math.pi * 2.0 / dotCount);
      final double dist = radius * (0.25 + 0.38 * math.sin(t * 0.4 + d * 1.5).abs());
      final Offset dotPos = center + Offset(math.cos(ang), math.sin(ang)) * dist + parallax * (radius * 0.08);

      final double twinkle = 0.5 + 0.5 * math.sin(t * 2.8 + d * 2.1);
      final double dotR = math.max(0.8, radius * 0.024 * (0.6 + 0.4 * twinkle));

      final Color dotColor = d % 3 == 0
          ? Colors.white
          : (d % 3 == 1 ? const Color(0xFF00F5D4) : const Color(0xFFFF007F));

      canvas.drawCircle(
        dotPos,
        dotR,
        Paint()
          ..isAntiAlias = true
          ..color = dotColor.withValues(
            alpha: ((0.45 + 0.45 * twinkle) * gain).clamp(0.0, 0.95),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.4, radius * 0.012)),
      );
    }
  }
}

/// لایهٔ عمق و اتمسفر پشت مایع ابریشمی
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
  final Offset cool = center - Offset(radius * 0.28, radius * 0.30) + shift;
  canvas.drawCircle(
    cool,
    radius * 0.96,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        cool,
        radius * 0.96,
        <Color>[
          const Color(0xFF00F5D4).withValues(alpha: (0.30 + 0.12 * e) * gain),
          const Color(0xFF7209B7).withValues(alpha: 0.12 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.48, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.16),
  );

  // هالهٔ گرم مرجانی-سرخابی در پایین-راست
  final Offset warm = center + Offset(radius * 0.26, radius * 0.26) + shift;
  canvas.drawCircle(
    warm,
    radius * 1.02,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        warm,
        radius * 1.02,
        <Color>[
          const Color(0xFFFF007F).withValues(alpha: (0.35 + 0.15 * e) * gain),
          const Color(0xFF3A0CA3).withValues(alpha: 0.20 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.52, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18),
  );
}
