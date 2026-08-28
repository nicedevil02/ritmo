import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

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

  /// Present a bottom sheet using RitmoSheetScaffold with Apple Detents (60% -> 94%).
  static Future<T?> present<T>({
    required BuildContext context,
    required String semanticsLabel,
    required WidgetBuilder builder,
    bool isDismissible = true,
    double initialHeightFactor = 0.60,
    double maxHeightFactor = 0.94,
  }) {
    RitmoHaptics.sheetOpen();
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: isDismissible,
      builder: (ctx) => DraggableScrollableSheet(
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
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    final media = MediaQuery.of(context);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

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
                  color: colors.textPrimary.withValues(alpha: 0.18),
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

    Widget containerWidget;
    if (!isGlass) {
      containerWidget = Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDarkMode ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    } else {
      containerWidget = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: sheetRadius,
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withValues(alpha: 0.35)
                  : colors.primary.withValues(alpha: 0.08),
              offset: const Offset(0, -3),
              blurRadius: 16,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: sheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.glassTint,
                borderRadius: sheetRadius,
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.0,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: sheetRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.20),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
                child: sheetBody,
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: containerWidget,
      ),
    );
  }
}

/// Wraps any screen or navigation shell to provide the authentic Apple iOS 26 Card Deck
/// background transformation (7% scale-down, 18dp rounded top corners, dimming overlay,
/// parallax shift) when a modal sheet is pushed on top of it.
class AppleCardDeckHost extends StatelessWidget {
  final Widget child;
  final Animation<double>? animation;
  final double scaleDownFactor; // 0.07 -> scale reaches 0.93
  final double topCornerRadius; // 18.0
  final double maxDimAlpha; // 0.25

  final double shiftUpDistance; // 18.0pt upward shift for Apple deck peeking

  const AppleCardDeckHost({
    super.key,
    required this.child,
    this.animation,
    this.scaleDownFactor = 0.07,
    this.topCornerRadius = 20.0,
    this.maxDimAlpha = 0.25,
    this.shiftUpDistance = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final effectiveAnim = animation ?? route?.secondaryAnimation;

    if (effectiveAnim == null) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: effectiveAnim,
      builder: (context, staticChild) {
        final progress = effectiveAnim.value;
        if (progress <= 0.0) {
          return staticChild!;
        }

        final scale = 1.0 - (scaleDownFactor * progress);
        final radius = topCornerRadius * progress;
        final translateY = -shiftUpDistance * progress;

        // Option 3: Silver Frost Sheen (Clean Apple Frost instead of muddy black)
        final frostGradient = isDark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: (0.35 * progress).clamp(0.0, 1.0)),
                  const Color(0xFF0F172A).withValues(alpha: (0.20 * progress).clamp(0.0, 1.0)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.15, 0.50],
              )
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: (0.40 * progress).clamp(0.0, 1.0)),
                  const Color(0xFFF1F5F9).withValues(alpha: (0.25 * progress).clamp(0.0, 1.0)),
                  const Color(0xFFE2E8F0).withValues(alpha: (0.10 * progress).clamp(0.0, 1.0)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.12, 0.35, 0.65],
              );

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
              child: Stack(
                children: [
                  staticChild!,
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: frostGradient,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
