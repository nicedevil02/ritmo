// =============================================================================
//  Ritmo Orb Ribbon & Topographic Core (v4)
//
//  Redesigned to render an authentic 3D Iridescent Liquid Crystal Marble:
//    * Volumetric wavy ribbons with organic cubic bezier curvature
//    * Parallel topographic contour striations (خطوط تراز کانتوری موازی و زنده)
//    * Smooth isometric wave phase flow and audio/AI reactive dynamics
//    * Pixel-budget adaptive rendering (60/120 FPS latency-free Canvas math)
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

enum RitmoPlumeTone { milk, blush, coral, ember, violet }

/// One volumetric ribbon wave inside the crystal marble.
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

  /// Angle the ribbon root is rooted at.
  final double anchor;

  /// How far toward the rim the spine reaches (fraction of radius).
  final double reach;

  /// Signed curvature / bow of the spine.
  final double bow;

  /// Contour sweep-back angle.
  final double sweep;

  /// 1 = near the surface (bright, crisp), 0 = deep (dim, volumetric).
  final double depth;

  /// Half-width of the ribbon band at its widest (fraction of radius).
  final double shaft;

  /// Stroke weight multiplier.
  final double weight;

  final double phase;
  final double swayRate;

  /// Number of topographic contour striations across the ribbon.
  final int barbs;
}

// tone, anchor, reach, bow, sweep, depth, shaft, weight, prio
const List<List<double>> _kLayout = <List<double>>[
  <double>[0, -1.22, 0.92, 0.58, 0.88, 0.96, 0.190, 1.00, 1], // Main luminous white/milk ribbon
  <double>[2, 0.95, 0.86, -0.65, 0.82, 0.78, 0.220, 0.95, 2], // Primary coral wave
  <double>[4, 2.65, 0.82, 0.52, 0.76, 0.42, 0.175, 0.85, 3], // Lavender/violet deep ribbon
  <double>[3, -2.55, 0.74, -0.72, 0.92, 0.24, 0.160, 0.75, 4], // Ember/gold accent ribbon
  <double>[1, 0.15, 0.68, 0.44, 0.68, 0.58, 0.145, 0.65, 5], // Secondary blush wave
];

List<RitmoPlume> ritmoBuildPlumes({
  int seed = 11,
  int count = 7,
  bool detailed = true,
}) {
  final math.Random rng = math.Random(seed * 7919 + 13);
  final int keep = count >= 7 ? 4 : (count >= 4 ? 3 : 2);
  final List<RitmoPlume> out = <RitmoPlume>[];

  for (final List<double> row in _kLayout) {
    if (row[8] > keep) continue;
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
        swayRate: 0.42 + rng.nextDouble() * 0.48,
        barbs: detailed ? 14 + (weight * 10.0).round() : 8,
      ),
    );
  }

  // Deepest first, so the front ribbons gracefully layer on top.
  out.sort((a, b) => a.depth.compareTo(b.depth));
  return out;
}

