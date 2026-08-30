import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Single unified primitive for bottom sheets across the application with Apple HIG detents.
class RitmoSheetScaffold extends StatelessWidget {
  final String semanticsLabel;
  final Widget child;
  final bool isDismissible;
  final double initialHeightFactor;
  final double maxHeightFactor;
  final ScrollController? scrollController;

  const RitmoSheetScaffold({
    super.key,
    required this.semanticsLabel,
    required this.child,
    this.isDismissible = true,
    this.initialHeightFactor = 0.60,
    this.maxHeightFactor = 0.94,
    this.scrollController,
  });

  /// Present a bottom sheet using RitmoSheetScaffold with Apple Detents (60% -> 95%).
  static Future<T?> present<T>({
    required BuildContext context,
    required String semanticsLabel,
    required WidgetBuilder builder,
    bool isDismissible = true,
    double initialHeightFactor = 0.60,
    double maxHeightFactor = 0.95,
    AnimationController? transitionAnimationController,
  }) {
    RitmoHaptics.sheetOpen();
    final controller = DraggableScrollableController();
    double lastSize = initialHeightFactor;

    controller.addListener(() {
      if (!controller.isAttached) return;
      final cur = controller.size;
      if ((lastSize < 0.77 && cur >= 0.77) || (lastSize > 0.77 && cur <= 0.77)) {
        HapticFeedback.selectionClick();
      }
      lastSize = cur;
    });

    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: isDismissible,
      transitionAnimationController: transitionAnimationController,
      builder: (ctx) => DraggableScrollableSheet(
        controller: controller,
        initialChildSize: initialHeightFactor.clamp(0.2, 1.0),
        minChildSize: 0.35,
        maxChildSize: maxHeightFactor.clamp(0.5, 0.96),
        snap: true,
        snapSizes: [
          initialHeightFactor.clamp(0.2, 1.0),
          maxHeightFactor.clamp(0.5, 0.96),
        ],
        expand: false,
        builder: (context, scrollController) => Semantics(
          label: semanticsLabel,
          container: true,
          child: RitmoSheetScaffold(
            semanticsLabel: semanticsLabel,
            isDismissible: isDismissible,
            initialHeightFactor: initialHeightFactor,
            maxHeightFactor: maxHeightFactor,
            scrollController: scrollController,
            child: builder(context),
          ),
        ),
      ),
    ).then((result) {
      RitmoHaptics.sheetClose();
      return result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = context.isDark;
    final media = MediaQuery.of(context);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 4.5,
                width: 38,
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: isDarkMode ? 0.18 : 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );

    final sheetBody = Material(
      type: MaterialType.transparency,
      child: content,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: RitmoGlassSheet(
          borderRadius: sheetRadius,
          child: sheetBody,
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
  final double topCornerRadius; // 20.0

  /// Global reactive coordinator for foreground sheet extent (0.0 to 1.0)
  static final ValueNotifier<double> activeForegroundSheetExtent = ValueNotifier<double>(0.60);

  const AppleCardDeckHost({
    super.key,
    required this.child,
    this.animation,
    this.foregroundExtentNotifier,
    this.topCornerRadius = 20.0,
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
      if (progress <= 0.0) {
        return staticChild;
      }

      final clampedExtent = extent.clamp(0.0, 1.0);

      // Normalized progress between 60% and 95%
      final tExtent = ((clampedExtent - 0.60) / (0.95 - 0.60)).clamp(0.0, 1.0);

      // Continuous Lerp Scaling: 4.5% at 60% up to 8.0% at 95%, smoothly returning to 0% if pulled down below 60%
      final scaleFactorBelow60 = clampedExtent < 0.60 ? (clampedExtent / 0.60).clamp(0.0, 1.0) : 1.0;
      final targetScaleDown = (0.045 + (0.035 * tExtent)) * scaleFactorBelow60;
      final scale = 1.0 - (targetScaleDown * progress);

      final radius = topCornerRadius * progress;

      // Top Peek Y-Shift: -10px at 60% to -16px at 95%
      final targetShift = (10.0 + (6.0 * tExtent)) * scaleFactorBelow60;
      final translateY = -targetShift * progress;



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

      return Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
            child: Stack(
              children: [
                staticChild,

                // Uniform Dynamic Depth Scrim (Native Apple iOS HIG Card Deck Stacking)
                // Covers the background card seamlessly with zero cut lines or split headers!
                if (effectiveAlpha > 0.001)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: dimColor,
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
