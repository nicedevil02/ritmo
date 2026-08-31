// =============================================================================
//  Ritmo Orb Aurora Engine (Concept 2 — Apple Intelligence Aurora Fluid Orb)
//
//  • لایه‌های نرم و مواج شفق قطبی (Aurora Borealis Fluid Waves)
//  • بدون خطوط راه‌راه یا سیمی؛ کاملاً روان، مخملی و درخشان
//  • امواج کروماتیک ارگانیک با ترکیب فیروزه‌ای، سرخابی، کهربایی و بنفش رویال
//  • هستهٔ نورانی متحرک و حلقه‌های تنفسی هوش مصنوعی
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

enum RitmoPlumeTone { milk, blush, coral, ember, violet }

/// مدل دادهٔ روبان / لایهٔ شفق
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

List<RitmoPlume> ritmoBuildPlumes({
  int seed = 11,
  int count = 7,
  bool detailed = true,
}) {
  return const <RitmoPlume>[
    RitmoPlume(
      tone: RitmoPlumeTone.coral,
      anchor: 0.0,
      reach: 0.88,
      bow: 0.0,
      sweep: 0.0,
      depth: 0.9,
      shaft: 0.45,
      weight: 1.0,
      phase: 0.0,
      swayRate: 1.0,
      barbs: 0,
    ),
  ];
}

/// ساخت منحنی بستهٔ نرم از میان نقاط با تکنیک درون‌یابی بزیه
Path _smoothClosedPath(List<Offset> pts) {
  final Path path = Path();
  if (pts.length < 3) return path;

  final Offset last = pts[pts.length - 1];
  final Offset first = pts[0];
  path.moveTo((last.dx + first.dx) / 2.0, (last.dy + first.dy) / 2.0);

  for (int i = 0; i < pts.length; i++) {
    final Offset cur = pts[i];
    final Offset next = pts[(i + 1) % pts.length];
    path.quadraticBezierTo(
      cur.dx,
      cur.dy,
      (cur.dx + next.dx) / 2.0,
      (cur.dy + next.dy) / 2.0,
    );
  }

  path.close();
  return path;
}

/// تولید حباب ارگانیک مواج شفق قطبی (Aurora Fluid Blob)
Path _buildAuroraWaveBlob({
  required Offset center,
  required double radius,
  required double t,
  required double speedMult,
  required double lobes,
  required double wobble,
  required double phaseShift,
  int samples = 72,
}) {
  final List<Offset> pts = <Offset>[];
  final double time = t * speedMult;

  for (int i = 0; i < samples; i++) {
    final double a = (i / samples) * math.pi * 2.0;

    // امواج نرم هارمونیک چندفرکانسه برای مایع شفق قطبی
    final double wave1 = math.sin(lobes * a + time + phaseShift) * wobble;
    final double wave2 = math.cos((lobes + 1.0) * a - time * 0.8) * (wobble * 0.45);
    final double wave3 = math.sin(2.0 * a + time * 1.3) * (wobble * 0.25);

    final double r = radius * (1.0 + wave1 + wave2 + wave3).clamp(0.20, 1.45);
    pts.add(
      Offset(
        center.dx + math.cos(a) * r,
        center.dy + math.sin(a) * r,
      ),
    );
  }

  return _smoothClosedPath(pts);
}

