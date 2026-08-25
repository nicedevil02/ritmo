import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Circular / Linear Metric Ring for Weekly Active MET-min (Section 5.1 & 5.10).
class MvMetricRing extends StatelessWidget {
  final double currentMet;
  final double targetMet;
  final int activeDays;
  final int targetDays;

  const MvMetricRing({
    super.key,
    required this.currentMet,
    required this.targetMet,
    required this.activeDays,
    required this.targetDays,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final ratio = targetMet > 0
        ? (currentMet / targetMet).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'دقیقهٔ فعال این هفته',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${currentMet.round()} / ${targetMet.round()}',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: colors.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          SizedBox(height: metrics.spaceSm),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$activeDays از $targetDays روز فعال',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '${(ratio * 100).round()}٪ تکمیل شده',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
