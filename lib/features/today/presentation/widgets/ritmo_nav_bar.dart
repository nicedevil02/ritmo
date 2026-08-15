// نوار ناوبری پرمیوم ریتمو — «ریل زنده»
// یک کپسول شیشه‌ای شناور با نشانگر لغزان، برچسب فقط برای مقصد فعال،
// رنگ هویت هر ماژول و دکمهٔ قهرمان مرکزی.
//
// قرارداد ارتفاع: ارتفاع رندرشده همیشه دقیقاً RitmoShellMetrics.navBarHeight است.
// تست test/features/today/ritmo_nav_bar_height_test.dart این قرارداد را قفل می‌کند
// چون جای دکمهٔ شناور صفحهٔ سفر از همین عدد حساب می‌شود.
//
// کل چیدمان مطلق است (Stack + PositionedDirectional) و پهناها محاسبه می‌شوند،
// نه مذاکره؛ بنابراین سرریز RenderFlex در هیچ عرض و هیچ مقیاس متنی رخ نمی‌دهد.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_glass_surface.dart';

/// هندسهٔ داخلی ریل — تنها منبع حقیقت اندازه‌های نوار
abstract final class _RailMetrics {
  static const double slotBase = 48; // حداقل هدف لمسی هر مقصد
  static const double centerSlot = 60; // پهنای خانهٔ دکمهٔ مرکزی
  static const double centerButton = 46;
  static const double iconSize = 21;
  static const double labelGap = 6;
  static const double pillInsetV = 6;
  static const double pillInsetH = 2;
  static const double activeLift = 1.5;
  static const double activeScale = 1.08;
  static const double minSlotWidth = 28;
  static const double fallbackWidth = 360; // فقط وقتی عرض نامحدود باشد
}

/// یک مقصد ناوبری؛ ترتیب لیست‌ها همان ترتیب بصری راست‌به‌چپ است
@immutable
class _NavDestination {
  const _NavDestination({
    required this.index,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });

  final int index;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
}

/// نوار ناوبری پایین اپ — بدون هیچ دسترسی به State شل، تا مستقل تست شود
class RitmoNavBar extends StatelessWidget {
  const RitmoNavBar({
    super.key,
    required this.mode,
    required this.currentIndex,
    required this.onSelectTab,
    required this.onCenterTap,
    this.onCenterLongPress,
  });

  final AppMode mode;
  final int currentIndex;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onCenterTap;
  final VoidCallback? onCenterLongPress;

  /// حالت ساده: کارها(۰) · دکمه · تقویم(۱) · بیشتر(۲)
  static const List<_NavDestination> _simpleDestinations = <_NavDestination>[
    _NavDestination(
      index: 0,
      activeIcon: CupertinoIcons.check_mark_circled_solid,
      inactiveIcon: CupertinoIcons.check_mark_circled,
      label: 'کارها',
    ),
    _NavDestination(
      index: 1,
      activeIcon: CupertinoIcons.calendar_circle_fill,
      inactiveIcon: CupertinoIcons.calendar,
      label: 'تقویم',
    ),
    _NavDestination(
      index: 2,
      activeIcon: CupertinoIcons.square_grid_2x2_fill,
      inactiveIcon: CupertinoIcons.square_grid_2x2,
      label: 'بیشتر',
    ),
  ];

  /// حالت کامل: تقویم(۴) · دستیار(۳) · دکمه · سیستم‌ها(۰) · بینش‌ها(۱)
  static const List<_NavDestination> _fullDestinations = <_NavDestination>[
    _NavDestination(
      index: 4,
      activeIcon: CupertinoIcons.calendar_circle_fill,
      inactiveIcon: CupertinoIcons.calendar,
      label: 'تقویم',
    ),
    _NavDestination(
      index: 3,
      activeIcon: CupertinoIcons.sparkles,
      inactiveIcon: CupertinoIcons.sparkles,
      label: 'دستیار',
    ),
    _NavDestination(
      index: 0,
      activeIcon: CupertinoIcons.square_grid_2x2_fill,
      inactiveIcon: CupertinoIcons.square_grid_2x2,
      label: 'سیستم‌ها',
    ),
    _NavDestination(
      index: 1,
      activeIcon: CupertinoIcons.lightbulb_fill,
      inactiveIcon: CupertinoIcons.lightbulb,
      label: 'بینش‌ها',
    ),
  ];

