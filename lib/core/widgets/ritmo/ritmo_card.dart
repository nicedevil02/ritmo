// =============================================================================
//  ritmo_card.dart
//  سیستم مرجع واحد کارت‌های ریتمو (Ritmo Universal Card System)
//  ترکیب مهندسی نئومورفیسم مدرن (Soft UI) و استانداردهای متریال اپل
//  یکپارچه با ۱۲ پالت رنگی و سیستم تم مرکزی
// =============================================================================

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

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
        final tintSurface = Color.lerp(baseColor, colors.primary, isDark ? 0.12 : 0.08)!;
        return isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(tintSurface, Colors.white, 0.08)!,
                  Color.lerp(tintSurface, Colors.black, 0.12)!,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(tintSurface, Colors.white, 0.70)!,
                  tintSurface,
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
      if (widget.isSelected) {
        return Color.lerp(baseColor, colors.primary, isDark ? 0.12 : 0.08)!;
      }

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
              ? colors.primary.withValues(alpha: isDark ? 0.85 : 0.75)
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
        final shadowDark = isDark
            ? Colors.black.withValues(alpha: 0.45)
            : Color.lerp(colors.surfaceElevated, Colors.black, 0.18)!.withValues(alpha: 0.55);

        return [
          BoxShadow(
            color: colors.primary.withValues(alpha: isDark ? 0.25 : 0.18),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: shadowDark,
            blurRadius: 10,
            offset: const Offset(3, 3.5),
          ),
          BoxShadow(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.95),
            blurRadius: 7,
            offset: const Offset(-2.5, -2.5),
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
    this.height,
    this.radius = 18,
    this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  final Widget child;
  final VoidCallback onTap;
  final double? height;
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
        child: Center(
          child: widget.child,
        ),
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
/// کارت مرجع شاهکار نئومورفیک (Ritmo Master Reference Hero Card)
/// با دکمه‌ها و پیل‌های برجسته کامپکت، فیزیکی و هاله تنفسی زنده (Breathing Ambient Halo)
class RitmoNeuMasterCard extends StatefulWidget {
  const RitmoNeuMasterCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.activeChipLabel,
    this.activeChipIcon = CupertinoIcons.moon_fill,
    this.activeChipEmoji,
    this.statusLabel = 'قلمرو فعال',
    required this.timeRange,
    required this.remainingTime,
    this.activeColor,
    this.gaugeWidget,
    this.actionButtonText = 'مدیریت قلمرو',
    this.onActionTap,
    this.onTap,
    this.height = 180,
    this.margin,
    this.enableBreathing = true,
  });

  final String title;
  final String subtitle;
  final String activeChipLabel;
  final IconData activeChipIcon;
  final String? activeChipEmoji;
  final String statusLabel;
  final String timeRange;
  final String remainingTime;
  final Color? activeColor;
  final Widget? gaugeWidget;
  final String actionButtonText;
  final VoidCallback? onActionTap;
  final VoidCallback? onTap;
  final double height;
  final EdgeInsetsGeometry? margin;
  final bool enableBreathing;

  @override
  State<RitmoNeuMasterCard> createState() => _RitmoNeuMasterCardState();
}

