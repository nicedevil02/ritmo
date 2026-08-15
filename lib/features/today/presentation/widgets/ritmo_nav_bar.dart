import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_glass_surface.dart';

/// اطلاعات مقصد ناوبری برای ساخت آیتم‌ها و ریل زنده
class _DestinationInfo {
  const _DestinationInfo({
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

/// نوار ناوبری پرمیوم ریتمو — «ریل زنده»
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final reduceTransparency = context.behavior.reduceTransparency;

    return Container(
      height: RitmoShellMetrics.navBarHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RitmoRadius.sheet),
        boxShadow: reduceTransparency
            ? null
            : [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: isDark ? 0.38 : 0.12),
                  blurRadius: 28,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: RitmoGlassSurface(
        blurSigma: 24,
        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm, vertical: RitmoSpacing.xs),
        borderRadius: BorderRadius.circular(RitmoRadius.sheet),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.65),
          width: 1.0,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: mode == AppMode.simple
              ? _buildSimpleBar(context)
              : _buildFullBar(context),
        ),
      ),
    );
  }

  /// حالت ساده: کارها(0) · دکمه(+) · تقویم(1) · بیشتر(2)
  Widget _buildSimpleBar(BuildContext context) {
    const destinations = [
      _DestinationInfo(
        index: 0,
        activeIcon: CupertinoIcons.check_mark_circled_solid,
        inactiveIcon: CupertinoIcons.check_mark_circled,
        label: 'کارها',
      ),
      _DestinationInfo(
        index: 1,
        activeIcon: CupertinoIcons.calendar_circle_fill,
        inactiveIcon: CupertinoIcons.calendar,
        label: 'تقویم',
      ),
      _DestinationInfo(
        index: 2,
        activeIcon: CupertinoIcons.square_grid_2x2_fill,
        inactiveIcon: CupertinoIcons.square_grid_2x2,
        label: 'بیشتر',
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tab 0: Tasks
        _buildDestinationSlot(context, destinations[0]),

        // Center Hero Button: Plus/Focus
        _buildCenterButtonSlot(context),

        // Tab 1: Calendar
        _buildDestinationSlot(context, destinations[1]),

        // Tab 2: More
        _buildDestinationSlot(context, destinations[2]),
      ],
    );
  }

  /// حالت کامل: تقویم(4) · دستیار(3) · دکمه(خانه/+) · سیستم‌ها(0) · بینش‌ها(1)
  Widget _buildFullBar(BuildContext context) {
    const destinations = [
      _DestinationInfo(
        index: 4,
        activeIcon: CupertinoIcons.calendar_circle_fill,
        inactiveIcon: CupertinoIcons.calendar,
        label: 'تقویم',
      ),
      _DestinationInfo(
        index: 3,
        activeIcon: CupertinoIcons.sparkles,
        inactiveIcon: CupertinoIcons.sparkles,
        label: 'دستیار',
      ),
      _DestinationInfo(
        index: 0,
        activeIcon: CupertinoIcons.square_grid_2x2_fill,
        inactiveIcon: CupertinoIcons.square_grid_2x2,
        label: 'سیستم‌ها',
      ),
      _DestinationInfo(
        index: 1,
        activeIcon: CupertinoIcons.lightbulb_fill,
        inactiveIcon: CupertinoIcons.lightbulb,
        label: 'بینش‌ها',
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Tab 4: Calendar
        _buildDestinationSlot(context, destinations[0]),

        // Tab 3: Assistant
        _buildDestinationSlot(context, destinations[1]),

        // Center Hero Button (Home or Universal Planner)
        _buildCenterButtonSlot(context),

        // Tab 0: Systems
        _buildDestinationSlot(context, destinations[2]),

        // Tab 1: Insights
        _buildDestinationSlot(context, destinations[3]),
      ],
    );
  }

  Widget _buildDestinationSlot(BuildContext context, _DestinationInfo dest) {
    final isSelected = currentIndex == dest.index;
    final tintColor = _getDestinationColor(context, dest.index);

    return Flexible(
      child: _RitmoDestinationItem(
        info: dest,
        isSelected: isSelected,
        tintColor: tintColor,
        onTap: () {
          RitmoHapticsPolicy.selection();
          onSelectTab(dest.index);
        },
      ),
    );
  }

  Widget _buildCenterButtonSlot(BuildContext context) {
    final isSimple = mode == AppMode.simple;
    final isHomeActive = !isSimple && currentIndex == RitmoShellMetrics.homeTabIndexFor(AppMode.full);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _RitmoCenterHeroButton(
        isSimple: isSimple,
        isHomeActive: isHomeActive,
        onTap: () {
          RitmoHapticsPolicy.tap();
          onCenterTap();
        },
        onLongPress: onCenterLongPress != null
            ? () {
                RitmoHapticsPolicy.selection();
                onCenterLongPress!();
              }
            : null,
      ),
    );
  }

  /// جدول رنگ هویت مقصد (§۳.۲)
  Color _getDestinationColor(BuildContext context, int index) {
    final colors = context.colors;
    if (mode == AppMode.simple) {
      switch (index) {
        case 0:
          return colors.modules.routines;
        case 1:
          return colors.modules.planner;
        case 2:
          return colors.primary;
        default:
          return colors.primary;
      }
    } else {
      switch (index) {
        case 4:
          return colors.modules.planner;
        case 3:
          return colors.primary;
        case 0:
          return colors.modules.routines;
        case 1:
          return colors.modules.insights;
        default:
          return colors.primary;
      }
    }
  }
}

