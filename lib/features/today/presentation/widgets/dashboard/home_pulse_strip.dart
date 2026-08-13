import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_pressable.dart';

/// یک سنجهٔ کوتاه در کارت «نبض امروز».
@immutable
class HomePulseMetric {
  const HomePulseMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

/// کارت «نبض امروز»: حلقهٔ پیشرفت مسیر روز در کنار سنجه‌های کلیدی،
/// تا کاربر بدون رفتن به صفحهٔ دیگر بداند امروز کجاست.
class HomePulseStrip extends StatelessWidget {
  const HomePulseStrip({
    super.key,
    required this.progress,
    required this.doneCount,
    required this.totalCount,
    required this.metrics,
    this.title = 'نبض امروز',
    this.caption,
  });

  /// نسبت پیشرفت (۰ تا ۱).
  final double progress;
  final int doneCount;
  final int totalCount;
  final List<HomePulseMetric> metrics;
  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    final ringColors = colors.brandGradient.length >= 2
        ? colors.brandGradient
        : <Color>[colors.primary, colors.primary];

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RitmoRadius.cardLarge),
        color: isDark
            ? colors.card.withValues(alpha: 0.50)
            : Colors.white.withValues(alpha: 0.74),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        boxShadow: isDark ? RitmoElevation.none : RitmoElevation.cardLight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ring(context, colors, clamped, ringColors),
          const SizedBox(width: RitmoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                    if (caption != null && caption!.isNotEmpty)
                      Text(
                        toPersianDigits(caption!),
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textTertiary,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.sm),
                for (int i = 0; i < metrics.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  _metricRow(context, colors, metrics[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(
    BuildContext context,
    RitmoColors colors,
    double value,
    List<Color> ringColors,
  ) {
    return SizedBox(
      height: 82,
      width: 82,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: RitmoMotion.reduceMotion(context)
            ? Duration.zero
            : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => CustomPaint(
          painter: _PulseRingPainter(
            progress: animated,
            trackColor: colors.surfaceSunken.withValues(alpha: 0.9),
            ringColors: ringColors,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  toPersianDigits('${(animated * 100).round()}٪'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
                Text(
                  toPersianDigits('$doneCount از $totalCount'),
                  style: TextStyle(
                    fontSize: 9,
                    color: colors.textSecondary,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricRow(
    BuildContext context,
    RitmoColors colors,
    HomePulseMetric metric,
  ) {
    final row = Row(
      children: [
        Container(
          height: 22,
          width: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: metric.color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(metric.icon, size: 12, color: metric.color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: colors.textSecondary,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
        Text(
          toPersianDigits(metric.value),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            fontFamily: 'Vazirmatn',
          ),
        ),
        if (metric.onTap != null) ...[
          const SizedBox(width: 2),
          Icon(
            CupertinoIcons.chevron_left,
            size: 11,
            color: colors.textTertiary,
          ),
        ],
      ],
    );

    if (metric.onTap == null) return row;

    return RitmoPressable(
      onTap: metric.onTap,
      semanticLabel: '${metric.label}: ${metric.value}',
      scaleDown: 0.99,
      child: row,
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  const _PulseRingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColors,
  });

  final double progress;
  final Color trackColor;
  final List<Color> ringColors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: ringColors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0).toDouble(),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.ringColors != ringColors;
  }
}
