import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// سازنده محتوای صفحه تک‌صفحه‌ای با تزریق کنترلر اسکرول و پدینگ استاندارد بالا
typedef RitmoSingleContentBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
  double topPadding,
);

/// اسکفولد جامع و مرجع هدر داینامیک تک‌صفحه‌ای اپل
/// (Ritmo Canonical Single Morphing Header Scaffold)
///
/// این ویجت برای صفحاتی طراحی شده که ساختار تک‌صفحه‌ای دارند (بدون تب‌های موازی)
/// و نیاز به هدر شیشه‌ای مورفینگ با فیزیک اپل، پدینگ هوشمند داینامیک،
/// مدیریت خودکار اسکرول و قابلیت Pull-To-Refresh دارند.
class RitmoSingleMorphingScaffold extends StatefulWidget {
  const RitmoSingleMorphingScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.onBack,
    this.statusBadge,
    this.collapseDistance = 55.0,
    this.titleColor,
    this.accentColor,
    this.bodyBuilder,
    this.body,
    this.scrollController,
    this.background,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.contentTopPaddingOverride,
    this.extraTopPadding = 130.0,
    this.onRefresh,
  }) : assert(
          bodyBuilder != null || body != null,
          'Either bodyBuilder or body must be provided.',
        );

  /// عنوان اصلی صفحه (هنگام باز بودن بزرگ و هنگام اسکرول درون کپسول قرار می‌گیرد)
  final String title;

  /// زیرعنوان توضیحی یا اطلاعاتی
  final String? subtitle;

  /// دکمه‌ها و اکشن‌های سمت چپ هدر
  final List<Widget>? actions;

  /// ویجت سفارشی سمت راست (مثل آواتار کاربر یا دکمه بازگشت اختصاصی)
  final Widget? leading;

  /// کالبک کلیک روی دکمه بازگشت پیش‌فرض
  final VoidCallback? onBack;

  /// بج وضعیت اختیاری
  final Widget? statusBadge;

  /// آستانه اسکرول برای اتمام مورفینگ عنوان (پیش‌فرض ۵۵ پیکسل)
  final double collapseDistance;

  /// رنگ سفارشی عنوان
  final Color? titleColor;

  /// رنگ شاخص تم یا دکمه‌ها
  final Color? accentColor;

  /// سازنده محتوای صفحه با دریافت کنترلر اسکرول و پدینگ بالای مورد نیاز
  final RitmoSingleContentBuilder? bodyBuilder;

  /// ویجت بدنه ثابت (در صورتی که از bodyBuilder استفاده نشود)
  final Widget? body;

  /// کنترلر اسکرول خارجی (در صورت نیاز به مدیریت اسکرول از بیرون)
  final ScrollController? scrollController;

  /// لایه پس‌زمینه اختیاری (مثل افکت‌های نوری یا گرادیانت متحرک)
  final Widget? background;

  /// رنگ پس‌زمینه داربست
  final Color? backgroundColor;

  /// دکمه اکشن شناور (FAB)
  final Widget? floatingActionButton;

  /// موقعیت قرارگیری FAB
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// نوار ناوبری پایینی
  final Widget? bottomNavigationBar;

  /// مقدار بازنویسی‌شده پدینگ بالای محتوا
  final double? contentTopPaddingOverride;

  /// فاصله پدینگ اولیه از بالای صفحه تا زیر هدر بزرگ (پیش‌فرض ۱۳۰ پیکسل)
  final double extraTopPadding;

  /// کالبک کشیدن برای تازه‌سازی (Pull-To-Refresh)
  final Future<void> Function()? onRefresh;

  @override
  State<RitmoSingleMorphingScaffold> createState() => _RitmoSingleMorphingScaffoldState();
}

class _RitmoSingleMorphingScaffoldState extends State<RitmoSingleMorphingScaffold> {
  late ScrollController _internalScrollController;
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  ScrollController get _activeScrollController =>
      widget.scrollController ?? _internalScrollController;

  @override
  void initState() {
    super.initState();
    _internalScrollController = ScrollController();
    _internalScrollController.addListener(_onInternalScroll);
    if (widget.scrollController != null) {
      widget.scrollController!.addListener(_onInternalScroll);
    }
  }

  @override
  void didUpdateWidget(RitmoSingleMorphingScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onInternalScroll);
      widget.scrollController?.addListener(_onInternalScroll);
    }
  }

  void _onInternalScroll() {
    final offset = _activeScrollController.hasClients ? _activeScrollController.offset : 0.0;
    if (_scrollOffset.value != offset) {
      _scrollOffset.value = offset;
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onInternalScroll);
    _internalScrollController.removeListener(_onInternalScroll);
    _internalScrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topPadding = MediaQuery.paddingOf(context).top;
    final calculatedTopPadding = widget.contentTopPaddingOverride ?? (topPadding + widget.extraTopPadding);

    Widget contentWidget;
    if (widget.bodyBuilder != null) {
      contentWidget = widget.bodyBuilder!(context, _activeScrollController, calculatedTopPadding);
    } else {
      contentWidget = widget.body!;
    }

    if (widget.onRefresh != null) {
      contentWidget = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        edgeOffset: calculatedTopPadding,
        color: widget.accentColor ?? colors.primary,
        child: contentWidget,
      );
    }

    return Scaffold(
      backgroundColor: widget.backgroundColor ?? colors.background,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      bottomNavigationBar: widget.bottomNavigationBar,
      body: Stack(
        children: [
          // ۱. لایه پس‌زمینه اختیاری
          if (widget.background != null)
            Positioned.fill(
              child: widget.background!,
            ),

          // ۲. لایه محتوای اسکرول‌پذیر با لیسنر بهینه
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical) {
                  _scrollOffset.value = notification.metrics.pixels;
                }
                return false;
              },
              child: contentWidget,
            ),
          ),

          // ۳. هدر شیشه‌ای مورفینگ اپل در لایه بالایی
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _scrollOffset,
                builder: (context, _) {
                  return RitmoAppleMorphingGlassHeader(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    scrollOffset: _scrollOffset.value,
                    collapseDistance: widget.collapseDistance,
                    leading: widget.leading,
                    onBack: widget.onBack,
                    statusBadge: widget.statusBadge,
                    titleColor: widget.titleColor,
                    actions: widget.actions,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
