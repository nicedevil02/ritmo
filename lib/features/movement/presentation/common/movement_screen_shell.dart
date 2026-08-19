import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// شل استاندارد و پایدار صفحه‌های ماژول حرکت
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: RitmoTextStyles.pageTitle(colors.textPrimary)),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                style: RitmoTextStyles.caption(colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: actions,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBar: bottomDock != null
          ? SafeArea(top: false, child: bottomDock!)
          : null,
      body: RitmoTheme.buildBackgroundContainer(
        context: context,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (banner != null) ...[
                banner!,
                const SizedBox(height: RitmoSpacing.sm),
              ],
              Expanded(
                child: Padding(padding: padding, child: content),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
