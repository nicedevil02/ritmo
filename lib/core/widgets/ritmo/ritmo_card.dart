// =============================================================================
//  ritmo_card.dart
//  سیستم مرجع واحد کارت‌های ریتمو (Ritmo Universal Card System)
//  ترکیب مهندسی نئومورفیسم مدرن (Soft UI) و استانداردهای متریال اپل
//  یکپارچه با ۱۲ پالت رنگی و سیستم تم مرکزی
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// گونه‌های متریال کارت مرجع ریتمو
enum RitmoCardVariant {
  /// سطح برآمده نئومورفیک ۳ بعدی (Neumorphic Raised) با سایه‌های دوگانه متضاد و گرادیان سطحی
  neumorphic,

  /// سطح فرورفته نئومورفیک (Neumorphic Sunken/Inset) با سایه و گرادیان معکوس برای گودی‌ها و ورودی‌ها
  neumorphicSunken,

  /// متریال اکریلیک مات اپل (Apple Elevated Acrylic)
  elevated,

  /// متریال شیشه کامل شفاف با بلور بلادرنگ (Liquid Glass)
  glass,

  /// سطح بدون پرشدگی با خط کادر نرم (Outlined)
  outlined,
}

/// -----------------------------------------------------------------------------
/// موتور محاسبات نور، سایه‌ها و گرادیان‌های نئومورفیک (Ritmo Neu Engine)
/// -----------------------------------------------------------------------------
class RitmoNeu {
  const RitmoNeu._();

  /// لبه روشن سطح (بالا-چپ) برای گرادیان محدب
  static Color highlightColor(Color base, bool isDark) =>
      Color.lerp(base, Colors.white, isDark ? 0.06 : 0.40)!;

  /// لبه تیره سطح (پایین-راست) برای گرادیان مقعر
  static Color shadowBaseColor(Color base, bool isDark) =>
      Color.lerp(base, Colors.black, isDark ? 0.25 : 0.08)!;

  /// سایه روشن نور بالا-چپ
  static Color lightShadow(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.045)
      : Colors.white.withValues(alpha: 0.95);

  /// سایه تیره پایین-راست
  static Color darkShadow(bool isDark) => isDark
      ? Colors.black.withValues(alpha: 0.52)
      : const Color(0xFFBAC4D2).withValues(alpha: 0.80);

  /// گرادیان محدب برآمده نئومورفیک (روشن در بالا-چپ به رنگ پایه در پایین-راست)
  static LinearGradient raisedGradient(Color base, bool isDark) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [highlightColor(base, isDark), base],
      );

  /// گرادیان مقعر فرورفته نئومورفیک (تیره در بالا-چپ به روشن در پایین-راست)
  static LinearGradient sunkenGradient(Color base, bool isDark) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [shadowBaseColor(base, isDark), highlightColor(base, isDark)],
      );

  /// سایه‌های دوگانه متضاد برآمده (نور از بالا-چپ ۱۳۵ درجه)
  static List<BoxShadow> raisedShadows(
    bool isDark, {
    double blur = 14,
    double distance = 4.5,
  }) =>
      [
        BoxShadow(
          color: darkShadow(isDark),
          offset: Offset(distance, distance * 1.1),
          blurRadius: blur,
        ),
        BoxShadow(
          color: lightShadow(isDark),
          offset: Offset(-distance, -distance),
          blurRadius: blur * 0.9,
        ),
      ];

  /// سایه‌های دوگانه فرورفته (گودی در بوم)
  static List<BoxShadow> sunkenShadows(
    bool isDark, {
    double blur = 8,
    double distance = 3,
  }) =>
      [
        BoxShadow(
          color: darkShadow(isDark),
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: lightShadow(isDark),
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
      ];
}

/// کارت مرجع واحد سیستم طراحی ریتمو
class RitmoCard extends StatefulWidget {
  const RitmoCard({
    super.key,
    required this.child,
    this.variant = RitmoCardVariant.neumorphic,
    this.padding = const EdgeInsets.all(RitmoSpacing.lg),
    this.margin,
    this.borderRadius,
    this.borderColor,
    this.borderWidth,
    this.backgroundColor,
    this.customShadows,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.enableSpring = true,
    this.clipBehavior = Clip.antiAlias,
  });

  /// متد کارخانه‌ای برای کارت برآمده نئومورفیک (پیش‌فرض اصلی ریتمو)
  const factory RitmoCard.neumorphic({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    List<BoxShadow>? customShadows,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isSelected,
    bool enableSpring,
    Clip clipBehavior,
  }) = _RitmoNeumorphicCard;