  /// جدول رنگ هویت مقصد — فقط از هشت فیلد موجود RitmoModuleColors
  Color _tintFor(BuildContext context, int index) {
    final colors = context.colors;
    if (mode == AppMode.simple) {
      switch (index) {
        case 0:
          return colors.modules.routines;
        case 1:
          return colors.modules.planner;
        default:
          return colors.primary;
      }
    }
    switch (index) {
      case 4:
        return colors.modules.planner;
      case 0:
        return colors.modules.routines;
      case 1:
        return colors.modules.insights;
      default:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final reduceTransparency = context.behavior.reduceTransparency;

    final isSimple = mode == AppMode.simple;
    final destinations = isSimple ? _simpleDestinations : _fullDestinations;
    final centerSlot = isSimple ? 1 : 2;
    final tints = <Color>[
      for (final destination in destinations) _tintFor(context, destination.index),
    ];

    return Container(
      height: RitmoShellMetrics.navBarHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RitmoRadius.sheet),
        boxShadow: reduceTransparency
            ? null
            : <BoxShadow>[
                // سایهٔ محیطی: کپسول را از محتوای پشتش جدا می‌کند
                BoxShadow(
                  color: colors.shadow.withValues(alpha: isDark ? 0.46 : 0.14),
                  blurRadius: 26,
                  spreadRadius: -6,
                  offset: const Offset(0, 10),
                ),
                // سایهٔ نزدیک: لبه را تیز و ملموس نگه می‌دارد
                BoxShadow(
                  color: colors.shadow.withValues(alpha: isDark ? 0.26 : 0.07),
                  blurRadius: 6,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      // بدون border سفارشی، تا مسیر جایگزین کاهش شفافیت و کنتراست بالای
      // RitmoGlassSurface دست‌نخورده بماند.
      child: RitmoGlassSurface(
        blurSigma: 28,
        borderRadius: BorderRadius.circular(RitmoRadius.sheet),
        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.xs),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: _LivingRail(
            key: ValueKey<AppMode>(mode),
            destinations: destinations,
            tints: tints,
            centerSlot: centerSlot,
            currentIndex: currentIndex,
            isSimple: isSimple,
            isHomeActive: !isSimple &&
                currentIndex == RitmoShellMetrics.homeTabIndexFor(AppMode.full),
            onSelectTab: onSelectTab,
            onCenterTap: onCenterTap,
            onCenterLongPress: onCenterLongPress,
          ),
        ),
      ),
    );
  }
}

/// ریل زنده — همهٔ حرکت نوار از یک عدد پیوسته تغذیه می‌شود
class _LivingRail extends StatefulWidget {
  const _LivingRail({
    super.key,
    required this.destinations,
    required this.tints,
    required this.centerSlot,
    required this.currentIndex,
    required this.isSimple,
    required this.isHomeActive,
    required this.onSelectTab,
    required this.onCenterTap,
    this.onCenterLongPress,
  });

  final List<_NavDestination> destinations;
  final List<Color> tints;
  final int centerSlot;
  final int currentIndex;
  final bool isSimple;
  final bool isHomeActive;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onCenterTap;
  final VoidCallback? onCenterLongPress;

  @override
  State<_LivingRail> createState() => _LivingRailState();
}

class _LivingRailState extends State<_LivingRail> {
  late double _railTarget;

  int get _slotCount => widget.destinations.length + 1;

  /// خانهٔ بصری هر مقصد، با در نظر گرفتن جای دکمهٔ مرکزی
  int _slotOfDestination(int destinationOrder) =>
      destinationOrder < widget.centerSlot ? destinationOrder : destinationOrder + 1;

  /// خانهٔ مقصد فعال؛ اگر تب فعال مقصدی روی نوار نداشته باشد (خانه در حالت کامل)
  /// نشانگر به سمت دکمهٔ مرکزی می‌رود و همان‌جا محو می‌شود.
  double _resolveTarget() {
    for (var i = 0; i < widget.destinations.length; i++) {
      if (widget.destinations[i].index == widget.currentIndex) {
        return _slotOfDestination(i).toDouble();
      }
    }
    return widget.centerSlot.toDouble();
  }

