import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// 1-line Readiness Indicator Bar (Section 5.1 & 5.10).
class MvReadinessBar extends StatelessWidget {
  final MvDecision<MvReadinessTier> decision;
  final VoidCallback? onTap;

  const MvReadinessBar({
    super.key,
    required this.decision,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final tier = decision.value;
    final Color badgeColor;
    final String emoji;

    switch (tier) {
      case MvReadinessTier.full:
        badgeColor = colors.success;
        emoji = '⚡';
        break;
      case MvReadinessTier.light:
        badgeColor = colors.accent;
        emoji = '🌤️';
        break;
      case MvReadinessTier.minimal:
        badgeColor = colors.warning;
        emoji = '🌿';
        break;
      case MvReadinessTier.rest:
        badgeColor = colors.textSecondary;
        emoji = '🧘';
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.spaceMd,
            vertical: metrics.spaceSm,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(metrics.radiusCard),
            border: Border.all(color: colors.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              // Badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.spaceSm,
                  vertical: metrics.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 12)),
                    SizedBox(width: metrics.spaceXs),
                    Text(
                      tier.titleFa,
                      style: textTheme.labelSmall?.copyWith(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: metrics.spaceSm),

              // Reason
              Expanded(
                child: Text(
                  decision.reasonFa,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              Icon(
                Icons.chevron_left_rounded,
                size: metrics.iconSm,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
