import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/l10n/app_localizations.dart';

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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final ratio = targetMet > 0
        ? (currentMet / targetMet).clamp(0.0, 1.0)
        : 0.0;

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.mv_metric_ring_active_mins ?? 'Active minutes this week',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${toPersianDigits(currentMet.round().toString())} / ${toPersianDigits(targetMet.round().toString())}',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sunken Neumorphic Progress Bar
          RitmoNeuProgressBar(
            progress: ratio,
            height: 10,
            color: colors.primary,
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n?.mv_metric_ring_active_days(
                      toPersianDigits(activeDays.toString()),
                      toPersianDigits(targetDays.toString()),
                    ) ??
                    '$activeDays of $targetDays active days',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                l10n?.mv_metric_ring_completed_pct(
                      toPersianDigits((ratio * 100).round().toString()),
                    ) ??
                    '${(ratio * 100).round()}% completed',
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
