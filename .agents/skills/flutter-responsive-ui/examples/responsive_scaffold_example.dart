import 'package:flutter/material.dart';

/// Standard device screen categories.
enum ScreenTier { compact, medium, expanded }

/// Helper utility for extracting responsive tiers and dimensions.
class ResponsiveUtils {
  static const double compactBreakpoint = 600.0;
  static const double mediumBreakpoint = 1024.0;

  static ScreenTier getTier(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compactBreakpoint) return ScreenTier.compact;
    if (width < mediumBreakpoint) return ScreenTier.medium;
    return ScreenTier.expanded;
  }

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactBreakpoint;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compactBreakpoint && width < mediumBreakpoint;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= mediumBreakpoint;
}

/// A clean, declarative widget to switch layout based on screen width.
class ResponsiveLayout extends StatelessWidget {
  final Widget compact;
  final Widget? medium;
  final Widget? expanded;

  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveUtils.mediumBreakpoint) {
          return expanded ?? medium ?? compact;
        } else if (constraints.maxWidth >= ResponsiveUtils.compactBreakpoint) {
          return medium ?? compact;
        } else {
          return compact;
        }
      },
    );
  }
}
