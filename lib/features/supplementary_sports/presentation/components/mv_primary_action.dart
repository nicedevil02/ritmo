import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Primary / Secondary Action Button with guaranteed >=48dp touch target (Rule R-05).
class MvPrimaryAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isSecondary;
  final bool isDestructive;
  final bool isLoading;

  const MvPrimaryAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isSecondary = false,
    this.isDestructive = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final Color bgColor;
    final Color fgColor;

    if (isDestructive) {
      bgColor = Colors.transparent;
      fgColor = colors.textSecondary;
    } else if (isSecondary) {
      bgColor = colors.surfaceElevated;
      fgColor = colors.primary;
    } else {
      bgColor = colors.primary;
      fgColor = colors.onPrimary;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      elevation: isSecondary || isDestructive ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.radiusField),
        side: isSecondary ? BorderSide(color: colors.border) : BorderSide.none,
      ),
      minimumSize: Size(double.infinity, metrics.touchTarget),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.spaceLg,
        vertical: metrics.spaceSm,
      ),
    );

    return ElevatedButton(
      style: buttonStyle,
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: metrics.iconMd, color: fgColor),
                  SizedBox(width: metrics.spaceSm),
                ],
                Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}