  /// متد کارخانه‌ای برای کارت فرورفته نئومورفیک
  const factory RitmoCard.neumorphicSunken({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isSelected,
    bool enableSpring,
    Clip clipBehavior,
  }) = _RitmoNeumorphicSunkenCard;

  /// متد کارخانه‌ای برای کارت اکریلیک مات اپل
  const factory RitmoCard.elevated({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    List<BoxShadow>? customShadows,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isSelected,
    bool enableSpring,
    Clip clipBehavior,
  }) = _RitmoElevatedCard;

  /// متد کارخانه‌ای برای کارت‌های شیشه‌ای کامل
  const factory RitmoCard.glass({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    List<BoxShadow>? customShadows,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isSelected,
    bool enableSpring,
    Clip clipBehavior,
  }) = _RitmoGlassCard;

  /// متد کارخانه‌ای برای کارت‌های خطی Outline
  const factory RitmoCard.outlined({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding,
    EdgeInsetsGeometry? margin,
    BorderRadius? borderRadius,
    Color? borderColor,
    double? borderWidth,
    Color? backgroundColor,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isSelected,
    bool enableSpring,
    Clip clipBehavior,
  }) = _RitmoOutlinedCard;

  final Widget child;
  final RitmoCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double? borderWidth;
  final Color? backgroundColor;
  final List<BoxShadow>? customShadows;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool enableSpring;
  final Clip clipBehavior;

  @override
  State<RitmoCard> createState() => _RitmoCardState();
}

class _RitmoCardState extends State<RitmoCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null || !widget.enableSpring) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap == null || !widget.enableSpring) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (widget.onTap == null || !widget.enableSpring) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(24);

    final baseColor = widget.backgroundColor ?? colors.surfaceElevated;

    // ۱. تعیین دکوراسیون و گرادیان نئومورفیک
    Gradient? resolveGradient() {
      if (widget.isSelected) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.primary, Colors.white, isDark ? 0.08 : 0.35)!,
            colors.primary.withValues(alpha: isDark ? 0.85 : 0.90),
          ],
        );
      }

      switch (widget.variant) {
        case RitmoCardVariant.neumorphic:
          return _isPressed
              ? RitmoNeu.sunkenGradient(baseColor, isDark)
              : RitmoNeu.raisedGradient(baseColor, isDark);
        case RitmoCardVariant.neumorphicSunken:
          return RitmoNeu.sunkenGradient(colors.surfaceSunken, isDark);
        case RitmoCardVariant.elevated:
        case RitmoCardVariant.glass:
        case RitmoCardVariant.outlined:
          return null;
      }
    }

    Color resolveSolidColor() {
      if (widget.backgroundColor != null) return widget.backgroundColor!;
      if (widget.isSelected) return colors.primary;

      switch (widget.variant) {
        case RitmoCardVariant.neumorphic:
        case RitmoCardVariant.elevated:
          return baseColor;
        case RitmoCardVariant.neumorphicSunken:
          return colors.surfaceSunken;
        case RitmoCardVariant.glass:
          return isGlass ? colors.glassTint : (isDark ? baseColor : Colors.white);
        case RitmoCardVariant.outlined:
          return Colors.transparent;
      }
    }

    // ۲. تعیین حاشیه ظریف تیتانیومی
    Border? resolveBorder() {
      if (widget.variant == RitmoCardVariant.neumorphic && !widget.isSelected && !highContrast) {
        // در نئومورفیسم لایت نیازی به خط دور نیست، در دارک یک کادر بسیار محو به تفکیک کمک می‌کند
        if (isDark) {
          return Border.all(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.12),
            width: 0.8,
          );
        }
        return null;
      }

      final double width = widget.borderWidth ??
          (widget.isSelected ? 1.5 : (highContrast ? 2.0 : (isDark ? 0.9 : 0.8)));

      final Color color = widget.borderColor ??
          (widget.isSelected
              ? colors.primary
              : (highContrast
                  ? colors.border
                  : (isDark
                      ? const Color(0xFF94A3B8).withValues(alpha: 0.14)
                      : colors.border)));

      return Border.all(color: color, width: width);
    }

    // ۳. تعیین سایه‌های نئومورفیک دوگانه
    List<BoxShadow> resolveShadows() {
      if (widget.customShadows != null) return widget.customShadows!;
      if (widget.variant == RitmoCardVariant.outlined) return const [];

      if (widget.isSelected) {
        return [
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.40 : 0.30),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: RitmoNeu.lightShadow(isDark),
            blurRadius: 10,
            offset: const Offset(-3, -3),
          ),
        ];
      }

      switch (widget.variant) {
        case RitmoCardVariant.neumorphic:
          return _isPressed
              ? RitmoNeu.sunkenShadows(isDark, blur: 8, distance: 2.5)
              : RitmoNeu.raisedShadows(isDark, blur: 15, distance: 5.0);
        case RitmoCardVariant.neumorphicSunken:
          return RitmoNeu.sunkenShadows(isDark, blur: 9, distance: 3.0);
        case RitmoCardVariant.elevated:
        case RitmoCardVariant.glass:
          return [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
              offset: const Offset(0, 3),
              blurRadius: 10,
            ),
          ];
        case RitmoCardVariant.outlined:
          return const [];
      }
    }

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: resolveGradient() == null ? resolveSolidColor() : null,
        gradient: resolveGradient(),
        borderRadius: effectiveRadius,
        border: resolveBorder(),
        boxShadow: resolveShadows(),
      ),
      child: widget.child,
    );

    // اعمال فیلتر بلور زنده در حالت Glass
    if (widget.variant == RitmoCardVariant.glass && isGlass && !highContrast) {
      final blur = context.glassBlurSigma.clamp(0.0, 50.0);
      content = ClipRRect(
        borderRadius: effectiveRadius,
        clipBehavior: widget.clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
      );
    }

    if (widget.margin != null) {
      content = Padding(padding: widget.margin!, child: content);
    }

    if (widget.onTap != null || widget.onLongPress != null) {
      content = GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: () {
          RitmoHapticsPolicy.selection();
          widget.onTap?.call();
        },
        onLongPress: widget.onLongPress != null
            ? () {
                RitmoHapticsPolicy.selection();
                widget.onLongPress?.call();
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: content,
        ),
      );
    }

    return content;
  }
}

