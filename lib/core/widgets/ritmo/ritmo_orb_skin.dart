// =============================================================================
//  Ritmo Orb Skin — لایه‌های نورِ پوسته و اپتیک شیشهٔ کریستالی (v4)
//
//  • سایهٔ داخلی و زیرجریانِ ارغوانی ⇒ حسِ حجم سه‌بعدی
//  • تاجِ نور روی برآمدگی‌ها ⇒ نمایش دینامیک تغییر فرم پوسته
//  • کمانِ هلالی بازتاب نور (Curved Specular Crescent Glare) ⇒ اپتیک شیشهٔ صیقلی
//  • لبهٔ فرنل (Fresnel Caustic Rim) با گرادیان زاویه‌ای چرخان
// =============================================================================

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_shell.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_siri_orb.dart'
    show RitmoOrbPalette;

void ritmoPaintShellSkin({
  required Canvas canvas,
  required Path shell,
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required Offset tilt,
  required double energy,
  required double intensity,
  required double t,
  required List<RitmoShellBulge> bulges,
  required bool isDark,
  required bool detailed,
}) {
  if (radius <= 1.0) return;

  final double e = energy.clamp(0.0, 1.0);
  final double gain = intensity.clamp(0.4, 1.4);
  final Color shadeColor =
      isDark ? const Color(0xFF242834) : const Color(0xFF63566C);

  canvas.save();
  canvas.clipPath(shell);

  // 1. سایهٔ داخلیِ کروی (پایین-راست)
  final Offset shadeAt = center + Offset(radius * 0.40, radius * 0.50);
  canvas.drawCircle(
    shadeAt,
    radius * 1.08,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        shadeAt,
        radius * 1.08,
        <Color>[
          shadeColor.withValues(alpha: 0.22 * gain),
          shadeColor.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.22),
  );

  // 2. زیرجریانِ ارغوانی و فیروزه‌ای پایین (Subsurface Chromatic Scattering)
  final Offset violetAt = center + Offset(radius * 0.14, radius * 0.60);
  canvas.drawCircle(
    violetAt,
    radius * 0.82,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        violetAt,
        radius * 0.82,
        <Color>[
          palette.violet.withValues(alpha: (0.18 + 0.08 * e) * gain),
          palette.aura.withValues(alpha: (0.08 * gain)),
          palette.violet.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.45, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.26),
  );

  // 3. تاجِ نورِ برآمدگی‌های پوسته
  for (int i = 0; i < bulges.length; i++) {
    final RitmoShellBulge b = bulges[i];
    if (b.amount <= 0.02) continue;

    final Offset dir = Offset(math.cos(b.angle), math.sin(b.angle));
    final Offset crest = RitmoOrbShell.crestOf(
      center: center,
      radius: radius,
      bulge: b,
    );
    final double rr = math.max(1.0, radius * (0.32 + 0.26 * b.width));
    final Offset glowAt = crest - dir * (rr * 0.50);

    canvas.drawCircle(
      glowAt,
      rr,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          glowAt,
          rr,
          <Color>[
            palette.milk.withValues(alpha: 0.28 * b.amount * gain),
            palette.milk.withValues(alpha: 0.0),
          ],
          const <double>[0.0, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 0.45),
    );

    canvas.drawCircle(
      crest - dir * (radius * 0.050),
      math.max(0.8, radius * 0.10 * (0.60 + b.amount)),
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: 0.25 * b.amount)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06),
    );
  }

  // 4. کمانِ هلالی بازتاب نور شیشه (Curved Specular Crescent Glare)
  final Offset glareAnchor = center - tilt * (radius * 0.12);
  final double glareRadius = radius * 0.78;
  final Rect glareRect = Rect.fromCircle(center: glareAnchor, radius: glareRadius);

  // Crescent sweep curve in the upper-left quadrant (-140° to -40°)
  const double startAngle = -math.pi * 0.88;
  const double sweepLen = math.pi * 0.62;

  final Path crescentPath = Path()
    ..addArc(glareRect, startAngle, sweepLen);

  // Soft ambient glare glow
  canvas.drawPath(
    crescentPath,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2.0, radius * 0.14)
      ..shader = ui.Gradient.sweep(
        glareAnchor,
        <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: ((0.32 + 0.12 * e) * gain).clamp(0.0, 0.60)),
          Colors.white.withValues(alpha: ((0.55 + 0.18 * e) * gain).clamp(0.0, 0.85)),
          Colors.white.withValues(alpha: ((0.20 + 0.08 * e) * gain).clamp(0.0, 0.45)),
          Colors.white.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.25, 0.50, 0.75, 1.0],
        TileMode.clamp,
        startAngle,
        startAngle + sweepLen,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, radius * 0.08)),
  );

  // Crisp fine specular line
  canvas.drawPath(
    crescentPath,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(0.8, radius * 0.028)
      ..shader = ui.Gradient.sweep(
        glareAnchor,
        <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: ((0.60 + 0.20 * e) * gain).clamp(0.0, 0.95)),
          Colors.white.withValues(alpha: ((0.90 + 0.10 * e) * gain).clamp(0.0, 1.0)),
          Colors.white.withValues(alpha: ((0.40 + 0.10 * e) * gain).clamp(0.0, 0.70)),
          Colors.white.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 0.25, 0.50, 0.75, 1.0],
        TileMode.clamp,
        startAngle,
        startAngle + sweepLen,
      ),
  );

  // Secondary tiny micro-point glare
  final Offset microSpot =
      glareAnchor + Offset(-radius * 0.42, -radius * 0.45);
  canvas.drawCircle(
    microSpot,
    math.max(0.8, radius * 0.065),
    Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: (0.75 * gain).clamp(0.0, 0.95))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, radius * 0.035)),
  );

  canvas.restore();

  // 5. لبهٔ فرنل دور شیشه (Fresnel Edge Caustic Rim): بیرون از clip تا بسیار شفاف و کریستالی بماند
  final double a0 = -math.pi / 2.0 + 0.28 * math.sin(t * 0.20);
  canvas.drawPath(
    shell,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.85, radius * 0.048)
      ..shader = ui.Gradient.sweep(
        center,
        <Color>[
          Colors.white.withValues(alpha: 0.95),
          palette.milk.withValues(alpha: 0.45),
          palette.aura.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.15),
          palette.milk.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.95),
        ],
        const <double>[0.0, 0.18, 0.42, 0.62, 0.84, 1.0],
        TileMode.repeated,
        a0,
        a0 + math.pi * 2.0,
      ),
  );

  if (!detailed) return;

  // Soft atmospheric rim blur layer
  canvas.drawPath(
    shell,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, radius * 0.020)
      ..color = Colors.white.withValues(alpha: 0.32)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.022),
  );
}

