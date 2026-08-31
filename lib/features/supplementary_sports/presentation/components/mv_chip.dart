import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Unified Pill Chip Component (Section 5.10).
class MvChip extends StatelessWidget {
  final String label;
  final Widget? icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const MvChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final textColor = isSelected ? colors.primary : colors.textPrimary;

    return RitmoNeuSurface(
      sunken: isSelected,
      radius: 20,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            icon!,
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
