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
    this.initialHeightFactor = 0.94,
    this.maxHeightFactor = 0.94,
    this.scrollController,
  });

  /// Present a bottom sheet using RitmoSheetScaffold with Ritmo Detents (94%).
  static Future<T?> present<T>({
    required BuildContext context,
    required String semanticsLabel,
    required WidgetBuilder builder,
    bool isDismissible = true,
    double initialHeightFactor = 0.94,
    double maxHeightFactor = 0.94,
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
      enableDrag: true,
      isDismissible: isDismissible,
      transitionAnimationController: transitionAnimationController,
      builder: (ctx) => DraggableScrollableSheet(
        controller: controller,
        initialChildSize: initialHeightFactor.clamp(0.2, 1.0),
        minChildSize: 0.0,
        maxChildSize: maxHeightFactor.clamp(0.5, 0.96),
        snap: true,
        snapSizes: [
          0.0,
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
      final visibleTopHeightFactor = (1.0 - (clampedExtent * progress)).clamp(0.0, 1.0);

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
                if (progress > 0.001 && visibleTopHeightFactor > 0.001)
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
                          height: MediaQuery.of(context).size.height * visibleTopHeightFactor,
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
                              stops: const [0.0, 0.94, 1.0],
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
