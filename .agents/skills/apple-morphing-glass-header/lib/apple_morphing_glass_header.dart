import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// {@template apple_morphing_glass_header}
/// Production-grade Apple Dynamic Morphing Glass Capsule Header.
///
/// Features:
/// 1. Unified Single Morphing Capsule: Header bar, morphing title, live subtitle,
///    actions, and segmented tabs live in a single continuous frosted glass capsule.
/// 2. Fluid Continuous Morphing: Large title lerps seamlessly into an inline header title.
/// 3. Elastic Rubber-Banding Overscroll: Pulling down at rest expands header height
///    and scales title up with 120 FPS zero-latency response.
/// 4. Quick-Return Liquid Tabs: Tabs collapse on scrolling down and expand on forward scroll.
/// 5. Adaptive Frosted Glass: BackdropFilter blur, dynamic opacity, and high-contrast support.
/// {@endtemplate}
class AppleMorphingGlassHeader extends StatelessWidget {
  /// The title text of the screen.
  final String title;

  /// Optional subtitle or live status summary.
  final String? subtitle;

  /// Current scroll offset in pixels (can be negative for overscroll).
  final double scrollOffset;

  /// Whether segmented tabs are currently expanded in collapsed capsule state.
  final bool isTabsExpanded;

  /// Distance in pixels over which the full-size header morphs into a compact capsule.
  final double collapseDistance;

  /// Callback when the back navigation button is tapped. If null, no back button is rendered.
  final VoidCallback? onBack;

  /// Trailing action buttons (e.g. search, add, settings, AI assistant).
  final List<Widget>? actions;

  /// Optional segmented tab control embedded inside the header capsule.
  final Widget? tabs;

  /// Optional custom leading widget replacing default back button.
  final Widget? leading;

  /// Optional status badge shown next to title or subtitle.
  final Widget? statusBadge;

  /// Primary accent tint color for glass borders and active states.
  final Color? accentColor;

  /// Glass background tint color (defaults to surface with opacity).
  final Color? glassColor;

  /// Maximum blur sigma for BackdropFilter (default: 24.0).
  final double blurSigma;

  /// Base resting height without tabs (default: 96.0).
  final double baseRestingHeight;

  /// Rest height with tabs (default: 156.0).
  final double tabsRestingHeight;

  /// Compact capsule height (default: 54.0).
  final double compactHeight;

  /// Expanded capsule height with tabs (default: 108.0).
  final double expandedTabsHeight;

  const AppleMorphingGlassHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.scrollOffset,
    this.isTabsExpanded = true,
    this.collapseDistance = 55.0,
    this.onBack,
    this.actions,
    this.tabs,
    this.leading,
    this.statusBadge,
    this.accentColor,
    this.glassColor,
    this.blurSigma = 24.0,
    this.baseRestingHeight = 96.0,
    this.tabsRestingHeight = 156.0,
    this.compactHeight = 54.0,
    this.expandedTabsHeight = 108.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final highContrast = mediaQuery.highContrast;
    final topInset = mediaQuery.padding.top;

    final currentLeading = leading;
    final currentOnBack = onBack;
    final currentActions = actions;
    final currentTabs = tabs;
    final currentBadge = statusBadge;
    final currentSubtitle = subtitle;

    // -------------------------------------------------------------
    // 1. Elastic Overscroll Rubber-Banding Physics
    // -------------------------------------------------------------
    final isOverscrolling = scrollOffset < 0;
    final overscrollAmount = isOverscrolling ? (-scrollOffset).clamp(0.0, 200.0) : 0.0;
    final elasticStretch = overscrollAmount * 0.48;
    final elasticScale = 1.0 + (overscrollAmount * 0.0014).clamp(0.0, 0.12);

    // -------------------------------------------------------------
    // 2. Positive Scroll Collapse Progress (0.0 to 1.0)
    // -------------------------------------------------------------
    final effectivePositiveOffset = scrollOffset.clamp(0.0, 500.0);
    final rawT = (effectivePositiveOffset / collapseDistance).clamp(0.0, 1.0);
    final t = Curves.easeInOutCubic.transform(rawT);

    final hasTabs = currentTabs != null;
    final hasSubtitle = currentSubtitle != null;

