// C-43, C-44: CycleSegmentedTabs (Apple Dynamic Island & Neumorphic Sliding Control)
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

    final tabs = <_TabItem>[
      const _TabItem(title: 'داشبورد', icon: CupertinoIcons.today),
      const _TabItem(title: 'روندها', icon: CupertinoIcons.chart_bar_alt_fill),
      const _TabItem(title: 'همبستگی‌ها', icon: CupertinoIcons.sparkles),
      if (showWorship)
        const _TabItem(title: 'روزه قضا', icon: CupertinoIcons.bookmark_fill),
    ];

    final tabCount = tabs.length;
    final safeActiveIndex = activeTab.clamp(0, tabCount - 1);

    // پالت نئومورفیک شیار زیرین و پیل شناور
    final trackBgColor = isDark ? const Color(0xFF16191E) : const Color(0xFFE7EBF0);
    final pillBgColor = isDark ? const Color(0xFF22262F) : Colors.white;
    final pillLightShadow = isDark ? const Color(0xFF2E3440) : Colors.white;
    final pillDarkShadow = isDark
        ? Colors.black.withValues(alpha: 0.60)
        : const Color(0xFFB0BAC7).withValues(alpha: 0.65);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const outerPadding = 4.0;
        final availableWidth = totalWidth - (outerPadding * 2);
        final tabWidth = availableWidth / tabCount;
        const trackHeight = 44.0;
        const pillHeight = trackHeight - (outerPadding * 2);

        return Container(
          height: trackHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: trackBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.80),
              width: 1.0,
            ),
            boxShadow: [
              // شیار فرورفته نئومورفیک (Concave Track Shadow)
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.70)
                    : const Color(0xFFB8C2CE).withValues(alpha: 0.70),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: isDark
                    ? const Color(0xFF222630)
                    : Colors.white,
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // ۱. پیل شناور متحرک نئومورفیک (Convex Sliding Pill Indicator)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                // در محیط راست‌به‌چپ، موقعیت بر اساس ایندکس محاسبه می‌شود
                right: outerPadding + (safeActiveIndex * tabWidth),
                top: outerPadding,
                width: tabWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: pillBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? activeThemeColor.withValues(alpha: 0.35)
                          : activeThemeColor.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                    boxShadow: [
                      // هایلایت بالا-چپ
                      BoxShadow(
                        color: pillLightShadow,
                        offset: const Offset(-1.5, -1.5),
                        blurRadius: 3,
                      ),
                      // سایه نرم پایین-راست
                      BoxShadow(
                        color: pillDarkShadow,
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                      // هاله رنگی فاز چرخه زیر پیل فعال
                      BoxShadow(
                        color: activeThemeColor.withValues(
                          alpha: isDark ? 0.25 : 0.15,
                        ),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ),

              // ۲. ردیف عناوین و آیکون‌های تب‌ها با تعامل لمسی و انیمیشن رنگ
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: outerPadding),
                  child: Row(
                    children: List.generate(tabCount, (index) {
                      final tab = tabs[index];
                      final isActive = index == safeActiveIndex;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTabChanged(index);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(
                                fontSize: 12.2,
                                fontWeight: isActive
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: isActive
                                    ? (isDark
                                        ? Colors.white
                                        : Color.lerp(
                                            activeThemeColor,
                                            Colors.black,
                                            0.35,
                                          ))
                                    : (isDark
                                        ? const Color(0xFF888F9C)
                                        : const Color(0xFF6B7280)),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        child: Icon(
                                          tab.icon,
                                          key: ValueKey(isActive),
                                          size: 14,
                                          color: isActive
                                              ? activeThemeColor
                                              : (isDark
                                                  ? const Color(0xFF888F9C)
                                                  : const Color(0xFF6B7280)),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tab.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabItem {
  const _TabItem({required this.title, required this.icon});
  final String title;
  final IconData icon;
}
