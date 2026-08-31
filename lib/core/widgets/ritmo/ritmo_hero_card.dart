// Ritmo HeroCard — کارت ویژه هیرو با رنگ مادول و حداکثر یک Glow
// استفاده در اصلی‌ترین بخش صفحات مادول

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class RitmoHeroCard extends StatelessWidget {
  const RitmoHeroCard({
    super.key,
    required this.child,
    this.moduleColor,
    this.padding,
    this.showGlow = false,
  });

  final Widget child;
  final Color? moduleColor;
  final EdgeInsetsGeometry? padding;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final accentColor = moduleColor ?? colors.primary;
    final effectivePadding = padding ?? EdgeInsets.all(context.metrics.spaceXl);

    return Container(
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(context.metrics.radiusHero),
        border: Border.all(
          color: isDark ? colors.border : accentColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
        boxShadow: [
          if (!isDark) ...RitmoElevation.elevatedLight,
          if (showGlow)
            BoxShadow(
              color: accentColor.withValues(alpha: 0.18),
              blurRadius: 48,
              spreadRadius: 2,
            ),
        ],
      ),
      child: child,
    );
  }
}
