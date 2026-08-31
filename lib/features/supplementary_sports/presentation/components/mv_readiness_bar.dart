import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// 1-line Readiness Indicator Bar (Section 5.1 & 5.10).
/// Refactored to RitmoCard.neumorphic with RitmoCardBadge.
class MvReadinessBar extends StatelessWidget {
  final MvDecision<MvReadinessTier> decision;
  final VoidCallback? onTap;

  const MvReadinessBar({super.key, required this.decision, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final tier = decision.value;
    final Color badgeColor;

    switch (tier) {
      case MvReadinessTier.full:
        badgeColor = colors.success;
        break;
      case MvReadinessTier.light:
        badgeColor = colors.accent;
        break;
      case MvReadinessTier.minimal:
        badgeColor = colors.warning;
        break;
      case MvReadinessTier.rest:
        badgeColor = colors.textSecondary;
        break;
    }

    return RitmoCard.neumorphic(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Badge
          RitmoCardBadge(
            label: tier.titleFa,
            color: badgeColor,
          ),
          const SizedBox(width: 10),

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
            size: 20,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}
