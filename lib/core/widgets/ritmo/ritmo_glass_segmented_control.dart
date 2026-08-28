// =============================================================================
//  ritmo_glass_segmented_control.dart
//  کنترل تب‌های شیشه‌ای مایع استاندارد اپل (Apple Liquid Glass Segmented Control)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// آیتم داده‌ای تب شیشه‌ای
class RitmoTabItem<T> {
  const RitmoTabItem({
    required this.title,
    required this.icon,
    this.value,
    this.badge,
  });

  final String title;
  final IconData icon;
  final T? value;
  final Widget? badge;
}

/// کامپوننت تب‌های شیشه‌ای مایع اپل (Apple Liquid Glass Segmented Control)
///
/// قابلیت‌ها:
/// - شیار ترنسلوسنت محو نوری (Vibrancy Quaternary Fill) بدون پس‌زمینه کدر یا سایه تیره.
/// - پیل لغزنده شناور و نورانی با هایلایت درخشان و هاله رنگی اختصاصی (Soft Ambient Glow).
/// - انیمیشن فیزیکی لغزش نرم و بازخورد لمسی اپل (Haptic Feedback).
/// - محاسبه دقیق جهت راست‌به‌چپ (RTL) و تطبیق خودکار متن در صفحه.
class RitmoGlassSegmentedControl<T> extends StatelessWidget {
  const RitmoGlassSegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTabChanged,
    this.accentColor,
    this.height = 46.0,
    this.padding = const EdgeInsets.all(3.5),
    this.fontSize,
  });

  /// لیست تب‌ها
  final List<RitmoTabItem<T>> items;

  /// ایندکس انتخاب‌شده
  final int selectedIndex;

  /// کالبک تغییر تب
  final ValueChanged<int> onTabChanged;

  /// رنگ اکسنت برای هاله و آیکون فعال (اختیاری)
  final Color? accentColor;

  /// ارتفاع نوار تب‌ها
  final double height;

  /// پدینگ داخلی شیار
  final EdgeInsetsGeometry padding;

  /// سایز فونت متن تب‌ها
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final activeAccent = accentColor ?? colors.primary;
    final tabCount = items.length;

    if (tabCount == 0) return const SizedBox.shrink();

    final safeIndex = selectedIndex.clamp(0, tabCount - 1);

    // پالت متریال شیشه‌ای شیار (Track) و پیل فعال (Active Pill)
    final Color trackBgColor;
    final Border? trackBorder;
    final List<BoxShadow>? trackShadows;

    if (!isGlass) {
      trackBgColor = colors.surfaceSunken;
      trackBorder = Border.all(
        color: isDark ? colors.border : colors.divider,
        width: 1.0,
      );
      trackShadows = null;
    } else {
      trackBgColor = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04);
      trackBorder = Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.70),
        width: 0.8,
      );
      trackShadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
          offset: const Offset(0, 1),
          blurRadius: 3,
        ),
      ];
    }

    final Color pillColor;
    final Border pillBorder;
    final List<BoxShadow> pillShadows;

    if (!isGlass) {
      pillColor = colors.surfaceElevated;
      pillBorder = Border.all(
        color: activeAccent.withValues(alpha: 0.40),
        width: 1.0,
      );
      pillShadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          offset: const Offset(0, 1.5),
          blurRadius: 4,
        ),
      ];
    } else {
      pillColor = isDark
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.95);
      pillBorder = Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.90),
        width: 0.9,
      );
      pillShadows = [
        // سایه عمق‌بخش معلق
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.45)
              : const Color(0xFF94A3B8).withValues(alpha: 0.35),
          offset: const Offset(0, 2),
          blurRadius: 6,
          spreadRadius: 0,
        ),
        // هالهٔ رنگی ملایم اکسنت (Soft Ambient Glow)
        BoxShadow(
          color: activeAccent.withValues(alpha: isDark ? 0.25 : 0.15),
          blurRadius: 8,
          spreadRadius: 0.5,
        ),
      ];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final edgeInsets = padding.resolve(Directionality.of(context));
        final horizontalPadding = edgeInsets.left + edgeInsets.right;
        final verticalPadding = edgeInsets.top + edgeInsets.bottom;
        final availableWidth = totalWidth - horizontalPadding;
        final tabWidth = availableWidth / tabCount;
        final pillHeight = height - verticalPadding;

        final isRtl = Directionality.of(context) == TextDirection.rtl;

        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: trackBgColor,
            borderRadius: BorderRadius.circular(height / 2),
            border: trackBorder,
            boxShadow: trackShadows,
          ),
          child: Stack(
            children: [
              // ۱. پیل لغزنده فعال شیشه‌ای (Illuminated Sliding Pill)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                right: isRtl ? edgeInsets.right + (safeIndex * tabWidth) : null,
                left: isRtl ? null : edgeInsets.left + (safeIndex * tabWidth),
                top: edgeInsets.top,
                width: tabWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(pillHeight / 2),
                    border: pillBorder,
                    boxShadow: pillShadows,
                    gradient: isGlass && isDark
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.16),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                          )
                        : null,
                  ),
                ),
              ),

              // ۲. ردیف آیکون‌ها و عناوین تب‌ها
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: edgeInsets.right),
                  child: Row(
                    children: List.generate(tabCount, (index) {
                      final item = items[index];
                      final isActive = index == safeIndex;

                      final textColor = isActive
                          ? (isDark ? Colors.white : (isGlass ? const Color(0xFF0F172A) : activeAccent))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

                      final iconColor = isActive
                          ? activeAccent
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

                      final effectiveFontSize = fontSize ?? (tabCount > 3 ? 11.0 : 12.5);

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTabChanged(index);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: effectiveFontSize,
                                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                color: textColor,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          item.icon,
                                          key: ValueKey(isActive),
                                          size: 15,
                                          color: iconColor,
                                        ),
                                      ),
                                      const SizedBox(width: 4.5),
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.badge != null) ...[
                                        const SizedBox(width: 4),
                                        item.badge!,
                                      ],
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
