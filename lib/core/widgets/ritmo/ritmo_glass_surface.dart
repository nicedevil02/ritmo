// Ritmo GlassSurface — پیاده‌سازی واحد و مرکزی سطوح شیشه‌ای Ritmo
// جایگزین RitmoGlassCard, RitmoGlassCardLight, FrostedGlassCard و _buildGlassCard

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class RitmoGlassSurface extends StatelessWidget {
  const RitmoGlassSurface({
    super.key,
    required this.child,
    this.blurSigma,
    this.borderRadius,
    this.padding,
    this.border,
  });

  final Widget child;
  final double? blurSigma;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final isDark = context.isDark;

    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(RitmoRadius.card);

    if (!context.isGlassEnabled || highContrast) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: effectiveRadius,
          border:
              border ??
              Border.all(
                color: highContrast
                    ? colors.textPrimary
                    : (isDark ? colors.border : colors.divider),
                width: highContrast ? 2.0 : 1.0,
              ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: effectiveRadius,
          child: child,
        ),
      );
    }

    final effectiveBlur =
        (blurSigma ?? context.glassBlurSigma).clamp(0.0, 50.0);

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: effectiveRadius,
            border:
                border ??
                Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.65),
                  width: 1.0,
                ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: effectiveRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: effectiveRadius,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
