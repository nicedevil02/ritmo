import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Unified Action Sheet Scaffold for all sports & movement modal sheets.
/// Fully connected to Ritmo canonical glass material, theme colors, and Apple HIG detents (0.60 / 0.95).
class MvSheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? bottomAction;
  final List<Widget>? headerActions;
  final bool isDismissible;
  final VoidCallback? onCancel;
  final ScrollController? scrollController;

  const MvSheetScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.bottomAction,
    this.headerActions,
    this.isDismissible = true,
    this.onCancel,
    this.scrollController,
  });

  /// Static helper to show an action sheet using canonical Apple HIG glass transitions and detents.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    double initialChildSize = 0.94,
    double maxChildSize = 0.94,
  }) {
    RitmoHaptics.sheetOpen();
    final controller = DraggableScrollableController();
    double lastSize = initialChildSize;

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
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(ctx, factor: maxChildSize),
          ),
          child: DraggableScrollableSheet(
            controller: controller,
            initialChildSize: initialChildSize.clamp(0.3, 0.96),
            minChildSize: 0.35,
            maxChildSize: maxChildSize.clamp(0.5, 0.96),
            snap: true,
            snapSizes: [
              initialChildSize.clamp(0.3, 0.96),
              maxChildSize.clamp(0.5, 0.96),
            ],
            expand: false,
            builder: (context, scrollCtrl) => RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: EdgeInsets.zero,
              child: builder(context),
            ),
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
    final isDark = context.isDark;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Apple Grabber Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: colors.textPrimary.withValues(alpha: isDark ? 0.18 : 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Canonical Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Right: Leading Circular Tactile Close (X) Button (RTL)
                  GestureDetector(
                    onTap: onCancel ?? () {
                      RitmoHaptics.tap();
                      Navigator.maybePop(context);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceElevated.withValues(alpha: 0.85)
                            : colors.textPrimary.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? colors.border.withValues(alpha: 0.35)
                              : colors.border.withValues(alpha: 0.15),
                          width: 0.85,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),

                  // Center: Title & Subtitle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Left: Trailing Action or Symmetrical Balancer
                  if (headerActions != null && headerActions!.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: headerActions!,
                    )
                  else
                    const SizedBox(width: 34, height: 34), // Balances Close button
                ],
              ),
            ),
            Divider(color: colors.divider.withValues(alpha: 0.6), height: 1),

            // Scrollable Body (Expanded ensures zero bottom overflow)
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: body,
              ),
            ),

            // Bottom Sticky Action (if provided)
            if (bottomAction != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: bottomAction,
              ),
          ],
        ),
      ),
    );
  }
}
