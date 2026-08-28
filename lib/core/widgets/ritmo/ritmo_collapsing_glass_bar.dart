// =============================================================================
//  ritmo_collapsing_glass_bar.dart
//  هدر داینامیک لارج تایتل شیشه‌ای اپل با ترنزیشن فیزیکی کپسولی یکپارچه
//  (Apple Dynamic Large Title Morphing Glass Header)
// =============================================================================

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// دکمه اکشن شیشه‌ای با استاندارد Vibrancy اپل
class RitmoVibrancyActionButton extends StatelessWidget {
  const RitmoVibrancyActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.tooltip,
    this.isAiButton = false,
    this.accentColor,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? tooltip;
  final bool isAiButton;
  final Color? accentColor;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final effectiveAccent = accentColor ?? colors.primary;

    final bgColor = isAiButton
        ? (isDark
            ? effectiveAccent.withValues(alpha: 0.22)
            : effectiveAccent.withValues(alpha: 0.14))
        : (isGlass
            ? (isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.05))
            : colors.surfaceSunken);

    final borderColor = isAiButton
        ? effectiveAccent.withValues(alpha: isDark ? 0.45 : 0.35)
        : (isGlass
            ? (isDark
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.80))
            : (isDark ? colors.border : colors.divider));

    final child = Semantics(
      button: true,
      label: tooltip ?? '',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: borderColor, width: 0.9),
              boxShadow: isAiButton
                  ? [
                      BoxShadow(
                        color: effectiveAccent.withValues(alpha: isDark ? 0.30 : 0.18),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                        offset: const Offset(0, 1.5),
                        blurRadius: 4,
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: isAiButton ? 17 : 18,
                  color: iconColor ?? (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
                if (badge != null)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: badge!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: child);
    }
    return child;
  }
}

/// هدر داینامیک لارج تایتل شیشه‌ای اپل با ترنزیشن فیزیکی کپسولی یکپارچه
/// (Apple Dynamic Large Title Morphing Glass Header)
///
/// قابلیت‌ها:
/// ۱. در بالای صفحه (Scroll = 0): کاملاً شفاف و باز، تیتر بزرگ ۲۷pt در پایین و تب‌ها چسبیده زیر آن.
/// ۲. فاز اول اسکرول: تشکیل یک کپسول شیشه‌ای واحد که هم دکمه‌ها/تیتر و هم **نوار تب‌ها** درون آن قرار دارند.
/// ۳. اسکرول بیشتر به پایین: همان کپسول شیشه‌ای به صورت نرم ارتفاعش کم شده و تب‌ها داخلش جمع می‌شوند (تک‌خطی).
/// ۴. اسکرول معکوس به بالا در هر جای صفحه: همان کپسول دوباره باز شده و نوار تب‌ها داخل انتهای آن ظاهر می‌شود.
class RitmoAppleMorphingGlassHeader extends StatelessWidget {
  const RitmoAppleMorphingGlassHeader({
    super.key,
    required this.title,
    required this.scrollOffset,
    this.subtitle,
    this.tabs,
    this.isTabsExpanded = true,
    this.actions,
    this.leading,
    this.onBack,
    this.collapseDistance = 55.0,
    this.titleColor,
    this.accentColor,
    this.statusBadge,
  });

  final String title;
  final double scrollOffset;
  final String? subtitle;
  final Widget? tabs;
  final bool isTabsExpanded;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBack;
  final double collapseDistance;
  final Color? titleColor;
  final Color? accentColor;
  final Widget? statusBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final topInset = MediaQuery.paddingOf(context).top;

    // پیشرفت تشکیل کپسول از ۰.۰ (سکون) تا ۱.۰ (کپسول تشکیل شده)
    final rawT = (scrollOffset / collapseDistance).clamp(0.0, 1.0);
    final t = Curves.easeInOutCubic.transform(rawT);

    final hasTabs = tabs != null;
    final hasSubtitle = subtitle != null;

    // محاسبه ارتفاع کپسول در حالات مختلف:
    // ۱. در حالت بالای صفحه (t = 0): ارتفاع باز کامل (۱۶۴ یا ۱۱۴)
    // ۲. در حالت کپسول با تب‌های باز (t = 1 و isTabsExpanded = true): ارتفاع ۱۰۸ پیکسل
    // ۳. در حالت کپسول فشرده تک‌خطی (t = 1 و isTabsExpanded = false): ارتفاع ۵۴ پیکسل
    final double targetHeight;
    if (t < 0.99) {
      final restingHeight = hasTabs ? (hasSubtitle ? 168.0 : 156.0) : (hasSubtitle ? 112.0 : 96.0);
      final activeCapsuleHeight = hasTabs ? 108.0 : 54.0;
      targetHeight = lerpDouble(restingHeight, activeCapsuleHeight, t)!;
    } else {
      targetHeight = (hasTabs && isTabsExpanded) ? 108.0 : 54.0;
    }

