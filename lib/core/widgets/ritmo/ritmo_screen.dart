import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// پوسته‌ی یگانه‌ی صفحه — RFC «Ritmo Aurora» §P2
///
/// جایگزین `Scaffold` خام و `RitmoPageScaffold`:
/// - پس‌زمینه‌ی گرادیانی (الان `timeAwareGradient`؛ مقصد نهایی: توکن گرادیان
///   مشتق از پالت — §۵.۷)
/// - هدر تیتر-بزرگ جمع‌شونده (`SliverAppBar.large`) یا AppBar ساده
/// - مدیریت inset پایین تا محتوا زیر نوار ناوبری شل نرود
/// - جهت و SafeArea از زمینه‌ی اپ (فارسی/RTL) ارث می‌برد
///
/// توجه: [body] باید محتوای غیر-اسکرولی باشد (ستون/گرید داخل اسکرول پوسته
/// قرار می‌گیرد). برای لیست‌های سفارشی بلند، فعلاً همان Scaffold + الگوی
/// CustomScrollView دستی مجاز است تا نسخه‌ی slivers اضافه شود.
class RitmoScreen extends StatelessWidget {
  const RitmoScreen({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.collapsingHeader = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.bottomInsetPadding = 96,
  });

  /// تیتر صفحه — در حالت پیش‌فرض به‌صورت تیتر بزرگ جمع‌شونده رندر می‌شود.
  final String title;

  /// محتوای صفحه (غیر-اسکرولی؛ اسکرول را پوسته مدیریت می‌کند).
  final Widget body;

  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  /// وقتی false باشد، یک AppBar ساده‌ی ثابت رندر می‌شود (مناسب فرم‌ها).
  final bool collapsingHeader;

  /// پدینگ افقی محتوا — پیش‌فرض ۱۶ طبق توکن `RitmoSpacing.lg`.
  final EdgeInsetsGeometry padding;

  /// فضای امن اضافه در انتهای محتوا برای شل ناوبری شناور.
  final double bottomInsetPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    final bottomPad = systemBottom + bottomInsetPadding;

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: RitmoTheme.buildBackgroundContainer(
        context: context,
        child: SafeArea(
          bottom: false,
          child: collapsingHeader
              ? CustomScrollView(
                  slivers: [
                    SliverAppBar.large(
                      title: Text(title),
                      actions: actions,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      scrolledUnderElevation: 0,
                    ),
                    SliverPadding(
                      padding: padding.add(EdgeInsets.only(bottom: bottomPad)),
                      sliver: SliverToBoxAdapter(child: body),
                    ),
                  ],
                )
              : Column(
                  children: [
                    AppBar(
                      title: Text(title),
                      actions: actions,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: padding.add(
                          EdgeInsets.only(bottom: bottomPad),
                        ),
                        child: body,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
