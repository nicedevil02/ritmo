import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_screen.dart';

/// شل یگانهٔ صفحه‌های ماژول حرکت — بر پایهٔ [RitmoScreen] (Aurora).
///
/// قرارداد: هیچ صفحه‌ای در ماژول حق استفادهٔ مستقیم از `Scaffold` ندارد.
/// این شل Safe Area، بنر ثابت بالای محتوا، Dock پایین و Pull to Refresh
/// اختیاری را مدیریت می‌کند. پدینگ افقی محتوا (طبق قرارداد `RitmoSpacing.lg`)
/// در خود صفحه/کارت‌ها اعمال می‌شود نه اینجا.
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

  /// زیرعنوان اختیاری که به‌صورت نوار باریک زیر AppBar نمایش داده می‌شود.
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;

  /// ناحیهٔ CTA ثابت پایین صفحه (در اسلات bottomNavigationBar رندر می‌شود).
  final Widget? bottomDock;

  /// بنر ثابت بالای محتوا (مثلاً بنر خطا یا وضعیت).
  final Widget? banner;

  /// برای سازگاری با نسخهٔ قبلی نگه داشته شده؛ مدیریت اسکرول در خود صفحه انجام می‌شود.
  final ScrollController? scrollController;

  /// اگر مقدار داده شود، محتوا داخل RefreshIndicator قرار می‌گیرد.
  final Future<void> Function()? onRefresh;

  /// برای سازگاری با نسخهٔ قبلی نگه داشته شده؛ هدر Aurora ثابت است.
  final bool collapsingHeader;

  /// پدینگ دور محتوای اصلی (پیش‌فرض صفر؛ صفحه‌ها خودشان lg اعمال می‌کنند).
  final EdgeInsetsGeometry padding;

  /// برای سازگاری با نسخهٔ قبلی نگه داشته شده؛ inset پایین را RitmoScreen مدیریت می‌کند.
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

    return RitmoScreen(
      title: title,
      actions: actions,
      collapsingHeader: false,
      padding: EdgeInsets.zero,
      bottomInsetPadding: 0,
      bottomNavigationBar: bottomDock != null
          ? SafeArea(
              top: false,
              child: bottomDock!,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: RitmoSpacing.lg,
                end: RitmoSpacing.lg,
                bottom: RitmoSpacing.xs,
              ),
              child: Text(
                subtitle!,
                style: RitmoTextStyles.caption(colors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (banner != null) ...[
            banner!,
            const SizedBox(height: RitmoSpacing.sm),
          ],
          Expanded(
            child: Padding(
              padding: padding,
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}
