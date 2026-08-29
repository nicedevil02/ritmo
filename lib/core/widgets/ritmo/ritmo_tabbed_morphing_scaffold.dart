import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// سازنده محتوای هر تب با تزریق کنترلر اسکرول هماهنگ‌شده
typedef RitmoTabContentBuilder = Widget Function(
  BuildContext context,
  ScrollController scrollController,
);

/// سازنده نوار تب‌های سفارشی
typedef RitmoCustomTabsBuilder = Widget Function(
  BuildContext context,
  int activeIndex,
  void Function(int index) onTabChanged,
);

/// اسکفولد جامع و مرجع هدر داینامیک چندتبی اپل
/// (Ritmo Canonical Tabbed Morphing Header Scaffold)
///
/// این ویجت مادر تمامی محاسبات فیزیک اسکرول، همگام‌سازی وضعیت کپسول هدر بین تب‌ها،
/// انیمیشن مورف ۳۰۰ میلی‌ثانیه‌ای و واکنش به اسکرول سریع (Quick-Return) را به صورت
/// کاملاً متمرکز و یکپارچه مدیریت می‌کند.
class RitmoTabbedMorphingScaffold extends StatefulWidget {
  const RitmoTabbedMorphingScaffold({
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
    this.tabItems,
    this.customTabsBuilder,
    this.customTabs,
    this.tabBuilders,
    this.tabChildren,
    this.tabCount,
    this.initialIndex = 0,
    this.externalTabController,
    this.onTabChanged,
    this.background,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.useIndexedStack = false,
    this.contentTopPaddingOverride,
    this.scrollControllers,
  }) : assert(
          (tabItems != null || customTabsBuilder != null || customTabs != null || tabCount != null),
          'At least one of tabItems, customTabsBuilder, customTabs, or tabCount must be provided.',
        ),
        assert(
          (tabBuilders != null || tabChildren != null),
          'Either tabBuilders or tabChildren must be provided.',
        );

  /// عنوان هدر
  final String title;

  /// زیرعنوان هدر
  final String? subtitle;

  /// دکمه‌ها و اکشن‌های سمت چپ هدر
  final List<Widget>? actions;

  /// ویجت اختیاری سمت راست هدر
  final Widget? leading;

  /// دکمه بازگشت (در صورت null بودن، با Navigator.pop برمی‌گردد)
  final VoidCallback? onBack;

  /// نشانگر وضعیت زنده در کنار عنوان
  final Widget? statusBadge;

  /// فاصله اسکرول تا جمع‌شدن کامل کپسول هدر (پیش‌فرض: ۵۵.۰)
  final double collapseDistance;

  /// رنگ عنوان
  final Color? titleColor;

  /// رنگ شاخص و هایلایت هدر
  final Color? accentColor;

  /// آیتم‌های تب استاندارد برای RitmoGlassSegmentedControl
  final List<RitmoTabItem<int>>? tabItems;

  /// سازنده تب‌بار سفارشی
  final RitmoCustomTabsBuilder? customTabsBuilder;

  /// ویجت تب‌بار سفارشی ایستا
  final Widget? customTabs;

  /// سازنده‌های محتوای تب‌ها با دریافت خودکار ScrollController اختصاصی
  final List<RitmoTabContentBuilder>? tabBuilders;

  /// محتوای ویجت‌های تب‌ها (در صورت عدم استفاده از tabBuilders)
  final List<Widget>? tabChildren;

  /// تعداد کل تب‌ها (در صورت مشخص نبودن در tabItems یا tabBuilders)
  final int? tabCount;

  /// تب پیش‌فرض در زمان باز شدن صفحه
  final int initialIndex;

  /// کنترلر تب خارجی (در صورت نیاز به کنترل تب‌ها از بیرون)
  final TabController? externalTabController;

  /// کالبک تغییر تب
  final ValueChanged<int>? onTabChanged;

  /// ویجت لایه زیرین پس‌زمینه (نظیر انیمیشن گرادیان یا پترن)
  final Widget? background;

  /// رنگ پس‌زمینه اسکفولد
  final Color? backgroundColor;

  /// دکمه شناور پایین صفحه
  final Widget? floatingActionButton;

  /// موقعیت دکمه شناور
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// نوار ناوبری پایین صفحه
  final Widget? bottomNavigationBar;

  /// در صورت true بودن، به جای TabBarView از IndexedStack جهت حفظ قطعی حافظه استفاده می‌شود
  final bool useIndexedStack;

  /// مقدار سفارشی برای فاصله محتوا از بالای صفحه
  final double? contentTopPaddingOverride;

  /// کنترلرهای اسکرول اختصاصی خارجی (اختیاری)
  final List<ScrollController>? scrollControllers;

  @override
  State<RitmoTabbedMorphingScaffold> createState() =>
      _RitmoTabbedMorphingScaffoldState();
}

