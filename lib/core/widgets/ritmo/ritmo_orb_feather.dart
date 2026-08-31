// =============================================================================
//  Ritmo Orb Feather v2 — ربان‌های شیشهٔ کشیده (Pulled Glass Ribbons)
//
//  درسی که از تیله‌های شیشهٔ واقعی گرفتیم: داخلِ این تیله‌ها «پَر» نیست؛
//  ورقه‌های نازکِ رنگی است که در حالِ مذاب بودن کشیده و تابیده شدند. چون تاب
//  خورده‌اند، یک لبهٔ تیزِ نوری دارند و یک دنبالهٔ محو — دقیقاً همان چیزی
//  که چشم اسمش را می‌گذارد «پَر».
//
//  پس لبه را تیز می‌کشیم (بدون blur) و فقط بدنه را شیری می‌گذاریم.
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

enum RitmoPlumeTone { milk, blush, coral, ember, violet }

@immutable
class RitmoPlume {
  const RitmoPlume({
    required this.tone,
    required this.baseAngle,
    required this.startRadius,
    required this.endRadius,
    required this.turn,
    required this.width,
    required this.depth,
    required this.crisp,
    required this.phase,
    required this.swayRate,
    required this.barbs,
  });

  final RitmoPlumeTone tone;

  /// زاویهٔ شروعِ ربان.
  final double baseAngle;

  /// شعاع شروع و پایان (نسبت به شعاعِ تیله).
  final double startRadius;
  final double endRadius;

  /// میزان تابیدن در طولِ مسیر (منفی = خلاف جهت).
  final double turn;

  /// پهنای ورقه در عریض‌ترین نقطه.
  final double width;

  /// ۱ = نزدیک به سطح (روشن و تیز)، ۰ = تهِ تیله (محو و تاریک).
  final double depth;

  /// شدتِ لبهٔ تیز.
  final double crisp;

  final double phase;
  final double swayRate;

  /// ریشک‌های نازکی که از لبه بیرون می‌زنند.
  final int barbs;
}

// tone, baseAngle, startR, endR, turn, width, depth, crisp, prio
const List<List<double>> _kLayout = <List<double>>[
  <double>[2, 2.55, 0.06, 0.88, 0.66, 0.30, 0.96, 0.95, 1],
  <double>[0, 5.42, 0.04, 0.80, -0.52, 0.21, 0.78, 1.00, 2],
  <double>[4, 4.05, 0.14, 0.94, 0.84, 0.26, 0.34, 0.55, 3],
  <double>[3, 0.92, 0.10, 0.72, -0.74, 0.15, 0.58, 0.90, 4],
  <double>[1, 3.48, 0.05, 0.62, 0.38, 0.34, 0.18, 0.35, 5],
];

