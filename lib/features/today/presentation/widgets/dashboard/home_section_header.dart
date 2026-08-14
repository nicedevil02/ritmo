import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

/// سرتیتر یکدست بخش‌های صفحهٔ خانه.
///
/// همهٔ بخش‌ها (مسیر امروز، کارها، سیستم‌ها، دستیار) با همین ویجت تیتر می‌خورند
/// تا سلسله‌مراتب بصری صفحه یکدست بماند و تیترهای دست‌ساز تکرار نشوند.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accent;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = accent ?? colors.primary;
    final hasAction = actionLabel != null && onAction != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              height: 30,
              width: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                border: Border.all(color: tone.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, size: 16, color: tone),
            ),
            const SizedBox(width: RitmoSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                      ),
                  ),
                ],
              ],
            ),
          ),
          if (hasAction)
            Semantics(
              button: true,
              label: actionLabel,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    RitmoHaptics.tap();
                    onAction!();
                  },
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.sm,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          actionLabel!,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: tone,
                            ),
                        ),
                        const SizedBox(width: 2),
                        Icon(CupertinoIcons.chevron_left, size: 12, color: tone),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
