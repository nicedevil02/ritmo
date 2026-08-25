import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_behavior.dart';
import 'package:ritmo/core/theme/ritmo_colors.dart';
import 'package:ritmo/core/theme/tokens/ritmo_metrics.dart';

/// متریال شیشه‌ای لایه‌ای — RFC «Ritmo Aurora» §۵.۲
///
/// تنها مسیر مجاز برای سطوح شفاف: سه تیر توکنی، tint از پالت (هرگز سفید
/// خام)، هایلایت اسپکیولار روی لبه‌ی بالا، و تنزل خودکار به سطح مات وقتی
/// شفافیت مجاز نیست.
///
/// بودجه‌ی سخت: حداکثر یک لایه‌ی بلور در هر فریم، هرگز داخل لیست اسکرول‌شو.

enum RitmoMaterialTier { thin, regular, thick }

@immutable
class RitmoMaterialSpec {
  const RitmoMaterialSpec({
    required this.sigma,
    required this.tintAlpha,
    required this.highlightAlpha,
    required this.opaqueFallback,
  });

  /// قدرت بلور: thin = 8 · regular = 18 · thick = 32
  final double sigma;

  /// شدت tint گرفته از پالت (glassTint) — نه رنگ خام.
  final double tintAlpha;

  /// شدت هایلایت اسپکیولار روی لبه‌ی بالا.
  final double highlightAlpha;

  /// رنگ جایگزین وقتی شفافیت مجاز نیست (دسترس‌پذیری یا دستگاه ضعیف).
  final Color opaqueFallback;
}

/// نگاشت تیرها به مشخصات — در `RitmoTheme.build` به‌عنوان [ThemeExtension]
/// ثبت می‌شود و با `context.materials` خوانده می‌شود.
class RitmoMaterials extends ThemeExtension<RitmoMaterials> {
  const RitmoMaterials({
    required this.thin,
    required this.regular,
    required this.thick,
  });

  final RitmoMaterialSpec thin;
  final RitmoMaterialSpec regular;
  final RitmoMaterialSpec thick;

  factory RitmoMaterials.fromColors(
    RitmoColors? colors, {
    double blurSigma = 20.0,
    int opacityPercent = 35,
  }) {
    // وقتی تم ثبت نشده (مثل تست‌های ایزوله)، یک سطح مات تیره‌ی خنثی برمی‌گردانیم.
    final fallback = colors?.surfaceElevated ?? const Color(0xFF14171C);
    final baseAlpha = (opacityPercent / 100.0).clamp(0.05, 0.95);
    return RitmoMaterials(
      thin: RitmoMaterialSpec(
        sigma: (blurSigma * 0.6).clamp(0.0, 50.0),
        tintAlpha: (baseAlpha * 0.8).clamp(0.05, 0.95),
        highlightAlpha: 0.16,
        opaqueFallback: fallback,
      ),
      regular: RitmoMaterialSpec(
        sigma: blurSigma.clamp(0.0, 50.0),
        tintAlpha: baseAlpha,
        highlightAlpha: 0.22,
        opaqueFallback: fallback,
      ),
      thick: RitmoMaterialSpec(
        sigma: (blurSigma * 1.5).clamp(0.0, 60.0),
        tintAlpha: (baseAlpha * 1.3).clamp(0.05, 0.95),
        highlightAlpha: 0.28,
        opaqueFallback: fallback,
      ),
    );
  }

  RitmoMaterialSpec of(RitmoMaterialTier tier) => switch (tier) {
    RitmoMaterialTier.thin => thin,
    RitmoMaterialTier.regular => regular,
    RitmoMaterialTier.thick => thick,
  };

  @override
  RitmoMaterials copyWith({
    RitmoMaterialSpec? thin,
    RitmoMaterialSpec? regular,
    RitmoMaterialSpec? thick,
  }) {
    return RitmoMaterials(
      thin: thin ?? this.thin,
      regular: regular ?? this.regular,
      thick: thick ?? this.thick,
    );
  }

