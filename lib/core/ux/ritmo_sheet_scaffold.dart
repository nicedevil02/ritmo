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
      containerWidget = ClipRRect(
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