// -----------------------------------------------------------------------------
// Constructors Factory Wrappers
// -----------------------------------------------------------------------------

class _RitmoNeumorphicCard extends RitmoCard {
  const _RitmoNeumorphicCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.borderRadius,
    super.borderColor,
    super.borderWidth,
    super.backgroundColor,
    super.customShadows,
    super.onTap,
    super.onLongPress,
    super.isSelected = false,
    super.enableSpring = true,
    super.clipBehavior = Clip.antiAlias,
  }) : super(variant: RitmoCardVariant.neumorphic);
}

class _RitmoNeumorphicSunkenCard extends RitmoCard {
  const _RitmoNeumorphicSunkenCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.borderRadius,
    super.borderColor,
    super.borderWidth,
    super.backgroundColor,
    super.onTap,
    super.onLongPress,
    super.isSelected = false,
    super.enableSpring = true,
    super.clipBehavior = Clip.antiAlias,
  }) : super(variant: RitmoCardVariant.neumorphicSunken);
}

class _RitmoElevatedCard extends RitmoCard {
  const _RitmoElevatedCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.borderRadius,
    super.borderColor,
    super.borderWidth,
    super.backgroundColor,
    super.customShadows,
    super.onTap,
    super.onLongPress,
    super.isSelected = false,
    super.enableSpring = true,
    super.clipBehavior = Clip.antiAlias,
  }) : super(variant: RitmoCardVariant.elevated);
}

class _RitmoGlassCard extends RitmoCard {
  const _RitmoGlassCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.borderRadius,
    super.borderColor,
    super.borderWidth,
    super.backgroundColor,
    super.customShadows,
    super.onTap,
    super.onLongPress,
    super.isSelected = false,
    super.enableSpring = true,
    super.clipBehavior = Clip.antiAlias,
  }) : super(variant: RitmoCardVariant.glass);
}

class _RitmoOutlinedCard extends RitmoCard {
  const _RitmoOutlinedCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.borderRadius,
    super.borderColor,
    super.borderWidth,
    super.backgroundColor,
    super.onTap,
    super.onLongPress,
    super.isSelected = false,
    super.enableSpring = true,
    super.clipBehavior = Clip.antiAlias,
  }) : super(variant: RitmoCardVariant.outlined);
}

// =============================================================================
//  المان‌های اتمیک نئومورفیک داخل کارت‌ها (Neumorphic Atomic Components)
// =============================================================================

