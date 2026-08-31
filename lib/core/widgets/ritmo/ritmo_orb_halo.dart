// =============================================================================
//  Ritmo Orb Halo — هالهٔ پشتِ تیله
//  در ردهٔ S هیچ هاله‌ای نیست (در ۱۹ پیکسل فقط لکهٔ محو می‌شود)، در M یک
//  گرادیانِ بدون blur، و در L یک پاسِ نرم.
// =============================================================================

import 'package:flutter/widgets.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_orb_types.dart';

class RitmoOrbHaloPainter extends CustomPainter {
  const RitmoOrbHaloPainter({
    required this.palette,
    required this.strength,
    required this.breath,
    required this.tier,
    required this.isDark,
  });

  final RitmoOrbPalette palette;

  /// قدرتِ هاله از امضای حالت (۰ = خاموش)
  final double strength;

  /// ۰..۱ — همان نفسِ تیله؛ هاله با بدنه هم‌فاز است، نه مستقل.
  final double breath;
  final RitmoOrbTier tier;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (tier == RitmoOrbTier.s || strength <= 0.01) return;
    final double dim = size.shortestSide;
    if (dim <= 0.0) return;
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double radius = dim / 2.0 * (0.92 + 0.08 * breath);
    final double alpha =
        (strength * (isDark ? 0.30 : 0.22) * (0.72 + 0.28 * breath))
            .clamp(0.0, 1.0);
    if (alpha <= 0.01) return;

    final Rect area = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          palette.aura.withValues(alpha: alpha),
          palette.aura.withValues(alpha: alpha * 0.42),
          palette.violet.withValues(alpha: alpha * 0.16),
          const Color(0x00000000),
        ],
        stops: const <double>[0.30, 0.52, 0.76, 1.0],
      ).createShader(area);
    if (tier == RitmoOrbTier.l) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.14);
    }
    canvas.drawCircle(center, radius, paint);
    ritmoCountPaint(blurs: tier == RitmoOrbTier.l ? 1 : 0);
  }

  @override
  bool shouldRepaint(RitmoOrbHaloPainter old) =>
      old.palette != palette ||
      old.strength != strength ||
      old.breath != breath ||
      old.tier != tier ||
      old.isDark != isDark;
}
