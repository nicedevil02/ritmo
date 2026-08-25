// نوار ناوبری شیشه‌ای پویا و پرمیوم ریتمو با دکمه مرکزی برجسته و طراحی کپسولی شناور
// (Premium Dynamic Glassmorphic Floating Pill Navigation Bar with Elevated Center Button)

import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

// ── Glassmorphic & Pill Design Constants ─────────────────────────
const double _kHMargin = 16.0; // horizontal margin of the pill
const double _kBottomGap = 8.0; // gap between pill bottom and nav area bottom
const double _kPillRadius = 26.0; // corner radius (capsule)
const double _kMoundHeight = 10.0; // height of the crest mound above baseline
const double _kMoundHW = 42.0; // mound half-width at baseline
const double _kCenterBtnSize = 48.0; // center elevated button diameter
const double _kCenterBtnRimW = 2.5; // metallic rim width
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

/// نوار ناوبری شیشه‌ای پویا و پرمیوم ریتمو
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
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final destinations = _destinations;
    final slotCount = destinations.length;
    final activeSlot = _findSlotIndex(widget.currentIndex);

    // ── Dynamic Glass & Theme Tokens ──
    final Color pillBg = isGlass ? colors.glassTint : colors.surfaceElevated;
    final Color pillBorder = isGlass
        ? (isDark
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.70))
        : (isDark ? colors.border : colors.divider);

    final Color shadowDark = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : colors.primary.withValues(alpha: 0.08);
    final Color shadowLight = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.white.withValues(alpha: 0.85);

    final Color inactiveColor = isDark
        ? colors.textSecondary.withValues(alpha: 0.75)
        : colors.textSecondary;
    final Color activeLabelColor = colors.textPrimary;
    final Color indicatorColor = colors.primary;

    final Color centerBtnColor = colors.primary;
    final Color centerBtnRim = isDark
        ? Colors.white.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.90);

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
              // محاسبه مرکز هلال نسبت به داخل قرص (RTL)
              final ncx = barWidth - (currentSlotPos + 0.5) * slotWidth;
              final activeItem = destinations[activeSlot];

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ─── 1. سایه محیطی و عمق ───
                  Positioned(
                    left: _kHMargin,
                    right: _kHMargin,
                    top: 0,
                    height: pillH,
                    child: CustomPaint(
                      painter: _NeumorphicShadowPainter(
                        darkShadow: shadowDark,
                        lightShadow: shadowLight,
                        moundCenterX: ncx,
                        isDark: isDark,
                      ),
                    ),
                  ),

                  // ─── 2. بدنه قرص کپسولی با فیلتر شیشه‌ای پویا و قوس برآمده ───
                  Positioned(
                    left: _kHMargin,
                    right: _kHMargin,
                    top: 0,
                    height: pillH,
                    child: ClipPath(
                      clipper: _PillMoundClipper(moundCenterX: ncx),
                      child: isGlass
                          ? BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: blur,
                                sigmaY: blur,
                              ),
                              child: CustomPaint(
                                painter: _NeumorphicPillPainter(
                                  fillColor: pillBg,
                                  borderColor: pillBorder,
                                  moundCenterX: ncx,
                                  isDark: isDark,
                                  isGlass: true,
                                ),
                              ),
                            )
                          : CustomPaint(
                              painter: _NeumorphicPillPainter(
                                fillColor: pillBg,
                                borderColor: pillBorder,
                                moundCenterX: ncx,
                                isDark: isDark,
                                isGlass: false,
                              ),
                            ),
                    ),
                  ),

                  // ─── 3. آیتم‌های ناوبری ───
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
                                isDark: isDark,
                                inactiveColor: inactiveColor,
                                activeLabelColor: activeLabelColor,
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

                  // ─── 4. دکمه دایره‌ای برجسته مرکزی ───
                  Positioned(
                    left: _kHMargin + ncx - _kCenterBtnSize / 2,
                    top: -2.0,
                    width: _kCenterBtnSize,
                    height: _kCenterBtnSize,
                    child: _AnimatedFloatingButton(
                      activeItem: activeItem,
                      backgroundColor: centerBtnColor,
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
//  آیتم اسلات نئومورفیک
// ═══════════════════════════════════════════════════════════════════

class _NeumorphicSlotItem extends StatelessWidget {
  const _NeumorphicSlotItem({
    required this.item,
    required this.isActive,
    required this.slotDistance,
    required this.isDark,
    required this.inactiveColor,
    required this.activeLabelColor,
    required this.indicatorColor,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final double slotDistance;
  final bool isDark;
  final Color inactiveColor;
  final Color activeLabelColor;
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
                          child: Icon(
                            item.inactiveIcon,
                            size: _kIconSize,
                            color: inactiveColor,
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
//  دکمه دایره‌ای شناور برجسته با حلقه متالیک و انیمیشن مورف آیکون
// ═══════════════════════════════════════════════════════════════════

class _AnimatedFloatingButton extends StatefulWidget {
  const _AnimatedFloatingButton({
    required this.activeItem,
    required this.backgroundColor,
    required this.rimColor,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
  });

  final _NavItem activeItem;
  final Color backgroundColor;
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
              // حلقه متالیک بیرونی (سفید / خاکستری شفاف)
              border: Border.all(
                color: widget.rimColor,
                width: _kCenterBtnRimW,
              ),
              boxShadow: [
                // سایه اصلی پایین دکمه
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isDark ? 0.50 : 0.22,
                  ),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 5),
                ),
                // سایه روشن بالای دکمه (نئومورفیک)
                if (!widget.isDark)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.50),
                    blurRadius: 6,
                    spreadRadius: 0,
                    offset: const Offset(0, -2),
                  ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // گرادیان ظریف برای حجم سه‌بعدی دکمه
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.backgroundColor.withValues(alpha: 0.88),
                    widget.backgroundColor,
                  ],
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) =>
                      RotationTransition(
                    turns: Tween<double>(begin: -0.2, end: 0.0)
                        .animate(animation),
                    child: ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                  ),
                  child: Icon(
                    _currentIcon,
                    key: ValueKey<IconData>(_currentIcon),
                    size:
                        _currentIcon == CupertinoIcons.add ? 24 : 22,
                    color: Colors.white,
                  ),
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
//  مسیر قرص کپسولی با قوس برآمده (Mound Crest) در بالای دکمه فعال
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
/// (در بخش تقویم فقط برآمدگی سمت چپ، در بخش بینش‌ها فقط برآمدگی سمت راست، و در تب‌های میانی برآمدگی دوطرفه)
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

  // شیب سمت چپ (صعود به قله)
  moundPath.cubicTo(
    mLeft + leftSpan * 0.45,
    base,
    clampedCx - leftSpan * 0.40,
    0.0,
    clampedCx,
    0.0,
  );

  // شیب سمت راست (نزول از قله)
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
//  نقاش سایه محیطی و عمق ناوبری
// ═══════════════════════════════════════════════════════════════════

class _NeumorphicShadowPainter extends CustomPainter {
  const _NeumorphicShadowPainter({
    required this.darkShadow,
    required this.lightShadow,
    required this.moundCenterX,
    this.isDark = true,
  });

  final Color darkShadow;
  final Color lightShadow;
  final double moundCenterX;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPillMoundPath(size.width, size.height, moundCenterX);

    // سایه تاریک (پایین و اطراف — عمق اصلی)
    final darkPaint = Paint()
      ..color = darkShadow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 16 : 14);
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(path, darkPaint);
    canvas.restore();

    // هالوی روشن (بالا — در تم روشن)
    if (!isDark) {
      final lightPaint = Paint()
        ..color = lightShadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.save();
      canvas.translate(0, -2);
      canvas.drawPath(path, lightPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _NeumorphicShadowPainter oldDelegate) =>
      oldDelegate.darkShadow != darkShadow ||
      oldDelegate.lightShadow != lightShadow ||
      oldDelegate.moundCenterX != moundCenterX ||
      oldDelegate.isDark != isDark;
}

// ═══════════════════════════════════════════════════════════════════
//  نقاش بدنه قرص کپسولی با حاشیه نورانی و لایه گرادیان شیشه‌ای
// ═══════════════════════════════════════════════════════════════════

class _NeumorphicPillPainter extends CustomPainter {
  const _NeumorphicPillPainter({
    required this.fillColor,
    required this.borderColor,
    required this.moundCenterX,
    required this.isDark,
    required this.isGlass,
  });

  final Color fillColor;
  final Color borderColor;
  final double moundCenterX;
  final bool isDark;
  final bool isGlass;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPillMoundPath(size.width, size.height, moundCenterX);

    // ۱. پر کردن بدنه قرص
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // ۲. گرادیان بازتابی فوقانی (Specular highlight برای حجم شیشه‌ای)
    if (isGlass) {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      final specularPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.12 : 0.28),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45],
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, specularPaint);
    }

    // ۳. حاشیه نورانی ظریف
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NeumorphicPillPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.moundCenterX != moundCenterX ||
      oldDelegate.isDark != isDark ||
      oldDelegate.isGlass != isGlass;
}
