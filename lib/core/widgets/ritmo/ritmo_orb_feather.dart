// =============================================================================
//  Ritmo Orb Feather v3 - real vanes, budgeted for a 24px radius.
//
//  Why v1 and v2 read as flat colour: they were designed for a big canvas, but
//  the orb renders at radius ~19-24px. At that size:
//    * a `radius * 0.34` sheet is an 8px blob (17% of the diameter)
//    * a `radius * 0.14` blur sigma is ~3px of mush on an 8px shape
//    * the old caustic pool was `radius * 0.62` at alpha 0.4 - a milk cloud
//      covering 40% of the marble, drowning every structure under it
//    * barbs were 2.6px long and 0.55px wide - literally invisible
//
//  v3 inverts the budget:
//    * the sheet is thin (radius * 0.05-0.09); the BARBS carry the volume
//    * barbs are radius * 0.19-0.44 long, >= 0.85px wide, and never blurred
//    * the ground is genuinely dark so light structures pop off it
//    * every vane gets a dark trailing edge so neighbours cannot merge
//    * barb count and stroke weight adapt to the real pixel budget
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

enum RitmoPlumeTone { milk, blush, coral, ember, violet }

/// One quill: a thin pulled sheet plus the barbs branching off it.
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

  /// Angle the quill is rooted at.
  final double anchor;

  /// How far toward the rim the spine reaches (fraction of radius).
  final double reach;

  /// Signed curvature of the spine.
  final double bow;

  /// Barb sweep-back, in radians past the perpendicular.
  final double sweep;

  /// 1 = near the surface (bright, crisp), 0 = deep (dim).
  final double depth;

  /// Half-width of the sheet at its widest, as a fraction of radius. Small.
  final double shaft;

  /// Stroke weight multiplier.
  final double weight;

  final double phase;
  final double swayRate;

  /// Barbs per side at full detail; scaled down by the pixel budget.
  final int barbs;
}

// tone, anchor, reach, bow, sweep, depth, shaft, weight, prio
const List<List<double>> _kLayout = <List<double>>[
  <double>[0, -1.28, 0.94, 0.55, 0.92, 0.96, 0.070, 1.00, 1],
  <double>[2, 1.05, 0.88, -0.62, 0.86, 0.74, 0.085, 0.94, 2],
  <double>[4, 2.72, 0.80, 0.50, 0.78, 0.34, 0.060, 0.82, 3],
  <double>[3, -2.62, 0.72, -0.70, 0.98, 0.16, 0.055, 0.72, 4],
  <double>[1, 0.10, 0.62, 0.40, 0.70, 0.52, 0.048, 0.62, 5],
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
        swayRate: 0.46 + rng.nextDouble() * 0.52,
        barbs: detailed ? 14 + (weight * 9.0).round() : 9,
      ),
    );
  }

  // Deepest first, so the front vanes land on top of them.
  out.sort((RitmoPlume a, RitmoPlume b) => a.depth.compareTo(b.depth));
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

Offset _bez(Offset a, Offset c, Offset b, double s) {
  final double u = 1.0 - s;
  return Offset(
    u * u * a.dx + 2.0 * u * s * c.dx + s * s * b.dx,
    u * u * a.dy + 2.0 * u * s * c.dy + s * s * b.dy,
  );
}

Offset _bezTan(Offset a, Offset c, Offset b, double s) {
  final double u = 1.0 - s;
  return Offset(
    2.0 * (u * (c.dx - a.dx) + s * (b.dx - c.dx)),
    2.0 * (u * (c.dy - a.dy) + s * (b.dy - c.dy)),
  );
}

/// Feather taper: nothing at the root, fattest past the middle, nothing at the
/// tip. `bias` slides where the fat part sits.
double _hump(double s, double bias, double power) {
  final double x = math.pow(s.clamp(0.0, 1.0), bias).toDouble();
  final double v = math.sin(x * math.pi);
  return math.pow(v < 0.0 ? 0.0 : v, power).toDouble();
}