/// هدر استاندارد کارت ریتمو با آیکون ۳ بعدی، تایتل، زیرعنوان و اکشن
class RitmoCardHeader extends StatelessWidget {
  const RitmoCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onActionTap,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onActionTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final effectiveIconColor = iconColor ?? colors.primary;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(effectiveIconColor, Colors.white, isDark ? 0.10 : 0.35)!,
                    effectiveIconColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: effectiveIconColor.withValues(alpha: isDark ? 0.40 : 0.30),
                    blurRadius: 8,
                    offset: const Offset(1.5, 2.5),
                  ),
                  BoxShadow(
                    color: RitmoNeu.lightShadow(isDark),
                    blurRadius: 6,
                    offset: const Offset(-1.5, -1.5),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Vazirmatn',
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// کپسول متریک یا ردیف تعاملی ۳ بعدی داخل کارت ریتمو
class RitmoCardTile extends StatefulWidget {
  const RitmoCardTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    this.isSunken = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isSunken;

  @override
  State<RitmoCardTile> createState() => _RitmoCardTileState();
}

class _RitmoCardTileState extends State<RitmoCardTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    final baseColor = widget.backgroundColor ??
        (isDark ? colors.surfaceSunken.withValues(alpha: 0.50) : colors.surface);

    final isActuallySunken = widget.isSunken || _pressed;

    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: widget.padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: isActuallySunken
            ? RitmoNeu.sunkenGradient(baseColor, isDark)
            : RitmoNeu.raisedGradient(baseColor, isDark),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white.withValues(alpha: 0.70),
          width: 0.6,
        ),
        boxShadow: isActuallySunken
            ? RitmoNeu.sunkenShadows(isDark, blur: 6, distance: 2.0)
            : RitmoNeu.raisedShadows(isDark, blur: 8, distance: 2.5),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 1.5),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'Vazirmatn',
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?widget.trailing,
        ],
      ),
    );

    if (widget.onTap != null) {
      tile = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          RitmoHapticsPolicy.selection();
          widget.onTap?.call();
        },
        child: tile,
      );
    }

    return tile;
  }
}

/// دکمه برجسته نئومورفیک ۳ بعدی
class RitmoNeuButton extends StatefulWidget {
  const RitmoNeuButton({
    super.key,
    required this.child,
    required this.onTap,
    this.height = 42,
    this.radius = 18,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget child;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  State<RitmoNeuButton> createState() => _RitmoNeuButtonState();
}

class _RitmoNeuButtonState extends State<RitmoNeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final base = widget.color ?? colors.surfaceElevated;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        RitmoHapticsPolicy.selection();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        height: widget.height,
        padding: widget.padding,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: _pressed
              ? RitmoNeu.sunkenGradient(base, isDark)
              : RitmoNeu.raisedGradient(base, isDark),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.85),
            width: 0.7,
          ),
          boxShadow: _pressed
              ? RitmoNeu.sunkenShadows(isDark, blur: 6, distance: 2.0)
              : RitmoNeu.raisedShadows(isDark, blur: 10, distance: 3.5),
        ),
        child: widget.child,
      ),
    );
  }
}

/// نشانگر وضعیت یا برچسب نئومورفیک متصل به رنگ‌های معنایی پالت
class RitmoCardBadge extends StatelessWidget {
  const RitmoCardBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.isOutlined = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        gradient: isOutlined
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(color, Colors.white, isDark ? 0.08 : 0.35)!,
                  color,
                ],
              ),
        color: isOutlined ? Colors.transparent : null,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: color.withValues(alpha: isOutlined ? 0.8 : 0.35),
          width: 0.8,
        ),
        boxShadow: isOutlined
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.35 : 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: isOutlined ? color : Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontFamily: 'Vazirmatn',
              color: isOutlined ? color : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// خط جداکننده محو نئومورفیک (خط دوگانه شیاردار)
class RitmoCardDivider extends StatelessWidget {
  const RitmoCardDivider({super.key, this.margin = const EdgeInsets.symmetric(vertical: 10)});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Padding(
      padding: margin,
      child: Container(
        height: 1.5,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : const Color(0xFFBAC3CF).withValues(alpha: 0.60),
              width: 0.8,
            ),
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              width: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// سطح ۳ بعدی نئومورفیک (برآمده / فرورفته / هاله نوری)
class RitmoNeuSurface extends StatelessWidget {
  const RitmoNeuSurface({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.tint,
    this.glowColor,
    this.sunken = false,
    this.blur = 10,
    this.distance = 3.5,
    this.onTap,
  });

  final Widget child;
  final double? height;
  final double? width;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final Color? glowColor;
  final bool sunken;
  final double blur;
  final double distance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final base = colors.surfaceElevated;

    final tintColor = tint;

    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: tintColor != null
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(tintColor, Colors.white, isDark ? 0.05 : 0.40)!,
                tintColor,
              ],
            )
          : (sunken
              ? RitmoNeu.sunkenGradient(colors.surfaceSunken, isDark)
              : RitmoNeu.raisedGradient(base, isDark)),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.70),
        width: 0.6,
      ),
      boxShadow: glowColor != null
          ? [
              BoxShadow(
                color: glowColor!.withValues(alpha: isDark ? 0.35 : 0.25),
                blurRadius: blur + 4,
                offset: Offset(0, distance),
              ),
              BoxShadow(
                color: RitmoNeu.lightShadow(isDark),
                blurRadius: blur,
                offset: Offset(-distance, -distance),
              ),
            ]
          : (sunken
              ? RitmoNeu.sunkenShadows(isDark, blur: blur, distance: distance)
              : RitmoNeu.raisedShadows(isDark, blur: blur, distance: distance)),
    );

    Widget result = Container(
      height: height,
      width: width,
      padding: padding,
      alignment: height != null ? Alignment.center : null,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          RitmoHapticsPolicy.selection();
          onTap?.call();
        },
        child: result,
      );
    }

    return result;
  }
}