class _RitmoTabbedMorphingScaffoldState
    extends State<RitmoTabbedMorphingScaffold>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerMorphAnimCtrl;
  Animation<double>? _headerMorphAnim;

  late List<ScrollController> _tabScrollControllers;
  late List<double> _tabOffsets;
  late List<bool> _tabExpanded;

  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isTabsExpanded = ValueNotifier<bool>(true);
  double _accumulatedUpScroll = 0.0;
  int _activeTabIndex = 0;
  bool _ownsTabController = false;

  int get _resolvedTabCount {
    if (widget.tabCount != null) return widget.tabCount!;
    if (widget.tabItems != null) return widget.tabItems!.length;
    if (widget.tabBuilders != null) return widget.tabBuilders!.length;
    if (widget.tabChildren != null) return widget.tabChildren!.length;
    return 1;
  }

  @override
  void initState() {
    super.initState();
    final count = _resolvedTabCount;
    _activeTabIndex = widget.initialIndex.clamp(0, count > 0 ? count - 1 : 0);

    // آماده‌سازی کنترلرهای اسکرول به تفکیک تب
    if (widget.scrollControllers != null &&
        widget.scrollControllers!.length >= count) {
      _tabScrollControllers = widget.scrollControllers!;
    } else {
      _tabScrollControllers = List.generate(
        count,
        (_) => ScrollController(),
      );
    }
    _tabOffsets = List.generate(count, (_) => 0.0);
    _tabExpanded = List.generate(count, (_) => true);

    // انیمیشن مورف هدر (۳۰۰ میلی‌ثانیه با فیزیک اپل)
    _headerMorphAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _headerMorphAnimCtrl.addListener(() {
      if (_headerMorphAnim != null) {
        _scrollOffset.value = _headerMorphAnim!.value;
      }
    });

    // مدیریت کنترلر تب
    if (widget.externalTabController != null) {
      _tabController = widget.externalTabController!;
      _ownsTabController = false;
    } else {
      _tabController = TabController(
        length: count,
        vsync: this,
        initialIndex: _activeTabIndex,
      );
      _ownsTabController = true;
    }

    _tabController.addListener(_handleTabControllerChange);
    _tabController.animation?.addListener(_handleTabAnimationTick);
  }

  @override
  void didUpdateWidget(covariant RitmoTabbedMorphingScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalTabController != oldWidget.externalTabController &&
        widget.externalTabController != null) {
      _tabController.removeListener(_handleTabControllerChange);
      _tabController.animation?.removeListener(_handleTabAnimationTick);
      if (_ownsTabController) {
        _tabController.dispose();
      }
      _tabController = widget.externalTabController!;
      _ownsTabController = false;
      _tabController.addListener(_handleTabControllerChange);
      _tabController.animation?.addListener(_handleTabAnimationTick);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabControllerChange);
    _tabController.animation?.removeListener(_handleTabAnimationTick);
    if (_ownsTabController) {
      _tabController.dispose();
    }
    _headerMorphAnimCtrl.dispose();
    if (widget.scrollControllers == null) {
      for (final controller in _tabScrollControllers) {
        controller.dispose();
      }
    }
    _scrollOffset.dispose();
    _isTabsExpanded.dispose();
    super.dispose();
  }

  void _handleTabControllerChange() {
    if (_tabController.indexIsChanging ||
        _tabController.animation?.value == _tabController.index.toDouble()) {
      if (_activeTabIndex != _tabController.index) {
        _activeTabIndex = _tabController.index;
        _syncHeaderWithActiveTab(_activeTabIndex, animate: true);
        widget.onTabChanged?.call(_activeTabIndex);
        if (mounted) setState(() {});
      }
    }
  }

  void _handleTabAnimationTick() {
    final value = _tabController.animation?.value ?? 0.0;
    final roundIndex = value.round().clamp(0, _resolvedTabCount - 1);
    if ((value - roundIndex).abs() < 0.05 && _tabController.index == roundIndex) {
      if (_activeTabIndex != roundIndex) {
        _activeTabIndex = roundIndex;
        _syncHeaderWithActiveTab(roundIndex, animate: true);
        widget.onTabChanged?.call(roundIndex);
        if (mounted) setState(() {});
      }
    }
  }

  void _syncHeaderWithActiveTab(int activeIndex, {bool animate = true}) {
    if (activeIndex < 0 || activeIndex >= _tabOffsets.length) return;
    final controller = _tabScrollControllers[activeIndex];
    final targetOffset = controller.hasClients ? controller.offset : _tabOffsets[activeIndex];
    _tabOffsets[activeIndex] = targetOffset;

    final currentOffset = _scrollOffset.value;
    final isExpanded = targetOffset <= 75.0 || _tabExpanded[activeIndex];
    _isTabsExpanded.value = isExpanded;
    _accumulatedUpScroll = 0.0;

    if (animate && (targetOffset - currentOffset).abs() > 1.0) {
      _headerMorphAnimCtrl.stop();
      _headerMorphAnim = Tween<double>(
        begin: currentOffset,
        end: targetOffset,
      ).animate(
        CurvedAnimation(
          parent: _headerMorphAnimCtrl,
          curve: Curves.easeOutCubic,
        ),
      );
      _headerMorphAnimCtrl.forward(from: 0.0);
    } else {
      _headerMorphAnimCtrl.stop();
      _scrollOffset.value = targetOffset;
    }
  }

  void _onTabScroll(int tabIndex, ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return;
    final pixels = notification.metrics.pixels;
    _tabOffsets[tabIndex] = pixels;

    if (_activeTabIndex == tabIndex) {
      if (_headerMorphAnimCtrl.isAnimating) {
        _headerMorphAnimCtrl.stop();
      }
      _scrollOffset.value = pixels;

      if (pixels <= 20) {
        _accumulatedUpScroll = 0.0;
        if (!_isTabsExpanded.value) {
          _isTabsExpanded.value = true;
          _tabExpanded[tabIndex] = true;
        }
      } else if (notification is ScrollUpdateNotification) {
        final delta = notification.scrollDelta ?? 0.0;
        if (delta > 1.0) {
          // اسکرول مداوم به سمت پایین: جمع شدن تب‌ها
          _accumulatedUpScroll = 0.0;
          if (pixels > 75 && _isTabsExpanded.value) {
            _isTabsExpanded.value = false;
            _tabExpanded[tabIndex] = false;
          }
        } else if (delta < -1.0) {
          // اسکرول رو به بالا با آستانه ۲۸ پیکسلی جهت حذف لرزش دست
          _accumulatedUpScroll += -delta;
          if (_accumulatedUpScroll > 28.0 && !_isTabsExpanded.value) {
            _isTabsExpanded.value = true;
            _tabExpanded[tabIndex] = true;
          }
        }
      } else if (notification is ScrollEndNotification) {
        _accumulatedUpScroll = 0.0;
      }
    }
  }

  void _switchTab(int index) {
    if (index < 0 || index >= _resolvedTabCount) return;
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      _tabController.animateTo(index);
      _syncHeaderWithActiveTab(index, animate: true);
      widget.onTabChanged?.call(index);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final count = _resolvedTabCount;

    // ایجاد لیست فرزندان هر تب
    final List<Widget> tabWidgets = [];
    for (int i = 0; i < count; i++) {
      final Widget tabChild;
      if (widget.tabBuilders != null && i < widget.tabBuilders!.length) {
        tabChild = widget.tabBuilders![i](context, _tabScrollControllers[i]);
      } else if (widget.tabChildren != null && i < widget.tabChildren!.length) {
        tabChild = widget.tabChildren![i];
      } else {
        tabChild = const SizedBox.shrink();
      }

      tabWidgets.add(
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            _onTabScroll(i, n);
            return false;
          },
          child: tabChild,
        ),
      );
    }

    // ویجت تب‌بار
    final Widget? tabsWidget;
    if (widget.customTabsBuilder != null) {
      tabsWidget = widget.customTabsBuilder!(
        context,
        _activeTabIndex,
        _switchTab,
      );
    } else if (widget.customTabs != null) {
      tabsWidget = widget.customTabs;
    } else if (widget.tabItems != null) {
      tabsWidget = RitmoGlassSegmentedControl<int>(
        items: widget.tabItems!,
        selectedIndex: _activeTabIndex.clamp(0, widget.tabItems!.length - 1),
        onTabChanged: _switchTab,
        accentColor: widget.accentColor ?? colors.primary,
        height: 46.0,
      );
    } else {
      tabsWidget = null;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.backgroundColor ?? colors.bg,
        floatingActionButton: widget.floatingActionButton,
        floatingActionButtonLocation: widget.floatingActionButtonLocation,
        bottomNavigationBar: widget.bottomNavigationBar,
        body: Stack(
          children: [
            // ۱. لایه پس‌زمینه اختیاری
            if (widget.background != null)
              Positioned.fill(child: widget.background!),

            // ۲. لایه محتوای تب‌ها
            Positioned.fill(
              child: widget.useIndexedStack
                  ? IndexedStack(
                      index: _activeTabIndex,
                      children: tabWidgets,
                    )
                  : TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: tabWidgets,
                    ),
            ),

            // ۳. هدر داینامیک لارج تایتل شیشه‌ای اپل
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_scrollOffset, _isTabsExpanded]),
                  builder: (context, _) {
                    return RitmoAppleMorphingGlassHeader(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      scrollOffset: _scrollOffset.value,
                      isTabsExpanded: _isTabsExpanded.value,
                      collapseDistance: widget.collapseDistance,
                      titleColor: widget.titleColor,
                      accentColor: widget.accentColor,
                      statusBadge: widget.statusBadge,
                      leading: widget.leading,
                      onBack: widget.onBack ??
                          () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                      actions: widget.actions,
                      tabs: tabsWidget,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
