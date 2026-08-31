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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final displayTitle =
        title ?? (l10n?.mv_insufficient_data_default_title ?? 'Not enough data yet');

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          RitmoNeuSurface(
            radius: 20,
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.analytics_outlined,
              size: 20,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
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
