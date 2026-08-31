import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// Quick Log 2-Tap Activity Row on Today Tab (Section 5.1, N-01, AC-03).
/// Refactored to RitmoNeuSurface with central theme colors.
class MvQuickLogRow extends StatelessWidget {
  final VoidCallback onQuickWalk;
  final VoidCallback onQuickStretch;
  final VoidCallback? onRepeatLast;
  final String? lastActivityTitle;
  final VoidCallback onCustomLog;

  const MvQuickLogRow({
    super.key,
    required this.onQuickWalk,
    required this.onQuickStretch,
    this.onRepeatLast,
    this.lastActivityTitle,
    required this.onCustomLog,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n?.mv_quick_log_title ?? 'Quick Log',
              style: textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              key: const ValueKey('mv_quick_log_custom'),
              onTap: onCustomLog,
              child: Text(
                l10n?.mv_quick_log_custom_action ?? 'Custom...',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickItem(
                context: context,
                emoji: '🚶',
                title: l10n?.mv_quick_log_walk_20 ?? '20 min Walk',
                onTap: onQuickWalk,
              ),
              const SizedBox(width: 8),
              _buildQuickItem(
                context: context,
                emoji: '🧘',
                title: l10n?.mv_quick_log_stretch_10 ?? '10 min Light Stretch',
                onTap: onQuickStretch,
              ),
              if (lastActivityTitle != null && onRepeatLast != null) ...[
                const SizedBox(width: 8),
                _buildQuickItem(
                  context: context,
                  emoji: '🔁',
                  title: lastActivityTitle!,
                  onTap: onRepeatLast!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickItem({
    required BuildContext context,
    required String emoji,
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return RitmoNeuSurface(
      radius: 20,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: textTheme.bodyLarge),
          const SizedBox(width: 6),
          Text(
            title,
            style: textTheme.labelMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
