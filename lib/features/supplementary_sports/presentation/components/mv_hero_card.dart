import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'mv_primary_action.dart';

/// Hero Card for Today Tab (Section 5.1 & 5.10).
/// Strictly renders max 1 primary action and 1 secondary action (AC-02).
class MvHeroCard extends StatelessWidget {
  final MvSlot slot;
  final MvReadinessTier readinessTier;
  final Widget? animationWidget;
  final VoidCallback onStart;
  final VoidCallback onCantToday;
  final VoidCallback? onContinue;
  final bool isInProgress;

  const MvHeroCard({
    super.key,
    required this.slot,
    this.readinessTier = MvReadinessTier.full,
    this.animationWidget,
    required this.onStart,
    required this.onCantToday,
    this.onContinue,
    this.isInProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final isRest = slot.isRest;
    final isMinimal = readinessTier == MvReadinessTier.minimal;

    final title = isRest
        ? (l10n?.mv_hero_rest_title ?? 'Rest & Recovery Day')
        : isMinimal
        ? (l10n?.mv_hero_minimal_title ?? '10-Minute Minimum Effective Dose')
        : slot.headlineFa;

    final subtitle = isRest
        ? (l10n?.mv_hero_rest_subtitle ?? 'Light stretching is best today.')
        : isMinimal
        ? (l10n?.mv_hero_minimal_subtitle ?? 'Just 10 minutes today.')
        : '${toPersianDigits(slot.targetMinutes.toString())} ${l10n?.mv_unit_min ?? 'min'} · ${slot.intensityTier.titleFa}';

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(metrics.radiusHero),
        border: Border.all(color: colors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animation / Hero Banner
          if (animationWidget != null && !isRest)
            SizedBox(
              height: 180,
              width: double.infinity,
              child: animationWidget,
            ),

          // Content Area
          Padding(
            padding: EdgeInsets.all(metrics.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Focus Chip / Badge
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.spaceSm,
                        vertical: metrics.spaceXs,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      ),
                      child: Text(
                        isRest ? (l10n?.mv_slot_rest_badge_label ?? 'Rest') : slot.slotType.titleFa,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!isRest)
                      Text(
                        '${toPersianDigits(slot.targetMinutes.toString())} ${l10n?.mv_unit_min ?? 'min'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: metrics.spaceMd),

                // Title
                Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: metrics.spaceXs),

                // Subtitle
                Text(
                  subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: metrics.spaceLg),

                // Primary & Secondary Actions
                if (slot.isCompleted)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(metrics.spaceMd),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(metrics.radiusField),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: colors.success,
                          size: metrics.iconMd,
                        ),
                        SizedBox(width: metrics.spaceSm),
                        Text(
                          l10n?.mv_hero_completed ?? 'Today session completed',
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isRest)
                  MvPrimaryAction(
                    label: l10n?.mv_hero_rest_action ?? '5-min Light Stretch',
                    icon: Icons.self_improvement_rounded,
                    onPressed: onStart,
                  )
                else if (isInProgress && onContinue != null)
                  MvPrimaryAction(
                    label: l10n?.mv_hero_continue ?? 'Continue Session',
                    icon: Icons.play_arrow_rounded,
                    onPressed: onContinue,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: MvPrimaryAction(
                          key: const ValueKey('mv_hero_start_btn'),
                          label: l10n?.mv_hero_start ?? 'Start Session',
                          icon: Icons.play_arrow_rounded,
                          onPressed: onStart,
                        ),
                      ),
                      SizedBox(width: metrics.spaceSm),
                      Expanded(
                        flex: 2,
                        child: MvPrimaryAction(
                          label: l10n?.mv_hero_cant_today ?? 'Can\'t Today',
                          isSecondary: true,
                          onPressed: onCantToday,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
