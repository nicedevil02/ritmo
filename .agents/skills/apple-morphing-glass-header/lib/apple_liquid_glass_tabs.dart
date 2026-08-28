import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Item descriptor for [AppleLiquidGlassTabs].
class AppleTabItem<T> {
  final String title;
  final IconData? icon;
  final T value;
  final Widget? badge;

  const AppleTabItem({
    required this.title,
    this.icon,
    required this.value,
    this.badge,
  });
}

/// {@template apple_liquid_glass_tabs}
/// An Apple-style segmented control designed to sit seamlessly inside [AppleMorphingGlassHeader].
///
/// Features:
/// - Smooth sliding pill indicator with spring curve
/// - Subtle frosted glass container styling
/// - Haptic selection feedback on tap
/// {@endtemplate}
class AppleLiquidGlassTabs<T> extends StatelessWidget {
  final List<AppleTabItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onTabChanged;
  final Color? accentColor;
  final double height;

  const AppleLiquidGlassTabs({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onTabChanged,
    this.accentColor,
    this.height = 44.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = accentColor ?? theme.colorScheme.primary;

    final selectedIndex = items.indexWhere((it) => it.value == selectedValue);
    final effectiveIndex = selectedIndex >= 0 ? selectedIndex : 0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / items.length;

          return Stack(
            children: [
              // Sliding Active Pill Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: effectiveIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? primary.withValues(alpha: 0.28)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? primary.withValues(alpha: 0.50)
                          : Colors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Labels & Touch Targets
              Row(
                children: items.map((item) {
                  final isSelected = item.value == selectedValue;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTabChanged(item.value);
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item.icon != null) ...[
                              Icon(
                                item.icon,
                                size: 16,
                                color: isSelected
                                    ? (isDark ? Colors.white : primary)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13.0,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                            if (item.badge != null) ...[
                              const SizedBox(width: 5),
                              item.badge!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
