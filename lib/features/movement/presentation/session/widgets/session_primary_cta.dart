import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// دکمهٔ اقدام اصلی در محدودهٔ دسترسی شست با ارتفاع استاندارد و دسترسی‌پذیری کامل
class SessionPrimaryCta extends StatelessWidget {
  const SessionPrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final sportsColor = context.modules.sports;
    final buttonHeight = context.isLargeTextScale
        ? MovementLayout.kPrimaryButtonHeightLarge
        : MovementLayout.kPrimaryButtonHeight;

    final bg = backgroundColor ?? sportsColor;
    final fg = foregroundColor ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg.withValues(alpha: 0.5),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.field),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: fg, strokeWidth: 2.5),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 22, color: fg),
                      const SizedBox(width: RitmoSpacing.sm),
                    ],
                    Text(
                      label,
                      style: RitmoTextStyles.label(
                        fg,
                      ).copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