List<RitmoPlume> ritmoBuildPlumes({
  int seed = 11,
  int count = 7,
  bool detailed = true,
}) {
  final math.Random rng = math.Random(seed * 7919 + 13);
  final int keep = count >= 5 ? 5 : 3;
  final List<RitmoPlume> out = <RitmoPlume>[];

  for (final List<double> row in _kLayout) {
    if (row[8] > keep) continue;
    final double weight = row[5];
    out.add(
      RitmoPlume(
        tone: RitmoPlumeTone.values[row[0].round()],
        baseAngle: row[1],
        startRadius: row[2],
        endRadius: row[3],
        turn: row[4],
        width: weight,
        depth: row[6],
        crisp: row[7],
        phase: rng.nextDouble() * math.pi * 2.0,
        swayRate: 0.62 + rng.nextDouble() * 0.76,
        barbs: detailed ? 5 + (weight * 12.0).round() : 0,
      ),
    );
  }

  // عمیق‌ترین‌ها اول رندر شوند تا رویی‌ها رویشان بیفتند.
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

const int _kSteps = 15;

/// ربان‌های تابیدهٔ داخلِ تیله.
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
  final double edgeW = math.max(0.75, radius * 0.040);

  final List<Offset> left = <Offset>[];
  final List<Offset> right = <Offset>[];
  final List<Offset> ring = <Offset>[];

  for (final RitmoPlume p in plumes) {
    left.clear();
    right.clear();

    final double depth = p.depth.clamp(0.0, 1.0);
    final double sway = math.sin(t * 0.52 * p.swayRate + p.phase) * 0.13;
    final double breathe = 1.0 + 0.055 * math.sin(t * 0.37 + p.phase);
    final double par = 0.12 + 0.30 * depth;
    final Offset shift = Offset(parallax.dx, parallax.dy) * radius * 0.10 * par;

    for (int i = 0; i <= _kSteps; i++) {
      final double s = i / _kSteps;
      final double ang = p.baseAngle +
          p.turn * s * math.pi * 1.18 +
          swirl * p.swayRate +
          sway * (0.35 + s);
      final double rad = radius *
          (p.startRadius + (p.endRadius - p.startRadius) * s) *
          breathe *
          (1.0 + 0.04 * math.sin(s * 3.4 + t * 0.6 + p.phase));

      final Offset dir = Offset(math.cos(ang), math.sin(ang));
      final Offset pt = center + dir * rad + shift;
      final Offset nrm = Offset(-dir.dy, dir.dx);

      // پروفیلِ ورقهٔ کشیده: دو سر نازک، وسط پر.
      final double u = math.pow(s, 0.76).toDouble();
      final double prof = math.pow(math.sin(u * math.pi), 1.08).toDouble();
      final double half =
          radius * p.width * prof * (1.0 + 0.34 * pu + 0.10 * e);

      left.add(pt + nrm * half * 0.58);
      right.add(pt - nrm * half * 0.42);
    }

    ring
      ..clear()
      ..addAll(left);
    for (int i = right.length - 1; i >= 0; i--) {
      ring.add(right[i]);
    }

    final Path body = Path()..addPolygon(ring, true);
    final Color tone = _toneColor(p.tone, palette);
    final double bodyA = (0.16 + 0.30 * depth) * gain * (1.0 + 0.22 * pu);

    final Paint fill = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        left.first,
        left.last,
        <Color>[
          tone.withValues(alpha: (bodyA * 0.35).clamp(0.0, 0.60)),
          Color.lerp(tone, palette.milk, 0.45 + 0.35 * depth)!
              .withValues(alpha: bodyA.clamp(0.0, 0.72)),
          tone.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.52, 1.0],
      );
    if (depth < 0.40) {
      fill.maskFilter =
          MaskFilter.blur(BlurStyle.normal, radius * (0.14 - 0.20 * depth));
    }
    canvas.drawPath(body, fill);

    // لبهٔ تیزِ نوری — بدون هیچ blur.
    final double crisp = p.crisp * (0.35 + 0.65 * depth);
    if (crisp > 0.05) {
      canvas.drawPath(
        Path()..addPolygon(left, false),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = edgeW * (0.55 + 0.55 * crisp)
          ..shader = ui.Gradient.linear(
            left.first,
            left.last,
            <Color>[
              palette.milk.withValues(alpha: 0.0),
              palette.milk.withValues(
                alpha: (0.55 * crisp * gain + 0.20 * pu).clamp(0.0, 0.92),
              ),
              Color.lerp(palette.milk, tone, 0.55)!
                  .withValues(alpha: (0.30 * crisp * gain).clamp(0.0, 0.55)),
            ],
            const <double>[0.0, 0.46, 1.0],
          ),
      );
    }

    // ریشک‌ها: خطوط مویی که از لبه رو به عقب جارو می‌شوند.
    if (!detailed || p.barbs <= 0 || depth < 0.30) continue;

    final Paint barb = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.55, radius * 0.016);

    final int n = p.barbs;
    for (int j = 0; j < n; j++) {
      final double s = 0.16 + 0.74 * (j / math.max(1, n - 1));
      final int idx = (s * _kSteps).round().clamp(1, _kSteps);
      final Offset a = left[idx];
      final Offset back = left[idx - 1];
      final Offset tan = a - back;
      final double tl = tan.distance;
      if (tl < 0.001) continue;
      final Offset tu = tan / tl;
      final Offset outward = Offset(-tu.dy, tu.dx);

      final double len = radius * (0.055 + 0.085 * math.sin(s * math.pi)) *
          (1.0 + 0.30 * pu);
      final Offset tip = a + outward * len * 0.92 - tu * len * 0.55;
      final double fade = math.sin(s * math.pi);

      barb.color = Color.lerp(palette.milk, _toneColor(p.tone, palette), 0.30)!
          .withValues(
        alpha: (0.34 * fade * p.crisp * gain * depth + 0.10 * pu)
            .clamp(0.0, 0.62),
      );
      canvas.drawLine(a, tip, barb);
    }
  }

  // چشمک: یک برقِ کوتاه داخل تیله.
  final double wk = wink.clamp(0.0, 1.0);
  if (wk > 0.02) {
    canvas.drawCircle(
      center + Offset(-radius * 0.18, -radius * 0.10),
      radius * (0.30 + 0.22 * wk),
      Paint()
        ..isAntiAlias = true
        ..color = palette.milk.withValues(alpha: 0.16 * wk * gain)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.30),
    );
  }
}

/// زمینهٔ داخلِ تیله: یک عمقِ تاریک + هلالِ کاستیکِ تیز.
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
  final Offset shift = parallax * radius * 0.05;

  // ۱) عمق: پشتِ ربان‌ها تاریک باشد تا نورها بزنند بیرون.
  final Offset deep = center + Offset(radius * 0.26, radius * 0.30) + shift;
  canvas.drawCircle(
    deep,
    radius * 1.05,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        deep,
        radius * 1.05,
        <Color>[
          palette.violet.withValues(alpha: 0.30 * gain),
          palette.violet.withValues(alpha: 0.12 * gain),
          palette.violet.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.55, 1.0],
      ),
  );

  // ۲) هلالِ کاستیک: جمع شدنِ نور در پایینِ چپ.
  final double a = -2.30 + 0.16 * math.sin(t * 0.30);
  final Offset pool = center +
      Offset(math.cos(a), -math.sin(a)) * radius * 0.44 +
      shift * 1.4;
  final double pr = radius * (0.62 + 0.05 * math.sin(t * 0.44) + 0.06 * pulse);

  canvas.drawCircle(
    pool,
    pr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        pool,
        pr,
        <Color>[
          palette.milk.withValues(alpha: (0.30 + 0.10 * e) * gain),
          palette.milk.withValues(alpha: 0.12 * gain),
          palette.milk.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.48, 1.0],
      ),
  );

  // ۳) لبهٔ تیزِ همان هلال — این یکی مطلقاً بدون blur.
  final Rect arc = Rect.fromCircle(center: pool, radius: pr * 0.86);
  canvas.drawArc(
    arc,
    -1.05 + 0.10 * math.sin(t * 0.26),
    1.65,
    false,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.7, radius * 0.030)
      ..color = palette.milk
          .withValues(alpha: ((0.34 + 0.14 * e) * gain).clamp(0.0, 0.66)),
  );
}