    // -------------------------------------------------------------
    // 3. Dynamic Height Calculation
    // -------------------------------------------------------------
    final double targetHeight;
    if (t < 0.99) {
      final restingHeight = (hasTabs
              ? (hasSubtitle ? (tabsRestingHeight + 12.0) : tabsRestingHeight)
              : (hasSubtitle ? (baseRestingHeight + 16.0) : baseRestingHeight)) +
          elasticStretch;
      final activeCapsuleHeight = hasTabs ? expandedTabsHeight : compactHeight;
      targetHeight = lerpDouble(restingHeight, activeCapsuleHeight, t)!;
    } else {
      targetHeight = (hasTabs && isTabsExpanded) ? expandedTabsHeight : compactHeight;
    }

    // -------------------------------------------------------------
    // 4. Margins & Rounded Capsule Geometry
    // -------------------------------------------------------------
    final currentMarginH = lerpDouble(0.0, 10.0, t)!;
    final currentMarginTop = topInset + lerpDouble(2.0, 6.0, t)!;
    final currentRadius = lerpDouble(0.0, 27.0, t)!;

    final effectiveBlur = t * blurSigma.clamp(0.0, 50.0);

    // -------------------------------------------------------------
    // 5. Apple Liquid Glass Colors & Shadows
    // -------------------------------------------------------------
    final Color bgColor;
    final Border? border;
    final List<BoxShadow>? shadows;

    final effectiveAccent = accentColor ?? theme.colorScheme.primary;

