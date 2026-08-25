// نوار ناوبری نئومورفیک فوق‌پرمیوم و صیقلی ریتمو با لبه‌های پخ‌خورده، گودی سه‌بعدی و دکمه متالیک
// (Ultra-Premium Tactile Neumorphic Navigation Bar with Specular Chamfer, Recessed Crater Socket & Elevated Button)

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

// ── Neumorphic & Tactile Design Constants ─────────────────────────
const double _kHMargin = 16.0; // horizontal margin of the pill
const double _kBottomGap = 8.0; // gap between pill bottom and nav area bottom
const double _kPillRadius = 26.0; // corner radius (capsule)
const double _kMoundHeight = 11.0; // height of the crest mound above baseline
const double _kMoundHW = 44.0; // mound half-width at baseline
const double _kCenterBtnSize = 48.0; // center elevated button diameter
const double _kCenterBtnRimW = 2.8; // metallic white rim width
const double _kIconSize = 20.0; // inactive item icon size
const double _kLabelSize = 9.5; // label font size
const double _kIndicatorW = 14.0; // active indicator bar width
const double _kIndicatorH = 3.0; // active indicator bar height

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

/// نوار ناوبری نئومورفیک فوق‌لوکس ریتمو
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
      activeIcon: CupertinoIcons.person_crop_circle_fill,
      inactiveIcon: CupertinoIcons.person_crop_circle,
      label: 'پروفایل',
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
    final isDark = context.isDark;
    final behavior = context.behavior;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final isGlassEnabled = !behavior.reduceTransparency && !highContrast;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final destinations = _destinations;
    final slotCount = destinations.length;
    final activeSlot = _findSlotIndex(widget.currentIndex);

    // ── Dynamic Theme & Neumorphic Palette Tokens ──
    final Color pillTop = isDark
        ? colors.surfaceElevated
        : colors.surface;
    final Color pillBottom = isDark
        ? colors.surface
        : colors.surfaceSunken;

    final Color shadowDarkAmbient = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : colors.shadow.withValues(alpha: 0.35);
    final Color shadowDarkDirect = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : colors.shadow.withValues(alpha: 0.25);

    final Color borderTop = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.95);
    final Color borderBottom = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : colors.border.withValues(alpha: 0.35);

    final Color inactiveColor = colors.textTertiary;
    final Color indicatorColor = colors.primary;

    // ── Active Center Floating Button Colors from Active Palette ──
    final Color centerBtnColorTop = colors.brandGradient.isNotEmpty
        ? colors.brandGradient.first
        : colors.primary;
    final Color centerBtnColorBottom = colors.brandGradient.length > 1
        ? colors.brandGradient.last
        : colors.primaryPressed;
    final Color centerBtnIconColor = colors.onPrimary;
    final Color centerBtnRim = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.95);

    final navH = context.metrics.navBarHeight;
    final pillH = navH - _kBottomGap;

    return SizedBox(
      height: navH + bottomInset,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final barWidth = totalWidth - 2 * _kHMargin;
          final slotWidth = barWidth / slotCount;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: activeSlot.toDouble(),
              end: activeSlot.toDouble(),
            ),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutQuart,
            builder: (context, currentSlotPos, _) {
              // محاسبه مرکز قوس و دکمه نسبت به داخل قرص (RTL)
              final ncx = barWidth - (currentSlotPos + 0.5) * slotWidth;
              final activeItem = destinations[activeSlot];

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ─── 1. سایه‌های سه‌بعدی نئومورفیک (لایه عمقی + لایه مستقیم) ───
                  Positioned(
                    left: _kHMargin,
                    right: _kHMargin,
                    top: 0,
                    height: pillH,
                    child: CustomPaint(
                      painter: _NeumorphicShadowPainter(
                        darkShadowAmbient: shadowDarkAmbient,
                        darkShadowDirect: shadowDarkDirect,
                        moundCenterX: ncx,
                      ),
                    ),
                  ),

                  // ─── 2. بدنه قرص با شیب سه‌بعدی، بلور زنده و حاشیه پخ‌خورده نورانی (Specular Chamfer) ───
                  Positioned(
                    left: _kHMargin,
                    right: _kHMargin,
                    top: 0,
                    height: pillH,
                    child: isGlassEnabled
                        ? ClipPath(
                            clipper: _PillMoundClipper(
                              moundCenterX: ncx,
                            ),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 25.0,
                                sigmaY: 25.0,
                              ),
                              child: CustomPaint(
                                painter: _NeumorphicPillPainter(
                                  fillGradientTop: pillTop.withValues(
                                    alpha: isDark ? 0.75 : 0.85,
                                  ),
                                  fillGradientBottom: pillBottom.withValues(
                                    alpha: isDark ? 0.88 : 0.92,
                                  ),
                                  borderGradientTop: borderTop,
                                  borderGradientBottom: borderBottom,
                                  moundCenterX: ncx,
                                ),
                              ),
                            ),
                          )
                        : CustomPaint(
                            painter: _NeumorphicPillPainter(
                              fillGradientTop: pillTop,
                              fillGradientBottom: pillBottom,
                              borderGradientTop: borderTop,
                              borderGradientBottom: borderBottom,
                              moundCenterX: ncx,
                            ),
                          ),
                  ),

                  // ─── 3. تورفتگی نرم پارچه‌ای روی نوار دور دکمه (از ساعت ۲ تا ۱۰ با شعاع ۲۸ پیکسل) ───
                  Positioned(
                    left: _kHMargin,
                    right: _kHMargin,
                    top: 0,
                    height: pillH,
                    child: CustomPaint(
                      painter: _SunkenCraterPainter(
                        centerX: ncx,
                        centerY: -2.0 + _kCenterBtnSize / 2,
                        radius: 28.0,
                        isDark: isDark,
                      ),
                    ),
                  ),

                  // ─── 4. آیتم‌های ناوبری (کاملاً متمرکز در راستای عمودی) ───
                  Positioned(
                    left: _kHMargin,
                    right: _kHMargin,
                    top: _kMoundHeight,
                    height: pillH - _kMoundHeight,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: [
                          for (var i = 0; i < slotCount; i++)
                            Expanded(
                              child: _NeumorphicSlotItem(
                                item: destinations[i],
                                isActive: i == activeSlot,
                                slotDistance: (currentSlotPos - i).abs(),
                                inactiveColor: inactiveColor,
                                indicatorColor: indicatorColor,
                                onTap: () {
                                  if (destinations[i].index ==
                                      RitmoShellMetrics.homeTabIndexFor(
                                        widget.mode,
                                      )) {
                                    RitmoHaptics.confirm();
                                    widget.onCenterTap();
                                  } else {
                                    RitmoHaptics.selection();
                                    widget.onSelectTab(
                                      destinations[i].index,
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ─── 5. دکمه دایره‌ای شناور فوق‌لوکس با حلقه متالیک و گرادیان سه‌بعدی ───
                  Positioned(
                    left: _kHMargin + ncx - _kCenterBtnSize / 2,
                    top: -2.0,
                    width: _kCenterBtnSize,
                    height: _kCenterBtnSize,
                    child: _AnimatedFloatingButton(
                      activeItem: activeItem,
                      bgTop: centerBtnColorTop,
                      bgBottom: centerBtnColorBottom,
                      iconColor: centerBtnIconColor,
                      rimColor: centerBtnRim,
                      isDark: isDark,
                      onTap: () {
                        if (activeItem.index ==
                            RitmoShellMetrics.homeTabIndexFor(widget.mode)) {
                          RitmoHaptics.confirm();
                          widget.onCenterTap();
                        } else {
                          RitmoHaptics.selection();
                          widget.onSelectTab(activeItem.index);
                        }
                      },
                      onLongPress: widget.onCenterLongPress != null
                          ? () {
                              RitmoHaptics.warning();
                              widget.onCenterLongPress!();
                            }
                          : null,
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

// ═══════════════════════════════════════════════════════════════════
//  آیتم اسلات نئومورفیک (متمرکز در راستای عمودی)
// ═══════════════════════════════════════════════════════════════════

class _NeumorphicSlotItem extends StatelessWidget {
  const _NeumorphicSlotItem({
    required this.item,
    required this.isActive,
    required this.slotDistance,
    required this.inactiveColor,
    required this.indicatorColor,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final double slotDistance;
  final Color inactiveColor;
  final Color indicatorColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconOpacity = isActive
        ? 0.0
        : (slotDistance < 0.7
            ? (slotDistance / 0.7).clamp(0.0, 1.0)
            : 1.0);

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── فضای آیکون ──
                SizedBox(
                  height: _kIconSize,
                  child: isActive
                      ? null
                      : Opacity(
                          opacity: iconOpacity,
                          child: ValueListenableBuilder<int>(
                            valueListenable: SettingsService.instance.revision,
                            builder: (context, revision, child) {
                              if (item.label == 'پروفایل') {
                                final avatarPath = SettingsService.instance
                                    .get<String>('user_avatar_path');
                                if (avatarPath.isNotEmpty &&
                                    File(avatarPath).existsSync()) {
                                  return Container(
                                    width: _kIconSize,
                                    height: _kIconSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            inactiveColor.withValues(alpha: 0.6),
                                        width: 1.0,
                                      ),
                                      image: DecorationImage(
                                        image: FileImage(File(avatarPath)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                }
                              }
                              return Icon(
                                item.inactiveIcon,
                                size: _kIconSize,
                                color: inactiveColor,
                              );
                            },
                          ),
                        ),
                ),

                const SizedBox(height: 3),

                // ── لیبل (در حالت فعال ناپدید می‌شود تا زیر دکمه نماند) ──
                SizedBox(
                  height: _kLabelSize,
                  child: isActive
                      ? null
                      : Opacity(
                          opacity: iconOpacity,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontSize: _kLabelSize,
                              fontWeight: FontWeight.w500,
                              color: inactiveColor,
                              letterSpacing: -0.2,
                              height: 1.0,
                            ),
                          ),
                        ),
                ),

                // ── نشانگر فعال (خط کوچک زیر دکمه) ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: isActive ? _kIndicatorW : 0,
                  height: _kIndicatorH,
                  margin: EdgeInsets.only(top: isActive ? 6 : 0),
                  decoration: BoxDecoration(
                    color: isActive ? indicatorColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(_kIndicatorH / 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  نقاش تورفتگی سه‌بعدی روی نوار دور دکمه (از ساعت ۲ تا ۱۰ با شعاع ۲۷ پیکسل)
// ═══════════════════════════════════════════════════════════════════

class _SunkenCraterPainter extends CustomPainter {
  const _SunkenCraterPainter({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.isDark,
  });

  final double centerX;
  final double centerY;
  final double radius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(centerX, centerY);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // زاویه ساعت ۲ (-۳۰ درجه یا -pi/6) تا ساعت ۱۰ (۲۱۰ درجه یا 7pi/6)
    // طول کمان: ۴pi/3 (۲۴۰ درجه رو به پایین)
    const startAngle = -math.pi / 6;
    const sweepAngle = math.pi * 4 / 3;

    // ۱. سایه عمقی، نرم و پخش‌شده پارچه‌ای (Soft Velvet Fabric Crease Shadow)
    final innerShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4)
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        [
          (isDark ? Colors.black : const Color(0xFF707D8F))
              .withValues(alpha: isDark ? 0.45 : 0.30),
          (isDark ? Colors.black : const Color(0xFF94A0B0))
              .withValues(alpha: isDark ? 0.20 : 0.12),
          Colors.transparent,
        ],
        [0.0, 0.6, 1.0],
      );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1.2),
      startAngle,
      sweepAngle,
      false,
      innerShadowPaint,
    );

    // ۲. هایلایت مات، مخملی و ملایم لبه فرورفتگی پارچه‌ای (Velvety Specular Ambient Catch)
    final rimHighlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4)
      ..shader = ui.Gradient.linear(
        Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius),
        [
          Colors.transparent,
          (isDark ? Colors.white : Colors.white)
              .withValues(alpha: isDark ? 0.18 : 0.70),
        ],
        [0.35, 1.0],
      );

    canvas.drawArc(
      rect,
      startAngle,
      sweepAngle,
      false,
      rimHighlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SunkenCraterPainter oldDelegate) =>
      oldDelegate.centerX != centerX ||
      oldDelegate.centerY != centerY ||
      oldDelegate.radius != radius ||
      oldDelegate.isDark != isDark;
}

// ═══════════════════════════════════════════════════════════════════
//  دکمه دایره‌ای شناور با حلقه متالیک و انیمیشن مورف آیکون
// ═══════════════════════════════════════════════════════════════════

class _AnimatedFloatingButton extends StatefulWidget {
  const _AnimatedFloatingButton({
    required this.activeItem,
    required this.bgTop,
    required this.bgBottom,
    required this.iconColor,
    required this.rimColor,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  final _NavItem activeItem;
  final Color bgTop;
  final Color bgBottom;
  final Color iconColor;
  final Color rimColor;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_AnimatedFloatingButton> createState() =>
      _AnimatedFloatingButtonState();
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

    _initialMorphTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || !_isHome) return;
      setState(() => _showPlusOnHome = true);
      _startPeriodicMorphing();
    });
  }

  void _startPeriodicMorphing() {
    _homeMorphTimer?.cancel();
    _subMorphTimer?.cancel();

    _homeMorphTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted || !_isHome) {
        timer.cancel();
        return;
      }
      setState(() => _showPlusOnHome = false);

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
              // حلقه متالیک براق بیرونی
              border: Border.all(
                color: widget.rimColor,
                width: _kCenterBtnRimW,
              ),
              boxShadow: [
                // سایه اصلی عمیق زیر دکمه
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isDark ? 0.55 : 0.28,
                  ),
                  blurRadius: 14,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
                // سایه تماس لبه
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isDark ? 0.35 : 0.15,
                  ),
                  blurRadius: 4,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.bgTop,
                    widget.bgBottom,
                  ],
                ),
              ),
              child: Center(
                child: ValueListenableBuilder<int>(
                  valueListenable: SettingsService.instance.revision,
                  builder: (context, revision, child) {
                    final avatarPath = SettingsService.instance
                        .get<String>('user_avatar_path');
                    final isProfile = widget.activeItem.label == 'پروفایل';
                    final bool hasAvatar = isProfile &&
                        avatarPath.isNotEmpty &&
                        File(avatarPath).existsSync();

                    final Widget currentChild;
                    if (hasAvatar) {
                      currentChild = Container(
                        key: ValueKey<String>('avatar_$avatarPath'),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          image: DecorationImage(
                            image: FileImage(File(avatarPath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    } else {
                      currentChild = Icon(
                        _currentIcon,
                        key: ValueKey<String>('icon_${_currentIcon.codePoint}'),
                        size: _currentIcon == CupertinoIcons.add ? 24 : 22,
                        color: widget.iconColor,
                      );
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) =>
                          RotationTransition(
                        turns: Tween<double>(begin: -0.15, end: 0.0)
                            .animate(animation),
                        child: ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                      ),
                      child: currentChild,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  مسیر قرص کپسولی با قوس برآمده (Mound Crest) هوشمند و انطباقی
// ═══════════════════════════════════════════════════════════════════

/// کلیپر دقیق مسیر قرص کپسولی با قوس برآمده جهت اتصال فیلتر BackdropFilter شیشه‌ای
class _PillMoundClipper extends CustomClipper<Path> {
  const _PillMoundClipper({required this.moundCenterX});

  final double moundCenterX;

  @override
  Path getClip(Size size) {
    return _buildPillMoundPath(size.width, size.height, moundCenterX);
  }

  @override
  bool shouldReclip(covariant _PillMoundClipper oldClipper) =>
      oldClipper.moundCenterX != moundCenterX;
}

/// مسیر قرص کپسولی با قوس برآمده هوشمند و انطباقی
Path _buildPillMoundPath(double w, double h, double cx) {
  const r = _kPillRadius;
  const base = _kMoundHeight;
  const mhw = _kMoundHW;

  // ۱. بدنه پایه کپسول (قرص کامل با گوشه‌های کاملاً گرد)
  final pillPath = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, base, w, h - base),
        const Radius.circular(r),
      ),
    );

  // ۲. محاسبه مرزهای شیب قوس (شیب نرم به سمت داخل، ادغام طبیعی با گوشه در سمت بیرونی)
  final clampedCx = cx.clamp(r + 6.0, w - r - 6.0);
  final mLeft = (clampedCx - mhw).clamp(r, w - r);
  final mRight = (clampedCx + mhw).clamp(r, w - r);

  final leftSpan = clampedCx - mLeft;
  final rightSpan = mRight - clampedCx;

  final moundPath = Path();
  moundPath.moveTo(mLeft, base);

  // شیب سمت چپ (صعود به قله با قوس سیال)
  moundPath.cubicTo(
    mLeft + leftSpan * 0.45,
    base,
    clampedCx - leftSpan * 0.40,
    0.0,
    clampedCx,
    0.0,
  );

  // شیب سمت راست (نزول از قله با قوس سیال)
  moundPath.cubicTo(
    clampedCx + rightSpan * 0.40,
    0.0,
    mRight - rightSpan * 0.45,
    base,
    mRight,
    base,
  );

  moundPath.lineTo(mRight, base + 12.0);
  moundPath.lineTo(mLeft, base + 12.0);
  moundPath.close();

  // ۳. پیوند و ادغام ریاضی بی‌نقص
  return Path.combine(PathOperation.union, pillPath, moundPath);
}

// ═══════════════════════════════════════════════════════════════════
//  نقاش سایه محیطی و عمق چندلایه نئومورفیک
// ═══════════════════════════════════════════════════════════════════

class _NeumorphicShadowPainter extends CustomPainter {
  const _NeumorphicShadowPainter({
    required this.darkShadowAmbient,
    required this.darkShadowDirect,
    required this.moundCenterX,
  });

  final Color darkShadowAmbient;
  final Color darkShadowDirect;
  final double moundCenterX;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPillMoundPath(size.width, size.height, moundCenterX);

    // ۱. سایه پخش‌شده محیطی در زیر نوار (Ambient Diffused Shadow)
    final ambientPaint = Paint()
      ..color = darkShadowAmbient
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.save();
    canvas.translate(0, 7);
    canvas.drawPath(path, ambientPaint);
    canvas.restore();

    // ۲. سایه مستقیم تماسی در زیر نوار (Direct Contact Shadow)
    final directPaint = Paint()
      ..color = darkShadowDirect
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.save();
    canvas.translate(0, 2);
    canvas.drawPath(path, directPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NeumorphicShadowPainter oldDelegate) =>
      oldDelegate.darkShadowAmbient != darkShadowAmbient ||
      oldDelegate.darkShadowDirect != darkShadowDirect ||
      oldDelegate.moundCenterX != moundCenterX;
}

// ═══════════════════════════════════════════════════════════════════
//  نقاش بدنه قرص کپسولی با حاشیه پخ‌خورده نورانی (Specular Chamfer)
// ═══════════════════════════════════════════════════════════════════

class _NeumorphicPillPainter extends CustomPainter {
  const _NeumorphicPillPainter({
    required this.fillGradientTop,
    required this.fillGradientBottom,
    required this.borderGradientTop,
    required this.borderGradientBottom,
    required this.moundCenterX,
  });

  final Color fillGradientTop;
  final Color fillGradientBottom;
  final Color borderGradientTop;
  final Color borderGradientBottom;
  final double moundCenterX;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPillMoundPath(size.width, size.height, moundCenterX);

    // ۱. پر کردن بدنه با گرادیان سه‌بعدی ملایم
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [fillGradientTop, fillGradientBottom],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // ۲. حاشیه پخ‌خورده براق سه‌بعدی (Specular Chamfer Border)
    final borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [borderGradientTop, borderGradientBottom],
        [0.0, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NeumorphicPillPainter oldDelegate) =>
      oldDelegate.fillGradientTop != fillGradientTop ||
      oldDelegate.fillGradientBottom != fillGradientBottom ||
      oldDelegate.borderGradientTop != borderGradientTop ||
      oldDelegate.borderGradientBottom != borderGradientBottom ||
      oldDelegate.moundCenterX != moundCenterX;
}