  @override
  RitmoMaterials lerp(RitmoMaterials? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// تیر دستگاه — پرچم ساده‌ی «دستگاه ضعیف» برای تنزل خودکار متریال.
/// در ریشه‌ی اپ تزریق می‌شود؛ پیش‌فرض (نبودن ویجت) یعنی دستگاه توانمند.
class RitmoDeviceTier extends InheritedWidget {
  const RitmoDeviceTier({
    super.key,
    required this.isLowEnd,
    required super.child,
  });

  final bool isLowEnd;

  static RitmoDeviceTier? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RitmoDeviceTier>();

  static bool isLowEndOf(BuildContext context) =>
      maybeOf(context)?.isLowEnd ?? false;

  @override
  bool updateShouldNotify(RitmoDeviceTier oldWidget) =>
      isLowEnd != oldWidget.isLowEnd;
}

/// کلیپر گوشه‌ی پیوسته (squircle) — همان منحنی توکن `RitmoRadius.squircle`
/// با ضریب ۲٫۳۵، ولی به‌شکل [CustomClipper] برای استفاده با [ClipPath].
abstract final class RitmoShapes {
  static CustomClipper<Path> squircleClipper(double radius) =>
      _SquircleClipper(radius);
}

class _SquircleClipper extends CustomClipper<Path> {
  const _SquircleClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) {
    final shape = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius * 2.35),
    );
    return shape.getOuterPath(Offset.zero & size);
  }

  @override
  bool shouldReclip(_SquircleClipper oldClipper) => radius != oldClipper.radius;
}

/// پریمیتیو یگانه‌ی سطح شیشه‌ای. جایگزین `RitmoGlassCard` و
/// `RitmoGlassCardLight` و `RitmoGlassSurface` می‌شود (نگاشت مهاجرت: P2).
class RitmoMaterial extends StatelessWidget {
  const RitmoMaterial({
    super.key,
    required this.tier,
    required this.child,
    this.radius = 16, // == RitmoRadius.card
  });

  final RitmoMaterialTier tier;
  final Widget child;

  /// شعاع گوشه — پیش‌فرض همان توکن کارت (۱۶).
  final double radius;

  @override
  Widget build(BuildContext context) {
    final spec = context.materials.of(tier);
    final tint = Theme.of(context).extension<RitmoColors>()?.glassTint;
    final effectiveRadius = radius == 16
        ? (Theme.of(context).extension<RitmoMetrics>()?.radiusCard ?? 16.0)
        : radius;

    // تنزل خودکار: دسترس‌پذیری + دستگاه ضعیف
    final reduceTransparency =
        Theme.of(context).extension<RitmoBehavior>()?.reduceTransparency ??
        false;
    final degrade =
        reduceTransparency ||
        MediaQuery.highContrastOf(context) ||
        RitmoDeviceTier.isLowEndOf(context);

    if (degrade) {
      return _OpaqueSurface(
        color: spec.opaqueFallback,
        radius: effectiveRadius,
        child: child,
      );
    }

    return RepaintBoundary(
      child: ClipPath(
        clipper: RitmoShapes.squircleClipper(effectiveRadius),
        child: BackdropFilter(
          // صریح، برای جلوگیری از نشتی و هاله‌ی رنگی در لبه‌ها.
          filter: ImageFilter.blur(
            sigmaX: spec.sigma,
            sigmaY: spec.sigma,
            tileMode: TileMode.clamp,
          ),
          child: _TintAndHighlight(spec: spec, tint: tint, child: child),
        ),
      ),
    );
  }
}

class _OpaqueSurface extends StatelessWidget {
  const _OpaqueSurface({
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: RitmoShapes.squircleClipper(radius),
      child: ColoredBox(
        color: color,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

class _TintAndHighlight extends StatelessWidget {
  const _TintAndHighlight({
    required this.spec,
    required this.tint,
    required this.child,
  });

  final RitmoMaterialSpec spec;
  final Color? tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (tint ?? Colors.white).withValues(alpha: spec.tintAlpha),
      ),
      child: DecoratedBox(
        // هایلایت اسپکیولار: گرادیان کوتاه از بالا به پایین.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: spec.highlightAlpha),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.35],
          ),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

extension RitmoMaterialsContext on BuildContext {
  /// دسترسی به مشخصات متریال؛ اگر روی تم ثبت نشده باشد، از رنگ‌های فعلی
  /// (و در بدترین حالت از یک سطح خنثی) مشتق می‌شود.
  RitmoMaterials get materials {
    final registered = Theme.of(this).extension<RitmoMaterials>();
    if (registered != null) return registered;
    return RitmoMaterials.fromColors(Theme.of(this).extension<RitmoColors>());
  }
}
