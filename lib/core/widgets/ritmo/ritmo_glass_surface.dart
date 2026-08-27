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

    final defaultShadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ]
        : [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: defaultShadows,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: effectiveRadius,
              gradient: border == null
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        isDark
                            ? Colors.white.withValues(alpha: 0.36)
                            : Colors.white.withValues(alpha: 0.85),
                        isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.25),
                      ],
                    )
                  : null,
              border: border,
            ),
            padding: border == null ? const EdgeInsets.all(1.2) : null,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: colors.glassTint,
                borderRadius: effectiveRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.40),
                    isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white.withValues(alpha: 0.10),
                  ],
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
      ),
    );
  }
}
