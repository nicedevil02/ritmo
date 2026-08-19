import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// تنها راه مجاز باز کردن شیت در کل برنامه (R-03).
/// این ویجت ارتفاع را سقف می‌گیرد نه قطعی، به صفحه‌کلید احترام می‌گذارد،
/// و محتوا را اسکرول‌پذیر می‌کند. هیچ شیت جدیدی بیرون این ویجت ساخته نشود.
class RitmoSheetScaffold extends StatelessWidget {
  const RitmoSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.maxHeightFactor = 0.9,
    this.footer,
    this.childIsScrollable = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// سقف ارتفاع نسبت به ارتفاع قابل استفاده. پیش‌فرض ۰٫۹.
  final double maxHeightFactor;

  /// ویجت‌های چسبیده به پایین شیت که اسکرول نمی‌شوند (معمولاً دکمهٔ ثبت).
  final Widget? footer;

  /// اگر محتوا خودش اسکرول‌پذیر است (ListView / CustomScrollView)، این را true بگذار.
  final bool childIsScrollable;

  /// متد استاندارد باز کردن شیت در کل برنامه.
  static Future<T?> present<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required WidgetBuilder builder,
    double maxHeightFactor = 0.9,
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
      builder: (ctx) => RitmoSheetScaffold(
        title: title,
        subtitle: subtitle,
        maxHeightFactor: maxHeightFactor,
        footer: footer,
        childIsScrollable: childIsScrollable,
        child: builder(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(
              context,
              factor: maxHeightFactor,
            ),
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RitmoRadius.card),
            ),
            border: Border.all(color: colors.border, width: 1.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(
                    top: RitmoSpacing.md,
                    bottom: RitmoSpacing.xs,
                  ),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withValues(alpha: 0.3),
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
              const Divider(height: 1),
              // Body
              Flexible(
                child: childIsScrollable
                    ? Padding(
                        padding: const EdgeInsets.all(RitmoSpacing.xl),
                        child: child,
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(RitmoSpacing.xl),
                        child: child,
                      ),
              ),
              // Optional Footer
              if (footer != null) ...[
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.xl,
                      vertical: RitmoSpacing.md,
                    ),
                    child: footer!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
