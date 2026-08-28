// =============================================================================
//  ritmo_glass_header.dart
//  پریمیتیو و کانتینر مرکزی هدر شیشه‌ای کپسولی متصل به تنظیمات ظاهر
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// هدر شیشه‌ای استاندارد متصل به تنظیمات متریال شیشه در بخش ظاهر (`AppearanceGroupScreen`)
///
/// قابلیت‌ها:
/// - پشتیبانی پویا از [context.isGlassEnabled]، [context.glassBlurSigma]، [context.glassOpacityPercent] و [colors.glassTint].
/// - تنزل هوشمند و بهینه به حالت مات (`surfaceElevated`) هنگام فعال بودن کاهش شفافیت یا کنتراست بالا.
/// - سایه دو لایه‌ای عمق‌بخش و لایه انعکاسی گرادیان نور بالا (Specular Highlight).
/// - ایزوله‌سازی رندرینگ با [RepaintBoundary] برای حداکثر کارایی (60/120 FPS).
class RitmoGlassHeader extends StatelessWidget {
  const RitmoGlassHeader({
    super.key,
    required this.child,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blurSigma,
    this.color,
    this.border,
    this.shadows,
  });

  /// محتوای داخلی هدر
  final Widget child;

  /// ارتفاع ثابت (اختیاری) — در صورت null بودن، با اندازه محتوا منطبق می‌شود
  final double? height;

  /// پدینگ داخلی
  final EdgeInsetsGeometry? padding;

  /// مارجین بیرونی
  final EdgeInsetsGeometry? margin;

  /// شعاع گوشه‌ها — پیش‌فرض ۲۶ پیکسل (فرم کپسولی / جزیره‌ای)
  final BorderRadius? borderRadius;

  /// مقدار بلور سفارشی (اختیاری؛ پیش‌فرض از تنظیمات ظاهر خوانده می‌شود)
  final double? blurSigma;

  /// رنگ تینت سفارشی (اختیاری؛ پیش‌فرض از پالت فعال و درصد شفافیت تنظیمات خوانده می‌شود)
  final Color? color;

  /// کادر دور سفارشی (اختیاری)
  final Border? border;

  /// سایه‌های سفارشی (اختیاری)
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final effectiveRadius = borderRadius ?? BorderRadius.circular(26);

    // ۱. حالت تنزل به سطح مات (Opaque Fallback) وقتی شیشه غیرفعال است یا کنتراست بالا فعال است
    if (!isGlass || highContrast) {
      return Container(
        margin: margin,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: effectiveRadius,
          border: border ??
              Border.all(
                color: highContrast
                    ? colors.textPrimary
                    : (isDark ? colors.border : colors.divider),
                width: highContrast ? 2.0 : 1.0,
              ),
          boxShadow: shadows ??
              (isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.08),
                        offset: const Offset(0, 4),
                        blurRadius: 14,
                      ),
                    ]),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: effectiveRadius,
          child: child,
        ),
      );
    }

    // ۲. حالت شیشه‌ای کامل متصل به تنظیمات
    final effectiveBlur = (blurSigma ?? context.glassBlurSigma).clamp(0.0, 50.0);
    final tintColor = color ?? colors.glassTint;

    final defaultShadows = isDark
        ? [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.22),
              offset: const Offset(0, 4),
              blurRadius: 20,
              spreadRadius: 1.5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.50),
              offset: const Offset(0, 2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ]
        : [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.08),
              offset: const Offset(0, 5),
              blurRadius: 14,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.90),
              offset: const Offset(0, -1),
              blurRadius: 3,
              spreadRadius: 0,
            ),
          ];

    final defaultBorder = isDark
        ? null
        : Border.all(
            color: Colors.white.withValues(alpha: 0.70),
            width: 1.0,
          );

    return RepaintBoundary(
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: shadows ?? defaultShadows,
        ),
        child: ClipRRect(
          borderRadius: effectiveRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: effectiveBlur,
              sigmaY: effectiveBlur,
            ),
            child: Container(
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                color: tintColor,
                borderRadius: effectiveRadius,
                border: border ?? defaultBorder,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.08 : 0.22),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: effectiveRadius,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
