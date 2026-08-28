// lib/core/widgets/ritmo_module_app_bar.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class RitmoModuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RitmoModuleAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.statusBadge,
    this.actions,
    this.onBack,
    this.density,
    this.preferredHeight,
    this.showBackButton,
  });

  /// Factory constructor guaranteeing exact preferredSize pixel equality with BuildContext metrics.
  factory RitmoModuleAppBar.fromContext({
    Key? key,
    required BuildContext context,
    required String title,
    String? subtitle,
    Widget? statusBadge,
    List<Widget>? actions,
    VoidCallback? onBack,
    bool? showBackButton,
  }) {
    final m = context.metrics;
    return RitmoModuleAppBar(
      key: key,
      title: title,
      subtitle: subtitle,
      statusBadge: statusBadge,
      actions: actions,
      onBack: onBack,
      showBackButton: showBackButton,
      preferredHeight: m.rowHeight + m.spaceSm,
    );
  }

  final String title;
  final String? subtitle;
  final Widget? statusBadge;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final RitmoDensityLevel? density;
  final double? preferredHeight;
  final bool? showBackButton;

  @override
  Size get preferredSize {
    if (preferredHeight != null) return Size.fromHeight(preferredHeight!);
    final m = RitmoMetrics.of(density ?? RitmoUiScale.defaultDensity);
    return Size.fromHeight(m.rowHeight + m.spaceSm);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final m = context.metrics;
    final effectiveHeight = preferredHeight ?? (m.rowHeight + m.spaceSm); // 60/64/72/78
    final bool shouldShowBack = showBackButton ?? Navigator.canPop(context);

    final barContent = SafeArea(
      bottom: false,
      child: Container(
        height: effectiveHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (shouldShowBack) ...[
              // Back Button (Min touchTarget)
              Semantics(
                button: true,
                label: 'بازگشت',
                child: InkWell(
                  onTap: onBack ?? () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(m.touchTarget / 2),
                  child: Container(
                    width: m.touchTarget,
                    height: m.touchTarget,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: m.iconLg,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: m.spaceSm),
            ],

            // Title and Subtitle / Status Badge
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: RitmoTextStyles.titleMedium(
                            colors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (statusBadge != null) ...[
                        SizedBox(width: m.spaceSm),
                        statusBadge!,
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Flexible(
                      child: Text(
                        subtitle!,
                        style: RitmoTextStyles.badge(
                          colors.textSecondary.withValues(alpha: 0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action Buttons
            ...?actions,
          ],
        ),
      ),
    );

    if (!isGlass || highContrast) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            border: Border(
              bottom: BorderSide(
                color: highContrast
                    ? colors.textPrimary
                    : (isDark ? colors.border : colors.divider),
                width: highContrast ? 2.0 : 0.8,
              ),
            ),
          ),
          child: barContent,
        ),
      );
    }

    final effectiveBlur = context.glassBlurSigma.clamp(0.0, 50.0);
    final tintColor = colors.glassTint;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
          child: Container(
            decoration: BoxDecoration(
              color: tintColor,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : colors.border.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.40],
              ),
            ),
            child: barContent,
          ),
        ),
      ),
    );
  }
}
