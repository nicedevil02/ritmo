// =============================================================================
//  Ritmo Liquid Silk Aurora Vortex Engine (v5)
//
//  تلفیق کانسپت ۱ (ورتکس ابریشمی مایع) + کانسپت ۲ (شفق مخملی ساتین):
//    • امواج ابریشمی، سیال و پیوستهٔ نور مایع (بدون خطوط سیمی یا راه‌راه)
//    • بستر شفق قطبی مخملی (Velvet Multicolor Aurora Bloom)
//    • کانون نوری درخشان در مرکز ورتکس با پالس‌های زندهٔ پاسخ‌دهی
//    • رندرینگ ۱۲۰ فریم بر ثانیه با ریاضیات خالص Canvas
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

enum RitmoSilkWaveType { magentaCoral, cyanTurquoise, orchidViolet, silkPeach }

/// مدل موج ابریشمی سیال درون تیله
@immutable
class RitmoPlume {
  const RitmoPlume({
    required this.type,
    required this.baseAngle,
    required this.speed,
    required this.spiralFactor,
    required this.breadth,
    required this.depth,
    required this.phase,
  });

  final RitmoSilkWaveType type;
  final double baseAngle;
  final double speed;
  final double spiralFactor;
  final double breadth;
  final double depth;
  final double phase;
}

List<RitmoPlume> ritmoBuildPlumes({
  int seed = 11,
  int count = 7,
  bool detailed = true,
}) {
  final math.Random rng = math.Random(seed * 7919 + 17);
  return <RitmoPlume>[
    RitmoPlume(
      type: RitmoSilkWaveType.magentaCoral,
      baseAngle: 0.0,
      speed: 0.48,
      spiralFactor: 0.88,
      breadth: 0.42,
      depth: 0.95,
      phase: rng.nextDouble() * math.pi * 2.0,
    ),
    RitmoPlume(
      type: RitmoSilkWaveType.cyanTurquoise,
      baseAngle: math.pi * 0.65,
      speed: -0.42,
      spiralFactor: 0.92,
      breadth: 0.38,
      depth: 0.85,
      phase: rng.nextDouble() * math.pi * 2.0,
    ),
    RitmoPlume(
      type: RitmoSilkWaveType.orchidViolet,
      baseAngle: math.pi * 1.35,
      speed: 0.52,
      spiralFactor: 0.80,
      breadth: 0.36,
      depth: 0.70,
      phase: rng.nextDouble() * math.pi * 2.0,
    ),
    RitmoPlume(
      type: RitmoSilkWaveType.silkPeach,
      baseAngle: math.pi * 0.25,
      speed: -0.36,
      spiralFactor: 0.75,
      breadth: 0.30,
      depth: 0.55,
      phase: rng.nextDouble() * math.pi * 2.0,
    ),
  ];
}

