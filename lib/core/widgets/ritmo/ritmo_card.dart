// =============================================================================
//  ritmo_card.dart
//  سیستم مرجع واحد کارت‌های ریتمو (Ritmo Universal Card System)
//  مطابق استانداردهای Apple HIG Acrylic Surface، یکپارچه با ۱۲ پالت رنگی
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// گونه‌های متریال کارت مرجع ریتمو
enum RitmoCardVariant {
  /// متریال اکریلیک مات و اعلا — پیش‌فرض کارت‌های داشبورد و فید (Apple Acrylic)
  elevated,

  /// متریال شیشه کامل شفاف با بلور بلادرنگ — برای کارت‌های روی بنر و عناصر شناور
  glass,

  /// سطح فرورفته — برای اینپوت‌ها و بخش‌های متمرکز داخلی
  sunken,

  /// سطح بدون پرشدگی با خط کادر نرم — برای آیتم‌های ثانویه و دکمه‌های «+ افزودن»
  outlined,
}

/// کارت مرجع واحد سیستم طراحی ریتمو
class RitmoCard extends StatefulWidget {
  const RitmoCard({
    super.key,
    required this.child,
    this.variant = RitmoCardVariant.elevated,
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

  /// متد کارخانه‌ای سریع برای کارت‌های اکریلیک پیش‌فرض
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

  /// متد کارخانه‌ای برای کارت‌های فرورفته
  const factory RitmoCard.sunken({
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
  }) = _RitmoSunkenCard;

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

    // ۱. تعیین رنگ پس‌زمینه بر اساس گونه کارت و تم
    Color resolveBackgroundColor() {
      if (widget.backgroundColor != null) return widget.backgroundColor!;
      if (widget.isSelected) {
        return colors.primary.withValues(alpha: isDark ? 0.16 : 0.10);
      }

      switch (widget.variant) {
        case RitmoCardVariant.elevated:
          return colors.surfaceElevated;
        case RitmoCardVariant.glass:
          return isGlass
              ? colors.glassTint
              : (isDark ? colors.surfaceElevated : Colors.white);
        case RitmoCardVariant.sunken:
          return colors.surfaceSunken;
        case RitmoCardVariant.outlined:
          return Colors.transparent;
      }
    }

    // ۲. تعیین حاشیه تیتانیومی مات استاندارد
    Border resolveBorder() {
      final double width = widget.borderWidth ??
          (widget.isSelected
              ? 1.5
              : (highContrast ? 2.0 : (isDark ? 0.9 : 0.8)));

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

    // ۳. تعیین سایه عمیق تماسی بدون هاله رنگی
    List<BoxShadow> resolveShadows() {
      if (widget.customShadows != null) return widget.customShadows!;
      if (widget.variant == RitmoCardVariant.sunken ||
          widget.variant == RitmoCardVariant.outlined) {
        return const [];
      }

      if (isDark) {
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
          if (widget.isSelected)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.25),
              offset: const Offset(0, 2),
              blurRadius: 12,
            ),
        ];
      } else {
        return [
          BoxShadow(
            color: const Color(0xFF64748B).withValues(alpha: 0.08),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
          if (widget.isSelected)
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.18),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
        ];
      }
    }

    Widget content = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: resolveBackgroundColor(),
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

    // اعمال مارجین بیرونی در صورت وجود
    if (widget.margin != null) {
      content = Padding(padding: widget.margin!, child: content);
    }

    // اتصال به انیمیشن فشردن اپل و فیدبک لمسی
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
          scale: _isPressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 140),
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

class _RitmoSunkenCard extends RitmoCard {
  const _RitmoSunkenCard({
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
  }) : super(variant: RitmoCardVariant.sunken);
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
//  المان‌های اتمیک داخلی کارت‌ها (Internal Atomic Components)
// =============================================================================

/// هدر استاندارد کارت ریتمو با آیکون، تایتل، زیرعنوان و اکشن
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
    final effectiveIconColor = iconColor ?? colors.primary;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: effectiveIconColor.withValues(alpha: 0.30),
                  width: 0.8,
                ),
              ),
              child: Icon(icon, size: 17, color: effectiveIconColor),
            ),
            const SizedBox(width: 10),
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

/// کپسول متریک یا ردیف تعاملی داخل کارت ریتمو
class RitmoCardTile extends StatelessWidget {
  const RitmoCardTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final radius = borderRadius ?? BorderRadius.circular(14);

    Widget tile = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: backgroundColor ??
            (isDark
                ? colors.surfaceSunken.withValues(alpha: 0.35)
                : colors.surface.withValues(alpha: 0.85)),
        border: Border.all(
          color: borderColor ??
              (isDark
                  ? colors.border.withValues(alpha: 0.25)
                  : colors.divider),
          width: 0.7,
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle!,
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
          ?trailing,
        ],
      ),
    );

    if (onTap != null) {
      tile = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            RitmoHapticsPolicy.selection();
            onTap?.call();
          },
          borderRadius: radius,
          child: tile,
        ),
      );
    }

    return tile;
  }
}

/// نشانگر وضعیت یا برچسب متصل به رنگ‌های معنایی پالت
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isOutlined ? 0.8 : 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontFamily: 'Vazirmatn',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// خط جداکننده محو داخلی برای بخش‌بندی کارت‌ها
class RitmoCardDivider extends StatelessWidget {
  const RitmoCardDivider({super.key, this.margin = const EdgeInsets.symmetric(vertical: 10)});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Padding(
      padding: margin,
      child: Divider(
        height: 1,
        thickness: 0.8,
        color: isDark ? colors.border.withValues(alpha: 0.20) : colors.divider,
      ),
    );
  }
}

