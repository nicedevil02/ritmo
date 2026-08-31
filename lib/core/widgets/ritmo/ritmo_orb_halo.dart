// =============================================================================
//  هالهٔ محیطی تیله + «پژواک نور»
//
//  دو لایهٔ ساده ولی تعیین‌کننده در حسِ «گران‌قیمت بودن»:
//    ۱) استخر نوری که دقیقاً همراه نفس کم و زیاد می‌شود
//    ۲) حلقه‌ای که موقع ورود به درون جمع می‌شود و موقع رفتن باز می‌شود
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// نقاشِ هاله و پژواکِ نورِ پشت تیله. همیشه پشت خودِ تیله کشیده می‌شود.
class RitmoOrbHaloPainter extends CustomPainter {
  const RitmoOrbHaloPainter({
    required this.aura,
    required this.warm,
    required this.orbSize,
    required this.breath01,
    required this.depth,
    required this.opacity,
    required this.bloom,
    required this.ripple,
    required this.rippleAlpha,
  });

  /// رنگ هاله (معمولاً `palette.aura`)
  final Color aura;

  /// رنگ داغ برای لحظهٔ جشن (معمولاً `palette.hot`)
  final Color warm;

  /// قطر خودِ تیله (نه قطر جعبه)
  final double orbSize;

  /// مقدار نفس در بازهٔ ۰..۱
  final double breath01;

  /// عمق نفس
  final double depth;

  /// شفافیت کلی حضور
  final double opacity;

  /// شکفتن جشن (۰ تا حدود ۱)
  final double bloom;

  /// پیشرفت حلقهٔ پژواک (۰ = چسبیده به تیله، ۱ = کاملاً باز)
  final double ripple;

  /// شفافیت حلقهٔ پژواک
  final double rippleAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01 && rippleAlpha <= 0.01) return;

    final Offset c = Offset(size.width / 2.0, size.height / 2.0);
    final double r0 = orbSize / 2.0;
    if (r0 <= 1.0) return;

    // ۱) استخر نور: با هر دم روشن‌تر و با هر بازدم خاموش‌تر می‌شود
    final double glowA =
        ((0.13 + 0.13 * breath01) * depth * opacity + 0.16 * bloom)
            .clamp(0.0, 0.52);

    if (glowA > 0.012) {
      final double glowR = r0 * (1.34 + 0.16 * breath01 + 0.22 * bloom);
      final Color inner =
          Color.lerp(aura, warm, (0.35 * bloom).clamp(0.0, 0.45))!;

      final Paint glow = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            inner.withValues(alpha: glowA),
            aura.withValues(alpha: glowA * 0.45),
            aura.withValues(alpha: 0.0),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: glowR))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r0 * 0.42);

      canvas.drawCircle(c, glowR, glow);
    }

    // ۲) پژواک نور: حلقه‌ای که موقع رفتن، تیله را به نور حل می‌کند
    if (rippleAlpha > 0.012) {
      final double rr = r0 * (0.94 + 0.95 * ripple);
      final double w = math.max(0.6, r0 * 0.16 * (1.0 - ripple));
      final double a =
          (rippleAlpha * opacity.clamp(0.18, 1.0)).clamp(0.0, 0.50);

      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = aura.withValues(alpha: a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r0 * 0.14);

      canvas.drawCircle(c, rr, ring);
    }
  }

  @override
  bool shouldRepaint(covariant RitmoOrbHaloPainter old) {
    return old.aura != aura ||
        old.warm != warm ||
        old.orbSize != orbSize ||
        old.breath01 != breath01 ||
        old.depth != depth ||
        old.opacity != opacity ||
        old.bloom != bloom ||
        old.ripple != ripple ||
        old.rippleAlpha != rippleAlpha;
  }
}
