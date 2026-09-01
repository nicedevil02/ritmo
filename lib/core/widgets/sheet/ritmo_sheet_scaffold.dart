import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// تنها پوسته رسمی و مرجع باز کردن شیت در کل برنامه (Ritmo Canonical Sheet Scaffold / Apple HIG Detents).
///
/// این ویجت تمامی رفتارهای استاندارد پنجره‌های پایینی ریتمو را تضمین می‌کند:
/// ۱. باز شدن با استاندارد Detents ریتمو (۹۴٪ تمام‌صفحه و بسته‌شدن هوشمند با کشیدن به پایین).
/// ۲. رفتار فنری و هپتیک فیزیکی اپل در نقاط توقف (`Snap Points`).
/// ۳. هدر متقارن رسمی با دکمه لمسی X، عنوان و زیرعنوان، یا هندل بار مینیمال (در صورت نبود عنوان).
/// ۴. هماهنگی بی‌نقص با کیبورد (`viewInsets.bottom`) برای جلوگیری از هرگونه سرریز.
/// ۵. پشتیبانی از فوتر چسبیده به پایین همراه با `SafeArea` برای دکمه‌های اقدام پایانی.
class RitmoSheetScaffold extends StatelessWidget {
  const RitmoSheetScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.semanticsLabel,
    required this.child,
    this.initialHeightFactor = 0.94,
    this.maxHeightFactor = 0.94,
    this.footer,
    this.childIsScrollable = false,
    this.isDismissible = true,
    this.scrollController,
  });

  /// عنوان رسمی هدر شیت (اختیاری؛ در صورت خالی بودن، فقط هندل بار نمایش داده می‌شود)
  final String? title;

  /// زیرعنوان توضیحی هدر
  final String? subtitle;

  /// برچسب دسترس‌پذیری برای صفحه‌خوان‌ها
  final String? semanticsLabel;

  /// بدنه اصلی محتوا
  final Widget child;

  /// سقف و شروع ارتفاع نسبت به صفحه (Ritmo Detents: 0.94)
  final double initialHeightFactor;
  final double maxHeightFactor;

  /// ویجت‌های چسبیده به پایین شیت که اسکرول نمی‌شوند (معمولاً دکمهٔ ثبت)
  final Widget? footer;

  /// اگر محتوا خودش اسکرول‌پذیر است (ListView / CustomScrollView)، این را true بگذارید
  final bool childIsScrollable;

  /// آیا کاربر می‌تواند با تب روی پس‌زمینه شیت را ببندد
  final bool isDismissible;

  final ScrollController? scrollController;

  /// متد مرجع و استاندارد باز کردن شیت در کل برنامه
  static Future<T?> present<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    String? title,
    String? subtitle,
    String? semanticsLabel,
    Widget? footer,
    bool childIsScrollable = false,
    bool isDismissible = true,
    bool enableDrag = true,
    double initialHeightFactor = 0.94,
    double maxHeightFactor = 0.94,
    AnimationController? transitionAnimationController,
  }) {
    RitmoHaptics.sheetOpen();
    AppleCardDeckHost.activeForegroundSheetExtent.value = initialHeightFactor;
    final controller = DraggableScrollableController();
    double lastSize = initialHeightFactor;

    controller.addListener(() {
      if (!controller.isAttached) return;
      final cur = controller.size;
      AppleCardDeckHost.activeForegroundSheetExtent.value = cur;
      if ((lastSize < 0.77 && cur >= 0.77) || (lastSize > 0.77 && cur <= 0.77)) {
        HapticFeedback.selectionClick();
      }
      lastSize = cur;
    });

    final effectiveSemantics = semanticsLabel ?? title ?? 'Sheet';

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      transitionAnimationController: transitionAnimationController,
      builder: (ctx) {
        const minSize = 0.0;
        final maxSize = maxHeightFactor.clamp(0.5, 0.96);
        final initialSize = initialHeightFactor.clamp(0.2, maxSize);
        return DraggableScrollableSheet(
          controller: controller,
          initialChildSize: initialSize,
          minChildSize: minSize,
          maxChildSize: maxSize,
          snap: true,
          expand: false,
          builder: (sheetContext, scrollController) => Semantics(
            label: effectiveSemantics,
            container: true,
            child: RitmoSheetScaffold(
              title: title,
              subtitle: subtitle,
              semanticsLabel: effectiveSemantics,
              isDismissible: isDismissible,
              initialHeightFactor: initialHeightFactor,
              maxHeightFactor: maxHeightFactor,
              footer: footer,
              childIsScrollable: childIsScrollable,
              scrollController: scrollController,
              child: builder(sheetContext),
            ),
          ),
        );
      },
    ).then((result) {
      AppleCardDeckHost.activeForegroundSheetExtent.value = 0.60;
      RitmoHaptics.sheetClose();
      return result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = context.isDark;
    final media = MediaQuery.of(context);
    final m = context.metrics;
    final sheetRadius = BorderRadius.vertical(
      top: Radius.circular(m.radiusHero),
    );

    final hasHeader = title != null && title!.isNotEmpty;

    final sheetContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Drag Handle Bar
        Center(
          child: Container(
            margin: EdgeInsets.only(
              top: m.spaceMd,
              bottom: hasHeader ? m.spaceXs : m.spaceMd,
            ),
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: colors.textPrimary.withValues(alpha: isDarkMode ? 0.18 : 0.22),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),

        // Canonical Symmetrical Header Row (if title provided)
        if (hasHeader) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: m.spaceLg,
              vertical: m.spaceSm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Leading (Right in RTL): Circular Tactile Close (X) Button
                GestureDetector(
                  onTap: () {
                    RitmoHapticsPolicy.tap();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? colors.surfaceElevated.withValues(alpha: 0.85)
                          : colors.textPrimary.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode
                            ? colors.border.withValues(alpha: 0.35)
                            : colors.border.withValues(alpha: 0.15),
                        width: 0.85,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                ),

                // Center: Title + Subtitle
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title!,
                        textAlign: TextAlign.center,
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: RitmoTextStyles.caption(
                            colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing (Left in RTL): Symmetrical Spacer
                const SizedBox(width: 34, height: 34),
              ],
            ),
          ),
          Divider(color: colors.divider, height: 1),
        ],

        // Scrollable or Flexible Body Content
        Flexible(
          child: childIsScrollable
              ? Padding(
                  padding: EdgeInsets.all(hasHeader ? m.spaceXl : m.spaceMd),
                  child: child,
                )
              : SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(hasHeader ? m.spaceXl : m.spaceMd),
                  child: child,
                ),
        ),

        // Optional Sticky Footer
        if (footer != null) ...[
          Divider(color: colors.divider, height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: m.spaceXl,
                vertical: m.spaceMd,
              ),
              child: footer,
            ),
          ),
        ],
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: RitmoGlassSheet(
          borderRadius: sheetRadius,
          child: Material(
            type: MaterialType.transparency,
            child: sheetContent,
          ),
        ),
      ),
    );
  }
}