class _RitmoNeuMasterCardState extends State<RitmoNeuMasterCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathingController;
  late final Animation<double> _breathingAnim;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _breathingAnim = CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOutSine,
    );

    if (widget.enableBreathing) {
      _breathingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant RitmoNeuMasterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableBreathing != oldWidget.enableBreathing) {
      if (widget.enableBreathing) {
        _breathingController.repeat(reverse: true);
      } else {
        _breathingController.stop();
      }
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final effectiveColor = widget.activeColor ?? colors.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 380.0;
          final dialColWidth = (maxW * 0.38).clamp(118.0, 138.0);

          final innerContent = SizedBox(
            height: widget.height - 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── ستون راست (RTL): اطلاعات، چیپ‌ها و پیل‌های نئومورفیک فیزیکی ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ردیف هدر چیپ‌های فیزیکی برجسته
                      Row(
                        children: [
                          // چیپ وضعیت فعال با نقطه سه‌بعدی
                          _buildTactileStatusPill(
                            isDark: isDark,
                            statusLabel: widget.statusLabel,
                            color: effectiveColor,
                          ),
                          const SizedBox(width: 6),
                          // چیپ نام قلمروی فعال با آیکون یا ایموجی منتخب
                          Expanded(
                            child: _buildTactileRealmPill(
                              isDark: isDark,
                              colors: colors,
                              label: widget.activeChipLabel,
                              icon: widget.activeChipIcon,
                              emoji: widget.activeChipEmoji,
                              color: effectiveColor,
                            ),
                          ),
                        ],
                      ),

                      // عنوان اصلی و زیرعنوان
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                fontFamily: 'Vazirmatn',
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Vazirmatn',
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // پیل فیزیکی بازه زمانی
                      _buildTactileTimePill(
                        isDark: isDark,
                        colors: colors,
                        timeRange: widget.timeRange,
                      ),

                      // پیل فیزیکی تایمر شمارش معکوس با هاله پالت
                      _buildTactileCountdownPill(
                        isDark: isDark,
                        remainingTime: widget.remainingTime,
                        color: effectiveColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // ── ستون چپ: گیج نئومورفیک سه‌بعدی و دکمه مدیریت فیزیکی ──
                SizedBox(
                  width: dialColWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Center(
                          child: widget.gaugeWidget ??
                              _build3dClockGauge(
                                context: context,
                                color: effectiveColor,
                                isDark: isDark,
                                size: (dialColWidth - 4).clamp(100.0, 120.0),
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildTactileManageButton(
                        isDark: isDark,
                        colors: colors,
                        text: widget.actionButtonText,
                        onTap: widget.onActionTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (!widget.enableBreathing) {
            return RitmoCard.neumorphic(
              onTap: widget.onTap,
              margin: widget.margin,
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              backgroundColor: Color.lerp(colors.surfaceElevated, effectiveColor, isDark ? 0.05 : 0.03),
              borderColor: effectiveColor.withValues(alpha: isDark ? 0.60 : 0.45),
              borderWidth: 1.2,
              customShadows: [
                BoxShadow(
                  color: effectiveColor.withValues(alpha: isDark ? 0.36 : 0.24),
                  blurRadius: 32,
                  spreadRadius: 3.5,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: effectiveColor.withValues(alpha: isDark ? 0.45 : 0.32),
                  blurRadius: 16,
                  spreadRadius: 1.0,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.45)
                      : Color.lerp(colors.surfaceElevated, Colors.black, 0.16)!.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(3.5, 4.5),
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.95),
                  blurRadius: 7,
                  offset: const Offset(-2.5, -2.5),
                ),
              ],
              child: innerContent,
            );
          }

          return AnimatedBuilder(
            animation: _breathingAnim,
            builder: (context, child) {
              final t = _breathingAnim.value;
              final outerSpread = lerpDouble(2.0, 5.5, t)!;
              final outerBlur = lerpDouble(22.0, 40.0, t)!;
              final outerAlpha = lerpDouble(isDark ? 0.22 : 0.14, isDark ? 0.48 : 0.34, t)!;

              final rimSpread = lerpDouble(0.4, 2.0, t)!;
              final rimBlur = lerpDouble(12.0, 22.0, t)!;
              final rimAlpha = lerpDouble(isDark ? 0.30 : 0.20, isDark ? 0.58 : 0.42, t)!;

              final borderAlpha = lerpDouble(isDark ? 0.40 : 0.30, isDark ? 0.75 : 0.58, t)!;
              final surfaceTintAlpha = lerpDouble(isDark ? 0.03 : 0.02, isDark ? 0.08 : 0.05, t)!;

              return RitmoCard.neumorphic(
                onTap: widget.onTap,
                margin: widget.margin,
                borderRadius: BorderRadius.circular(28),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                backgroundColor: Color.lerp(colors.surfaceElevated, effectiveColor, surfaceTintAlpha),
                borderColor: effectiveColor.withValues(alpha: borderAlpha),
                borderWidth: 1.2,
                customShadows: [
                  // ۱. هاله بیرونی نرم تنفسی (Breathing Ambient Dispersion)
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: outerAlpha),
                    blurRadius: outerBlur,
                    spreadRadius: outerSpread,
                    offset: const Offset(0, 4),
                  ),
                  // ۲. هاله ریم متمرکز تنفسی (Breathing Rim Glow)
                  BoxShadow(
                    color: effectiveColor.withValues(alpha: rimAlpha),
                    blurRadius: rimBlur,
                    spreadRadius: rimSpread,
                    offset: const Offset(0, 2),
                  ),
                  // ۳. سایه فیزیکی نئومورفیک تیره عمیق
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : Color.lerp(colors.surfaceElevated, Colors.black, 0.16)!.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(3.5, 4.5),
                  ),
                  // ۴. سایه فیزیکی نئومورفیک لبه روشن
                  BoxShadow(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.95),
                    blurRadius: 7,
                    offset: const Offset(-2.5, -2.5),
                  ),
                ],
                child: child!,
              );
            },
            child: innerContent,
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  اجزای فیزیکی سه‌بعدی کارت (Tactile Physical Primitives)
  // ───────────────────────────────────────────────────────────────────────────

  /// پیل وضعیت فعال با نقطه سه‌بعدی سبز درخشان (متصل به رنگ فعال)
  Widget _buildTactileStatusPill({
    required bool isDark,
    required String statusLabel,
    required Color color,
  }) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color.lerp(color, Colors.black, 0.65)!,
                  Color.lerp(color, Colors.black, 0.82)!,
                ]
              : [
                  Color.lerp(color, Colors.white, 0.88)!,
                  Color.lerp(color, Colors.white, 0.74)!,
                ],
        ),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.40)
              : Colors.white,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFFB8C8D8).withValues(alpha: 0.50),
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-1.5, -1.5),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 3,
                  offset: const Offset(0.5, 0.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              fontFamily: 'Vazirmatn',
              color: isDark
                  ? Color.lerp(color, Colors.white, 0.55)!
                  : Color.lerp(color, Colors.black, 0.35)!,
            ),
          ),
        ],
      ),
    );
  }

  /// پیل نام قلمروی فعال با آیکون ماه (هماهنگ با سطح تم)
  Widget _buildTactileRealmPill({
    required bool isDark,
    required RitmoColors colors,
    required String label,
    required IconData icon,
    String? emoji,
    required Color color,
  }) {
    final shadowDarkColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Color.lerp(colors.surfaceElevated, Colors.black, 0.18)!.withValues(alpha: 0.45);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color.lerp(colors.surfaceElevated, Colors.white, 0.08)!,
                  Color.lerp(colors.surfaceElevated, Colors.black, 0.15)!,
                ]
              : [
                  Color.lerp(colors.surfaceElevated, Colors.white, 0.85)!,
                  colors.surfaceElevated,
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Color.lerp(colors.surfaceElevated, Colors.white, 0.70)!,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowDarkColor,
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-1.5, -1.5),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null && emoji.trim().isNotEmpty)
            Text(
              emoji.trim(),
              style: const TextStyle(fontSize: 12),
            )
          else
            Icon(
              icon,
              size: 12,
              color: colors.textSecondary,
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'Vazirmatn',
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// پیل فیزیکی بازه زمانی با محفظه آیکون ساعت (هماهنگ با سطح تم)
  Widget _buildTactileTimePill({
    required bool isDark,
    required RitmoColors colors,
    required String timeRange,
  }) {
    final shadowDarkColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Color.lerp(colors.surfaceElevated, Colors.black, 0.18)!.withValues(alpha: 0.45);

    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color.lerp(colors.surfaceElevated, Colors.white, 0.08)!,
                  Color.lerp(colors.surfaceElevated, Colors.black, 0.15)!,
                ]
              : [
                  Color.lerp(colors.surfaceElevated, Colors.white, 0.85)!,
                  colors.surfaceElevated,
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Color.lerp(colors.surfaceElevated, Colors.white, 0.70)!,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowDarkColor,
            offset: const Offset(2.5, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.clock,
            size: 13,
            color: colors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              timeRange,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                fontFamily: 'Vazirmatn',
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// پیل فیزیکی تایمر شمارش معکوس با گرادیان نرم نعنایی/پالت و بج آیکون ساعت شنی
  Widget _buildTactileCountdownPill({
    required bool isDark,
    required String remainingTime,
    required Color color,
  }) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color.lerp(color, Colors.black, 0.68)!,
                  Color.lerp(color, Colors.black, 0.84)!,
                ]
              : [
                  Color.lerp(color, Colors.white, 0.88)!,
                  Color.lerp(color, Colors.white, 0.74)!,
                ],
        ),
        border: Border.all(
          color: isDark
              ? color.withValues(alpha: 0.40)
              : Colors.white,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFFB5C6D6).withValues(alpha: 0.50),
            offset: const Offset(2.5, 3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          // بج مربع گوشه‌گرد سه‌بعدی ساعت شنی
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Color.lerp(color, Colors.black, 0.55)!,
                        Color.lerp(color, Colors.black, 0.75)!,
                      ]
                    : [
                        Color.lerp(color, Colors.white, 0.78)!,
                        Color.lerp(color, Colors.white, 0.60)!,
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.35)
                      : color.withValues(alpha: 0.20),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Icon(
              CupertinoIcons.hourglass,
              size: 11,
              color: isDark
                  ? Color.lerp(color, Colors.white, 0.65)!
                  : Color.lerp(color, Colors.black, 0.40)!,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'باقی‌مانده:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'Vazirmatn',
              color: isDark
                  ? Color.lerp(color, Colors.white, 0.70)!
                  : Color.lerp(color, Colors.black, 0.35)!,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              remainingTime,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                fontFamily: 'Vazirmatn',
                color: isDark
                    ? Colors.white
                    : Color.lerp(color, Colors.black, 0.60)!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// دکمه برجسته فیزیکی «مدیریت قلمرو >» با عمق لمس
  Widget _buildTactileManageButton({
    required bool isDark,
    required RitmoColors colors,
    required String text,
    required VoidCallback? onTap,
  }) {
    return RitmoNeuButton(
      height: 28,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: onTap ?? () {},
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                fontFamily: 'Vazirmatn',
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            CupertinoIcons.chevron_left,
            size: 10,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }

  /// ساعت و گیج سه‌بعدی با شیار فرورفته، کمان شیشه‌ای و ماه طلایی
  Widget _build3dClockGauge({
    required BuildContext context,
    required Color color,
    required bool isDark,
    required double size,
  }) {
    final colors = context.colors;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Color.lerp(colors.surfaceElevated, Colors.black, 0.25)!,
                  Color.lerp(colors.surfaceElevated, Colors.black, 0.05)!,
                ]
              : [const Color(0xFFE2E7F0), Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.6)
                : const Color(0xFFB8C5D6).withValues(alpha: 0.8),
            offset: const Offset(-3, -3),
            blurRadius: 7,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white,
            offset: const Offset(3, 3),
            blurRadius: 7,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // دیسک مرکزی برآمده ساعت
          Container(
            width: size * 0.70,
            height: size * 0.70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Color.lerp(colors.surfaceElevated, Colors.white, 0.08)!,
                        Color.lerp(colors.surfaceElevated, Colors.black, 0.15)!,
                      ]
                    : [Colors.white, const Color(0xFFE9EDF5)],
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.50)
                      : const Color(0xFFBAC7D7).withValues(alpha: 0.70),
                  offset: const Offset(3, 3.5),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white,
                  offset: const Offset(-2.5, -2.5),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                CupertinoIcons.moon_fill,
                size: size * 0.28,
                color: const Color(0xFFFBBF24), // ماه طلایی روشن
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
/// نوار پیشرفت نئومورفیک فرورفته با شیار سه‌بعدی و پرکننده درخشان (Ritmo Neu Progress Bar)
/// -----------------------------------------------------------------------------
class RitmoNeuProgressBar extends StatelessWidget {
  const RitmoNeuProgressBar({
    super.key,
    required this.progress,
    this.height = 12,
    this.color,
    this.showLabel = false,
    this.label,
    this.borderRadius,
    this.animate = true,
  });

  /// مقدار پیشرفت بین ۰.۰ تا ۱.۰
  final double progress;
  final double height;
  final Color? color;
  final bool showLabel;
  final String? label;
  final BorderRadius? borderRadius;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final effectiveColor = color ?? colors.primary;
    final clamped = progress.clamp(0.0, 1.0);
    final radius = borderRadius ?? BorderRadius.circular(height / 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel || label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              Text(
                toPersianDigits('${(clamped * 100).toInt()}٪'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: RitmoNeu.sunkenGradient(colors.surfaceSunken, isDark),
            boxShadow: RitmoNeu.sunkenShadows(isDark, blur: 5, distance: 2.0),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final fillWidth = (maxWidth * clamped).clamp(0.0, maxWidth);

              return Align(
                alignment: Alignment.centerRight, // RTL
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: fillWidth),
                  duration: animate
                      ? const Duration(milliseconds: 600)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  builder: (context, width, child) {
                    if (width <= 0) return const SizedBox.shrink();

                    return Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(effectiveColor, Colors.white, isDark ? 0.20 : 0.35)!,
                            effectiveColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: effectiveColor.withValues(alpha: isDark ? 0.45 : 0.35),
                            blurRadius: 7,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// -----------------------------------------------------------------------------
/// کارت اسکلت لودینگ نئومورفیک (Ritmo Card Skeleton)
/// با انیمیشن تنفس نوری روان بدون پرش ابعادی
/// -----------------------------------------------------------------------------
class RitmoCardSkeleton extends StatefulWidget {
  const RitmoCardSkeleton({
    super.key,
    this.height = 140,
    this.borderRadius,
    this.margin,
  });

  final double height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  State<RitmoCardSkeleton> createState() => _RitmoCardSkeletonState();
}

class _RitmoCardSkeletonState extends State<RitmoCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return RitmoCard.neumorphic(
      margin: widget.margin,
      borderRadius: widget.borderRadius ?? BorderRadius.circular(28),
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final opacity = _animation.value;
          final boneColor = isDark
              ? Colors.white.withValues(alpha: opacity * 0.08)
              : const Color(0xFFCAD4E2).withValues(alpha: opacity * 0.45);

          return SizedBox(
            height: widget.height - 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: boneColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 120,
                            decoration: BoxDecoration(
                              color: boneColor,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 180,
                            decoration: BoxDecoration(
                              color: boneColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: boneColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 28,
                      width: 80,
                      decoration: BoxDecoration(
                        color: boneColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    Container(
                      height: 28,
                      width: 110,
                      decoration: BoxDecoration(
                        color: boneColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
/// کارت حالت خالی سه‌بعدی نئومورفیک (Ritmo Neu Empty Card)
/// برای نمایش وضعیت‌های بدون داده یا بدون برنامه
/// -----------------------------------------------------------------------------
class RitmoNeuEmptyCard extends StatelessWidget {
  const RitmoNeuEmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = CupertinoIcons.tray_fill,
    this.actionLabel,
    this.onActionTap,
    this.height = 180,
    this.margin,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final double height;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return RitmoCard.neumorphic(
      margin: margin,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: SizedBox(
        height: height - 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // شیار دایره‌ای نئومورفیک با آیکون نرم
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RitmoNeu.sunkenGradient(colors.surfaceSunken, isDark),
                boxShadow: RitmoNeu.sunkenShadows(isDark, blur: 6, distance: 2.2),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 24,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 12),
              RitmoNeuButton(
                height: 32,
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onTap: onActionTap ?? () {},
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.add, size: 14, color: colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}




