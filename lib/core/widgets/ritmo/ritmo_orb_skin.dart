// =============================================================================
//  Ritmo Orb Skin — شیشه، لبه و هایلایت
//  همهٔ نورها از یک [RitmoLightRig] می‌آیند و سفیدها از یک [RitmoWhitePurse]
//  خرج می‌شوند؛ پس دیگر ممکن نیست بالا-چپِ تیله شیری شود.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

const List<Color> _kGlassDark = <Color>[
  Color(0xFFFDFDFF),
  Color(0xFFE4E8F2),
  Color(0xFFAEB6C8),
  Color(0xFF666F86),
];

const List<Color> _kGlassLight = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFFEFAFA),
  Color(0xFFF2EEF4),
  Color(0xFFDBD6E2),
];

/// بدنهٔ شیشهٔ مرواریدی. یک گرادیان، بدون blur.
void ritmoPaintGlassBody(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoLightRig rig,
  required bool isDark,
  required RitmoOrbTier tier,
}) {
  final Rect sphere = Rect.fromCircle(center: center, radius: radius);
  final Paint base = Paint()
    ..shader = RadialGradient(
      center: rig.keyAlign,
      radius: 0.98,
      colors: isDark ? _kGlassDark : _kGlassLight,
      stops: const <double>[0.0, 0.42, 0.78, 1.0],
    ).createShader(sphere);
  canvas.drawCircle(center, radius, base);
  ritmoCountPaint();

  if (tier == RitmoOrbTier.s) return;

  // زمینِ تاریکِ کره — مقابلِ نور، همان‌جا که باید باشد.
  final Color shade = isDark ? const Color(0xFF17021F) : const Color(0xFF6B5F74);
  final Paint ground = Paint()
    ..shader = RadialGradient(
      center: rig.groundAlign,
      radius: 1.0,
      colors: <Color>[
        const Color(0x00000000),
        const Color(0x00000000),
        shade.withValues(alpha: rig.ground),
      ],
      stops: const <double>[0.0, 0.62, 1.0],
    ).createShader(sphere);
  canvas.drawCircle(center, radius, ground);
  ritmoCountPaint();
}

/// هایلایتِ اصلیِ شیشه + نقطهٔ نور. هر دو از کیفِ سفید خرج می‌کنند.
void ritmoPaintSheen(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoLightRig rig,
  required RitmoWhitePurse purse,
  required RitmoOrbTier tier,
  required bool allowSpecular,
}) {
  final Rect sphere = Rect.fromCircle(center: center, radius: radius);
  final double sheen = purse.take(0.30 * rig.key);
  if (sheen > 0.01) {
    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(rig.dir.dx * 1.28, rig.dir.dy * 1.28),
        radius: 0.58,
        colors: <Color>[
          const Color(0xFFFFFFFF).withValues(alpha: sheen),
          const Color(0xFFFFFFFF).withValues(alpha: sheen * 0.28),
          const Color(0x00FFFFFF),
        ],
        stops: const <double>[0.0, 0.42, 1.0],
      ).createShader(sphere);
    canvas.drawCircle(center, radius, paint);
    ritmoCountPaint(white: sheen);
  }

  if (!allowSpecular || tier != RitmoOrbTier.l) return;

  // بازتابِ نقطه‌ایِ منبعِ نور: کوچک، تیز، و فقط وقتی تیله مطمئن است.
  final double dot = purse.take(0.26);
  if (dot <= 0.01) return;
  canvas.save();
  canvas.translate(
    center.dx + rig.dir.dx * radius * 1.06,
    center.dy + rig.dir.dy * radius * 1.06,
  );
  canvas.rotate(rig.angle + math.pi / 2.0);
  final Paint hotSpot = Paint()
    ..color = const Color(0xFFFFFFFF).withValues(alpha: dot)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset.zero,
      width: radius * 0.30,
      height: radius * 0.17,
    ),
    hotSpot,
  );
  canvas.restore();
  ritmoCountPaint(blurs: 1, white: dot);
}

/// لبهٔ تیله. روشناییِ لبه بخشی از امضای حالت است، پس در سیاه‌وسفید هم خوانده
/// می‌شود.
void ritmoPaintRim(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required RitmoOrbPalette palette,
  required RitmoLightRig rig,
  required RitmoWhitePurse purse,
  required RitmoOrbTier tier,
  required bool isDark,
  required double brightness,
}) {
  final Rect sphere = Rect.fromCircle(center: center, radius: radius);
  final double lit = (rig.rim * brightness).clamp(0.0, 1.0);

  if (tier == RitmoOrbTier.l) {
    final double frost = purse.take(0.16 * lit);
    if (frost > 0.01) {
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, radius * 0.075)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: frost)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.07);
      canvas.drawCircle(center, radius * 0.985, paint);
      ritmoCountPaint(blurs: 1, white: frost);
    }
  }

  final double w = math.max(0.7, radius * 0.030);
  final Paint rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..shader = SweepGradient(
      colors: <Color>[
        const Color(0xFFFFFFFF).withValues(alpha: 0.82 * lit),
        const Color(0xFFFFFFFF).withValues(alpha: 0.14 * lit),
        palette.aura.withValues(alpha: 0.30 * lit),
        const Color(0xFFFFFFFF).withValues(alpha: 0.62 * lit),
        const Color(0xFFFFFFFF).withValues(alpha: 0.82 * lit),
      ],
      stops: const <double>[0.0, 0.28, 0.52, 0.84, 1.0],
      // قوسِ روشن دقیقاً سمتِ نور می‌نشیند.
      transform: GradientRotation(rig.angle - math.pi * 0.12),
    ).createShader(sphere);
  canvas.drawCircle(center, radius - w / 2.0, rim);
  ritmoCountPaint();
}
