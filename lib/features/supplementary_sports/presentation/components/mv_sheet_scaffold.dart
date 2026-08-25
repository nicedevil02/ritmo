import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Unified Action Sheet Scaffold for all sports & movement modal sheets (Section 5.9).
/// Follows docs/DESIGN_SYSTEM_ACTION_SHEETS.md & ADR 0007.
class MvSheetScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? bottomAction;
  final List<Widget>? headerActions;
  final bool isDismissible;

  const MvSheetScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.bottomAction,
    this.headerActions,
    this.isDismissible = true,
  });

  /// Static helper to show an action sheet using standard transitions and theme.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;

    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(metrics.radiusSheet),
        ),
      ),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
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
            // Drag Handle
            Center(
              child: Container(
                margin: EdgeInsets.only(
                  top: metrics.spaceMd,
                  bottom: metrics.spaceSm,
                ),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.spaceLg,
                vertical: metrics.spaceSm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          SizedBox(height: metrics.spaceXs),
                          Text(
                            subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ...?headerActions,
                ],
              ),
            ),

            // Body
            Flexible(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
                child: body,
              ),
            ),

            // Bottom Sticky Action (if provided)
            if (bottomAction != null)
              Padding(
                padding: EdgeInsets.all(metrics.spaceLg),
                child: bottomAction,
              ),
          ],
        ),
      ),
    );
  }
}