/// The vanes inside the marble.
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

  // Everything below is sized against the real pixel budget, not a guess.
  final bool tiny = radius < 26.0;
  final double budget = tiny ? 0.42 : (radius < 46.0 ? 0.66 : 1.0);
  final double boost = tiny ? 1.30 : (radius < 46.0 ? 1.12 : 1.0);
  final Color ink =
      Color.lerp(palette.violet, const Color(0xFF17021F), 0.74) ??
          palette.violet;

  for (final RitmoPlume p in plumes) {
    final double depth = p.depth.clamp(0.0, 1.0);
    final double front = 0.38 + 0.62 * depth;
    final double sway = math.sin(t * p.swayRate + p.phase);

    final double rootA = p.anchor + swirl * (0.60 + 0.40 * depth) + sway * 0.16;
    final Offset u = Offset(math.cos(rootA), math.sin(rootA));
    final Offset nrm = Offset(-u.dy, u.dx);
    final Offset par = parallax * (radius * 0.085 * (0.30 + 0.70 * depth));

    final Offset root = center + u * (radius * 0.075) + par;
    final double far = radius * p.reach * (1.0 + 0.05 * pu + 0.02 * sway);
    final Offset tip = center + u * far + par;
    final Offset ctrl = center +
        u * (far * 0.52) +
        nrm * (radius * 0.42 * p.bow * (1.0 + 0.18 * sway)) +
        par;

    final Color tone = _toneColor(p.tone, palette);
    final Color lit =
        Color.lerp(tone, palette.milk, 0.28 + 0.36 * depth) ?? tone;

    // ---- the thin pulled sheet (the rachis) -------------------------------
    final List<Offset> lft = <Offset>[];
    final List<Offset> rgt = <Offset>[];
    for (int i = 0; i <= 12; i++) {
      final double s = i / 12.0;
      final Offset a = _bez(root, ctrl, tip, s);
      final Offset tg = _bezTan(root, ctrl, tip, s);
      final double tl = tg.distance;
      if (tl < 0.0001) continue;
      final Offset nn = Offset(-tg.dy / tl, tg.dx / tl);
      final double half = math.max(
        0.40,
        radius * p.shaft * _hump(s, 0.70, 0.95) * (1.0 + 0.32 * pu),
      );
      lft.add(a + nn * half);
      rgt.add(a - nn * half);
    }

    if (lft.length > 2) {
      final List<Offset> ring = <Offset>[...lft];
      for (int i = rgt.length - 1; i >= 0; i--) {
        ring.add(rgt[i]);
      }

      canvas.drawPath(
        Path()..addPolygon(ring, true),
        Paint()
          ..isAntiAlias = true
          ..shader = ui.Gradient.linear(
            lft.first,
            lft.last,
            <Color>[
              tone.withValues(alpha: 0.0),
              lit.withValues(
                alpha: ((0.22 + 0.16 * e) * front * gain).clamp(0.0, 0.46),
              ),
              tone.withValues(alpha: (0.10 * front * gain).clamp(0.0, 0.22)),
            ],
            const <double>[0.0, 0.46, 1.0],
          ),
      );

      // Dark trailing edge. This single stroke is what makes the eye read
      // separate structures instead of one smear.
      canvas.drawPath(
        Path()..addPolygon(rgt, false),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.55, radius * 0.014)
          ..color =
              ink.withValues(alpha: (0.34 * front * gain).clamp(0.0, 0.50)),
      );

      // Crisp lit edge. Absolutely no blur.
      canvas.drawPath(
        Path()..addPolygon(lft, false),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = math.max(0.75, radius * 0.020) * boost
          ..shader = ui.Gradient.linear(
            lft.first,
            lft.last,
            <Color>[
              palette.milk.withValues(alpha: 0.0),
              palette.milk.withValues(
                alpha: ((0.52 + 0.18 * e) * front * gain + 0.16 * pu)
                    .clamp(0.0, 0.92),
              ),
              (Color.lerp(palette.milk, tone, 0.60) ?? tone).withValues(
                alpha: (0.26 * front * gain).clamp(0.0, 0.48),
              ),
            ],
            const <double>[0.0, 0.44, 1.0],
          ),
      );
    }

    // ---- the barbs: this is what actually reads as a feather --------------
    if (!detailed && depth < 0.50) continue;

    final int n = math.max(5, (p.barbs * budget).round());
    final Path vane = Path();

    for (int i = 0; i < n; i++) {
      final double s = 0.10 + 0.86 * (i / (n - 1));
      final Offset a = _bez(root, ctrl, tip, s);
      final Offset tg = _bezTan(root, ctrl, tip, s);
      final double tl = tg.distance;
      if (tl < 0.0001) continue;
      final Offset d = tg / tl;
      final double base = math.atan2(d.dy, d.dx);

      final double len = radius *
          (0.19 + 0.25 * p.reach) *
          _hump(s, 0.72, 0.85) *
          (1.0 + 0.24 * pu);
      if (len < 0.9) continue;

      // A wave travelling out along the spine, so the vane is alive.
      final double flex =
          math.sin(s * 3.4 - t * 1.25 * p.swayRate + p.phase) * 0.13;
      final double sweep =
          p.sweep * (0.60 + 0.36 * s) * (1.0 - 0.26 * pu) + flex;

      for (int k = -1; k <= 1; k += 2) {
        final double ang = base + k * (math.pi * 0.5 + sweep);
        final Offset dd = Offset(math.cos(ang), math.sin(ang));
        final Offset end = a + dd * len;
        final Offset cc = a + dd * (len * 0.50) + d * (len * 0.30);
        vane
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(cc.dx, cc.dy, end.dx, end.dy);
      }
    }

    final double w = math.max(0.85, radius * 0.026 * p.weight) * boost;

    // One soft pass for body, with a sigma small enough to survive.
    canvas.drawPath(
      vane,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 2.1
        ..color = tone.withValues(
          alpha: ((0.06 + 0.08 * e) * front * gain).clamp(0.0, 0.22),
        )
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, math.max(0.6, radius * 0.018)),
    );

    // The hairline itself: crisp, bright, unblurred.
    canvas.drawPath(
      vane,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w
        ..color = lit.withValues(
          alpha:
              ((0.30 + 0.28 * e + 0.18 * pu) * front * gain).clamp(0.0, 0.80),
        ),
    );
  }

  // ---- the heart the quills converge into ---------------------------------
  final Offset heart = center + parallax * (radius * 0.05);
  final double hr = radius * (0.30 + 0.06 * e + 0.06 * pu);
  canvas.drawCircle(
    heart,
    hr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        heart,
        hr,
        <Color>[
          palette.milk.withValues(alpha: (0.28 + 0.14 * e) * gain),
          palette.core.withValues(alpha: 0.13 * gain),
          palette.core.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.42, 1.0],
      ),
  );

  if (wk > 0.02) {
    canvas.drawCircle(
      center + Offset(-radius * 0.16, -radius * 0.10),
      radius * (0.20 + 0.16 * wk),
      Paint()
        ..isAntiAlias = true
        ..color = palette.milk.withValues(alpha: 0.22 * wk * gain)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.18),
    );
  }
}