Color _toneColor(RitmoPlumeTone tone, RitmoOrbPalette p) {
  switch (tone) {
    case RitmoPlumeTone.milk:
      return p.milk;
    case RitmoPlumeTone.blush:
      return p.mid;
    case RitmoPlumeTone.coral:
      return p.core;
    case RitmoPlumeTone.ember:
      return p.hot;
    case RitmoPlumeTone.violet:
      return p.violet;
  }
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

/// Smooth bell-curve taper for volumetric ribbons.
double _ribbonTaper(double s) {
  final double v = math.sin(s.clamp(0.0, 1.0) * math.pi);
  return math.pow(v < 0.0 ? 0.0 : v, 0.72).toDouble();
}

/// The topographic fluid ribbons inside the living crystal marble.
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

  final double gain = intensity.clamp(0.0, 1.6);
  if (gain <= 0.01) return;

  final double e = energy.clamp(0.0, 1.0);
  final double pu = pulse.clamp(0.0, 1.0);
  final double wk = wink.clamp(0.0, 1.0);

  final bool tiny = radius < 26.0;
  final double budget = tiny ? 0.45 : (radius < 46.0 ? 0.75 : 1.0);
  final double boost = tiny ? 1.25 : (radius < 46.0 ? 1.10 : 1.0);

  final Color deepShadow =
      Color.lerp(palette.violet, const Color(0xFF14021C), 0.82) ??
          palette.violet;

  for (final RitmoPlume p in plumes) {
    final double depth = p.depth.clamp(0.0, 1.0);
    final double front = 0.40 + 0.60 * depth;
    final double sway = math.sin(t * p.swayRate + p.phase);
    final double secondarySway = math.cos(t * p.swayRate * 0.75 + p.phase * 1.3);

    final double rootA = p.anchor + swirl * (0.50 + 0.50 * depth) + sway * 0.14;
    final Offset u = Offset(math.cos(rootA), math.sin(rootA));
    final Offset nrm = Offset(-u.dy, u.dx);
    final Offset par = parallax * (radius * 0.10 * (0.25 + 0.75 * depth));

    final Offset root = center + u * (radius * 0.06) + par;
    final double far = radius * p.reach * (1.0 + 0.06 * pu + 0.03 * sway);
    final Offset tip = center + u * far + par;

    // Dual control points for genuine S-curve organic fluid motion
    final Offset ctrl1 = center +
        u * (far * 0.35) +
        nrm * (radius * 0.38 * p.bow * (1.0 + 0.15 * sway)) +
        par;
    final Offset ctrl2 = center +
        u * (far * 0.72) -
        nrm * (radius * 0.22 * p.bow * (1.0 + 0.20 * secondarySway)) +
        par;

    final Color tone = _toneColor(p.tone, palette);
    final Color litColor =
        Color.lerp(tone, palette.milk, 0.40 + 0.45 * depth) ?? tone;

    // 1. Generate smooth ribbon geometry points
    const int segments = 16;
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
        0.8,
        radius * p.shaft * _ribbonTaper(s) * (1.0 + 0.28 * pu),
      );

      spine.add(pt);
      normals.add(nn);
      lft.add(pt + nn * halfWidth);
      rgt.add(pt - nn * halfWidth);
    }

    if (lft.length < 3) continue;

    // 2. Draw Volumetric Iridescent Ribbon Body
    final Path ribbonBody = Path()..moveTo(lft.first.dx, lft.first.dy);
    for (int i = 1; i < lft.length; i++) {
      ribbonBody.lineTo(lft[i].dx, lft[i].dy);
    }
    for (int i = rgt.length - 1; i >= 0; i--) {
      ribbonBody.lineTo(rgt[i].dx, rgt[i].dy);
    }
    ribbonBody.close();

    // Soft volumetric underbody glow
    canvas.drawPath(
      ribbonBody,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          lft.first,
          tip,
          <Color>[
            tone.withValues(alpha: 0.0),
            tone.withValues(
              alpha: ((0.28 + 0.20 * e) * front * gain).clamp(0.0, 0.65),
            ),
            litColor.withValues(
              alpha: ((0.42 + 0.25 * e + 0.15 * pu) * front * gain).clamp(0.0, 0.85),
            ),
            palette.violet.withValues(
              alpha: ((0.18 + 0.12 * e) * front * gain).clamp(0.0, 0.45),
            ),
          ],
          const <double>[0.0, 0.35, 0.72, 1.0],
        ),
    );

    // Deep edge shadow line for 3D separation
    canvas.drawPath(
      Path()..addPolygon(rgt, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.65, radius * 0.016)
        ..color = deepShadow.withValues(
          alpha: (0.35 * front * gain).clamp(0.0, 0.55),
        ),
    );

    // Glowing bright leading edge
    canvas.drawPath(
      Path()..addPolygon(lft, false),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.85, radius * 0.024) * boost
        ..shader = ui.Gradient.linear(
          lft.first,
          lft.last,
          <Color>[
            palette.milk.withValues(alpha: 0.0),
            palette.milk.withValues(
              alpha: ((0.65 + 0.20 * e + 0.20 * pu) * front * gain).clamp(0.0, 0.95),
            ),
            litColor.withValues(
              alpha: (0.35 * front * gain).clamp(0.0, 0.60),
            ),
          ],
          const <double>[0.0, 0.50, 1.0],
        ),
    );

    // 3. Draw Topographic Parallel Contour Lines (خطوط تراز کانتوری موازی و زنده)
    if (!detailed && depth < 0.45) continue;

    final int numContours = math.max(4, (p.barbs * budget).round());
    final Path contourBatch = Path();

    for (int k = 0; k < numContours; k++) {
      final double uNorm = k / (numContours - 1).toDouble();
      final double linePos = 0.10 + 0.82 * uNorm;

      // Isometric wave ripple flowing through time
      final double waveShift = math.sin(linePos * 5.2 - t * 1.8 * p.swayRate + p.phase) * 0.06;
      final double sampleS = (linePos + waveShift).clamp(0.0, 1.0);

      final int spineIdx = (sampleS * (spine.length - 1)).round().clamp(0, spine.length - 1);
      final Offset pt = spine[spineIdx];
      final Offset nn = normals[spineIdx];

      final double currentWidth = math.max(
        0.8,
        radius * p.shaft * _ribbonTaper(sampleS) * (1.0 + 0.28 * pu),
      );

      // Curved contour cross-rib
      final Offset pStart = pt - nn * (currentWidth * 0.95);
      final Offset pEnd = pt + nn * (currentWidth * 0.95);
      
      // Control point curved with 3D spherical dome effect
      final Offset pDome = pt + nn * (currentWidth * 0.15 * p.sweep) - (normals[spineIdx].scale(0.1, 0.1));

      contourBatch
        ..moveTo(pStart.dx, pStart.dy)
        ..quadraticBezierTo(pDome.dx, pDome.dy, pEnd.dx, pEnd.dy);
    }

    final double contourStrokeWidth = math.max(0.75, radius * 0.020 * p.weight) * boost;

    // Contour Soft Under-glow
    canvas.drawPath(
      contourBatch,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = contourStrokeWidth * 2.0
        ..color = tone.withValues(
          alpha: ((0.12 + 0.10 * e) * front * gain).clamp(0.0, 0.30),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, radius * 0.015)),
    );

    // Contour Crisp Holographic Line
    canvas.drawPath(
      contourBatch,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = contourStrokeWidth
        ..color = palette.milk.withValues(
          alpha: ((0.48 + 0.32 * e + 0.25 * pu + 0.35 * wk) * front * gain).clamp(0.0, 0.95),
        ),
    );
  }

  // 4. Volumetric Core Luminescence (قلب درخشان تیله)
  final Offset heart = center + parallax * (radius * 0.06);
  final double hr = radius * (0.34 + 0.08 * e + 0.08 * pu);
  canvas.drawCircle(
    heart,
    hr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        heart,
        hr,
        <Color>[
          palette.milk.withValues(alpha: (0.35 + 0.15 * e + 0.20 * pu) * gain),
          palette.core.withValues(alpha: (0.22 + 0.12 * e) * gain),
          palette.violet.withValues(alpha: 0.08 * gain),
          palette.core.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.38, 0.70, 1.0],
      ),
  );

  // Winking flash / Flare
  if (wk > 0.02) {
    canvas.drawCircle(
      center + Offset(-radius * 0.15, -radius * 0.12),
      radius * (0.24 + 0.20 * wk),
      Paint()
        ..isAntiAlias = true
        ..color = palette.milk.withValues(alpha: (0.38 * wk * gain).clamp(0.0, 0.70))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18),
    );
  }
}

