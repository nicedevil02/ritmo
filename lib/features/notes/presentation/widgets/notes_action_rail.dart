import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_glass_surface.dart';

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

  const NotesActionRail({
    super.key,
    required this.items,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoGlassSurface(
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.sm,
          vertical: RitmoSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _buildActionItem(context, items[i]),
              if (i < items.length - 1) const SizedBox(width: RitmoSpacing.xs),
            ],
            if (trailing != null) ...[
              const SizedBox(width: RitmoSpacing.xs),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, NotesActionItem item) {
    final colors = context.colors;
    final itemColor = item.color ?? (item.isPrimary ? colors.primary : colors.textSecondary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          RitmoHapticsPolicy.selection();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.md,
            vertical: RitmoSpacing.sm,
          ),
          decoration: item.isPrimary
              ? BoxDecoration(
                  color: itemColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 16, color: itemColor),
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                item.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: item.isPrimary ? FontWeight.bold : FontWeight.normal,
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
