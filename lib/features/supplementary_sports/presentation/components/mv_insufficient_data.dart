import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// Honest "Insufficient Data" View (Section 5.3, 5.10 & Rule 7).
class MvInsufficientData extends StatelessWidget {
  final String? title;
  final String requirementDescription;

  const MvInsufficientData({
    super.key,
    this.title,
    required this.requirementDescription,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final displayTitle = title ?? (l10n?.mv_insufficient_data_default_title ?? 'Not enough data yet');

    return Container(
      padding: EdgeInsets.all(metrics.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(metrics.spaceSm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceElevated,
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: metrics.iconMd,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(width: metrics.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: metrics.spaceXs),
                Text(
                  requirementDescription,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
