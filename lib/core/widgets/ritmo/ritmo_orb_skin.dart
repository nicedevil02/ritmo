// =============================================================================
//  Ritmo Orb Skin — لایه‌های نورِ پوسته
//
//  • سایهٔ داخلی و زیرجریانِ بنفش ⇒ حسِ حجم
//  • تاجِ نور روی برآمدگی‌ها ⇒ بدون این، ورم آمدنِ پوسته دیده نمی‌شود
//  • برقِ سطح که با tilt جابه‌جا می‌شود و لبهٔ نورِ چرخان
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
      isDark ? const Color(0xFF2A2F3D) : const Color(0xFF6B5F74);

  canvas.save();
  canvas.clipPath(shell);

  // سایهٔ داخلیِ پایین-راست
  final Offset shadeAt = center + Offset(radius * 0.42, radius * 0.52);
  canvas.drawCircle(
    shadeAt,
    radius * 1.05,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        shadeAt,
        radius * 1.05,
        <Color>[
          shadeColor.withValues(alpha: 0.20 * gain),
          shadeColor.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.20),
  );

  // زیرجریانِ بنفشِ پایین
  final Offset violetAt = center + Offset(radius * 0.16, radius * 0.62);
  canvas.drawCircle(
    violetAt,
    radius * 0.78,
    Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        violetAt,
        radius * 0.78,
        <Color>[
          palette.violet.withValues(alpha: (0.16 + 0.06 * e) * gain),
          palette.violet.withValues(alpha: 0.0),
        ],
        const <double>[0.0, 1.0],
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.24),
  );

  // تاجِ نورِ برآمدگی‌ها
  for (int i = 0; i < bulges.length; i++) {
    final RitmoShellBulge b = bulges[i];
    if (b.amount <= 0.02) continue;

    final Offset dir = Offset(math.cos(b.angle), math.sin(b.angle));
    final Offset crest = RitmoOrbShell.crestOf(
      center: center,
      radius: radius,
      bulge: b,
    );
    final double rr = math.max(1.0, radius * (0.30 + 0.24 * b.width));
    final Offset glowAt = crest - dir * (rr * 0.52);

    canvas.drawCircle(
      glowAt,
      rr,
      Paint()
        ..isAntiAlias = true
        ..shader = ui.Gradient.radial(
          glowAt,
          rr,
          <Color>[
            palette.milk.withValues(alpha: 0.26 * b.amount * gain),
            palette.milk.withValues(alpha: 0.0),
          ],
          const <double>[0.0, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rr * 0.45),
    );

    canvas.drawCircle(
      crest - dir * (radius * 0.055),
      math.max(0.8, radius * 0.10 * (0.60 + b.amount)),
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white.withValues(alpha: 0.22 * b.amount)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06),
    );
  }

  // برقِ سطح
  final Offset sheen =
      center + Offset(-radius * 0.32, -radius * 0.40) - tilt * (radius * 0.13);
  canvas.save();
  canvas.translate(sheen.dx, sheen.dy);
  canvas.rotate(-0.62 + tilt.dx * 0.10);
  canvas.translate(-sheen.dx, -sheen.dy);
  canvas.drawOval(
    Rect.fromCenter(
      center: sheen,
      width: radius * 0.92,
      height: radius * 0.50,
    ),
    Paint()
      ..isAntiAlias = true
      ..color = Colors.white
          .withValues(alpha: ((0.32 + 0.10 * e) * gain).clamp(0.0, 0.55))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.15),
  );
  canvas.restore();

  canvas.drawCircle(
    sheen + Offset(radius * 0.10, -radius * 0.02),
    math.max(0.7, radius * 0.075),
    Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: (0.52 * gain).clamp(0.0, 0.75))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05),
  );

  canvas.restore();

  // لبهٔ نور: بیرون از clip تا تیز بماند
  final double a0 = -math.pi / 2.0 + 0.30 * math.sin(t * 0.22);
  canvas.drawPath(
    shell,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.7, radius * 0.045)
      ..shader = ui.Gradient.sweep(
        center,
        <Color>[
          Colors.white.withValues(alpha: 0.90),
          palette.milk.withValues(alpha: 0.42),
          palette.aura.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.12),
          palette.milk.withValues(alpha: 0.40),
          Colors.white.withValues(alpha: 0.90),
        ],
        const <double>[0.0, 0.18, 0.42, 0.62, 0.84, 1.0],
        TileMode.repeated,
        a0,
        a0 + math.pi * 2.0,
      ),
  );

  if (!detailed) return;

  canvas.drawPath(
    shell,
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, radius * 0.016)
      ..color = Colors.white.withValues(alpha: 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.020),
  );
}
