// C-43, C-44: CycleSegmentedTabs (Apple Dynamic Island & Neumorphic Sliding Control)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/modules/module_gate.dart';

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
    final showWorship = ModuleGate.instance.isEnabledFrom(
      settings,
      'module_religion_enabled',
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = <_TabItem>[
      const _TabItem(title: 'داشبورد', icon: CupertinoIcons.square_grid_2x2_fill),
      const _TabItem(title: 'داده‌ها', icon: CupertinoIcons.chart_bar_alt_fill),
      const _TabItem(title: 'همبستگی‌ها', icon: CupertinoIcons.sparkles),
      if (showWorship)
        const _TabItem(title: 'روزه قضا', icon: CupertinoIcons.bookmark_fill),
    ];

    final tabCount = tabs.length;
    final safeActiveIndex = activeTab.clamp(0, tabCount - 1);

    // پالت نئومورفیک شیار زیرین و پیل شناور (Apple Neumorphic Palette)
    final trackBgColor = isDark ? const Color(0xFF16191E) : const Color(0xFFEFF2F6);
    final pillBgColor = isDark
        ? const Color(0xFF22262F)
        : Color.lerp(Colors.white, activeThemeColor, 0.12)!;
    final pillLightShadow = isDark ? const Color(0xFF2E3440) : Colors.white;
    final pillDarkShadow = isDark
        ? Colors.black.withValues(alpha: 0.60)
        : const Color(0xFFB2BDCB).withValues(alpha: 0.65);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const outerPadding = 4.0;
        final availableWidth = totalWidth - (outerPadding * 2);
        final tabWidth = availableWidth / tabCount;
        const trackHeight = 48.0;
        const pillHeight = trackHeight - (outerPadding * 2);

        return Container(
          height: trackHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: trackBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.90),
              width: 1.2,
            ),
            boxShadow: [
              // شیار فرورفته نئومورفیک (Concave Track Dual Shadow)
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.70)
                    : const Color(0xFFB8C2CE).withValues(alpha: 0.55),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: isDark
                    ? const Color(0xFF222630)
                    : Colors.white.withValues(alpha: 0.95),
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // ۱. پیل شناور متحرک نئومورفیک (Convex Sliding Pill Indicator)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                // در محیط راست‌به‌چپ، موقعیت بر اساس ایندکس محاسبه می‌شود
                right: outerPadding + (safeActiveIndex * tabWidth),
                top: outerPadding,
                width: tabWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: pillBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? activeThemeColor.withValues(alpha: 0.40)
                          : activeThemeColor.withValues(alpha: 0.28),
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
                      // هاله رنگی فاز چرخه زیر پیل فعال (Soft Phase Glow)
                      BoxShadow(
                        color: activeThemeColor.withValues(
                          alpha: isDark ? 0.28 : 0.18,
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
                                fontSize: tabCount > 3 ? 11.5 : 12.5,
                                fontWeight: isActive
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: isActive
                                    ? (isDark
                                        ? Colors.white
                                        : activeThemeColor)
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
                                          size: 15,
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
