import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/insight_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Interactive Muscle Body Map & Balance Widget (Section 5.3 & N-03).
class MvBodyMap extends StatelessWidget {
  final MvBodyMapDistribution distribution;
  final ValueChanged<String>? onMuscleGroupTap;
  final VoidCallback? onSuggestedActionTap;

  const MvBodyMap({
    super.key,
    required this.distribution,
    this.onMuscleGroupTap,
    this.onSuggestedActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final counts = distribution.muscleSessionCounts;

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
            children: [
              Text(
                'نقشهٔ عضلانی این هفته',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(Icons.accessibility_new_rounded, color: colors.primary, size: metrics.iconMd),
            ],
          ),
          SizedBox(height: metrics.spaceMd),

          // Muscle Chips Grid
          Wrap(
            spacing: metrics.spaceSm,
            runSpacing: metrics.spaceSm,
            children: MvMuscleGroup.all.map((mg) {
              final count = counts[mg.code] ?? 0;
              final isTrained = count > 0;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onMuscleGroupTap?.call(mg.code),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.spaceMd,
                      vertical: metrics.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: isTrained
                          ? colors.primary.withValues(alpha: 0.12)
                          : colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      border: Border.all(
                        color: isTrained ? colors.primary : colors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mg.emoji, style: const TextStyle(fontSize: 13)),
                        SizedBox(width: metrics.spaceXs),
                        Text(
                          mg.titleFa,
                          style: textTheme.labelSmall?.copyWith(
                            color: isTrained ? colors.primary : colors.textSecondary,
                            fontWeight: isTrained ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                        if (isTrained) ...[
                          SizedBox(width: metrics.spaceXs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(RitmoRadius.pill),
                            ),
                            child: Text(
                              count.toString(),
                              style: textTheme.labelSmall?.copyWith(
                                color: colors.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Neglected Group Suggestion CTA (N-03)
          if (distribution.suggestedActionFa != null) ...[
            SizedBox(height: metrics.spaceMd),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSuggestedActionTap,
                borderRadius: BorderRadius.circular(metrics.radiusField),
                child: Container(
                  padding: EdgeInsets.all(metrics.spaceMd),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(metrics.radiusField),
                    border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: colors.accent, size: metrics.iconMd),
                      SizedBox(width: metrics.spaceSm),
                      Expanded(
                        child: Text(
                          distribution.suggestedActionFa!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded, color: colors.accent, size: metrics.iconSm),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
