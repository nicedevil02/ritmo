import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_screen.dart';

/// تنها ریشهٔ مجاز صفحه‌های ماژول حرکت — بر پایهٔ [RitmoScreen]
class MovementScreenShell extends StatelessWidget {
  const MovementScreenShell({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.body,
    this.bottomDock,
    this.banner,
    this.scrollController,
    this.onRefresh,
    this.collapsingHeader = false,
    this.padding = EdgeInsets.zero,
    this.bottomInsetPadding = 0,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? bottomDock;
  final Widget? banner;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;
  final bool collapsingHeader;
  final EdgeInsetsGeometry padding;
  final double bottomInsetPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget content = body;

    if (onRefresh != null) {
      content = RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.surfaceElevated,
        onRefresh: onRefresh!,
        child: content,
      );
    }

    final fullBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) ...[
          banner!,
          const SizedBox(height: RitmoSpacing.sm),
        ],
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.lg,
              vertical: RitmoSpacing.xs,
            ),
            child: Text(
              subtitle!,
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
          ),
        ],
        Expanded(
          child: content,
        ),
      ],
    );

    return RitmoScreen(
      title: title,
      actions: actions,
      collapsingHeader: collapsingHeader,
      padding: padding,
      bottomInsetPadding: 0,
      bottomNavigationBar: bottomDock != null
          ? SafeArea(
              top: false,
              child: bottomDock!,
            )
          : null,
      body: fullBody,
    );
  }
}