/// کارت مرجع شاهکار نئومورفیک (Ritmo Master Reference Hero Card)
/// شامل چیدمان دو ستونه: گیج ۲۴ ساعته + دکمه تعاملی + چیپ‌های نئومورفیک + تایمر شمارش معکوس
class RitmoNeuMasterCard extends StatelessWidget {
  const RitmoNeuMasterCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activeChipLabel,
    this.activeChipIcon = Icons.nightlight_round,
    this.statusLabel = 'قلمرو فعال',
    required this.timeRange,
    required this.remainingTime,
    this.activeColor,
    this.gaugeWidget,
    this.actionButtonText = 'مدیریت قلمرو',
    this.onActionTap,
    this.onTap,
    this.height = 176,
  });

  final String title;
  final String subtitle;
  final String activeChipLabel;
  final IconData activeChipIcon;
  final String statusLabel;
  final String timeRange;
  final String remainingTime;
  final Color? activeColor;
  final Widget? gaugeWidget;
  final String actionButtonText;
  final VoidCallback? onActionTap;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final effectiveColor = activeColor ?? colors.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoCard.neumorphic(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        child: SizedBox(
          height: height - 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ستون راست (RTL): اطلاعات، چیپ‌ها و پیل‌های نئومورفیک ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ردیف هدر چیپ‌ها
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: RitmoNeuSurface(
                            sunken: true,
                            radius: 14,
                            blur: 6,
                            distance: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: RitmoNeuSurface(
                            tint: isDark
                                ? effectiveColor.withValues(alpha: 0.35)
                                : effectiveColor.withValues(alpha: 0.15),
                            glowColor: effectiveColor,
                            radius: 14,
                            blur: 7,
                            distance: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  activeChipLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : effectiveColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(activeChipIcon, size: 12, color: isDark ? Colors.white : effectiveColor),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // عنوان اصلی و زیرعنوان
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    // پیل بازه زمانی
                    RitmoNeuSurface(
                      height: 30,
                      radius: 15,
                      blur: 7,
                      distance: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_filled_rounded, size: 14, color: colors.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              timeRange,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // پیل شمارش معکوس با هاله نئومورفیک
                    RitmoNeuSurface(
                      height: 30,
                      radius: 15,
                      tint: isDark
                          ? effectiveColor.withValues(alpha: 0.35)
                          : effectiveColor.withValues(alpha: 0.15),
                      glowColor: effectiveColor,
                      blur: 8,
                      distance: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, size: 14, color: isDark ? Colors.white : effectiveColor),
                          const SizedBox(width: 6),
                          Text(
                            'باقی‌مانده:',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : effectiveColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              remainingTime,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : effectiveColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ── ستون چپ: گیج نئومورفیک و دکمه مدیریت ──
              SizedBox(
                width: 110,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (gaugeWidget != null)
                      gaugeWidget!
                    else
                      _buildDefaultSampleGauge(context, effectiveColor, isDark),
                    const SizedBox(height: 4),
                    RitmoNeuButton(
                      height: 30,
                      radius: 15,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      onTap: onActionTap ?? () {},
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              actionButtonText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 13,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultSampleGauge(BuildContext context, Color color, bool isDark) {
    return Container(
      width: 102,
      height: 102,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RitmoNeu.sunkenGradient(context.colors.surfaceSunken, isDark),
        boxShadow: RitmoNeu.sunkenShadows(isDark, blur: 8, distance: 3.0),
      ),
      child: Center(
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RitmoNeu.raisedGradient(context.colors.surfaceElevated, isDark),
            boxShadow: RitmoNeu.raisedShadows(isDark, blur: 6, distance: 2.0),
          ),
          child: Center(
            child: Icon(
              activeChipIcon,
              size: 26,
              color: isDark ? Colors.amberAccent : color,
            ),
          ),
        ),
      ),
    );
  }
}