/// The ground behind the vanes. Dark on purpose - light structures only read
/// when there is something dark to read them against.
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
  final Offset shift = parallax * (radius * 0.05);
  final Color ink =
      Color.lerp(palette.violet, const Color(0xFF14021C), 0.78) ??
          palette.violet;

  // 1) Dark ground, pushed to the lower right so the upper left stays glassy
  //    - that is how a marble lit from the top left actually looks.
  final Offset deep =
      center + Offset(radius * 0.28, radius * 0.32) + shift;
  canvas.drawCircle(
    deep,
    radius * 1.00,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        deep,
        radius * 1.00,
        <Color>[
          ink.withValues(alpha: 0.44 * gain),
          ink.withValues(alpha: 0.26 * gain),
          ink.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.58, 1.0],
      ),
  );

  // 2) A faint tint on the lit side so the shadow is coloured, not grey.
  final Offset cool = center - Offset(radius * 0.22, radius * 0.26) + shift;
  canvas.drawCircle(
    cool,
    radius * 0.86,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        cool,
        radius * 0.86,
        <Color>[
          palette.violet.withValues(alpha: 0.18 * gain),
          palette.violet.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 1.0],
      ),
  );

  // 3) Caustic pooling: a SMALL bright pool near the rim, not a cloud.
  final double a = -2.34 + 0.14 * math.sin(t * 0.30);
  final Offset pool = center +
      Offset(math.cos(a), -math.sin(a)) * (radius * 0.58) +
      shift * 1.4;
  final double pr =
      radius * (0.30 + 0.04 * math.sin(t * 0.44) + 0.04 * pulse);

  canvas.drawCircle(
    pool,
    pr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        pool,
        pr,
        <Color>[
          palette.milk.withValues(alpha: (0.26 + 0.10 * e) * gain),
          palette.milk.withValues(alpha: 0.08 * gain),
          palette.milk.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.46, 1.0],
      ),
  );

  // 4) Its crisp arc. Zero blur, this is the tell that it is glass.
  final Rect arc = Rect.fromCircle(center: pool, radius: pr * 1.02);
  canvas.drawArc(
    arc,
    -1.02 + 0.10 * math.sin(t * 0.26),
    1.58,
    false,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.65, radius * 0.022)
      ..color = palette.milk
          .withValues(alpha: ((0.30 + 0.12 * e) * gain).clamp(0.0, 0.60)),
  );
}
