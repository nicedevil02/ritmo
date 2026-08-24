// نوار ناوبری فوق‌صیقلی و پرمیوم ریتمو با ارتفاع بهینه و قوس لغزان سیال
// (Ultra-Polished Sleek Moving Notch Navigation Bar)

import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// مدل هر مقصد ناوبری
class _NavItem {
  const _NavItem({
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

/// نوار ناوبری باریک، لوکس و متحرک ریتمو
class RitmoNavBar extends StatefulWidget {
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

  static const List<_NavItem> _fullDestinations = [
    _NavItem(
      index: 4,
      activeIcon: CupertinoIcons.calendar_circle_fill,
      inactiveIcon: CupertinoIcons.calendar,
      label: 'تقویم',
    ),
    _NavItem(
      index: 3,
      activeIcon: CupertinoIcons.sparkles,
      inactiveIcon: CupertinoIcons.sparkles,
      label: 'دستیار',
    ),
    _NavItem(
      index: 2,
      activeIcon: CupertinoIcons.house_fill,
      inactiveIcon: CupertinoIcons.house_fill,
      label: 'خانه',
    ),
    _NavItem(
      index: 0,
      activeIcon: CupertinoIcons.square_grid_2x2_fill,
      inactiveIcon: CupertinoIcons.square_grid_2x2,
      label: 'سیستم‌ها',
    ),
    _NavItem(
      index: 1,
      activeIcon: CupertinoIcons.lightbulb_fill,
      inactiveIcon: CupertinoIcons.lightbulb,
      label: 'بینش‌ها',
    ),
  ];

  static const List<_NavItem> _simpleDestinations = [
    _NavItem(
      index: 0,
      activeIcon: CupertinoIcons.check_mark_circled_solid,
      inactiveIcon: CupertinoIcons.check_mark_circled,
      label: 'کارها',
    ),
    _NavItem(
      index: 1,
      activeIcon: CupertinoIcons.house_fill,
      inactiveIcon: CupertinoIcons.house_fill,
      label: 'خانه',
    ),
    _NavItem(
      index: 2,
      activeIcon: CupertinoIcons.calendar_circle_fill,
      inactiveIcon: CupertinoIcons.calendar,
      label: 'تقویم',
    ),
  ];

  @override
  State<RitmoNavBar> createState() => _RitmoNavBarState();
}

class _RitmoNavBarState extends State<RitmoNavBar> {
  List<_NavItem> get _destinations => widget.mode == AppMode.simple
      ? RitmoNavBar._simpleDestinations
      : RitmoNavBar._fullDestinations;

  int _findSlotIndex(int targetIndex) {
    final dests = _destinations;
    for (var i = 0; i < dests.length; i++) {
      if (dests[i].index == targetIndex) return i;
    }
    return dests.length ~/ 2;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final behavior = context.behavior;
    final isDark = context.isDark;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final destinations = _destinations;
    final slotCount = destinations.length;
    final activeSlot = _findSlotIndex(widget.currentIndex);

    final isGlassEnabled = !behavior.reduceTransparency && !highContrast;

    // Glass / Theme-Aware Color Tokens
    final Color barBgColor;
    final Color borderColor;
    final Color shadowColor;

    if (!isGlassEnabled) {
      // Solid Fallback for reduced transparency / high contrast
      barBgColor = colors.surfaceElevated;
      borderColor = highContrast
          ? colors.textPrimary
          : (isDark ? colors.border : colors.divider);
      shadowColor = isDark
          ? Colors.black.withValues(alpha: 0.35)
          : (colors.shadow.a > 0 ? colors.shadow : Colors.black.withValues(alpha: 0.06));
    } else {
      // Frosted Glass Tint adhering to Central Ritmo Theme
      barBgColor = colors.glassTint;
      borderColor = isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.65);
      shadowColor = Colors.black.withValues(alpha: isDark ? 0.38 : 0.05);
    }

    final centerBtnColor = isDark ? const Color(0xFF1B2228) : const Color(0xFF1C2126);

    return SizedBox(
      height: context.metrics.navBarHeight + bottomInset,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final slotWidth = totalWidth / slotCount;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: activeSlot.toDouble(),
              end: activeSlot.toDouble(),
            ),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutQuart,
            builder: (context, currentSlotPosition, _) {
              // محاسبه مرکز هلال در حالت RTL
              final notchCenterX =
                  totalWidth - (currentSlotPosition + 0.5) * slotWidth;

              final activeItem = destinations[activeSlot];

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. سایه هماهنگ با لبه‌های هلال
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DockedNotchedBarShadowPainter(
                        shadowColor: shadowColor,
                        notchCenterX: notchCenterX,
                      ),
                    ),
                  ),

                  // 2. پس‌زمینهٔ شیشه‌ای صیقلی با بلور زنده
                  Positioned.fill(
                    child: isGlassEnabled
                        ? ClipPath(
                            clipper: _DockedNotchedBarClipper(
                              notchCenterX: notchCenterX,
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 25.0,
                                sigmaY: 25.0,
                              ),
                              child: CustomPaint(
                                painter: _DockedNotchedBarPainter(
                                  color: barBgColor,
                                  borderColor: borderColor,
                                  notchCenterX: notchCenterX,
                                ),
                              ),
                            ),
                          )
                        : CustomPaint(
                            painter: _DockedNotchedBarPainter(
                              color: barBgColor,
                              borderColor: borderColor,
                              notchCenterX: notchCenterX,
                            ),
                          ),
                  ),

                  // 3. تب‌های کناری با ترنزیشن محوشدگی نرم
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: RitmoShellMetrics.navBarHeight,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: [
                          for (var i = 0; i < slotCount; i++)
                            Expanded(
                              child: _StaticSlotItem(
                                item: destinations[i],
                                isActive: i == activeSlot,
                                slotDistance: (currentSlotPosition - i).abs(),
                                isDark: isDark,
                                onTap: () {
                                  if (destinations[i].index ==
                                      RitmoShellMetrics.homeTabIndexFor(
                                        widget.mode,
                                      )) {
                                    HapticFeedback.mediumImpact();
                                    widget.onCenterTap();
                                  } else {
                                    HapticFeedback.selectionClick();
                                    widget.onSelectTab(destinations[i].index);
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 4. دکمهٔ دایره‌ای شناور فوق‌لوکس با موقعیت هماهنگ با هلال
                  Positioned(
                    left: notchCenterX - 19,
                    top: -5,
                    width: 38,
                    height: 38,
                    child: _AnimatedFloatingButton(
                      activeItem: activeItem,
                      backgroundColor: centerBtnColor,
                      isDark: isDark,
                      onTap: () {
                        if (activeItem.index ==
                            RitmoShellMetrics.homeTabIndexFor(widget.mode)) {
                          HapticFeedback.mediumImpact();
                          widget.onCenterTap();
                        } else {
                          HapticFeedback.selectionClick();
                          widget.onSelectTab(activeItem.index);
                        }
                      },
                      onLongPress: widget.onCenterLongPress,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// تب ثابت با محوشدگی هماهنگ
class _StaticSlotItem extends StatelessWidget {
  const _StaticSlotItem({
    required this.item,
    required this.isActive,
    required this.slotDistance,
    required this.isDark,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final double slotDistance;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark ? const Color(0xFF6B7880) : const Color(0xFF9AA4A8);

    final iconOpacity = (slotDistance * 1.6).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      selected: isActive,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Opacity(
                opacity: iconOpacity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.inactiveIcon,
                      size: 18,
                      color: inactiveColor,
                    ),
                    if (!isActive) ...[
                      const SizedBox(height: 1.5),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w600,
                          color: inactiveColor,
                          letterSpacing: -0.2,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// دکمهٔ دایره‌ای شناور صیقلی با لبهٔ Specular
/// دکمهٔ دایره‌ای شناور صیقلی با انیمیشن تغییر آیکون خانه به +
class _AnimatedFloatingButton extends StatefulWidget {
  const _AnimatedFloatingButton({
    required this.activeItem,
    required this.backgroundColor,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  final _NavItem activeItem;
  final Color backgroundColor;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_AnimatedFloatingButton> createState() => _AnimatedFloatingButtonState();
}

class _AnimatedFloatingButtonState extends State<_AnimatedFloatingButton> {
  bool _isPressed = false;
  bool _showPlusOnHome = false;
  Timer? _homeMorphTimer;
  Timer? _subMorphTimer;
  Timer? _initialMorphTimer;

  bool get _isHome => widget.activeItem.label == 'خانه';

  @override
  void initState() {
    super.initState();
    _setupHomeMorphing();
  }

  @override
  void didUpdateWidget(covariant _AnimatedFloatingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeItem.index != widget.activeItem.index ||
        oldWidget.activeItem.label != widget.activeItem.label) {
      _setupHomeMorphing();
    }
  }

  @override
  void dispose() {
    _homeMorphTimer?.cancel();
    _subMorphTimer?.cancel();
    _initialMorphTimer?.cancel();
    super.dispose();
  }

  void _setupHomeMorphing() {
    _homeMorphTimer?.cancel();
    _subMorphTimer?.cancel();
    _initialMorphTimer?.cancel();

    if (!_isHome) {
      if (_showPlusOnHome) {
        setState(() => _showPlusOnHome = false);
      }
      return;
    }

    // پس از رفتن به تب خانه، با یک انیمیشن نرم به + تبدیل می‌شود
    _initialMorphTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || !_isHome) return;
      setState(() => _showPlusOnHome = true);
      _startPeriodicMorphing();
    });
  }

  void _startPeriodicMorphing() {
    _homeMorphTimer?.cancel();
    _subMorphTimer?.cancel();

    // چرخهٔ ۷ ثانیه‌ای: ۵ ثانیه روی + و ۲ ثانیه روی خانه
    _homeMorphTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted || !_isHome) {
        timer.cancel();
        return;
      }
      // به آیکون خانه تغییر می‌کند (۲ ثانیه)
      setState(() => _showPlusOnHome = false);

      // پس از ۲ ثانیه مجدداً به + تبدیل می‌شود (۵ ثانیه باقی‌مانده)
      _subMorphTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted || !_isHome) return;
        setState(() => _showPlusOnHome = true);
      });
    });
  }

  IconData get _currentIcon {
    if (_isHome && _showPlusOnHome) {
      return CupertinoIcons.add;
    }
    return widget.activeItem.activeIcon;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.activeItem.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.backgroundColor,
              boxShadow: [
                // سایهٔ نرم و لوکس زیر دکمه
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isDark ? 0.45 : 0.18,
                  ),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: Tween<double>(begin: -0.2, end: 0.0).animate(animation),
                  child: ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                ),
                child: Icon(
                  _currentIcon,
                  key: ValueKey<IconData>(_currentIcon),
                  size: _currentIcon == CupertinoIcons.add ? 22 : 19,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// مسیر هلال مقعر متحرک
Path _buildNotchPath(double w, double h, double cx) {
  const notchHalfWidth = 44.0;
  const notchDepth = 35.0;

  final p = Path();
  p.moveTo(0, 0);
  p.lineTo(cx - notchHalfWidth, 0);

  // ۱. قوس محدب شانه چپ (انحنای فوق‌العاده نرم از خط افقی به سمت پایین)
  p.cubicTo(
    cx - notchHalfWidth + 14.0, 0.0,
    cx - notchHalfWidth * 0.55 - 3.0, notchDepth * 0.28,
    cx - notchHalfWidth * 0.50, notchDepth * 0.44,
  );

  // ۲. قوس مقعر گودی چپ (رسیدن نرم به کف گرد هلال)
  p.cubicTo(
    cx - notchHalfWidth * 0.50 + 5.0, notchDepth * 0.62,
    cx - 14.0, notchDepth,
    cx, notchDepth,
  );

  // ۳. قوس مقعر گودی راست (خروج نرم از کف هلال)
  p.cubicTo(
    cx + 14.0, notchDepth,
    cx + notchHalfWidth * 0.50 - 5.0, notchDepth * 0.62,
    cx + notchHalfWidth * 0.50, notchDepth * 0.44,
  );

  // ۴. قوس محدب شانه راست (بازگشت کاملاً نرم و بی‌گوشه به خط افقی)
  p.cubicTo(
    cx + notchHalfWidth * 0.55 + 3.0, notchDepth * 0.28,
    cx + notchHalfWidth - 14.0, 0.0,
    cx + notchHalfWidth, 0.0,
  );

  p.lineTo(w, 0);
  p.lineTo(w, h);
  p.lineTo(0, h);
  p.close();

  return p;
}

/// کلیپر دقیق فرم نوار برای ماسک کردن فیلتر شیشه‌ای (BackdropFilter)
class _DockedNotchedBarClipper extends CustomClipper<Path> {
  const _DockedNotchedBarClipper({required this.notchCenterX});
  final double notchCenterX;

  @override
  Path getClip(Size size) => _buildNotchPath(size.width, size.height, notchCenterX);

  @override
  bool shouldReclip(covariant _DockedNotchedBarClipper oldClipper) =>
      oldClipper.notchCenterX != notchCenterX;
}

/// نقاش سایهٔ نرم پیرامون نوار ناوبری
class _DockedNotchedBarShadowPainter extends CustomPainter {
  const _DockedNotchedBarShadowPainter({
    required this.shadowColor,
    required this.notchCenterX,
  });

  final Color shadowColor;
  final double notchCenterX;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildNotchPath(size.width, size.height, notchCenterX);
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.save();
    canvas.translate(0, -2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DockedNotchedBarShadowPainter oldDelegate) =>
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.notchCenterX != notchCenterX;
}

/// نقاش پس‌زمینهٔ صیقلی با هلال مقعر و خط براق بالای شیشه
class _DockedNotchedBarPainter extends CustomPainter {
  const _DockedNotchedBarPainter({
    required this.color,
    required this.borderColor,
    required this.notchCenterX,
  });

  final Color color;
  final Color borderColor;
  final double notchCenterX;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = notchCenterX;
    const notchHalfWidth = 44.0;
    const notchDepth = 35.0;

    final path = _buildNotchPath(w, h, cx);

    // Draw background (Frosted Glass Tint or Solid surface)
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Draw top specular border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final topBorderPath = Path();
    topBorderPath.moveTo(0, 0);
    topBorderPath.lineTo(cx - notchHalfWidth, 0);
    topBorderPath.cubicTo(
      cx - notchHalfWidth + 14.0, 0.0,
      cx - notchHalfWidth * 0.55 - 3.0, notchDepth * 0.28,
      cx - notchHalfWidth * 0.50, notchDepth * 0.44,
    );
    topBorderPath.cubicTo(
      cx - notchHalfWidth * 0.50 + 5.0, notchDepth * 0.62,
      cx - 14.0, notchDepth,
      cx, notchDepth,
    );
    topBorderPath.cubicTo(
      cx + 14.0, notchDepth,
      cx + notchHalfWidth * 0.50 - 5.0, notchDepth * 0.62,
      cx + notchHalfWidth * 0.50, notchDepth * 0.44,
    );
    topBorderPath.cubicTo(
      cx + notchHalfWidth * 0.55 + 3.0, notchDepth * 0.28,
      cx + notchHalfWidth - 14.0, 0.0,
      cx + notchHalfWidth, 0.0,
    );
    topBorderPath.lineTo(w, 0);
    canvas.drawPath(topBorderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _DockedNotchedBarPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.notchCenterX != notchCenterX;
  }
}
