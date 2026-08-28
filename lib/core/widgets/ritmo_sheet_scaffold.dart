import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// تنها راه مجاز باز کردن شیت در کل برنامه (R-03 / Apple HIG Detents).
/// این ویجت با استاندارد Detents اپل (۶۰٪ پیش‌فرض، ۹۴٪ در اسکرول به بالا، و بسته‌شدن با کشیدن به پایین)
/// به صفحه‌کلید احترام می‌گذارد، و محتوا را اسکرول‌پذیر می‌کند.
class RitmoSheetScaffold extends StatelessWidget {
  const RitmoSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.initialHeightFactor = 0.60,
    this.maxHeightFactor = 0.94,
    this.footer,
    this.childIsScrollable = false,
    this.scrollController,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// سقف و شروع ارتفاع نسبت به صفحه (Apple Detents: 0.60 -> 0.94)
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
    double initialHeightFactor = 0.60,
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
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: initialHeightFactor.clamp(0.2, 1.0),
        minChildSize: 0.35,
        maxChildSize: maxHeightFactor.clamp(0.5, 0.96),
        snap: true,
        snapSizes: [
          initialHeightFactor.clamp(0.2, 1.0),
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
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(
      top: Radius.circular(RitmoRadius.card),
    );

    final sheetContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle bar (Apple Style)
        Center(
          child: Container(
            margin: const EdgeInsets.only(
              top: RitmoSpacing.md,
              bottom: RitmoSpacing.xs,
            ),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textTertiary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.xl,
            vertical: RitmoSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: RitmoTextStyles.caption(
                          colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: colors.textSecondary),
                tooltip: 'بستن',
              ),
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

    final sheetBody = Material(
      type: MaterialType.transparency,
      child: sheetContent,
    );

    Widget containerWidget;
    if (!isGlass) {
      containerWidget = Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    } else {
      containerWidget = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: sheetRadius,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : colors.primary.withValues(alpha: 0.08),
              offset: const Offset(0, -3),
              blurRadius: 16,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: sheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.glassTint,
                borderRadius: sheetRadius,
                border: Border.all(
                  color: isDark
                      ? colors.border
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.0,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: sheetRadius,
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
                child: sheetBody,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: Colors.transparent,
        child: containerWidget,
      ),
    );
  }
}
