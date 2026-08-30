import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// تنها راه مجاز باز کردن شیت در کل برنامه (R-03 / Apple HIG Detents).
/// این ویجت با استاندارد Detents ریتمو (۹۴٪ تمام‌صفحه و بسته‌شدن با کشیدن به پایین)
/// به صفحه‌کلید احترام می‌گذارد، و محتوا را اسکرول‌پذیر می‌کند.
class RitmoSheetScaffold extends StatelessWidget {
  const RitmoSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.initialHeightFactor = 0.94,
    this.maxHeightFactor = 0.94,
    this.footer,
    this.childIsScrollable = false,
    this.scrollController,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// سقف و شروع ارتفاع نسبت به صفحه (Ritmo Detents: 0.94)
  final double initialHeightFactor;
  final double maxHeightFactor;

  /// ویجت‌های چسبیده به پایین شیت که اسکرول نمی‌شوند (معمولاً دکمهٔ ثبت).
  final Widget? footer;

  /// اگر محتوا خودش اسکرول‌پذیر است (ListView / CustomScrollView)، این را true بگذار.
  final bool childIsScrollable;
  final ScrollController? scrollController;

  /// متد استاندارد باز کردن شیت در کل برنامه.
  static Future<T?> present<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required WidgetBuilder builder,
    double initialHeightFactor = 0.94,
    double maxHeightFactor = 0.94,
    Widget? footer,
    bool childIsScrollable = false,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    RitmoHapticsPolicy.selection();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: initialHeightFactor.clamp(0.2, 1.0),
        minChildSize: 0.0,
        maxChildSize: maxHeightFactor.clamp(0.5, 0.96),
        snap: true,
        snapSizes: [
          0.0,
          maxHeightFactor.clamp(0.5, 0.96),
        ],
        expand: false,
        builder: (context, scrollController) => RitmoSheetScaffold(
          title: title,
          subtitle: subtitle,
          initialHeightFactor: initialHeightFactor,
          maxHeightFactor: maxHeightFactor,
          footer: footer,
          childIsScrollable: childIsScrollable,
          scrollController: scrollController,
          child: builder(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const sheetRadius = BorderRadius.vertical(
      top: Radius.circular(RitmoRadius.card),
    );

    final sheetContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle bar (Ritmo Style)
        Center(
          child: Container(
            margin: const EdgeInsets.only(
              top: RitmoSpacing.md,
              bottom: RitmoSpacing.xs,
            ),
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: colors.textTertiary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Canonical Header Row
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.lg,
            vertical: RitmoSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Leading (Right in RTL): Circular Tactile Close (X) Button
              GestureDetector(
                onTap: () {
                  RitmoHapticsPolicy.tap();
                  Navigator.of(context).pop();
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
                    CupertinoIcons.xmark,
                    size: 15,
                    color: colors.textSecondary,
                  ),
                ),
              ),

              // Center: Title + Subtitle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: RitmoTextStyles.caption(
                          colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing (Left in RTL): Symmetrical Spacer
              const SizedBox(width: 34, height: 34),
            ],
          ),
        ),
        Divider(color: colors.divider, height: 1),
        // Body
        Flexible(
          child: childIsScrollable
              ? Padding(
                  padding: const EdgeInsets.all(RitmoSpacing.xl),
                  child: child,
                )
              : SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(RitmoSpacing.xl),
                  child: child,
                ),
        ),
        // Optional Footer
        if (footer != null) ...[
          Divider(color: colors.divider, height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RitmoSpacing.xl,
                vertical: RitmoSpacing.md,
              ),
              child: footer,
            ),
          ),
        ],
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RitmoGlassSheet(
          borderRadius: sheetRadius,
          child: Material(
            type: MaterialType.transparency,
            child: sheetContent,
          ),
        ),
      ),
    );
  }
}
