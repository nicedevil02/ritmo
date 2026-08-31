// =============================================================================
//  Ritmo Orb Feather — بافت «پَر» درون تیله
//
//  در عکس‌های مرجع، داخل تیله رنگِ تخت نیست؛ چند تودهٔ پَرمانند است:
//  یک ساقهٔ نرم + ریشک‌هایی که به عقب خوابیده‌اند، یک لبهٔ ابریشمیِ تیز و
//  بقیهٔ حجم مه‌آلود. این فایل فقط همان بافت را می‌کشد (هیچ ویجتی ندارد).
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

/// جنس رنگیِ هر پَر.
enum RitmoPlumeTone { milk, blush, coral, ember, violet }

/// توصیف یک پَر. همه‌چیز در فضای واحد (شعاع = ۱) تا با هر اندازه‌ای کار کند.
@immutable
class RitmoPlume {
  const RitmoPlume({
    required this.anchor,
    required this.angle,
    required this.length,
    required this.curl,
    required this.spread,
    required this.barbs,
    required this.tone,
    required this.phase,
    required this.swayRate,
    required this.crisp,
    required this.weight,
  });

  /// ریشهٔ ساقه نسبت به مرکز تیله (ضریبی از شعاع).
  final Offset anchor;

  /// جهت ساقه (رادیان).
  final double angle;

  /// طول ساقه (ضریبی از شعاع).
  final double length;

  /// خمِ ساقه؛ علامتش سمت خم شدن را عوض می‌کند.
  final double curl;

  /// نصفِ پهنای ریشک‌ها در پهن‌ترین نقطه (ضریبی از شعاع).
  final double spread;

  /// تعداد ریشک در هر طرف.
  final int barbs;

  final RitmoPlumeTone tone;

  /// فاز انیمیشن تا پرها هم‌زمان تکان نخورند.
  final double phase;

  /// سرعت تابِ خودش.
  final double swayRate;

  /// چقدر لبهٔ ابریشمیِ تیز داشته باشد (۰..۱).
  final double crisp;

  /// وزن دیداری: پررنگی و اندازهٔ نسبی.
  final double weight;
}

// tone, anchorAngle, anchorRadius, dir, length, curl, spread, weight, crisp, prio
const List<List<double>> _kLayout = <List<double>>[
  <double>[4, 1.05, 0.34, -0.42, 1.10, 0.44, 0.30, 0.55, 0.18, 6],
  <double>[3, -0.92, 0.42, 2.30, 1.30, -0.52, 0.33, 0.85, 0.50, 3],
  <double>[2, -0.40, 0.24, 2.02, 1.44, -0.32, 0.38, 1.00, 0.72, 1],
  <double>[2, 0.38, 0.46, -1.88, 1.06, 0.48, 0.26, 0.68, 0.42, 7],
  <double>[1, 2.52, 0.34, -0.72, 1.26, 0.36, 0.40, 0.90, 0.78, 4],
  <double>[0, 2.96, 0.30, -0.28, 1.36, 0.28, 0.44, 1.00, 0.95, 2],
  <double>[0, -2.15, 0.44, 0.58, 1.02, -0.44, 0.31, 0.62, 0.85, 5],
];

/// ترکیب‌بندی پرها را می‌سازد. [count] کمتر = پرهای کم‌اهمیت‌تر حذف می‌شوند.
List<RitmoPlume> ritmoBuildPlumes({
  int seed = 11,
  int count = 7,
  bool detailed = true,
}) {
  final math.Random rng = math.Random(seed * 7919 + 13);
  final int keep = count.clamp(3, 7);
  final List<RitmoPlume> out = <RitmoPlume>[];

  for (int i = 0; i < _kLayout.length; i++) {
    final List<double> row = _kLayout[i];
    if (row[9] > keep) continue;

    final double j = rng.nextDouble() * 2.0 - 1.0;
    final double aAngle = row[1] + j * 0.16;
    final double aRadius = row[2] * (0.92 + rng.nextDouble() * 0.16);

    out.add(
      RitmoPlume(
        anchor: Offset(math.cos(aAngle) * aRadius, math.sin(aAngle) * aRadius),
        angle: row[3] + j * 0.20,
        length: row[4] * (0.94 + rng.nextDouble() * 0.14),
        curl: row[5] * (0.88 + rng.nextDouble() * 0.28),
        spread: row[6] * (0.94 + rng.nextDouble() * 0.14),
        barbs: detailed ? (7 + (row[7] * 4).round()) : 5,
        tone: RitmoPlumeTone.values[row[0].round()],
        phase: rng.nextDouble() * math.pi * 2.0,
        swayRate: 0.26 + rng.nextDouble() * 0.32,
        crisp: row[8],
        weight: row[7],
      ),
    );
  }
  return out;
}

