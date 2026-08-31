// =============================================================================
//  Ritmo Orb Aurora Engine (Concept 2 — Ultra-Luxury Velvet Celestial Orb)
//
//  • پالت رنگی فوق‌لوکس، باوقار و اشرافی (Velvet Lavender, Champagne Peach & Platinum)
//  • حذف شلوغی و رنگین‌کمانی؛ حفظ هارمونی عمیق، یکدست و شبیه سنگ‌های قیمتی
//  • امواج مخملی ارگانیک شفق با بلور عمیق و شکست نور اپتیکال
//  • کانون نورانی پلاتینیوم-رزگلد با تپش‌های آرام و سلطنتی
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

    // امواج نرم هارمونیک باوقار و آرام
    final double wave1 = math.sin(lobes * a + time + phaseShift) * wobble;
    final double wave2 = math.cos((lobes + 1.0) * a - time * 0.7) * (wobble * 0.40);
    final double wave3 = math.sin(2.0 * a + time * 1.1) * (wobble * 0.20);

    final double r = radius * (1.0 + wave1 + wave2 + wave3).clamp(0.20, 1.40);
    pts.add(
      Offset(
        center.dx + math.cos(a) * r,
        center.dy + math.sin(a) * r,
      ),
    );
  }

  return _smoothClosedPath(pts);
}

