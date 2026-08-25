import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

/// Single unified primitive for bottom sheets across the application.
class RitmoSheetScaffold extends StatelessWidget {
  final String semanticsLabel;
  final Widget child;
  final bool isDismissible;
  final double maxHeightFactor;

  const RitmoSheetScaffold({
    super.key,
    required this.semanticsLabel,
    required this.child,
    this.isDismissible = true,
    this.maxHeightFactor = 0.9,
  });

  /// Present a bottom sheet using RitmoSheetScaffold.
  static Future<T?> present<T>({
    required BuildContext context,
    required String semanticsLabel,
    required WidgetBuilder builder,
    bool isDismissible = true,
    double maxHeightFactor = 0.9,
  }) {
    RitmoHaptics.sheetOpen();
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: isDismissible,
      builder: (context) => Semantics(
        label: semanticsLabel,
        container: true,
        child: RitmoSheetScaffold(
          semanticsLabel: semanticsLabel,
          isDismissible: isDismissible,
          maxHeightFactor: maxHeightFactor,
          child: builder(context),
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
    final maxHeight = media.size.height * maxHeightFactor;
    const sheetRadius = BorderRadius.all(Radius.circular(28));

    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 5,
                width: 40,
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: 0.12),
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
        constraints: BoxConstraints(maxHeight: maxHeight),
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
      containerWidget = Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
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
        child: Container(
          margin: const EdgeInsets.all(16),
          child: containerWidget,
        ),
      ),
    );
  }
}
