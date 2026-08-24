import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class NotesActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool isPrimary;

  const NotesActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.isPrimary = false,
  });
}

class NotesActionRail extends StatelessWidget {
  final List<NotesActionItem> items;
  final Widget? trailing;

  const NotesActionRail({super.key, required this.items, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: isDark ? 0.92 : 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _buildActionItem(context, items[i], colors, isDark),
              if (i < items.length - 1) const SizedBox(width: 4),
            ],
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    NotesActionItem item,
    RitmoColors colors,
    bool isDark,
  ) {
    final itemColor =
        item.color ?? (item.isPrimary ? colors.primary : colors.textSecondary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          RitmoHapticsPolicy.selection();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: item.isPrimary
              ? BoxDecoration(
                  color: itemColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: itemColor.withValues(alpha: 0.35),
                    width: 1,
                  ),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 15, color: itemColor),
              const SizedBox(width: 5),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: item.isPrimary
                      ? FontWeight.bold
                      : FontWeight.w500,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