/// The ground behind the ribbons: spherical shadow, cool ambient tint, and caustic pool.
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
  final double gain = intensity.clamp(0.0, 1.6);
  if (gain <= 0.01) return;

  final double e = energy.clamp(0.0, 1.0);
  final Offset shift = parallax * (radius * 0.06);
  final Color ink =
      Color.lerp(palette.violet, const Color(0xFF12021A), 0.82) ??
          palette.violet;

  // 1. Dark spherical depth ground (lower-right)
  final Offset deep = center + Offset(radius * 0.26, radius * 0.30) + shift;
  canvas.drawCircle(
    deep,
    radius * 1.02,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        deep,
        radius * 1.02,
        <Color>[
          ink.withValues(alpha: 0.46 * gain),
          ink.withValues(alpha: 0.24 * gain),
          ink.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.60, 1.0],
      ),
  );

  // 2. Cool ambient glass tint (upper-left)
  final Offset cool = center - Offset(radius * 0.24, radius * 0.28) + shift;
  canvas.drawCircle(
    cool,
    radius * 0.90,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        cool,
        radius * 0.90,
        <Color>[
          palette.violet.withValues(alpha: 0.20 * gain),
          palette.violet.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 1.0],
      ),
  );

  // 3. Bottom internal caustic refraction pool
  final double a = -2.30 + 0.16 * math.sin(t * 0.32);
  final Offset pool = center +
      Offset(math.cos(a), -math.sin(a)) * (radius * 0.56) +
      shift * 1.3;
  final double pr =
      radius * (0.32 + 0.05 * math.sin(t * 0.45) + 0.05 * pulse);

  canvas.drawCircle(
    pool,
    pr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        pool,
        pr,
        <Color>[
          palette.milk.withValues(alpha: (0.28 + 0.12 * e) * gain),
          palette.milk.withValues(alpha: 0.09 * gain),
          palette.milk.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.48, 1.0],
      ),
  );

  // 4. Crisp Caustic Arc inside the glass
  final Rect arc = Rect.fromCircle(center: pool, radius: pr * 1.02);
  canvas.drawArc(
    arc,
    -1.05 + 0.12 * math.sin(t * 0.28),
    1.62,
    false,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.70, radius * 0.024)
      ..color = palette.milk.withValues(
        alpha: ((0.32 + 0.14 * e) * gain).clamp(0.0, 0.65),
      ),
  );
}