Offset _rot(Offset v, double a) {
  final double c = math.cos(a);
  final double s = math.sin(a);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}

Offset _unit(double a) => Offset(math.cos(a), math.sin(a));

Offset _norm(Offset v) {
  final double d = v.distance;
  if (d <= 0.00001) return const Offset(1.0, 0.0);
  return Offset(v.dx / d, v.dy / d);
}

Color _toneColor(RitmoOrbPalette p, RitmoPlumeTone tone) {
  switch (tone) {
    case RitmoPlumeTone.milk:
      return p.milk;
    case RitmoPlumeTone.blush:
      return Color.lerp(p.milk, p.mid, 0.58)!;
    case RitmoPlumeTone.coral:
      return p.core;
    case RitmoPlumeTone.ember:
      return p.hot;
    case RitmoPlumeTone.violet:
      return p.violet;
  }
}

/// پرها را داخل تیله می‌کشد. فراخوان باید از قبل [Canvas.clipPath] کرده باشد.
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
}) {
  if (radius <= 1.0 || plumes.isEmpty) return;

  final double e = energy.clamp(0.0, 1.0);
  final double gain = (0.80 + 0.30 * e) * intensity.clamp(0.4, 1.4);

  for (int i = 0; i < plumes.length; i++) {
    final RitmoPlume p = plumes[i];
    final Color c = _toneColor(palette, p.tone);

    final double sway = math.sin(t * p.swayRate + p.phase);
    final double sway2 = math.sin(t * p.swayRate * 0.61 + p.phase * 1.7 + 0.9);
    final double breathe = 0.90 + 0.10 * math.sin(t * 0.42 + p.phase);

    final double rot =
        swirl * (0.62 + 0.48 * p.weight) + 0.09 * sway * (0.45 + e);
    final Offset anchor = center +
        _rot(p.anchor * radius, rot) +
        parallax * (radius * (0.05 + 0.06 * p.weight));

    final double dir = p.angle + rot + 0.16 * sway2;
    final double len = radius * p.length * breathe * (0.94 + 0.10 * e);
    final Offset fwd = _unit(dir);
    final Offset side = _unit(dir + math.pi / 2.0);
    final double curl = p.curl * (0.85 + 0.30 * sway2);

    Offset spineAt(double u) {
      final double lat = radius *
          curl *
          (0.52 * math.sin(u * math.pi) +
              0.16 * math.sin(u * math.pi * 2.0 + t * 0.55 + p.phase));
      return anchor + fwd * (len * u) + side * lat;
    }

    double halfWidth(double u, int s) {
      final double uu = u.clamp(0.0, 1.0);
      final double env = math.pow(math.sin(math.pi * uu), 0.70).toDouble();
      final double ripple =
          0.88 + 0.12 * math.sin(uu * 7.0 + t * 0.90 + p.phase);
      final double asym = s > 0 ? 1.0 : 0.62;
      return radius * p.spread * env * ripple * asym;
    }

    // ۱) تودهٔ نرم: پوششِ بیرونیِ ریشک‌ها، خیلی مه‌آلود
    const int n = 12;
    final Path body = Path();
    for (int k = 0; k <= n; k++) {
      final double u = k / n;
      final Offset q = spineAt(u) + side * halfWidth(u, 1);
      if (k == 0) {
        body.moveTo(q.dx, q.dy);
      } else {
        body.lineTo(q.dx, q.dy);
      }
    }
    for (int k = n; k >= 0; k--) {
      final double u = k / n;
      final Offset q = spineAt(u) - side * halfWidth(u, -1);
      body.lineTo(q.dx, q.dy);
    }
    body.close();

    final Offset tip = spineAt(1.0);
    final double bodyA = (0.13 + 0.10 * p.weight) * gain;
    canvas.drawPath(
      body,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.linear(
          anchor,
          tip,
          <Color>[
            c.withValues(alpha: (bodyA * 0.30).clamp(0.0, 0.40)),
            c.withValues(alpha: bodyA.clamp(0.0, 0.40)),
            c.withValues(alpha: 0.0),
          ],
          const <double>[0.0, 0.44, 1.0],
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.6, radius * 0.10),
        ),
    );

    // ۲) ریشک‌ها: قوس‌های کوچکِ خوابیده به عقب → همان حسِ پَر
    final Path soft = Path();
    final Path crisp = Path();
    final int barbs = p.barbs.clamp(3, 14);

    for (int b = 0; b < barbs; b++) {
      final double u = (b + 0.5) / barbs;
      final Offset s0 = spineAt(u);
      final double flick = 0.86 +
          0.14 * math.sin(t * (1.05 + p.swayRate) + p.phase + u * 5.2);

      for (int sgn = -1; sgn <= 1; sgn += 2) {
        final double hw = halfWidth(u, sgn) * 1.06 * flick;
        if (hw < 0.5) continue;

        final double perp = dir + sgn * math.pi / 2.0;
        final double blend = 0.30 + 0.22 * u;
        final Offset bdir = _norm(
          _unit(perp) * (1.0 - blend) + _unit(dir + math.pi) * blend,
        );
        final Offset tipB = s0 + bdir * hw;
        final Offset ctrl =
            s0 + bdir * (hw * 0.55) + fwd * (hw * 0.28 * sgn.toDouble());

        soft.moveTo(s0.dx, s0.dy);
        soft.quadraticBezierTo(ctrl.dx, ctrl.dy, tipB.dx, tipB.dy);

        if (detailed && sgn > 0) {
          crisp.moveTo(s0.dx, s0.dy);
          crisp.quadraticBezierTo(ctrl.dx, ctrl.dy, tipB.dx, tipB.dy);
        }
      }
    }

    final double softA = (0.14 + 0.10 * p.weight) * gain;
    canvas.drawPath(
      soft,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.7, radius * 0.050)
        ..color = c.withValues(alpha: softA.clamp(0.0, 0.42))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.4, radius * 0.045),
        ),
    );

    if (!detailed) continue;

    // ۳) لبهٔ ابریشمیِ تیز: همان کنترستِ عکس‌های مرجع
    canvas.drawPath(
      crisp,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.5, radius * 0.018)
        ..color = Color.lerp(c, palette.milk, 0.35 * p.crisp)!
            .withValues(alpha: (softA * 0.90 * p.crisp).clamp(0.0, 0.34))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.25, radius * 0.012),
        ),
    );

    // ۴) ساقه (rachis): خطِ روشنِ وسطِ پَر
    final Path shaft = Path();
    for (int k = 0; k <= 10; k++) {
      final Offset q = spineAt(k / 10.0);
      if (k == 0) {
        shaft.moveTo(q.dx, q.dy);
      } else {
        shaft.lineTo(q.dx, q.dy);
      }
    }
    canvas.drawPath(
      shaft,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.5, radius * 0.014)
        ..color = Color.lerp(c, palette.milk, 0.55)!
            .withValues(alpha: (0.17 * gain * p.crisp).clamp(0.0, 0.30))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(0.25, radius * 0.010),
        ),
    );
  }
}

