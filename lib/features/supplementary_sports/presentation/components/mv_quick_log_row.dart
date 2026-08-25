import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Quick Log 2-Tap Activity Row on Today Tab (Section 5.1, N-01, AC-03).
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ثبت سریع فعالیت',
              style: textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: onCustomLog,
              child: Text(
                'ثبت سایر...',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: metrics.spaceSm),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickItem(
                context: context,
                emoji: '🚶',
                title: 'پیاده‌روی ۲۰ دقیقه',
                onTap: onQuickWalk,
              ),
              SizedBox(width: metrics.spaceSm),
              _buildQuickItem(
                context: context,
                emoji: '🧘',
                title: '۱۰ دقیقه نرمش سبک',
                onTap: onQuickStretch,
              ),
              if (lastActivityTitle != null && onRepeatLast != null) ...[
                SizedBox(width: metrics.spaceSm),
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        child: Container(
          constraints: BoxConstraints(minHeight: metrics.touchTarget),
          padding: EdgeInsets.symmetric(
            horizontal: metrics.spaceMd,
            vertical: metrics.spaceSm,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            border: Border.all(color: colors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: textTheme.bodyLarge),
              SizedBox(width: metrics.spaceSm),
              Text(
                title,
                style: textTheme.labelMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
