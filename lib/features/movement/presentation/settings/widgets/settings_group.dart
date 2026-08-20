import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// گروه تنظیمات (SettingsGroup)
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      margin: const EdgeInsets.only(bottom: RitmoSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: RitmoSpacing.lg,
                right: RitmoSpacing.lg,
                top: RitmoSpacing.md,
                bottom: RitmoSpacing.xs,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: sportsColor, size: 20),
                    const SizedBox(width: RitmoSpacing.xs),
                  ],
                  Text(
                    title,
                    style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}