  @override
  void initState() {
    super.initState();
    _railTarget = _resolveTarget();
  }

  @override
  void didUpdateWidget(covariant _LivingRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    _railTarget = _resolveTarget();
  }

  double _measureLabel(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final duration = RitmoMotion.effective(context, RitmoMotion.state);
    final labelStyle = RitmoTextStyles.badge(colors.textPrimary)
        .copyWith(fontWeight: FontWeight.w700);
    final idleColor = colors.textSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _RailMetrics.fallbackWidth;
        final scaler = MediaQuery.textScalerOf(context);
        final labelWidths = <double>[
          for (final destination in widget.destinations)
            _measureLabel(destination.label, labelStyle, scaler),
        ];

        return SizedBox(
          width: totalWidth,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: _railTarget, end: _railTarget),
            duration: duration,
            curve: RitmoMotion.enter,
            builder: (context, position, _) {
              // «فعال‌بودن» پیوستهٔ هر مقصد: ۱ وقتی نشانگر روی آن است، ۰ وقتی دور است
              final activations = <double>[
                for (var i = 0; i < widget.destinations.length; i++)
                  (1 - (position - _slotOfDestination(i)).abs()).clamp(0.0, 1.0),
              ];

              // پهنای هر خانه: پایه به‌علاوهٔ فضایی که برچسب فعال باز می‌کند
              final widths = List<double>.filled(_slotCount, 0.0);
              var used = _RailMetrics.centerSlot;
              widths[widget.centerSlot] = _RailMetrics.centerSlot;
              for (var i = 0; i < widget.destinations.length; i++) {
                final width = _RailMetrics.slotBase +
                    activations[i] * (labelWidths[i] + _RailMetrics.labelGap);
                widths[_slotOfDestination(i)] = width;
                used += width;
              }

              // فضای باقی‌مانده بین همهٔ خانه‌ها پخش می‌شود تا نوار همیشه پر بماند
              final share = (totalWidth - used) / _slotCount;
              final starts = List<double>.filled(_slotCount, 0.0);
              var cursor = 0.0;
              for (var i = 0; i < _slotCount; i++) {
                widths[i] =
                    (widths[i] + share).clamp(_RailMetrics.minSlotWidth, totalWidth);
                starts[i] = cursor;
                cursor += widths[i];
              }

              // هندسهٔ نشانگر: بین دو خانهٔ مجاور هم می‌لغزد و هم کش می‌آید
              final lower = position.floor().clamp(0, _slotCount - 1);
              final upper = position.ceil().clamp(0, _slotCount - 1);
              final fraction = position - position.floor();
              final pillStart = starts[lower] +
                  (starts[upper] - starts[lower]) * fraction +
                  _RailMetrics.pillInsetH;
              final pillWidth =
                  (widths[lower] + (widths[upper] - widths[lower]) * fraction) -
                      2 * _RailMetrics.pillInsetH;
              final pillOpacity =
                  activations.fold<double>(0, (best, value) => value > best ? value : best);
              final pillTint = Color.lerp(
                _tintOfSlot(lower, colors.primary),
                _tintOfSlot(upper, colors.primary),
                fraction,
              )!;

              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  if (pillOpacity > 0 && pillWidth > 0)
                    PositionedDirectional(
                      start: pillStart,
                      top: _RailMetrics.pillInsetV,
                      bottom: _RailMetrics.pillInsetV,
                      width: pillWidth,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: pillOpacity,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: pillTint.withValues(alpha: isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(RitmoRadius.pill),
                              border: Border.all(
                                color: pillTint.withValues(alpha: isDark ? 0.40 : 0.30),
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: pillTint.withValues(alpha: isDark ? 0.26 : 0.16),
                                  blurRadius: 14,
                                  spreadRadius: -4,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (var i = 0; i < widget.destinations.length; i++)
                    PositionedDirectional(
                      start: starts[_slotOfDestination(i)],
                      top: 0,
                      bottom: 0,
                      width: widths[_slotOfDestination(i)],
                      child: _DestinationSlot(
                        destination: widget.destinations[i],
                        activation: activations[i],
                        tint: widget.tints[i],
                        idleColor: idleColor,
                        labelStyle: labelStyle,
                        onTap: () {
                          RitmoHapticsPolicy.selection();
                          widget.onSelectTab(widget.destinations[i].index);
                        },
                      ),
                    ),
                  PositionedDirectional(
                    start: starts[widget.centerSlot],
                    top: 0,
                    bottom: 0,
                    width: widths[widget.centerSlot],
                    child: Center(
                      child: _CenterHeroButton(
                        isSimple: widget.isSimple,
                        isHomeActive: widget.isHomeActive,
                        onTap: widget.onCenterTap,
                        onLongPress: widget.onCenterLongPress,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Color _tintOfSlot(int slot, Color fallback) {
    for (var i = 0; i < widget.destinations.length; i++) {
      if (_slotOfDestination(i) == slot) {
        return widget.tints[i];
      }
    }
    return fallback;
  }
}

/// یک مقصد روی ریل — آیکون زنده به‌علاوهٔ برچسبی که فقط برای مقصد فعال باز می‌شود
class _DestinationSlot extends StatelessWidget {
  const _DestinationSlot({
    required this.destination,
    required this.activation,
    required this.tint,
    required this.idleColor,
    required this.labelStyle,
    required this.onTap,
  });

  final _NavDestination destination;
  final double activation;
  final Color tint;
  final Color idleColor;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = activation > 0.5;

    return Semantics(
      button: true,
      selected: isActive,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Transform.translate(
                offset: Offset(0, -_RailMetrics.activeLift * activation),
                child: Transform.scale(
                  scale: 1 + (_RailMetrics.activeScale - 1) * activation,
                  child: Icon(
                    isActive ? destination.activeIcon : destination.inactiveIcon,
                    size: _RailMetrics.iconSize,
                    color: Color.lerp(idleColor, tint, activation),
                  ),
                ),
              ),
              if (activation > 0)
                ClipRect(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: activation,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: _RailMetrics.labelGap,
                      ),
                      child: Opacity(
                        opacity: activation,
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: labelStyle.copyWith(color: tint),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// دکمهٔ قهرمان مرکزی — گرادیان برند، هالهٔ نوری، افت مقیاس و مورف خانه به پلاس
class _CenterHeroButton extends StatefulWidget {
  const _CenterHeroButton({
    required this.isSimple,
    required this.isHomeActive,
    required this.onTap,
    this.onLongPress,
  });

  final bool isSimple;
  final bool isHomeActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_CenterHeroButton> createState() => _CenterHeroButtonState();
}

class _CenterHeroButtonState extends State<_CenterHeroButton> {
  bool _isPressed = false;

  void _handleTap() {
    RitmoHapticsPolicy.tap();
    widget.onTap();
  }

  void _handleLongPress() {
    RitmoHapticsPolicy.selection();
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showPlus = widget.isSimple || widget.isHomeActive;
    final label = widget.isSimple
        ? 'افزودن کار'
        : (widget.isHomeActive ? 'کار جدید' : 'خانه');

    return Semantics(
      button: true,
      label: label,
      onTap: _handleTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: _handleTap,
        onLongPress: widget.onLongPress == null ? null : _handleLongPress,
        child: AnimatedScale(
          scale: _isPressed ? RitmoMotion.pressScale : 1.0,
          duration: RitmoMotion.effective(context, RitmoMotion.press),
          curve: RitmoMotion.enter,
          child: Container(
            width: _RailMetrics.centerButton,
            height: _RailMetrics.centerButton,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: colors.brandGradient,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.42),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.16),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: RitmoMotion.effective(context, RitmoMotion.state),
              switchInCurve: RitmoMotion.enter,
              switchOutCurve: RitmoMotion.exit,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: RotationTransition(
                  turns: Tween<double>(begin: -0.125, end: 0).animate(animation),
                  child: child,
                ),
              ),
              child: showPlus
                  ? Icon(
                      CupertinoIcons.add,
                      key: const ValueKey<String>('nav_center_plus'),
                      size: 23,
                      color: colors.onPrimary,
                    )
                  : Icon(
                      CupertinoIcons.house_fill,
                      key: const ValueKey<String>('nav_center_home'),
                      size: 20,
                      color: colors.onPrimary,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