/// Wraps any screen or navigation shell to provide the authentic Apple iOS Card Deck
/// background transformation (4.5% scale-down at 60% up to 8.0% at 95%, 20dp rounded top corners,
/// occlusion-aware visible-only dimming overlay, and upward peek translation) when a modal sheet is pushed on top.
class AppleCardDeckHost extends StatelessWidget {
  final Widget child;
  final Animation<double>? animation;
  final ValueNotifier<double>? foregroundExtentNotifier;
  final double topCornerRadius; // 30.0

  /// Global reactive coordinator for foreground sheet extent (0.0 to 1.0)
  static final ValueNotifier<double> activeForegroundSheetExtent = ValueNotifier<double>(0.60);

  const AppleCardDeckHost({
    super.key,
    required this.child,
    this.animation,
    this.foregroundExtentNotifier,
    this.topCornerRadius = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final effectiveAnim = animation ?? route?.secondaryAnimation;

    if (effectiveAnim == null) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildTransform(double progress, double extent, Widget staticChild) {
      final clampedExtent = extent.clamp(0.0, 1.0);

      // Normalized progress between 60% and 95%
      final tExtent = ((clampedExtent - 0.60) / (0.95 - 0.60)).clamp(0.0, 1.0);

      // Continuous Lerp Scaling: 4.5% at 60% up to 8.0% at 95%, smoothly returning to 0% if pulled down below 60%
      final scaleFactorBelow60 = clampedExtent < 0.60 ? (clampedExtent / 0.60).clamp(0.0, 1.0) : 1.0;
      final targetScaleDown = (0.045 + (0.035 * tExtent)) * scaleFactorBelow60;
      final scale = progress <= 0.0 ? 1.0 : 1.0 - (targetScaleDown * progress);

      // Fixed Static Corner Radius (locked at 30px)
      final radius = topCornerRadius;
      final clipBorderRadius = BorderRadius.vertical(top: Radius.circular(radius));

      // Top Peek Y-Shift: -10px at 60% to -16px at 95%
      final targetShift = (10.0 + (6.0 * tExtent)) * scaleFactorBelow60;
      final translateY = progress <= 0.0 ? 0.0 : -targetShift * progress;

      // Visible-Only Scrim Height: exactly (1.0 - extent)
      final rawVisibleHeight = MediaQuery.of(context).size.height * (1.0 - (clampedExtent * progress)).clamp(0.0, 1.0);
      // Soft feather buffer (+16px) ensures solid dark scrim covers 100% of visible space
      // while the soft gradient feathering fades seamlessly behind the foreground sheet's header.
      final visibleScrimHeight = (rawVisibleHeight + (progress > 0.001 ? 16.0 : 0.0)).clamp(0.0, MediaQuery.of(context).size.height);

      // Dynamic Scrim Density / Opacity based on foreground extent:
      // At 60%: standard nominal opacity (1.0x)
      // At 95%: deep focus opacity (1.50x, +50% density)
      // Pulled below 60% down to 0%: opacity fades linearly and melts away to 0.0!
      final double extentOpacityFactor;
      if (clampedExtent <= 0.60) {
        extentOpacityFactor = (clampedExtent / 0.60).clamp(0.0, 1.0);
      } else {
        extentOpacityFactor = 1.0 + (0.50 * tExtent);
      }

      final baseAlpha = isDark ? 0.42 : 0.22;
      final effectiveAlpha = (baseAlpha * progress * extentOpacityFactor).clamp(0.0, 1.0);
      final dimColor = Colors.black.withValues(alpha: effectiveAlpha);

      final borderColor = isDark
          ? const Color(0xFF94A3B8).withValues(alpha: (0.16 * progress).clamp(0.0, 1.0))
          : Colors.white.withValues(alpha: (0.70 * progress).clamp(0.0, 1.0));
      final borderWidth = isDark ? 0.9 : 1.0;

      return Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: progress <= 0.0 ? BorderRadius.zero : clipBorderRadius,
            clipBehavior: progress <= 0.0 ? Clip.none : Clip.antiAlias,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                staticChild,

                // 1. Occlusion-Aware Visible-Band Scrim with soft feathering & exact matching rounded corners
                // ONLY dims the visible band above the foreground sheet,
                // leaving the area behind the foreground sheet 100% pristine.
                if (progress > 0.001 && rawVisibleHeight > 0.001)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: ClipRRect(
                        borderRadius: clipBorderRadius,
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          height: visibleScrimHeight,
                          decoration: BoxDecoration(
                            borderRadius: clipBorderRadius,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                dimColor,
                                dimColor,
                                dimColor.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.88, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // 2. Preserved Crisp Glass Rim & Border (renders ON TOP of scrim)
                // Ensures the outer 1px white border and curve remain razor-sharp without dark occlusion artifacts.
                if (progress > 0.001)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: clipBorderRadius,
                          border: Border.all(
                            color: borderColor,
                            width: borderWidth,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final notifier = foregroundExtentNotifier ?? activeForegroundSheetExtent;
    return ListenableBuilder(
      listenable: Listenable.merge([effectiveAnim, notifier]),
      builder: (context, _) {
        return buildTransform(
          effectiveAnim.value,
          notifier.value,
          child,
        );
      },
    );
  }
}