    if (highContrast) {
      bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
      border = t > 0.05
          ? Border.all(
              color: isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC),
              width: 1.0,
            )
          : null;
      shadows = t > 0.2
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: t * 0.2),
                offset: Offset(0, 2 * t),
                blurRadius: 6 * t,
              ),
            ]
          : null;
    } else {
      final baseGlass = glassColor ??
          (isDark ? const Color(0xFF16181D) : const Color(0xFFF8FAFC));
      bgColor = baseGlass.withValues(
        alpha: (t * (isDark ? 0.78 : 0.86)).clamp(0.0, 0.95),
      );

      border = t > 0.05
          ? Border.all(
              color: (isDark
                      ? theme.colorScheme.primary.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.70))
                  .withValues(alpha: t),
              width: 0.9,
            )
          : null;

      shadows = t > 0.15
          ? [
              BoxShadow(
                color: (isDark
                    ? theme.colorScheme.primary.withValues(alpha: t * 0.16)
                    : theme.colorScheme.primary.withValues(alpha: t * 0.08)),
                offset: Offset(0, 3 * t),
                blurRadius: 16 * t,
              ),
              if (isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: t * 0.40),
                  offset: Offset(0, 2 * t),
                  blurRadius: 8 * t,
                ),
            ]
          : null;
    }

    // -------------------------------------------------------------
    // 6. Title, Subtitle & Action Coordinates
    // -------------------------------------------------------------
    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;

    final elasticScale = 1.0 + (overscrollAmount * 0.0014).clamp(0.0, 0.12);

    final titleBaseTop = 50.0 + (elasticStretch * 0.35);
    const titleInlineTop = 14.0;
    final titleTop = lerpDouble(titleBaseTop, titleInlineTop, t)!;
    final titleSideOffset = lerpDouble(14.0, (currentOnBack != null || currentLeading != null) ? 52.0 : 16.0, t)!;
    final titleFontSize = lerpDouble(27.0, 16.5, t)!;

    final subtitleOpacity = (1.0 - (2.4 * rawT)).clamp(0.0, 1.0);
    final subtitleTop = 86.0 + (elasticStretch * 0.58);

    final showTabsInCapsule = hasTabs && (t < 0.99 || isTabsExpanded);

    return Padding(
      padding: EdgeInsets.only(
        top: currentMarginTop,
        left: currentMarginH,
        right: currentMarginH,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(currentRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: effectiveBlur,
            sigmaY: effectiveBlur,
          ),
          child: AnimatedContainer(
            duration: (isOverscrolling || t < 0.99) ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeInOutCubic,
            height: targetHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(currentRadius),
              border: border,
              boxShadow: shadows,
              gradient: t > 0.05
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.08 * t),
                              Colors.white.withValues(alpha: 0.02 * t),
                              Colors.transparent,
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.75 * t),
                              Colors.white.withValues(alpha: 0.20 * t),
                              Colors.transparent,
                            ],
                      stops: isDark
                          ? const [0.0, 0.04, 0.35]
                          : const [0.0, 0.03, 0.45],
                    )
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // -------------------------------------------------------------
                // Layer A: Morphing Title (Large Title -> Inline Title)
                // -------------------------------------------------------------
                Positioned(
                  top: titleTop,
                  left: isRtl ? null : titleSideOffset,
                  right: isRtl ? titleSideOffset : null,
                  child: Transform.scale(
                    scale: elasticScale,
                    alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                        ),
                        if (currentBadge != null) ...[
                          const SizedBox(width: 8),
                          Opacity(
                            opacity: (1.0 - (1.5 * rawT)).clamp(0.0, 1.0),
                            child: currentBadge,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // -------------------------------------------------------------
                // Layer B: Subtitle (Smoothly Fades Out on Collapse)
                // -------------------------------------------------------------
                if (hasSubtitle && subtitleOpacity > 0.01)
                  Positioned(
                    top: subtitleTop,
                    left: 14.0,
                    right: 14.0,
                    child: Opacity(
                      opacity: subtitleOpacity,
                      child: Text(
                        currentSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),

                // -------------------------------------------------------------
                // Layer C: Leading / Back Action Button
                // -------------------------------------------------------------
                if (currentLeading != null)
                  Positioned(
                    top: 6,
                    left: isRtl ? null : 6,
                    right: isRtl ? 6 : null,
                    child: currentLeading,
                  )
                else if (currentOnBack != null)
                  Positioned(
                    top: 6,
                    left: isRtl ? null : 6,
                    right: isRtl ? 6 : null,
                    child: AppleVibrancyActionButton(
                      icon: isRtl ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_left,
                      onTap: currentOnBack,
                      tooltip: 'Back',
                    ),
                  ),

                // -------------------------------------------------------------
                // Layer D: Trailing Control Actions
                // -------------------------------------------------------------
                if (currentActions != null && currentActions.isNotEmpty)
                  Positioned(
                    top: 6,
                    left: isRtl ? 8 : null,
                    right: isRtl ? null : 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: currentActions,
                    ),
                  ),

                // -------------------------------------------------------------
                // Layer E: Quick-Return Segmented Liquid Tabs
                // -------------------------------------------------------------
                if (showTabsInCapsule)
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      opacity: (t < 0.99 || isTabsExpanded) ? 1.0 : 0.0,
                      child: currentTabs,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// {@template apple_vibrancy_action_button}
/// A frosted glass circular action button for headers and toolbars.
/// {@endtemplate}
class AppleVibrancyActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? iconColor;
  final Color? accentColor;
  final bool isSpecialAccent;
  final double size;

  const AppleVibrancyActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.iconColor,
    this.accentColor,
    this.isSpecialAccent = false,
    this.size = 40.0,
  });

  @override
  State<AppleVibrancyActionButton> createState() => _AppleVibrancyActionButtonState();
}

class _AppleVibrancyActionButtonState extends State<AppleVibrancyActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = widget.accentColor ?? theme.colorScheme.primary;

    final effectiveBg = widget.isSpecialAccent
        ? primary.withValues(alpha: isDark ? 0.28 : 0.16)
        : (isDark
            ? Colors.white.withValues(alpha: _isPressed ? 0.18 : 0.08)
            : Colors.black.withValues(alpha: _isPressed ? 0.10 : 0.04));

    final effectiveBorder = widget.isSpecialAccent
        ? primary.withValues(alpha: isDark ? 0.50 : 0.35)
        : (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08));

    final effectiveIconColor = widget.iconColor ??
        (widget.isSpecialAccent
            ? primary
            : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)));

    final Widget button = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: effectiveBg,
            border: Border.all(color: effectiveBorder, width: 0.8),
            boxShadow: widget.isSpecialAccent
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: widget.size * 0.48,
            color: effectiveIconColor,
          ),
        ),
      ),
    );

    final currentTooltip = widget.tooltip;
    if (currentTooltip != null) {
      return Tooltip(message: currentTooltip, child: button);
    }
    return button;
  }
}