/// آیتم مقصد ناوبری با قرص لغزان، برچسب پویا و آیکون زنده
class _RitmoDestinationItem extends StatelessWidget {
  const _RitmoDestinationItem({
    required this.info,
    required this.isSelected,
    required this.tintColor,
    required this.onTap,
  });

  final _DestinationInfo info;
  final bool isSelected;
  final Color tintColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final colors = context.colors;
    final reduceMotion = RitmoMotion.reduceMotion(context);
    final duration = RitmoMotion.effective(context, RitmoMotion.state);

    return Semantics(
      button: true,
      selected: isSelected,
      label: info.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: RitmoMotion.enter,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? RitmoSpacing.md : RitmoSpacing.xs,
                vertical: RitmoSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? tintColor.withValues(alpha: isDark ? 0.16 : 0.11)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                border: Border.all(
                  color: isSelected
                      ? tintColor.withValues(alpha: isDark ? 0.38 : 0.28)
                      : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated Icon with Scale & Slide
                  AnimatedSlide(
                    offset: (!reduceMotion && isSelected) ? const Offset(0, -0.06) : Offset.zero,
                    duration: duration,
                    curve: RitmoMotion.enter,
                    child: AnimatedScale(
                      scale: (!reduceMotion && isSelected) ? 1.06 : 1.0,
                      duration: duration,
                      curve: RitmoMotion.enter,
                      child: Icon(
                        isSelected ? info.activeIcon : info.inactiveIcon,
                        color: isSelected
                            ? tintColor
                            : colors.textSecondary.withValues(alpha: 0.72),
                        size: 20,
                      ),
                    ),
                  ),

                  // Label: only shown when active, with smooth animated expansion
                  if (isSelected) ...[
                    const SizedBox(width: RitmoSpacing.xs + 2),
                    Flexible(
                      child: ClipRect(
                        child: AnimatedSize(
                          duration: duration,
                          curve: RitmoMotion.enter,
                          alignment: Alignment.centerRight,
                          child: Text(
                            info.label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: tintColor,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// دکمهٔ قهرمان مرکزی با گرادیان برند، حلقهٔ نوری، افت مقیاس و مورف نرم
class _RitmoCenterHeroButton extends StatefulWidget {
  const _RitmoCenterHeroButton({
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
  State<_RitmoCenterHeroButton> createState() => _RitmoCenterHeroButtonState();
}

class _RitmoCenterHeroButtonState extends State<_RitmoCenterHeroButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = RitmoMotion.reduceMotion(context);
    final duration = RitmoMotion.effective(context, RitmoMotion.press);

    return Semantics(
      button: true,
      label: widget.isSimple
          ? 'افزودن کار'
          : (widget.isHomeActive ? 'برنامه‌ریز و کار جدید' : 'خانه'),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: (!reduceMotion && _isPressed) ? RitmoMotion.pressScale : 1.0,
          duration: duration,
          curve: RitmoMotion.enter,
          child: Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors.brandGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: RitmoMotion.effective(context, RitmoMotion.state),
              transitionBuilder: (child, animation) {
                if (reduceMotion) {
                  return child;
                }
                return RotationTransition(
                  turns: Tween<double>(begin: 0.125, end: 0.0).animate(animation),
                  child: ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                );
              },
              child: widget.isSimple || widget.isHomeActive
                  ? Icon(
                      CupertinoIcons.add,
                      key: const ValueKey('plus_icon'),
                      color: colors.onPrimary,
                      size: 23,
                    )
                  : Icon(
                      CupertinoIcons.house_fill,
                      key: const ValueKey('home_icon'),
                      color: colors.onPrimary,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
