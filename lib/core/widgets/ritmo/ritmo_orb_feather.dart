// =============================================================================
//  Ritmo Orb Feather — جریانِ درونِ تیله
//  قبلاً هر تودهٔ رنگ blur خودش را داشت (۸ تا ۱۰ پاس). حالا همهٔ توده‌ها در یک
//  Path جمع می‌شوند و با یک پاس blur و یک shader کشیده می‌شوند: یک جریانِ
//  به‌هم‌پیوسته، نه چند لکهٔ جدا.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

/// یک تودهٔ رنگ در جریانِ درون.
@immutable
class RitmoPlume {
  const RitmoPlume({
    required this.center,
    required this.radius,
    required this.warmth,
    required this.stretch,
    required this.angle,
  });

  final Offset center;
  final double radius;

  /// ۰ = سردِ یاسی، ۱ = داغِ مرجانی
  final double warmth;
  final double stretch;
  final double angle;
}

/// توده‌ها را می‌سازد. قطعی و بدون rng، تا حرکت قابلِ پیش‌بینی و قابلِ تست باشد.
List<RitmoPlume> ritmoBuildPlumes({
  required Offset center,
  required double radius,
  required double phase,
  required int count,
  required double density,
  required Offset drift,
}) {
  if (count <= 0 || radius <= 0.0) return const <RitmoPlume>[];
  final List<RitmoPlume> out = <RitmoPlume>[];
  for (int i = 0; i < count; i++) {
    final double k = i / count;
    final double p = phase * (0.55 + k * 0.42) + i * 1.73;
    final double orbit = radius * (0.16 + 0.26 * ((i + 1) % 3) / 2.0);
    final Offset pos = Offset(
      center.dx + math.cos(p) * orbit + drift.dx,
      center.dy + math.sin(p * 0.82 + 0.6) * orbit * 0.78 + drift.dy,
    );
    out.add(RitmoPlume(
      center: pos,
      radius: radius * (0.34 + 0.22 * density) * (1.0 - k * 0.28),
      warmth: i.isEven ? 1.0 - k * 0.35 : 0.28 + k * 0.30,
      stretch: 1.0 + 0.22 * math.sin(p * 0.7),
      angle: p * 0.35,
    ));
  }
  return out;
}

/// همهٔ توده‌ها با یک پاس. رنگ از محلِ قرار گرفتنِ توده می‌آید، نه از پالتِ جدا.
void ritmoPaintFlow(
  Canvas canvas, {
  required List<RitmoPlume> plumes,
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required RitmoOrbTier tier,
  required double intensity,
  required double density,
  required RitmoLightRig rig,
}) {
  if (plumes.isEmpty || radius <= 0.0) return;
  final Rect sphere = Rect.fromCircle(center: center, radius: radius);
  final double alpha = (0.52 + 0.42 * density) * intensity;

  final Path mass = Path();
  for (final RitmoPlume plume in plumes) {
    mass.addOval(Rect.fromCenter(
      center: plume.center,
      width: plume.radius * 2.0 * plume.stretch,
      height: plume.radius * 2.0 / plume.stretch,
    ));
  }

  final Paint paint = Paint()
    ..shader = RadialGradient(
      center: Alignment(-rig.dir.dx * 0.5, -rig.dir.dy * 0.5),
      radius: 1.05,
      colors: <Color>[
        palette.hot.withValues(alpha: (0.95 * alpha).clamp(0.0, 1.0)),
        palette.core.withValues(alpha: (0.88 * alpha).clamp(0.0, 1.0)),
        palette.mid.withValues(alpha: (0.62 * alpha).clamp(0.0, 1.0)),
        palette.violet.withValues(alpha: (0.34 * alpha).clamp(0.0, 1.0)),
      ],
      stops: const <double>[0.0, 0.38, 0.70, 1.0],
    ).createShader(sphere);
  if (tier != RitmoOrbTier.s) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.20);
  }
  canvas.drawPath(mass, paint);
  ritmoCountPaint(blurs: tier == RitmoOrbTier.s ? 0 : 1);

  if (tier != RitmoOrbTier.l) return;

  // تاجِ تیزِ ابریشمی: فقط روی داغ‌ترین توده، همان‌جا که چشم می‌رود.
  final RitmoPlume lead = plumes.first;
  final Path crest = Path()
    ..addOval(Rect.fromCenter(
      center: lead.center,
      width: lead.radius * 1.34 * lead.stretch,
      height: lead.radius * 1.34 / lead.stretch,
    ));
  final Paint crisp = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: <Color>[
        palette.hot.withValues(alpha: (0.90 * intensity).clamp(0.0, 1.0)),
        palette.core.withValues(alpha: (0.70 * intensity).clamp(0.0, 1.0)),
        const Color(0x00000000),
      ],
      stops: const <double>[0.0, 0.52, 1.0],
      transform: GradientRotation(lead.angle),
    ).createShader(sphere)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.055);
  canvas.drawPath(crest, crisp);
  ritmoCountPaint(blurs: 1);
}

/// بالشتِ شیری. سمتِ سایه می‌نشیند، نه روی هایلایت.
void ritmoPaintPillow(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required RitmoLightRig rig,
  required RitmoWhitePurse purse,
  required double phase,
}) {
  final double milk = purse.take(0.22 * rig.fill);
  if (milk <= 0.01) return;
  final Offset seat = Offset(
    center.dx - rig.dir.dx * radius * 0.42 + math.cos(phase * 0.4) * radius * 0.06,
    center.dy - rig.dir.dy * radius * 0.42 + math.sin(phase * 0.6) * radius * 0.05,
  );
  final Paint paint = Paint()
    ..shader = RadialGradient(
      colors: <Color>[
        palette.milk.withValues(alpha: milk),
        palette.milk.withValues(alpha: milk * 0.42),
        const Color(0x00FFFFFF),
      ],
      stops: const <double>[0.0, 0.52, 1.0],
    ).createShader(Rect.fromCircle(center: seat, radius: radius * 0.72))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.16);
  canvas.drawOval(
    Rect.fromCenter(center: seat, width: radius * 1.24, height: radius * 1.02),
    paint,
  );
  ritmoCountPaint(blurs: 1, white: milk);
}

/// کاستیک: نوری که از درونِ شیشه گذشته و در ربعِ مقابلِ منبع جمع شده.
/// موقعیتش از [RitmoLightRig.causticAlign] می‌آید، پس ساختاراً نمی‌تواند همِ سمتِ
/// هایلایت بنشیند — همان اشتباهی که قبلاً تیله را از شیشه بودن درمی‌آورد.
void ritmoPaintCaustic(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required RitmoLightRig rig,
  required RitmoWhitePurse purse,
}) {
  final double glow = purse.take(0.18 * rig.key);
  if (glow <= 0.01) return;
  final Offset seat = Offset(
    center.dx + rig.causticAlign.x * radius * 0.52,
    center.dy + rig.causticAlign.y * radius * 0.52,
  );
  final Rect area = Rect.fromCircle(center: seat, radius: radius * 0.62);
  final Paint paint = Paint()
    ..shader = RadialGradient(
      colors: <Color>[
        Color.lerp(palette.milk, palette.mid, 0.45)!.withValues(alpha: glow),
        palette.mid.withValues(alpha: glow * 0.55),
        const Color(0x00000000),
      ],
      stops: const <double>[0.0, 0.46, 1.0],
    ).createShader(area);
  canvas.drawOval(area, paint);
  ritmoCountPaint(white: glow * 0.5);
}
