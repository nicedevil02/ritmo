import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/insight_engine.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final counts = distribution.muscleSessionCounts;

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n?.mv_body_map_weekly_title ?? 'Muscle Map',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.accessibility_new_rounded,
                color: colors.primary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tactile Muscle Chips Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MvMuscleGroup.all.map((mg) {
              final count = counts[mg.code] ?? 0;
              final isTrained = count > 0;

              return RitmoNeuSurface(
                sunken: isTrained,
                radius: 20,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                onTap: () => onMuscleGroupTap?.call(mg.code),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mg.emoji, style: textTheme.bodySmall),
                    const SizedBox(width: 4),
                    Text(
                      mg.titleFa,
                      style: textTheme.labelSmall?.copyWith(
                        color: isTrained
                            ? colors.primary
                            : colors.textSecondary,
                        fontWeight: isTrained
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    if (isTrained) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count.toString(),
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),

          // Neglected Group Suggestion CTA (N-03)
          if (distribution.suggestedActionFa != null) ...[
            const SizedBox(height: 12),
            RitmoNeuSurface(
              sunken: true,
              radius: 14,
              padding: const EdgeInsets.all(12),
              onTap: onSuggestedActionTap,
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: colors.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      distribution.suggestedActionFa!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: colors.accent,
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