/// بالشتکِ شیریِ بزرگ با یک لبهٔ ابریشمیِ تیز — تودهٔ اصلیِ پایین-چپِ عکس‌ها.
void ritmoPaintPillow({
  required Canvas canvas,
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required double t,
  required double energy,
  required double intensity,
  required Offset parallax,
}) {
  if (radius <= 1.0) return;

  final double e = energy.clamp(0.0, 1.0);
  final double gain = intensity.clamp(0.4, 1.4);
  final double wob = math.sin(t * 0.33);
  final double wob2 = math.sin(t * 0.27 + 1.1);

  final Offset c0 = center +
      Offset(-radius * (0.20 + 0.035 * wob), radius * (0.24 - 0.030 * wob2)) +
      parallax * (radius * 0.05);
  final double rr = radius * (0.76 + 0.045 * wob2 + 0.030 * e);

  canvas.drawCircle(
    c0,
    rr,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        c0,
        rr,
        <Color>[
          palette.milk.withValues(alpha: (0.40 * gain).clamp(0.0, 0.55)),
          palette.milk.withValues(alpha: (0.15 * gain).clamp(0.0, 0.30)),
          palette.milk.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.56, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.16),
  );

  // لبهٔ تیزِ سمت راستِ بالشتک
  final double sweepStart = -1.18 + 0.10 * wob;
  canvas.drawArc(
    Rect.fromCircle(center: c0, radius: rr * 0.94),
    sweepStart,
    1.92,
    false,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.6, radius * 0.026)
      ..color = palette.milk.withValues(alpha: (0.30 * gain).clamp(0.0, 0.42))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.022),
  );
}