/// رسم ورتکس ابریشمی مایع نوری
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

  final Offset shift = parallax * (radius * 0.10);

  // ── پالت‌های رنگی مایع ابریشمی (Liquid Silk Color Ramps) ──
  const List<Color> magentaRamp = <Color>[
    Color(0xFFFF007A), // نئون سرخابی
    Color(0xFFFF3366), // مرجانی پرانرژی
    Color(0xFFFF9E00), // کهربایی گرم
    Color(0xFFFF5400), // نارنجی نئونی
  ];

  const List<Color> cyanRamp = <Color>[
    Color(0xFF00F5D4), // فیروزه‌ای نئونی
    Color(0xFF00BBF9), // آبی فیروزه‌ای روشن
    Color(0xFF4361EE), // آبی الکتریک
    Color(0xFF7209B7), // بنفش نئونی
  ];

  const List<Color> violetRamp = <Color>[
    Color(0xFF7209B7), // بنفش رویال
    Color(0xFFB5179E), // ارغوانی
    Color(0xFFF72585), // سرخابی درخشان
    Color(0xFF4CC9F0), // فیروزه‌ای نئونی
  ];

  const List<Color> silkRamp = <Color>[
    Color(0xFFFFFFFF), // سفید ابریشمی
    Color(0xFFFFCCD5), // صورتی شیری
    Color(0xFFFFB3C6), // هلویی ملایم
    Color(0xFF90E0EF), // آبی ملایم
  ];

  // ── رسم امواج مارپیچی ورتکس ابریشمی ──
  for (final RitmoPlume plume in plumes) {
    final double depth = plume.depth;
    final double front = 0.70 + 0.30 * depth;
    final double rot = plume.baseAngle + (t * plume.speed * (0.65 + 0.35 * e)) + swirl * 0.5;

    final List<Color> ramp = switch (plume.type) {
      RitmoSilkWaveType.magentaCoral => magentaRamp,
      RitmoSilkWaveType.cyanTurquoise => cyanRamp,
      RitmoSilkWaveType.orchidViolet => violetRamp,
      RitmoSilkWaveType.silkPeach => silkRamp,
    };

    // تولید مسیر جریان ابریشمی سیال (Smooth Fluid Swirl Path)
    const int steps = 36;
    final List<Offset> innerCurve = <Offset>[];
    final List<Offset> outerCurve = <Offset>[];
    final List<Offset> centerSpine = <Offset>[];

    final double startRadius = radius * (0.12 + 0.05 * math.sin(t * 0.8 + plume.phase));
    final double maxR = radius * (0.84 + 0.04 * pu);

    for (int i = 0; i <= steps; i++) {
      final double s = i / steps.toDouble();
      final double angle = rot + (s * math.pi * 2.2 * plume.spiralFactor);
      
      // شعاع مارپیچ هموار با لغزش موجی
      final double curRadius = startRadius + (maxR - startRadius) * math.pow(s, 0.85);
      final double waveWobble = math.sin(s * math.pi * 3.0 - t * 1.5 + plume.phase) * (radius * 0.035 * e);
      final double rFinal = (curRadius + waveWobble).clamp(1.0, radius * 0.94);

      final Offset pos = center + Offset(math.cos(angle) * rFinal, math.sin(angle) * rFinal) + shift * depth;
      
      // پهنای روبان ابریشمی با انحنای نرم
      final double taper = math.sin(s * math.pi);
      final double halfWidth = math.max(1.5, radius * plume.breadth * math.pow(taper, 0.6) * (1.0 + 0.18 * pu));

      final Offset normal = Offset(-math.sin(angle), math.cos(angle));

      centerSpine.add(pos);
      outerCurve.add(pos + normal * halfWidth);
      innerCurve.add(pos - normal * halfWidth);
    }

    if (outerCurve.length < 3) continue;

    // ایجاد بدنه پیوسته روبان مایع
    final Path silkPath = Path()..moveTo(outerCurve.first.dx, outerCurve.first.dy);
    for (int i = 1; i < outerCurve.length; i++) {
      silkPath.lineTo(outerCurve[i].dx, outerCurve[i].dy);
    }
    for (int i = innerCurve.length - 1; i >= 0; i--) {
      silkPath.lineTo(innerCurve[i].dx, innerCurve[i].dy);
    }
    silkPath.close();

    // ۱. هالهٔ عمیق نوری زیر مایع (Subsurface Volumetric Silk Glow)
    canvas.drawPath(
      silkPath,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.sweep(
          center + shift * depth,
          ramp.map((c) => c.withValues(alpha: (0.45 * front * gain).clamp(0.0, 0.75))).toList(),
          null,
          TileMode.clamp,
          rot,
          rot + math.pi * 2.0,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, radius * 0.10)),
    );

    // ۲. بدنهٔ مایع ابریشمی فوق‌اشباع و غلیظ (Liquid Silk Mass)
    canvas.drawPath(
      silkPath,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.sweep(
          center + shift * depth,
          ramp.map((c) => c.withValues(alpha: ((0.80 + 0.16 * e) * front * gain).clamp(0.0, 0.98))).toList(),
          null,
          TileMode.clamp,
          rot,
          rot + math.pi * 2.0,
        ),
    );

    // ۳. خط براق و درخشان ابریشمی روی ستون فقرات موج (Luminous Silk Crest Line)
    final Path spinePath = Path()..moveTo(centerSpine.first.dx, centerSpine.first.dy);
    for (int i = 1; i < centerSpine.length; i++) {
      spinePath.lineTo(centerSpine[i].dx, centerSpine[i].dy);
    }

    // هاله نرم خط درخشان
    canvas.drawPath(
      spinePath,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.8, radius * 0.038)
        ..shader = ui.Gradient.sweep(
          center + shift * depth,
          ramp.map((c) => c.withValues(alpha: (0.60 * front * gain).clamp(0.0, 0.85))).toList(),
          null,
          TileMode.clamp,
          rot,
          rot + math.pi * 2.0,
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.8, radius * 0.025)),
    );

    // خط تیز سفید هولوگرافیک روی ابریشم
    canvas.drawPath(
      spinePath,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(0.85, radius * 0.016)
        ..color = Colors.white.withValues(
          alpha: ((0.75 + 0.20 * e + 0.20 * pu + 0.25 * wk) * front * gain).clamp(0.0, 0.98),
        ),
    );
  }

  // ── کانون درخشان نور کوانتومی در مرکز ورتکس (Glowing Singularity Core) ──
  final Offset heart = center + shift;
  final double hr = radius * (0.32 + 0.08 * e + 0.08 * pu);

  // هاله بیرونی کانون
  canvas.drawCircle(
    heart,
    hr * 1.4,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        heart,
        hr * 1.4,
        <Color>[
          const Color(0xFFFF007A).withValues(alpha: (0.40 + 0.20 * e) * gain),
          const Color(0xFF00F5D4).withValues(alpha: (0.25 + 0.12 * e) * gain),
          const Color(0xFF7209B7).withValues(alpha: 0.10 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.40, 0.70, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.08),
  );

  // هسته درخشان سفید مرکزی
  canvas.drawCircle(
    heart,
    hr * 0.65,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        heart,
        hr * 0.65,
        <Color>[
          Colors.white.withValues(alpha: (0.85 + 0.15 * e + 0.15 * pu) * gain),
          const Color(0xFFFF9E00).withValues(alpha: (0.50 + 0.20 * e) * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 0.50, 1.0],
      ),
  );
}