/// رسم امواج و مایع شفق قطبی درون تیله (Apple Intelligence Aurora Orb)
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
  if (radius <= 1.0) return;

  final double gain = intensity.clamp(0.4, 1.6);
  final double e = energy.clamp(0.0, 1.0);
  final double pu = pulse.clamp(0.0, 1.0);
  final double wk = wink.clamp(0.0, 1.0);

  // تنفس طبیعی ارگانیک شفق
  final double breath = math.sin(t * 0.9) * 0.04 + math.sin(t * 1.8) * 0.02 + pu * 0.08;
  final Offset par = parallax * (radius * 0.10);
  final Offset coreCenter = center + par;

  // ---------------------------------------------------------------------------
  // ۱. موج شفق بیرونی (Outer Aurora Wave — فیروزه‌ای، آبی و بنفش رویال)
  // ---------------------------------------------------------------------------
  final double rOuter = radius * (0.84 + breath + 0.04 * e);
  final Path outerBlob = _buildAuroraWaveBlob(
    center: coreCenter,
    radius: rOuter,
    t: t,
    speedMult: 0.95 + 0.40 * e,
    lobes: 4.0,
    wobble: 0.16 + 0.06 * e,
    phaseShift: 0.0,
  );

  // هالهٔ بیرونی محو
  canvas.drawPath(
    outerBlob,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.sweep(
        coreCenter,
        <Color>[
          const Color(0xFF00F5D4).withValues(alpha: (0.70 * gain).clamp(0.0, 0.95)),
          const Color(0xFF00B4D8).withValues(alpha: (0.60 * gain).clamp(0.0, 0.90)),
          const Color(0xFF7209B7).withValues(alpha: (0.80 * gain).clamp(0.0, 0.95)),
          const Color(0xFFF72585).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFF00F5D4).withValues(alpha: (0.70 * gain).clamp(0.0, 0.95)),
        ],
        const <double>[0.0, 0.28, 0.58, 0.82, 1.0],
        TileMode.repeated,
        t * 0.35,
        t * 0.35 + math.pi * 2.0,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, radius * 0.14)),
  );

  // بدنهٔ نرم و مخملی موج بیرونی
  canvas.drawPath(
    outerBlob,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        coreCenter - Offset(radius * 0.15, radius * 0.15),
        rOuter * 1.15,
        <Color>[
          const Color(0xFF00F5D4).withValues(alpha: (0.85 * gain).clamp(0.0, 0.98)),
          const Color(0xFF7209B7).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFF3A0CA3).withValues(alpha: (0.40 * gain).clamp(0.0, 0.70)),
          Colors.transparent,
        ],
        const <double>[0.0, 0.45, 0.80, 1.0],
      ),
  );

  // ---------------------------------------------------------------------------
  // ۲. موج شفق میانی (Middle Aurora Fluid Body — سرخابی، مرجانی و کهربایی)
  // ---------------------------------------------------------------------------
  final double rMiddle = radius * (0.64 + breath * 0.8 + 0.05 * pu);
  final Path middleBlob = _buildAuroraWaveBlob(
    center: coreCenter + Offset(radius * 0.06 * math.cos(t * 0.7), radius * 0.06 * math.sin(t * 0.6)),
    radius: rMiddle,
    t: -t,
    speedMult: 1.10 + 0.45 * e,
    lobes: 3.0,
    wobble: 0.20 + 0.08 * e,
    phaseShift: math.pi * 0.65,
  );

  // هالهٔ درخشان میانی
  canvas.drawPath(
    middleBlob,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.sweep(
        coreCenter,
        <Color>[
          const Color(0xFFFF007A).withValues(alpha: (0.85 * gain).clamp(0.0, 0.98)),
          const Color(0xFFFF5252).withValues(alpha: (0.80 * gain).clamp(0.0, 0.95)),
          const Color(0xFFFFBE0B).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFF8338EC).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFFFF007A).withValues(alpha: (0.85 * gain).clamp(0.0, 0.98)),
        ],
        const <double>[0.0, 0.25, 0.52, 0.78, 1.0],
        TileMode.repeated,
        -t * 0.45,
        -t * 0.45 + math.pi * 2.0,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, radius * 0.09)),
  );

  // بدنهٔ اصلی لایهٔ میانی
  canvas.drawPath(
    middleBlob,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        coreCenter + Offset(radius * 0.12, -radius * 0.10),
        rMiddle * 1.10,
        <Color>[
          const Color(0xFFFFBE0B).withValues(alpha: (0.90 * gain).clamp(0.0, 1.0)),
          const Color(0xFFFF007A).withValues(alpha: (0.85 * gain).clamp(0.0, 0.98)),
          const Color(0xFF7209B7).withValues(alpha: (0.50 * gain).clamp(0.0, 0.85)),
          Colors.transparent,
        ],
        const <double>[0.0, 0.40, 0.75, 1.0],
      ),
  );

  // ---------------------------------------------------------------------------
  // ۳. حلقه‌های هم‌مرکز تنفسی شفق (Concentric Aurora Rings)
  // ---------------------------------------------------------------------------
  final double ring1Radius = radius * (0.42 + 0.08 * math.sin(t * 1.4) + 0.06 * pu);
  canvas.drawCircle(
    coreCenter,
    ring1Radius,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, radius * 0.045)
      ..shader = ui.Gradient.sweep(
        coreCenter,
        <Color>[
          Colors.white.withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFF00F5D4).withValues(alpha: (0.50 * gain).clamp(0.0, 0.85)),
          const Color(0xFFFF007A).withValues(alpha: (0.65 * gain).clamp(0.0, 0.90)),
          Colors.white.withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
        ],
        const <double>[0.0, 0.35, 0.70, 1.0],
        TileMode.repeated,
        t * 0.60,
        t * 0.60 + math.pi * 2.0,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.6, radius * 0.025)),
  );

  // ---------------------------------------------------------------------------
  // ۴. کانون نورانی و هستهٔ درخشان مرکزی (Radiant Intelligence Core)
  // ---------------------------------------------------------------------------
  final double coreR = radius * (0.32 + 0.06 * math.sin(t * 2.0) + 0.08 * pu + 0.12 * wk);
  canvas.drawCircle(
    coreCenter,
    coreR,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        coreCenter,
        coreR,
        <Color>[
          Colors.white.withValues(alpha: (0.95 * gain).clamp(0.0, 1.0)),
          const Color(0xFFFFD166).withValues(alpha: (0.85 * gain).clamp(0.0, 1.0)),
          const Color(0xFFFF007A).withValues(alpha: (0.65 * gain).clamp(0.0, 0.95)),
          const Color(0xFF00F5D4).withValues(alpha: (0.25 * gain).clamp(0.0, 0.60)),
          Colors.transparent,
        ],
        const <double>[0.0, 0.30, 0.62, 0.85, 1.0],
      ),
  );

  // تابش لحطهٔ فلر / وینک
  if (wk > 0.02) {
    canvas.drawCircle(
      coreCenter,
      radius * (0.45 + 0.25 * wk),
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: (0.45 * wk * gain).clamp(0.0, 0.80))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.15),
    );
  }
}

/// لایهٔ عمق و زمینهٔ اتمسفریک شفق قطبی
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
    radius * 0.95,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        cool,
        radius * 0.95,
        <Color>[
          const Color(0xFF00F5D4).withValues(alpha: (0.35 + 0.10 * e) * gain),
          const Color(0xFF7209B7).withValues(alpha: 0.15 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.50, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.20),
  );

  // هالهٔ عمیق سرخابی-بنفش در پایین-راست
  final Offset warm = center + Offset(radius * 0.26, radius * 0.26) + shift;
  canvas.drawCircle(
    warm,
    radius * 1.00,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        warm,
        radius * 1.00,
        <Color>[
          const Color(0xFFFF007A).withValues(alpha: (0.38 + 0.12 * e) * gain),
          const Color(0xFF3A0CA3).withValues(alpha: 0.25 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.55, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
  );
}
