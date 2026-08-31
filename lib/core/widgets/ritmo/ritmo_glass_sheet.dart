import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';

/// ویجت مرجع و استاندارد تمام پنجره‌ها، شیت‌های شناور و دیالوگ‌های شیشه‌ای ریتمو (Single Source of Truth).
///
/// این ویجت کپسوله کنندهٔ:
/// 1. هاله نوری امبینت پالت فعال در سایه (`Ambient Glow Halo` + `Contact Shadow`)
/// 2. بلور زنده متصل به اسلایدر تنظیمات ظاهر و زبان (`BackdropFilter`)
/// 3. رنگ شیشه دودی پالت فعال (`colors.glassTint` متصل به اسلایدر غلظت)
/// 4. حاشیه تیتانیومی خاکستری مات در تم تاریک (`#94A3B8 @ 0.16` با ضخامت `0.9px`) و سفید صیقلی در تم روشن
/// 5. گرادیان بازتاب نور افقی مات لبه بالا (`Matte Top Specular Sheen`)
/// 6. مدیریت حالت کنتراست بالا و غیرفعال بودن شیشه (`opaqueFallback`)
/// 7. اندازه‌گیری هوشمند و داینامیک ارتفاع شیت جهت تنظیم هاله پشته‌ای (`AppleCardDeckHost`)
class RitmoGlassSheet extends StatefulWidget {
  const RitmoGlassSheet({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.customShadows,
    this.enableSpecularSheen = true,
    this.enableAmbientGlow = true,
    this.clipBehavior = Clip.antiAlias,
  });

  /// محتوای داخلی پنجره / شیت
  final Widget child;

  /// گردی گوشه‌ها (پیش‌فرض: لبه‌های بالایی ۲۴ پیکسل)
  final BorderRadius? borderRadius;

  /// فاصله درونی
  final EdgeInsetsGeometry? padding;

  /// فاصله بیرونی
  final EdgeInsetsGeometry? margin;

  /// سایه‌های سفارشی در صورت نیاز به override
  final List<BoxShadow>? customShadows;

  /// آیا بازتاب نوری لبه بالایی فعال باشد؟ (پیش‌فرض: true)
  final bool enableSpecularSheen;

  /// آیا هاله نوری امبینت پالت فعال در سایه فعال باشد؟ (پیش‌فرض: true)
  final bool enableAmbientGlow;

  /// رفتار برش محتوا
  final Clip clipBehavior;

  /// رادیوس پیش‌فرض استاندارد شیت‌های اپل در ریتمو
  static const BorderRadius defaultSheetRadius = BorderRadius.vertical(
    top: Radius.circular(RitmoRadius.card),
  );

  @override
  State<RitmoGlassSheet> createState() => _RitmoGlassSheetState();
}

class _RitmoGlassSheetState extends State<RitmoGlassSheet> {
  @override
  void initState() {
    super.initState();
    _scheduleMeasurement();
  }

  @override
  void didUpdateWidget(covariant RitmoGlassSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasurement();
  }

  void _scheduleMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        if (screenHeight > 0) {
          final fraction = (box.size.height / screenHeight).clamp(0.15, 0.96);
          AppleCardDeckHost.activeForegroundSheetExtent.value = fraction;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final materialSpec = context.materials.regular;
    final effectiveRadius = widget.borderRadius ?? RitmoGlassSheet.defaultSheetRadius;

    final isOpaque = !isGlass || highContrast;

    // ۱. سایه‌های ۲ لایه‌ای (هاله نوری پالت در تاریک / سایه ملایم پالت در روشن)
    final List<BoxShadow> effectiveShadows = widget.customShadows ??
        (isDark
            ? (widget.enableAmbientGlow
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.20),
                      offset: const Offset(0, -4),
                      blurRadius: 18,
                      spreadRadius: 0.5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      offset: const Offset(0, -2),
                      blurRadius: 8,
                      spreadRadius: -1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      offset: const Offset(0, -3),
                      blurRadius: 16,
                    ),
                  ])
            : [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.08),
                  offset: const Offset(0, -3),
                  blurRadius: 16,
                ),
              ]);

    // ۲. حالت مات / Fallback بدون شیشه
    if (isOpaque) {
      return Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: materialSpec.opaqueFallback,
          borderRadius: effectiveRadius,
          boxShadow: effectiveShadows,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: effectiveRadius,
          clipBehavior: widget.clipBehavior,
          child: Padding(
            padding: widget.padding ?? EdgeInsets.zero,
            child: widget.child,
          ),
        ),
      );
    }

    // ۳. حالت شیشه مایع کامل (Liquid Glass Material)
    final blur = materialSpec.sigma.clamp(0.0, 50.0);

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: effectiveShadows,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        clipBehavior: widget.clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.glassTint,
              borderRadius: effectiveRadius,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF94A3B8).withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.70),
                width: isDark ? 0.9 : 1.0,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: effectiveRadius,
                gradient: widget.enableSpecularSheen
                    ? (isDark
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF94A3B8).withValues(alpha: 0.10),
                              const Color(0xFF64748B).withValues(alpha: 0.03),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.04, 0.40],
                          )
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.75),
                              Colors.white.withValues(alpha: 0.20),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.03, 0.45],
                          ))
                    : null,
              ),
              child: Padding(
                padding: widget.padding ?? EdgeInsets.zero,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
