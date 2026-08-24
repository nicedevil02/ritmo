// دکمه‌های استاندارد Ritmo — شامل Primary ، Secondary و IconButton
// جایگزین ElevatedButton / OutlinedButton خام در لایه presentation

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

class RitmoPrimaryButton extends StatelessWidget {
  const RitmoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final canPress = isEnabled && !isLoading && onPressed != null;

    final childWidget = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.onPrimary),
            ),
          ),
          SizedBox(width: m.spaceSm),
        ] else if (icon != null) ...[
          Icon(icon, size: m.iconMd, color: colors.onPrimary),
          SizedBox(width: m.spaceSm),
        ],
        Text(
          label,
          style:
              context.t.labelLarge?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ) ??
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onPrimary,
                fontFamily: 'Vazirmatn',
                height: 1.3,
              ),
        ),
      ],
    );

    final buttonStyle = MaterialButton(
      onPressed: canPress
          ? () {
              RitmoHaptics.tap();
              onPressed?.call();
            }
          : null,
      color: canPress ? colors.primary : colors.disabled,
      disabledColor: colors.disabled,
      height: m.touchTarget,
      minWidth: fullWidth ? double.infinity : 120,
      elevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(m.radiusField),
      ),
      padding: EdgeInsets.symmetric(horizontal: m.spaceLg, vertical: m.spaceMd),
      child: childWidget,
    );

    return Semantics(
      button: true,
      enabled: canPress,
      label: label,
      child: buttonStyle,
    );
  }
}

class RitmoSecondaryButton extends StatelessWidget {
  const RitmoSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;

    final childWidget = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: m.iconSm, color: colors.primary),
          SizedBox(width: m.spaceSm),
        ],
        Text(
          label,
          style:
              context.t.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ) ??
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.primary,
                fontFamily: 'Vazirmatn',
                height: 1.3,
              ),
        ),
      ],
    );

    return OutlinedButton(
      onPressed: onPressed != null
          ? () {
              RitmoHapticsPolicy.selection();
              onPressed?.call();
            }
          : null,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(fullWidth ? double.infinity : 100, m.touchTarget),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(m.radiusField),
        ),
        padding: EdgeInsets.symmetric(horizontal: m.spaceLg),
      ),
      child: childWidget,
    );
  }
}

class RitmoIconButton extends StatelessWidget {
  const RitmoIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 24.0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;

    final iconBtn = IconButton(
      icon: Icon(icon, size: size, color: color ?? colors.textPrimary),
      onPressed: onPressed != null
          ? () {
              RitmoHapticsPolicy.selection();
              onPressed?.call();
            }
          : null,
      tooltip: tooltip,
      constraints: BoxConstraints(
        minWidth: m.touchTarget,
        minHeight: m.touchTarget,
      ),
    );

    return iconBtn;
  }
}
