import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';

/// Sheet 1: "امروز نمی‌تونم" (Section 4, 5.1 & S2-T7).
/// Presents respectful non-guilt escape options from smallest effective dose to full rest.
class MvCantTodaySheet extends StatelessWidget {
  final MvSlot slot;
  final VoidCallback onMinimalDose;
  final VoidCallback onMoveToTomorrow;
  final VoidCallback onChangeToStretch;
  final VoidCallback onSkipEntirely;
  final VoidCallback? onCancelAnchorThisWeek;

  const MvCantTodaySheet({
    super.key,
    required this.slot,
    required this.onMinimalDose,
    required this.onMoveToTomorrow,
    required this.onChangeToStretch,
    required this.onSkipEntirely,
    this.onCancelAnchorThisWeek,
  });

  static Future<void> show({
    required BuildContext context,
    required MvSlot slot,
    required VoidCallback onMinimalDose,
    required VoidCallback onMoveToTomorrow,
    required VoidCallback onChangeToStretch,
    required VoidCallback onSkipEntirely,
    VoidCallback? onCancelAnchorThisWeek,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvCantTodaySheet(
        slot: slot,
        onMinimalDose: () {
          Navigator.pop(ctx);
          onMinimalDose();
        },
        onMoveToTomorrow: () {
          Navigator.pop(ctx);
          onMoveToTomorrow();
        },
        onChangeToStretch: () {
          Navigator.pop(ctx);
          onChangeToStretch();
        },
        onSkipEntirely: () {
          Navigator.pop(ctx);
          onSkipEntirely();
        },
        onCancelAnchorThisWeek: onCancelAnchorThisWeek != null
            ? () {
                Navigator.pop(ctx);
                onCancelAnchorThisWeek();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MvSheetScaffold(
      title: l10n?.mv_cant_today_title ?? 'Workout options for today',
      subtitle: l10n?.mv_cant_today_subtitle ?? 'Every small movement counts towards consistency.',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slot.isLocked && onCancelAnchorThisWeek != null) ...[
            _buildOption(
              key: const ValueKey('mv_anchor_cancelled_this_week'),
              context: context,
              icon: Icons.event_busy_rounded,
              title: l10n?.mv_cant_today_option_cancel_anchor_title ?? 'Cancel for this week',
              description: l10n?.mv_cant_today_option_cancel_anchor_desc ??
                  'Cancel only this week session; weekly commitment stays active.',
              onTap: onCancelAnchorThisWeek!,
              isRecommended: true,
            ),
            const SizedBox(height: 8),
          ],
          _buildOption(
            context: context,
            icon: Icons.timer_outlined,
            title: l10n?.mv_cant_today_option_minimal_title ?? 'Minimum effective dose (10 min)',
            description: l10n?.mv_cant_today_option_minimal_desc ?? 'Just a few light exercises to keep blood flow',
            onTap: onMinimalDose,
            isRecommended: !slot.isLocked,
          ),
          const SizedBox(height: 8),
          _buildOption(
            context: context,
            icon: Icons.self_improvement_rounded,
            title: l10n?.mv_cant_today_option_stretch_title ?? 'Change to 5-min stretch',
            description: l10n?.mv_cant_today_option_stretch_desc ?? 'Light sweat-free stretching',
            onTap: onChangeToStretch,
          ),
          const SizedBox(height: 8),
          _buildOption(
            context: context,
            icon: Icons.event_repeat_rounded,
            title: l10n?.mv_cant_today_option_tomorrow_title ?? 'Move to tomorrow',
            description: l10n?.mv_cant_today_option_tomorrow_desc ?? 'Rest today and workout tomorrow',
            onTap: onMoveToTomorrow,
          ),
          const SizedBox(height: 8),
          _buildOption(
            context: context,
            icon: Icons.close_rounded,
            title: l10n?.mv_cant_today_option_rest_title ?? 'Full rest day',
            description: l10n?.mv_cant_today_option_rest_desc ?? 'Skip today without guilt',
            onTap: onSkipEntirely,
            isDestructive: true,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption({
    Key? key,
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isRecommended = false,
    bool isDestructive = false,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final Color iconColor = isDestructive
        ? colors.textSecondary
        : isRecommended
        ? colors.primary
        : colors.textPrimary;

    return RitmoCard.neumorphic(
      key: key,
      onTap: onTap,
      isSelected: isRecommended,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          RitmoNeuSurface(
            width: 40,
            height: 40,
            radius: 12,
            padding: EdgeInsets.zero,
            child: Center(
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: isDestructive
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isRecommended) ...[
                      const SizedBox(width: 8),
                      RitmoCardBadge(
                        label: l10n?.mv_cant_today_recommended ?? 'Recommended',
                        color: colors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}
