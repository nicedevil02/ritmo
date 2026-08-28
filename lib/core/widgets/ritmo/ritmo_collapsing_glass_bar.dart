// =============================================================================
//  ritmo_collapsing_glass_bar.dart
//  هدر داینامیک لارج تایتل شیشه‌ای اپل (Apple Dynamic Large Title Collapsing Glass Bar)
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

/// نوار شیشه‌ای داینامیک بالای صفحه (Apple Top Glass Navbar)
///
/// قابلیت‌ها:
/// - در بالای صفحه: کاملاً شفاف و بدون بلور.
/// - هنگام اسکرول: ظهور تدریجی شیشه مات، بلور و تیتر فشرده با محو شدن تیتر بزرگ.
class RitmoDynamicGlassAppBar extends StatelessWidget {
  const RitmoDynamicGlassAppBar({
    super.key,
    required this.title,
    required this.scrollOffset,
    this.actions,
    this.leading,
    this.onBack,
    this.collapseDistance = 50.0,
    this.titleColor,
    this.statusBadge,
  });

  final String title;
  final double scrollOffset;
  final List<Widget>? actions;
  final Widget? leading;
  final VoidCallback? onBack;
  final double collapseDistance;
  final Color? titleColor;
  final Widget? statusBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;

    // پیشرفت اسکرول از ۰.۰ (بالای صفحه) تا ۱.۰ (اسکرول شده)
    final progress = (scrollOffset / collapseDistance).clamp(0.0, 1.0);

    final effectiveBlur = progress * context.glassBlurSigma.clamp(0.0, 50.0);
    final isOpaque = !isGlass || highContrast;

    final Color bgColor;
    final Border? border;
    final List<BoxShadow>? shadows;

    if (isOpaque) {
      bgColor = colors.surfaceElevated.withValues(alpha: progress);
      border = Border(
        bottom: BorderSide(
          color: (isDark ? colors.border : colors.divider).withValues(alpha: progress),
          width: 0.8,
        ),
      );
      shadows = progress > 0.5
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: progress * 0.15),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ]
          : null;
    } else {
      bgColor = colors.glassTint.withValues(alpha: progress * (context.glassOpacityPercent / 100.0).clamp(0.1, 0.9));
      border = Border(
        bottom: BorderSide(
          color: (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : colors.border.withValues(alpha: 0.35))
              .withValues(alpha: progress),
          width: 0.8,
        ),
      );
      shadows = progress > 0.3
          ? [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: progress * 0.40)
                    : const Color(0xFFCBD5E1).withValues(alpha: progress * 0.50),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ]
          : null;
    }

    final topInset = MediaQuery.paddingOf(context).top;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: Container(
            padding: EdgeInsets.only(
              top: topInset + 4,
              bottom: 8,
              left: 12,
              right: 12,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              border: border,
              boxShadow: shadows,
              gradient: isGlass && progress > 0.1
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: (isDark ? 0.08 : 0.20) * progress),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.45],
                    )
                  : null,
            ),
            child: Row(
              children: [
                // دکمه بازگشت یا دکمه Leading
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

                const SizedBox(width: 10),

                // تیتر فشرده میانی (ظاهر شونده با ترنزیشن نرم)
                Expanded(
                  child: Opacity(
                    opacity: progress,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: titleColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (statusBadge != null) ...[
                          const SizedBox(width: 6),
                          statusBadge!,
                        ],
                      ],
                    ),
                  ),
                ),

                // دکمه‌های اکشن بالا (Action Buttons)
                ...?actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// بخش هیرو تیتر بزرگ اپل (Apple Large Title Hero Section)
///
/// در بالای محتوای اسکرول‌شونده قرار می‌گیرد و با اسکرول محو می‌شود.
class RitmoLargeTitleHero extends StatelessWidget {
  const RitmoLargeTitleHero({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.titleColor,
    this.accentColor,
  });

  final String title;
  final String? subtitle;
  final Widget? badge;
  final Color? titleColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: titleColor ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ),
                ?badge,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
