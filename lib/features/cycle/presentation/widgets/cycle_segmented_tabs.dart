import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class CycleSegmentedTabs extends StatelessWidget {
  const CycleSegmentedTabs({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.settings,
    required this.activeThemeColor,
  });

  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final Map<String, String> settings;
  final Color activeThemeColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showWorship = ModuleGate.instance.isEnabledFrom(
      settings,
      'module_religion_enabled',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildTabButton(int index, String label, IconData icon) {
      final isActive = activeTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTabChanged(index);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? activeThemeColor.withValues(alpha: 0.12)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.black.withValues(alpha: 0.02)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? activeThemeColor
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : colors.border),
                width: 1.2,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isActive
                        ? activeThemeColor
                        : (isDark ? Colors.white54 : colors.textSecondary),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? activeThemeColor
                          : (isDark ? Colors.white70 : colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTabButton(0, 'داشبورد', CupertinoIcons.today),
        buildTabButton(1, 'روندها', CupertinoIcons.chart_bar_alt_fill),
        buildTabButton(2, 'همبستگی‌ها', CupertinoIcons.sparkles),
        if (showWorship)
          buildTabButton(3, 'روزه قضا', CupertinoIcons.bookmark_fill),
      ],
    );
  }
}