/// بستر شفق قطبی مخملی ساتین در پس‌زمینه (Frosted Velvet Aurora Bed)
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

  // چرخش آرام بستر شفق قطبی چندرنگ
  final double a0 = t * 0.25;

  // بستر ابری شفق قطبی با محوشدگی عمیق مخملی (Velvet Satin Aurora Bloom)
  canvas.drawCircle(
    center + shift,
    radius * 0.98,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.sweep(
        center + shift,
        <Color>[
          const Color(0xFFFF007A).withValues(alpha: (0.35 + 0.10 * e) * gain), // سرخابی
          const Color(0xFF00F5D4).withValues(alpha: (0.30 + 0.10 * e) * gain), // فیروزه‌ای
          const Color(0xFF7209B7).withValues(alpha: (0.28 + 0.08 * e) * gain), // بنفش
          const Color(0xFFFFB703).withValues(alpha: (0.32 + 0.10 * e) * gain), // هلویی/طلایی
          const Color(0xFFFF007A).withValues(alpha: (0.35 + 0.10 * e) * gain),
        ],
        const <double>[0.0, 0.25, 0.50, 0.75, 1.0],
        TileMode.repeated,
        a0,
        a0 + math.pi * 2.0,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.24),
  );

  // نور کاستیک فیروزه‌ای-یاسی در قطاع بالا-چپ
  final Offset upperLight = center - Offset(radius * 0.26, radius * 0.28) + shift;
  canvas.drawCircle(
    upperLight,
    radius * 0.75,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        upperLight,
        radius * 0.75,
        <Color>[
          const Color(0xFF00F5D4).withValues(alpha: (0.22 + 0.08 * e) * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.16),
  );

  // سایهٔ نرم کروی در پایین-راست برای تفکیک عمق سه‌بعدی
  final Offset deepShadow = center + Offset(radius * 0.32, radius * 0.36) + shift;
  canvas.drawCircle(
    deepShadow,
    radius * 0.88,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        deepShadow,
        radius * 0.88,
        <Color>[
          const Color(0xFF06020E).withValues(alpha: 0.40 * gain),
          Colors.transparent,
        ],
        const <double>[0.0, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.20),
  );
}