/// رسم امواج و مایع شفق قطبی با هارمونی لوکس (Luxury Velvet Celestial Orb)
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

  // تنفس باوقار و آرام شفق
  final double breath = math.sin(t * 0.7) * 0.035 + math.sin(t * 1.4) * 0.015 + pu * 0.06;
  final Offset par = parallax * (radius * 0.08);
  final Offset coreCenter = center + par;

  // ---------------------------------------------------------------------------
  // ۱. موج شفق بیرونی (Outer Velvet Mantle — اسطوخودوسی مخملی، بنفش رویال و نیلی ابسیدین)
  // ---------------------------------------------------------------------------
  final double rOuter = radius * (0.82 + breath + 0.03 * e);
  final Path outerBlob = _buildAuroraWaveBlob(
    center: coreCenter,
    radius: rOuter,
    t: t,
    speedMult: 0.85 + 0.30 * e,
    lobes: 4.0,
    wobble: 0.14 + 0.05 * e,
    phaseShift: 0.0,
  );

  // هالهٔ بیرونی محو و مخملی
  canvas.drawPath(
    outerBlob,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.sweep(
        coreCenter,
        <Color>[
          const Color(0xFF8E76FF).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFF6C5CE7).withValues(alpha: (0.70 * gain).clamp(0.0, 0.90)),
          const Color(0xFF4834D4).withValues(alpha: (0.80 * gain).clamp(0.0, 0.95)),
          const Color(0xFFA29BFE).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFF8E76FF).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
        ],
        const <double>[0.0, 0.28, 0.58, 0.82, 1.0],
        TileMode.repeated,
        t * 0.28,
        t * 0.28 + math.pi * 2.0,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, radius * 0.16)),
  );

  // بدنهٔ نرم و عمیق موج بیرونی
  canvas.drawPath(
    outerBlob,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        coreCenter - Offset(radius * 0.14, radius * 0.14),
        rOuter * 1.15,
        <Color>[
          const Color(0xFFA29BFE).withValues(alpha: (0.85 * gain).clamp(0.0, 0.98)),
          const Color(0xFF6C5CE7).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFF241442).withValues(alpha: (0.45 * gain).clamp(0.0, 0.75)),
          Colors.transparent,
        ],
        const <double>[0.0, 0.45, 0.80, 1.0],
      ),
  );

  // ---------------------------------------------------------------------------
  // ۲. موج شفق میانی (Middle Silk Body — شامپاینی گرم، رزگلد و مرجانی مخملی)
  // ---------------------------------------------------------------------------
  final double rMiddle = radius * (0.62 + breath * 0.7 + 0.04 * pu);
  final Path middleBlob = _buildAuroraWaveBlob(
    center: coreCenter + Offset(radius * 0.05 * math.cos(t * 0.6), radius * 0.05 * math.sin(t * 0.5)),
    radius: rMiddle,
    t: -t,
    speedMult: 0.95 + 0.35 * e,
    lobes: 3.0,
    wobble: 0.18 + 0.06 * e,
    phaseShift: math.pi * 0.65,
  );

  // هالهٔ لطیف میانی رزگلد
  canvas.drawPath(
    middleBlob,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.sweep(
        coreCenter,
        <Color>[
          const Color(0xFFFF7675).withValues(alpha: (0.85 * gain).clamp(0.0, 0.98)),
          const Color(0xFFFFA07A).withValues(alpha: (0.80 * gain).clamp(0.0, 0.95)),
          const Color(0xFFFFB8B8).withValues(alpha: (0.78 * gain).clamp(0.0, 0.95)),
          const Color(0xFFD6A2E8).withValues(alpha: (0.75 * gain).clamp(0.0, 0.95)),
          const Color(0xFFFF7675).withValues(alpha: (0.85 * gain).clamp(0.0, 0.98)),
        ],
        const <double>[0.0, 0.25, 0.52, 0.78, 1.0],
        TileMode.repeated,
        -t * 0.35,
        -t * 0.35 + math.pi * 2.0,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, radius * 0.10)),
  );

  // بدنهٔ لایهٔ رزگلد-شامپاینی
  canvas.drawPath(
    middleBlob,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        coreCenter + Offset(radius * 0.10, -radius * 0.08),
        rMiddle * 1.10,
        <Color>[
          const Color(0xFFFFF0EB).withValues(alpha: (0.92 * gain).clamp(0.0, 1.0)),
          const Color(0xFFFF7675).withValues(alpha: (0.85 * gain).clamp(0.0, 0.98)),
          const Color(0xFF6C5CE7).withValues(alpha: (0.50 * gain).clamp(0.0, 0.85)),
          Colors.transparent,
        ],
        const <double>[0.0, 0.40, 0.75, 1.0],
      ),
  );

  // ---------------------------------------------------------------------------
  // ۳. حلقهٔ هم‌مرکز درخشان پلاتینیوم (Platinum Silk Ripple Ring)
  // ---------------------------------------------------------------------------
  final double ring1Radius = radius * (0.40 + 0.06 * math.sin(t * 1.2) + 0.05 * pu);
  canvas.drawCircle(
    coreCenter,
    ring1Radius,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.038)
      ..shader = ui.Gradient.sweep(
        coreCenter,
        <Color>[
          Colors.white.withValues(alpha: (0.80 * gain).clamp(0.0, 0.95)),
          const Color(0xFFFFD8CC).withValues(alpha: (0.55 * gain).clamp(0.0, 0.85)),
          const Color(0xFFA29BFE).withValues(alpha: (0.65 * gain).clamp(0.0, 0.90)),
          Colors.white.withValues(alpha: (0.80 * gain).clamp(0.0, 0.95)),
        ],
        const <double>[0.0, 0.35, 0.70, 1.0],
        TileMode.repeated,
        t * 0.45,
        t * 0.45 + math.pi * 2.0,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, radius * 0.020)),
  );

  // ---------------------------------------------------------------------------
  // ۴. کانون نورانی پلاتینیوم و ابریشم خالص (Platinum Intelligence Core)
  // ---------------------------------------------------------------------------
  final double coreR = radius * (0.30 + 0.05 * math.sin(t * 1.6) + 0.06 * pu + 0.10 * wk);
  canvas.drawCircle(
    coreCenter,
    coreR,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        coreCenter,
        coreR,
        <Color>[
          Colors.white.withValues(alpha: (0.98 * gain).clamp(0.0, 1.0)),
          const Color(0xFFFFF2EC).withValues(alpha: (0.88 * gain).clamp(0.0, 1.0)),
          const Color(0xFFFF7675).withValues(alpha: (0.60 * gain).clamp(0.0, 0.92)),
          const Color(0xFF8E76FF).withValues(alpha: (0.22 * gain).clamp(0.0, 0.55)),
          Colors.transparent,
        ],
        const <double>[0.0, 0.32, 0.65, 0.88, 1.0],
      ),
  );

  // تابش لحظهٔ فلر / وینک
  if (wk > 0.02) {
    canvas.drawCircle(
      coreCenter,
      radius * (0.42 + 0.22 * wk),
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: (0.42 * wk * gain).clamp(0.0, 0.75))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.15),
    );
  }
}

/// لایهٔ عمق و زمینهٔ اتمسفریک باوقار و لوکس
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
  final Offset shift = parallax * (radius * 0.05);

  // هالهٔ لطیف اسطوخودوسی در بالا-چپ
  final Offset cool = center - Offset(radius * 0.26, radius * 0.28) + shift;
  canvas.drawCircle(
    cool,
    radius * 0.95,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        cool,
        radius * 0.95,
        <Color>[
          const Color(0xFFA29BFE).withValues(alpha: (0.30 + 0.08 * e) * gain),
          const Color(0xFF6C5CE7).withValues(alpha: 0.12 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.50, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.20),
  );

  // هالهٔ عمیق رزگلد و نیلی اشرافی در پایین-راست
  final Offset warm = center + Offset(radius * 0.24, radius * 0.24) + shift;
  canvas.drawCircle(
    warm,
    radius * 1.00,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        warm,
        radius * 1.00,
        <Color>[
          const Color(0xFFFF7675).withValues(alpha: (0.32 + 0.10 * e) * gain),
          const Color(0xFF2D1B4E).withValues(alpha: 0.22 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.55, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
  );
}