    final currentMarginH = lerpDouble(0.0, 10.0, t)!;
    final currentMarginTop = topInset + lerpDouble(2.0, 6.0, t)!;
    final currentRadius = lerpDouble(0.0, 27.0, t)!;

    final effectiveBlur = isGlass ? (t * context.glassBlurSigma.clamp(0.0, 50.0)) : 0.0;
    final isOpaque = !isGlass || highContrast;

    final Color bgColor;
    final Border? border;
    final List<BoxShadow>? shadows;

    if (isOpaque) {
      bgColor = colors.surfaceElevated.withValues(alpha: t);
      border = t > 0.05
          ? Border.all(
              color: (isDark ? colors.border : colors.divider).withValues(alpha: t),
              width: 0.8,
            )
          : null;
      shadows = t > 0.2
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: t * 0.15),
                offset: Offset(0, 2 * t),
                blurRadius: 6 * t,
              ),
            ]
          : null;
    } else {
      bgColor = colors.glassTint.withValues(
        alpha: t * (context.glassOpacityPercent / 100.0).clamp(0.1, 0.9),
      );
      border = t > 0.05
          ? Border.all(
              color: (isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : colors.border.withValues(alpha: 0.35))
                  .withValues(alpha: t),
              width: 0.8,
            )
          : null;
      shadows = t > 0.15
          ? [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: t * 0.40)
                    : const Color(0xFF94A3B8).withValues(alpha: t * 0.35),
                offset: Offset(0, 3 * t),
                blurRadius: 8 * t,
              ),
            ]
          : null;
    }

    // مختصات پیوسته ترنزیشن تیتر
    final titleRight = lerpDouble(14.0, 52.0, t)!;
    final titleTop = lerpDouble(50.0, 14.0, t)!;
    final titleFontSize = lerpDouble(27.0, 16.5, t)!;

    final subtitleOpacity = (1.0 - (2.4 * rawT)).clamp(0.0, 1.0);
    final showTabsInCapsule = hasTabs && (t < 0.99 || isTabsExpanded);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          top: currentMarginTop,
          left: currentMarginH,
          right: currentMarginH,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(currentRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: effectiveBlur,
              sigmaY: effectiveBlur,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              height: targetHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(currentRadius),
                border: border,
                boxShadow: shadows,
                gradient: isGlass && t > 0.1
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: (isDark ? 0.09 : 0.25) * t),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.45],
                      )
                    : null,
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // ۱. ردیف دکمه‌های اکشن بالا (Back & Action Buttons)
                  Positioned(
                    top: 6,
                    left: 8,
                    right: 8,
                    height: 42,
                    child: Row(
                      children: [
                        // دکمه بازگشت (سمت راست در RTL)
                        if (leading != null)
                          leading!
                        else if (Navigator.canPop(context))
                          RitmoVibrancyActionButton(
                            icon: CupertinoIcons.arrow_right,
                            tooltip: 'بازگشت',
                            onTap: onBack ?? () => Navigator.maybePop(context),
                          )
                        else
                          const SizedBox(width: 8),

                        const Spacer(),

                        // دکمه‌های اکشن (سمت چپ در RTL)
                        ...?actions,
                      ],
                    ),
                  ),

                  // ۲. ترنزیشن فیزیکی تیتر (Title Morphing)
                  Positioned(
                    top: titleTop,
                    right: titleRight,
                    left: lerpDouble(14.0, 100.0, t),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: titleFontSize,
                              fontWeight: t > 0.4 ? FontWeight.w800 : FontWeight.w900,
                              letterSpacing: -0.4,
                              color: titleColor ??
                                  (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (statusBadge != null) ...[
                          const SizedBox(width: 6),
                          Opacity(
                            opacity: t,
                            child: statusBadge,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ۳. زیرعنوان تیتر بزرگ (محوشونده با اسکرول)
                  if (hasSubtitle && subtitleOpacity > 0.01)
                    Positioned(
                      top: 86,
                      right: 14,
                      left: 14,
                      child: Opacity(
                        opacity: subtitleOpacity,
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                  // ۴. نوار تب‌ها داخل انتهای همان کپسول شیشه‌ای واحد
                  if (hasTabs)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      bottom: showTabsInCapsule ? 6.0 : -60.0,
                      right: 6,
                      left: 6,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: showTabsInCapsule ? 1.0 : 0.0,
                        child: tabs,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
