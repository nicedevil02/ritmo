// lib/features/worship/presentation/widgets/prayer_arc_hero.dart
// 24-Hour Celestial Orbit Wheel ("مدار ۲۴ ساعته فلکی خورشید و ماه")
// Architectural Masterpiece with Ultra-Slow Organic Floating Spheres:
// 1. Ultra-Slow Speed (45 seconds per cycle) for hypnotic, calm motion.
// 2. Multi-Harmonic Organic Buoyancy (±8.5px range) simulating natural water/zero-gravity floating.
// 3. Elastic Sphere Collision Physics (52px diameter buffer) causing floating spheres to softly bounce off each other.
// 4. Circular Badges (Shape: BoxShape.circle, 48px diameter):
//    - Top line: Persian title (e.g. "مغرب", "ظهر", "صبح")
//    - Bottom line: Persian time (e.g. "۱۹:۳۳", "۱۲:۲۱")
// 5. Dhuhr Azan dynamically pinned at exact Top Apex (-90°).
// 6. Pristine Orbit Ring track with Sun ☀️ and Crescent Moon 🌙 animations.
// 7. Sleek guide lines connecting orbit anchor dots to animated sphere positions.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/worship/logic/prayer_timeline.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

class PrayerArcHero extends StatefulWidget {
  const PrayerArcHero({
    super.key,
    required this.day,
    required this.onPracticeToggle,
    required this.onTravellerToggle,
    required this.onOpenCityPicker,
  });

  final WorshipDay day;
  final Function(String practiceId, bool isDone) onPracticeToggle;
  final Function(bool isTraveller) onTravellerToggle;
  final VoidCallback onOpenCityPicker;

  @override
  State<PrayerArcHero> createState() => _PrayerArcHeroState();
}

class _PrayerArcHeroState extends State<PrayerArcHero> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _tickerTimer;
  String _persianCityName = 'تهران';
  bool _showAsrIsha = false;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Extremely slow 45-second cycle for ultra-calm natural motion
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    )..repeat();

    _loadSettings();

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void didUpdateWidget(PrayerArcHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Load Asr/Isha setting
      final settingsList = await db.query('app_settings', where: 'key = ?', whereArgs: ['show_asr_isha_prayers'], limit: 1);
      final bool showAsrIsha = settingsList.isNotEmpty && settingsList.first['value'] == 'true';
      
      final cityId = widget.day.times.cityId;
      String cityName = 'تهران';
      
      if (cityId.isNotEmpty) {
        final rows = await db.query(
          'iran_cities',
          columns: ['city'],
          where: 'id = ?',
          whereArgs: [cityId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          cityName = rows.first['city'] as String? ?? 'تهران';
        }
      }
      
      if (mounted) {
        setState(() {
          _persianCityName = cityName;
          _showAsrIsha = showAsrIsha;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _persianCityName = 'تهران';
          _showAsrIsha = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final times = widget.day.times;
    final sky = _getSkyTheme(_now, times);

    // ── Triple Date Formatting ──
    final jalali = Jalali.now();
    final shamsiDate = '${jalali.formatter.wN}، ${jalali.day} ${jalali.formatter.mN} ${jalali.year}';
    final shamsiStr = toPersianDigits(shamsiDate);

    final monthsEn = ['ژانویه','فوریه','مارس','آوریل','مه','ژوئن','ژوئیه','اوت','سپتامبر','اکتبر','نوامبر','دسمبر'];
    final gregorianStr = toPersianDigits('${_now.day} ${monthsEn[_now.month - 1]} ${_now.year}');

    final hijriStr = widget.day.hijri.formatted;

    // ── Next Milestone & Countdown (Includes all celestial & prayer milestones) ──
    final candidates = PrayerTimeline.slotsForTimes(times, includeAsrIsha: _showAsrIsha);

    PrayerSlot? nextSlot;
    for (final s in candidates) {
      if (s.at.isAfter(_now)) {
        nextSlot = s;
        break;
      }
    }
    nextSlot ??= PrayerSlot(
      key: 'FAJR',
      titleFa: 'اذان صبح',
      at: times.fajr.add(const Duration(days: 1)),
      isPrayer: true,
    );

    final diff = nextSlot.at.difference(_now);
    final hoursLeft = diff.inHours;
    final minsLeft = diff.inMinutes % 60;

    String countdownText;
    if (diff.isNegative) {
      countdownText = 'زمان ${nextSlot.titleFa} فرا رسید';
    } else if (hoursLeft > 0) {
      countdownText = toPersianDigits('$hoursLeft ساعت و $minsLeft دقیقه تا ${nextSlot.titleFa}');
    } else if (minsLeft > 0) {
      countdownText = toPersianDigits('$minsLeft دقیقه تا ${nextSlot.titleFa}');
    } else {
      countdownText = 'کمتر از یک دقیقه تا ${nextSlot.titleFa}';
    }

    final isTraveller = widget.day.context.isTraveller;
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 600),
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: EdgeInsets.fromLTRB(6, 10, 6, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: sky.gradient,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: sky.gradient.first.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Stars Overlay for Night Sky
            if (sky.isNight)
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarsPainter(starCount: 52, opacity: 0.75),
                ),
              ),

            Column(
              children: [
                // ── Header Row: City Selector (Right) + Traveller Switch (Left) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Location City Button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onOpenCityPicker,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: sky.textColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sky.textColor.withValues(alpha: 0.20)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 13,
                              color: times.isFallbackLocation ? colors.warning : sky.goldColor,
                            ),
                            SizedBox(width: 5),
                            Text(
                              times.isFallbackLocation ? 'تهران (پیش‌فرض)' : _persianCityName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sky.textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Traveller Switch Pill
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        widget.onTravellerToggle(!isTraveller);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: isTraveller
                              ? sky.goldColor.withValues(alpha: 0.25)
                              : sky.textColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isTraveller ? sky.goldColor : sky.textColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.airplane,
                              size: 13,
                              color: isTraveller ? sky.goldColor : sky.textColor.withValues(alpha: 0.7),
                            ),
                            SizedBox(width: 4),
                            Text(
                              isTraveller ? 'مسافر (قصر)' : 'مقیم',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isTraveller ? FontWeight.bold : FontWeight.normal,
                                color: isTraveller ? sky.goldColor : sky.textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // ── CELESTIAL ORBIT WITH PROPORTIONAL GEOMETRIC SCALING ──
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 500,
                      maxHeight: 500,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final h = constraints.maxHeight;
                          final canvasSize = math.min(w, h);
                          final center = Offset(w / 2, h / 2);

                          // Proportional geometric calculations:
                          final orbitRadius = (canvasSize / 2) - (canvasSize * 0.045).clamp(10.0, 24.0);
                          final centerDiameter = (canvasSize * 0.46).clamp(140.0, 220.0);
                          final centerRadius = centerDiameter / 2.0;
                          final sphereDiameter = (canvasSize * 0.125).clamp(36.0, 56.0);
                          final sphereRadius = sphereDiameter / 2.0;

                          // Inner radius positioned strictly in the middle of available gap between central hub and orbit
                          final innerRadius = centerRadius + sphereRadius +
                              ((orbitRadius - sphereRadius - (centerRadius + sphereRadius)) * 0.5);

                          // Pre-compute static relaxation base nodes once per layout
                          final baseNodes = _computeBaseRelaxedNodes(
                            times: times,
                            center: center,
                            orbitRadius: orbitRadius,
                            innerRadius: innerRadius,
                            sphereDiameter: sphereDiameter,
                            showAsrIsha: _showAsrIsha,
                          );

                          return AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final resolvedNodes = _animateAndResolveCollisions(
                                baseNodes: baseNodes,
                                animValue: _pulseController.value,
                                sphereDiameter: sphereDiameter,
                              );

                              // Dynamic font scaling inside central clock hub
                              final clockFontSize = (centerDiameter * 0.13).clamp(16.0, 28.0);
                              final countdownFontSize = (centerDiameter * 0.062).clamp(9.5, 13.0);
                              final shamsiFontSize = (centerDiameter * 0.065).clamp(10.0, 13.5);
                              final hijriFontSize = (centerDiameter * 0.065).clamp(10.0, 13.5);
                              final gregorianFontSize = (centerDiameter * 0.055).clamp(8.5, 11.5);
                              final centerPadding = (centerDiameter * 0.05).clamp(6.0, 12.0);

                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  // 1. Orbit Track, Guide Rays, Anchor Dots & Sun/Moon Painter
                                  CustomPaint(
                                    size: Size(w, h),
                                    painter: _TwentyFourHourOrbitPainter(
                                      day: widget.day,
                                      now: _now,
                                      sky: sky,
                                      pulseValue: _pulseController.value,
                                      orbitRadius: orbitRadius,
                                      resolvedNodes: resolvedNodes,
                                    ),
                                  ),

                                  // 2. Glassmorphic Center Hub (Dynamic Proportional Diameter)
                                  Container(
                                    width: centerDiameter,
                                    height: centerDiameter,
                                    padding: EdgeInsets.all(centerPadding),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: sky.gradient.first.withValues(alpha: 0.95),
                                      border: Border.all(
                                        color: sky.goldColor.withValues(alpha: 0.60),
                                        width: 2.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          blurRadius: 28,
                                        ),
                                      ],
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                            // Live Digital Clock with Roll-up upward animation
                                            _RollUpClock(
                                              time: _now,
                                              style: TextStyle(
                                                fontSize: clockFontSize,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                                color: sky.textColor,
                                              ),
                                            ),
                                            SizedBox(height: 3),

                                            // Countdown text with Roll-up upward animation
                                            _RollUpText(
                                              text: countdownText,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: countdownFontSize,
                                                fontWeight: FontWeight.bold,
                                                color: sky.goldColor,
                                                height: 1.15,
                                              ),
                                            ),

                                            SizedBox(height: 4),
                                            Divider(
                                              height: 5,
                                              indent: 14,
                                              endIndent: 14,
                                              color: sky.goldColor.withValues(alpha: 0.4),
                                            ),

                                            // Integrated Triple Date with Roll-up upward animation
                                            _RollUpText(
                                              text: shamsiStr,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: shamsiFontSize,
                                                fontWeight: FontWeight.bold,
                                                color: sky.textColor,
                                              ),
                                            ),
                                            SizedBox(height: 1),
                                            _RollUpText(
                                              text: hijriStr,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: hijriFontSize,
                                                fontWeight: FontWeight.bold,
                                                color: sky.goldColor,
                                              ),
                                            ),
                                            SizedBox(height: 1),
                                            _RollUpText(
                                              text: gregorianStr,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: gregorianFontSize,
                                                fontWeight: FontWeight.w600,
                                                color: sky.textColor.withValues(alpha: 0.8),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // 3. Floating Circular Spheres with Stacked Title & Time
                                  ..._buildCircularSphereWidgets(context, resolvedNodes, sky, sphereDiameter),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // ── Bottom Row: Sky Period Badge (Bottom Right) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: sky.textColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: sky.textColor.withValues(alpha: 0.20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sky.periodIcon, size: 14, color: sky.goldColor),
                          SizedBox(width: 5),
                          Text(
                            sky.periodName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: sky.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Render Circular Spheres (Proportional Dynamic Sizing) ──
  List<Widget> _buildCircularSphereWidgets(
    BuildContext context,
    List<_ResolvedNode> resolvedNodes,
    _SkyTheme sky,
    double circleDiameter,
  ) {
    final practiceMap = <String, WorshipPracticeState>{};
    for (final st in widget.day.practices) {
      if (st.practice.subType != null) {
        practiceMap[st.practice.subType!.toUpperCase()] = st;
      }
    }

    final titleFontSize = (circleDiameter * 0.22).clamp(9.0, 12.0);
    final timeFontSize = (circleDiameter * 0.20).clamp(8.0, 11.0);
    final checkIconSize = (circleDiameter * 0.26).clamp(10.0, 14.0);
    final borderWidth = circleDiameter * 0.026;

    final nodes = <Widget>[];

    for (final node in resolvedNodes) {
      final a = node.anchor;
      final state = practiceMap[a.key];
      final isDone = state?.isDone ?? false;
      final isPrayer = a.isPrayer;

      final rawTimeStr = '${a.time.hour.toString().padLeft(2, '0')}:${a.time.minute.toString().padLeft(2, '0')}';
      final faTimeStr = toPersianDigits(rawTimeStr);

      nodes.add(
        Positioned(
          left: node.animatedOffset.dx - circleDiameter / 2,
          top: node.animatedOffset.dy - circleDiameter / 2,
          child: GestureDetector(
            onTap: () {
              if (isPrayer && state != null) {
                unawaited(HapticFeedback.lightImpact());
                widget.onPracticeToggle(state.practice.id, !isDone);
              } else {
                unawaited(HapticFeedback.selectionClick());
              }
            },
            child: Container(
              width: circleDiameter,
              height: circleDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isDone
                    ? LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [sky.goldColor, sky.accentColor],
                      )
                    : LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          sky.gradient.first.withValues(alpha: 0.95),
                          sky.gradient.last.withValues(alpha: 0.96),
                        ],
                      ),
                border: Border.all(
                  color: isDone
                      ? sky.goldColor
                      : isPrayer
                          ? sky.goldColor.withValues(alpha: 0.65)
                          : sky.textColor.withValues(alpha: 0.35),
                  width: isDone ? borderWidth * 1.2 : borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDone
                        ? sky.goldColor.withValues(alpha: 0.45)
                        : Colors.black.withValues(alpha: 0.60),
                    blurRadius: isDone ? 11 : 7,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDone)
                      Icon(Icons.check_rounded, size: checkIconSize, color: Colors.black)
                    else
                      Text(
                        a.titleFa,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w900,
                          color: sky.textColor,
                          height: 1.05,
                        ),
                      ),
                    SizedBox(height: circleDiameter * 0.025),
                    Text(
                      faTimeStr,
                      style: TextStyle(
                        fontSize: timeFontSize,
                        fontWeight: FontWeight.bold,
                        color: isDone ? Colors.black87 : sky.goldColor,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return nodes;
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  // ── Dynamic Sky Theme Calculation ──
  _SkyTheme _getSkyTheme(DateTime now, PrayerTimes times) {
    final fajr = times.fajr;
    final sunrise = times.sunrise;
    final dhuhr = times.dhuhr;
    final sunset = times.sunset;
    final maghrib = times.maghrib;
    final isha = times.isha;

    if (now.isBefore(fajr)) {
      return const _SkyTheme(
        gradient: [Color(0xFF070B14), Color(0xFF0F172A)],
        textColor: Color(0xFFCCD6F6),
        accentColor: Color(0xFF8892B0),
        goldColor: Color(0xFFC4A35A),
        periodName: 'شب',
        periodIcon: CupertinoIcons.moon_stars_fill,
        isNight: true,
      );
    }

    if (now.isBefore(sunrise)) {
      return const _SkyTheme(
        gradient: [
          Color(0xFF0D0826), // Deep Cosmic Midnight
          Color(0xFF1F1442), // Mystical Amethyst Indigo
          Color(0xFF43255F), // Velvet Twilight Amethyst
          Color(0xFF7A4269), // Soft Dawn Glow Aura
        ],
        textColor: Color(0xFFF4EBF7),
        accentColor: Color(0xFFD8B4FE),
        goldColor: Color(0xFFF7D070),
        periodName: 'سپیده‌دم',
        periodIcon: CupertinoIcons.sunrise_fill,
        isNight: true,
      );
    }

    final morning = DateTime(now.year, now.month, now.day, 10);
    if (now.isBefore(morning)) {
      return const _SkyTheme(
        gradient: [Color(0xFF2C3E6B), Color(0xFF4A90D9), Color(0xFF74B9FF)],
        textColor: Color(0xFFFFFFFF),
        accentColor: Color(0xFFA8D8EA),
        goldColor: Color(0xFFFFD700),
        periodName: 'صبح',
        periodIcon: CupertinoIcons.sun_min_fill,
        isNight: false,
      );
    }

    final dhuhrPlus1 = dhuhr.add(const Duration(hours: 1));
    if (now.isBefore(dhuhrPlus1)) {
      return const _SkyTheme(
        gradient: [Color(0xFF1F618D), Color(0xFF2980B9), Color(0xFF5DADE2)],
        textColor: Color(0xFFFFFFFF),
        accentColor: Color(0xFFA8D8EA),
        goldColor: Color(0xFFFFD700),
        periodName: 'ظهر',
        periodIcon: CupertinoIcons.sun_max_fill,
        isNight: false,
      );
    }

    final preSunset = sunset.subtract(const Duration(minutes: 90));
    if (now.isBefore(preSunset)) {
      return const _SkyTheme(
        gradient: [Color(0xFF2471A3), Color(0xFF5499C7), Color(0xFF85C1E9)],
        textColor: Color(0xFFF8F4EF),
        accentColor: Color(0xFFE8D5B0),
        goldColor: Color(0xFFFFD700),
        periodName: 'بعدازظهر',
        periodIcon: CupertinoIcons.cloud_sun_fill,
        isNight: false,
      );
    }

    if (now.isBefore(maghrib)) {
      return const _SkyTheme(
        gradient: [Color(0xFF2C3E6B), Color(0xFFBE5B3A), Color(0xFFE8913A), Color(0xFFF5D78A)],
        textColor: Color(0xFFFFF5E8),
        accentColor: Color(0xFFFFD185),
        goldColor: Color(0xFFFFD700),
        periodName: 'غروب',
        periodIcon: CupertinoIcons.sunset_fill,
        isNight: false,
      );
    }

    if (now.isBefore(isha)) {
      return const _SkyTheme(
        gradient: [Color(0xFF0D1B3E), Color(0xFF1E3163), Color(0xFF4A2866)],
        textColor: Color(0xFFD6CEE6),
        accentColor: Color(0xFFA78BCA),
        goldColor: Color(0xFFFFD700),
        periodName: 'شفق',
        periodIcon: CupertinoIcons.moon_fill,
        isNight: true,
      );
    }

    return const _SkyTheme(
      gradient: [Color(0xFF070B14), Color(0xFF0F172A)],
      textColor: Color(0xFFCCD6F6),
      accentColor: Color(0xFF8892B0),
      goldColor: Color(0xFFC4A35A),
      periodName: 'شب',
      periodIcon: CupertinoIcons.moon_stars_fill,
      isNight: true,
    );
  }
}

// ── Model: Resolved Node ──
class _ResolvedNode {
  _ResolvedNode({
    required this.anchor,
    required this.angleRad,
    required this.dotOffset,
    required this.badgeOffset,
    required this.animatedOffset,
  });

  final _AnchorData anchor;
  final double angleRad;
  final Offset dotOffset;
  Offset badgeOffset;
  Offset animatedOffset;
}

// ── Compute Static Base Relaxed Positions ──
List<_ResolvedNode> _computeBaseRelaxedNodes({
  required PrayerTimes times,
  required Offset center,
  required double orbitRadius,
  required double innerRadius,
  required double sphereDiameter,
  required bool showAsrIsha,
}) {
  final dhuhrFrac = times.dhuhr.hour + times.dhuhr.minute / 60.0;

  final anchors = [
    _AnchorData('FAJR', 'صبح', 'ص', times.fajr, true),
    _AnchorData('SUNRISE', 'طلوع', 'ط', times.sunrise, false),
    _AnchorData('DHUHR', 'ظهر', 'ظ', times.dhuhr, true),
    _AnchorData('ASR', 'عصر', 'ع', times.asr, true),
    _AnchorData('SUNSET', 'غروب', 'غ', times.sunset, false),
    _AnchorData('MAGHRIB', 'مغرب', 'م', times.maghrib, true),
    _AnchorData('ISHA', 'عشا', 'عش', times.isha, true),
    _AnchorData('MIDNIGHT_SHARI', 'نیمه‌شب', 'ن', times.midnightShari, false),
  ];
  
  if (!showAsrIsha) {
    anchors.removeWhere((a) => a.key == 'ASR' || a.key == 'ISHA');
  }

  final rawNodes = <_ResolvedNode>[];

  for (final a in anchors) {
    final hourFrac = a.time.hour + a.time.minute / 60.0;
    // Dhuhr pinned at top apex (-90°)
    final tRel = (hourFrac - dhuhrFrac) % 24.0;
    final angleRad = (tRel / 24.0) * 2 * math.pi - math.pi / 2;

    final dotOffset = Offset(
      center.dx + orbitRadius * math.cos(angleRad),
      center.dy + orbitRadius * math.sin(angleRad),
    );

    final rawBadgeOffset = Offset(
      center.dx + innerRadius * math.cos(angleRad),
      center.dy + innerRadius * math.sin(angleRad),
    );

    rawNodes.add(_ResolvedNode(
      anchor: a,
      angleRad: angleRad,
      dotOffset: dotOffset,
      badgeOffset: rawBadgeOffset,
      animatedOffset: rawBadgeOffset,
    ));
  }

  final rightNodes = rawNodes.where((n) => n.dotOffset.dx >= center.dx).toList();
  final leftNodes = rawNodes.where((n) => n.dotOffset.dx < center.dx).toList();

  void relaxHemisphere(List<_ResolvedNode> nodes, bool isRight) {
    if (nodes.length <= 1) return;
    nodes.sort((a, b) => a.badgeOffset.dy.compareTo(b.badgeOffset.dy));

    final minGap = sphereDiameter;

    for (var pass = 0; pass < 12; pass++) {
      for (var i = 0; i < nodes.length - 1; i++) {
        final curr = nodes[i];
        final next = nodes[i + 1];
        final dyDiff = next.badgeOffset.dy - curr.badgeOffset.dy;

        if (dyDiff < minGap) {
          final overlap = minGap - dyDiff;
          final shift = overlap / 2.0;

          final newCurrY = curr.badgeOffset.dy - shift;
          final newNextY = next.badgeOffset.dy + shift;

          curr.badgeOffset = _adjustPosition(curr.badgeOffset, newCurrY, center, innerRadius, isRight);
          next.badgeOffset = _adjustPosition(next.badgeOffset, newNextY, center, innerRadius, isRight);
        }
      }
    }
  }

  relaxHemisphere(rightNodes, true);
  relaxHemisphere(leftNodes, false);

  return [...rightNodes, ...leftNodes];
}

// ── Ultra-Slow Multi-Harmonic Organic Drift + Elastic Collision Physics ──
List<_ResolvedNode> _animateAndResolveCollisions({
  required List<_ResolvedNode> baseNodes,
  required double animValue,
  required double sphereDiameter,
}) {
  final t = animValue * 2 * math.pi;
  final resultNodes = <_ResolvedNode>[];

  for (var i = 0; i < baseNodes.length; i++) {
    final base = baseNodes[i];

    // Multi-frequency organic harmonic drift (Natural water/space buoyancy)
    final phaseX1 = i * 0.94 + 0.3;
    final phaseX2 = i * 1.71 + 1.2;
    final phaseY1 = i * 1.33 + 0.8;
    final phaseY2 = i * 2.15 + 2.1;

    final maxAmplitude = (sphereDiameter * 0.15).clamp(4.0, 8.5);
    final floatDx = maxAmplitude * (math.sin(t + phaseX1) + 0.35 * math.sin(2.1 * t + phaseX2));
    final floatDy = maxAmplitude * (math.cos(0.85 * t + phaseY1) + 0.35 * math.cos(1.6 * t + phaseY2));

    final node = _ResolvedNode(
      anchor: base.anchor,
      angleRad: base.angleRad,
      dotOffset: base.dotOffset,
      badgeOffset: base.badgeOffset,
      animatedOffset: base.badgeOffset + Offset(floatDx, floatDy),
    );
    resultNodes.add(node);
  }

  // Elastic Sphere Collision Resolution (Bubbles / Water Balloons Bouncing Effect)
  final collisionDist = sphereDiameter + 4.0;
  for (var pass = 0; pass < 4; pass++) {
    for (var i = 0; i < resultNodes.length; i++) {
      for (var j = i + 1; j < resultNodes.length; j++) {
        final n1 = resultNodes[i];
        final n2 = resultNodes[j];
        final diff = n1.animatedOffset - n2.animatedOffset;
        final dist = diff.distance;
        if (dist < collisionDist && dist > 0.001) {
          final overlap = (collisionDist - dist) / 2.0;
          final unit = diff / dist;
          n1.animatedOffset += unit * overlap;
          n2.animatedOffset -= unit * overlap;
        }
      }
    }
  }

  return resultNodes;
}

Offset _adjustPosition(Offset orig, double newY, Offset center, double radius, bool isRight) {
  final dy = newY - center.dy;
  final clampedDy = dy.clamp(-radius + 5.0, radius - 5.0);
  final dxAbs = math.sqrt(math.max(0.0, radius * radius - clampedDy * clampedDy));
  final newX = isRight ? center.dx + dxAbs : center.dx - dxAbs;
  return Offset(newX, center.dy + clampedDy);
}

// ── Model: Anchor Data ──
class _AnchorData {
  const _AnchorData(this.key, this.titleFa, this.initial, this.time, this.isPrayer);
  final String key;
  final String titleFa;
  final String initial;
  final DateTime time;
  final bool isPrayer;
}

// ── Model: Dynamic Sky Theme ──
class _SkyTheme {
  const _SkyTheme({
    required this.gradient,
    required this.textColor,
    required this.accentColor,
    required this.goldColor,
    required this.periodName,
    required this.periodIcon,
    required this.isNight,
  });

  final List<Color> gradient;
  final Color textColor;
  final Color accentColor;
  final Color goldColor;
  final String periodName;
  final IconData periodIcon;
  final bool isNight;
}

// ── Custom Painter: 360° Celestial Orbit Wheel & Rays to Spheres ──
class _TwentyFourHourOrbitPainter extends CustomPainter {
  _TwentyFourHourOrbitPainter({
    required this.day,
    required this.now,
    required this.sky,
    required this.pulseValue,
    required this.orbitRadius,
    required this.resolvedNodes,
  });

  final WorshipDay day;
  final DateTime now;
  final _SkyTheme sky;
  final double pulseValue;
  final double orbitRadius;
  final List<_ResolvedNode> resolvedNodes;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = orbitRadius;

    // 1. Draw 360° Circular Track Path
    final trackPaint = Paint()
      ..color = sky.textColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Draw Connecting Guide Rays & Anchor Dots
    final guideLinePaint = Paint()
      ..color = sky.goldColor.withValues(alpha: 0.38)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final dotBgPaint = Paint()..color = sky.textColor.withValues(alpha: 0.60);
    final dotGoldPaint = Paint()..color = sky.goldColor;

    for (final node in resolvedNodes) {
      canvas.drawLine(node.dotOffset, node.animatedOffset, guideLinePaint);

      canvas.drawCircle(node.dotOffset, 5.0, dotBgPaint);
      canvas.drawCircle(node.dotOffset, 2.8, dotGoldPaint);
    }

    // 3. Calculate Celestial Angles relative to Dhuhr Azan (Pinned at Top Apex -90°)
    final times = day.times;
    final dhuhrFrac = times.dhuhr.hour + times.dhuhr.minute / 60.0;

    double timeToAngle(DateTime dt) {
      final hf = dt.hour + dt.minute / 60.0 + dt.second / 3600.0;
      final tr = (hf - dhuhrFrac) % 24.0;
      return (tr / 24.0) * 2 * math.pi - math.pi / 2;
    }

    final angleSunrise = timeToAngle(times.sunrise);
    final angleSunset = timeToAngle(times.sunset);
    final nowAngle = timeToAngle(now);

    // Day Arc (Sunrise -> Sunset)
    var daySweep = (angleSunset - angleSunrise) % (2 * math.pi);
    if (daySweep <= 0) daySweep += 2 * math.pi;

    // Night Arc (Sunset -> Sunrise)
    final nightSweep = (2 * math.pi) - daySweep;

    // A) Draw Night Arc Track (Sunset -> Sunrise, Deep Cosmic Indigo / Midnight Starlight Navy)
    final nightArcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: nightSweep,
        colors: const [
          Color(0xFF4A148C), // Deep Midnight Purple
          Color(0xFF311B92), // Cosmic Royal Indigo
          Color(0xFF1A237E), // Deep Night Navy
          Color(0xFF3A1C71), // Pre-Dawn Violet
        ],
        transform: GradientRotation(angleSunset),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), angleSunset, nightSweep, false, nightArcPaint);

    // B) Draw Day Arc Track (Sunrise -> Sunset, Golden Solar Gradient)
    final dayArcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: daySweep,
        colors: const [
          Color(0xFFFFB300), // Dawn Warm Amber Gold
          Color(0xFFFFD700), // Noon Pure Solar Gold
          Color(0xFFFF6D00), // Afternoon Orange Dusk
          Color(0xFFD84315), // Sunset Deep Coral Red
        ],
        transform: GradientRotation(angleSunrise),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), angleSunrise, daySweep, false, dayArcPaint);

    // C) Draw Active Trail from Start of Current Period up to Now
    final isDayTime = now.isAfter(times.sunrise) && now.isBefore(times.sunset);

    if (isDayTime) {
      var activeSweep = (nowAngle - angleSunrise) % (2 * math.pi);
      if (activeSweep <= 0) activeSweep += 2 * math.pi;

      final activeDayPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), angleSunrise, activeSweep, false, activeDayPaint);
    } else {
      var activeSweep = (nowAngle - angleSunset) % (2 * math.pi);
      if (activeSweep <= 0) activeSweep += 2 * math.pi;

      final activeNightPaint = Paint()
        ..color = const Color(0xFF9FA8DA).withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), angleSunset, activeSweep, false, activeNightPaint);
    }

    // 4. Ultra-Smooth Celestial Body Morphing (Sun ☀️ <-> Moon 🌙)
    final bodyCenter = Offset(
      center.dx + radius * math.cos(nowAngle),
      center.dy + radius * math.sin(nowAngle),
    );

    // Calculate Celestial Morph Factor tMorph (0.0 = Moon 🌙, 1.0 = Sun ☀️)
    double tMorph;
    final minutesBeforeSunrise = times.sunrise.difference(now).inSeconds / 60.0;
    final minutesBeforeSunset = times.sunset.difference(now).inSeconds / 60.0;

    const transitionWindowMin = 15.0; // 15-minute cosmic morph window

    if (minutesBeforeSunrise.abs() <= transitionWindowMin) {
      // Morphing around Sunrise (-15 min to +15 min)
      final progress = (transitionWindowMin - minutesBeforeSunrise) / (2 * transitionWindowMin);
      tMorph = progress.clamp(0.0, 1.0);
    } else if (minutesBeforeSunset.abs() <= transitionWindowMin) {
      // Morphing around Sunset (-15 min to +15 min)
      final progress = (transitionWindowMin + minutesBeforeSunset) / (2 * transitionWindowMin);
      tMorph = (1.0 - progress).clamp(0.0, 1.0);
    } else {
      tMorph = isDayTime ? 1.0 : 0.0;
    }

    // A) Draw Crescent Moon Layer (Opacity = 1.0 - tMorph)
    if (tMorph < 1.0) {
      final moonOpacity = (1.0 - tMorph).clamp(0.0, 1.0);
      final moonScale = 0.5 + 0.5 * moonOpacity;
      final pulseRadius = (18.0 + pulseValue * 4.0) * moonScale;

      final glowPaint = Paint()
        ..color = Color(0xFF9FA8DA).withValues(alpha: 0.50 * moonOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(bodyCenter, pulseRadius, glowPaint);

      final moonPaint = Paint()..color = Color(0xFFFFF9C4).withValues(alpha: moonOpacity);
      canvas.drawCircle(bodyCenter, 12 * moonScale, moonPaint);

      final shadowPaint = Paint()..color = sky.gradient.first.withValues(alpha: moonOpacity);
      canvas.drawCircle(Offset(bodyCenter.dx + 4.0 * moonScale, bodyCenter.dy - 3.0 * moonScale), 9.5 * moonScale, shadowPaint);
    }

    // B) Draw Radiant Solar Sun Layer (Opacity = tMorph)
    if (tMorph > 0.0) {
      final sunOpacity = tMorph.clamp(0.0, 1.0);
      final sunScale = 0.5 + 0.5 * sunOpacity;

      Color sunDiscColor;
      if (now.hour >= 5 && now.hour < 7) {
        sunDiscColor = const Color(0xFFFF7043);
      } else if (now.hour >= 7 && now.hour < 11) {
        sunDiscColor = const Color(0xFFFFD700);
      } else if (now.hour >= 11 && now.hour < 14) {
        sunDiscColor = const Color(0xFFFFF9C4);
      } else if (now.hour >= 14 && now.hour < 18) {
        sunDiscColor = const Color(0xFFFFC107);
      } else {
        sunDiscColor = const Color(0xFFFF7043);
      }

      final pulseRadius = (18.0 + pulseValue * 4.5) * sunScale;
      final glowPaint = Paint()
        ..color = sunDiscColor.withValues(alpha: 0.55 * sunOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawCircle(bodyCenter, pulseRadius, glowPaint);

      final rayPaint = Paint()
        ..color = sunDiscColor.withValues(alpha: 0.65 * sunOpacity)
        ..strokeWidth = 2.0 * sunScale
        ..style = PaintingStyle.stroke;

      for (var i = 0; i < 8; i++) {
        final rayAngle = i * (2 * math.pi / 8);
        final r1 = 13.0 * sunScale;
        final r2 = (20.0 + pulseValue * 2.5) * sunScale;
        canvas.drawLine(
          Offset(bodyCenter.dx + r1 * math.cos(rayAngle), bodyCenter.dy + r1 * math.sin(rayAngle)),
          Offset(bodyCenter.dx + r2 * math.cos(rayAngle), bodyCenter.dy + r2 * math.sin(rayAngle)),
          rayPaint,
        );
      }

      final sunPaint = Paint()..color = sunDiscColor.withValues(alpha: sunOpacity);
      canvas.drawCircle(bodyCenter, 12 * sunScale, sunPaint);

      final innerPaint = Paint()..color = Colors.white.withValues(alpha: sunOpacity);
      canvas.drawCircle(bodyCenter, 5 * sunScale, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TwentyFourHourOrbitPainter oldDelegate) =>
      oldDelegate.now != now || oldDelegate.pulseValue != pulseValue || oldDelegate.sky.periodName != sky.periodName;
}

// ── Stars Painter ──
class _StarsPainter extends CustomPainter {
  _StarsPainter({required this.starCount, required this.opacity});
  final int starCount;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);

    for (var i = 0; i < starCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.5 + rng.nextDouble() * 1.0;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) =>
      old.starCount != starCount || old.opacity != opacity;
}

// ── 3D Cube Roll Single Digit (چرخش سه‌بعدی مکعبی به عقب: وجه پایین میاد روبرو) ──
class _CubeRollDigit extends StatelessWidget {
  const _CubeRollDigit({
    super.key,
    required this.digit,
    required this.style,
    this.duration = const Duration(milliseconds: 320),
    this.curve = Curves.easeOutCubic,
  });

  final String digit;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final digitWidth = (style.fontSize ?? 20) * 0.62;
    final digitHeight = (style.fontSize ?? 20) * 1.25;

    return SizedBox(
      width: digitWidth,
      height: digitHeight,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: curve,
        switchOutCurve: curve,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (child, animation) {
          final isIncoming = (child.key as ValueKey<String>?)?.value == digit;

          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = animation.value;
              final double angle;
              final double yShift;
              final double opacity;

              if (isIncoming) {
                // Incoming digit starts tilted from bottom (+pi/2) and rotates forward to 0
                angle = (1.0 - t) * (math.pi / 2);
                yShift = (1.0 - t) * (digitHeight * 0.5);
                opacity = (t * 1.5).clamp(0.0, 1.0);
              } else {
                // Outgoing digit tilts backward into screen (-pi/2) and moves up
                angle = -(1.0 - t) * (math.pi / 2);
                yShift = -(1.0 - t) * (digitHeight * 0.5);
                opacity = (t * 1.5).clamp(0.0, 1.0);
              }

              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.003) // 3D Perspective
                ..translate(0.0, yShift, 0.0)
                ..rotateX(angle);

              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: Opacity(
                  opacity: opacity,
                  child: child,
                ),
              );
            },
          );
        },
        child: Text(
          digit,
          key: ValueKey<String>(digit),
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}

// ── 3D Cube Roll Digital Clock (Per-digit: فقط ارقام در حال تغییر می‌چرخند) ──
class _RollUpClock extends StatelessWidget {
  const _RollUpClock({
    super.key,
    required this.time,
    required this.style,
  });

  final DateTime time;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    final colonWidth = (style.fontSize ?? 20) * 0.32;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hours (Tens & Units separately)
          _CubeRollDigit(digit: hh[0], style: style),
          _CubeRollDigit(digit: hh[1], style: style),

          SizedBox(
            width: colonWidth,
            child: Text(':', textAlign: TextAlign.center, style: style),
          ),

          // Minutes (Tens & Units separately)
          _CubeRollDigit(digit: mm[0], style: style),
          _CubeRollDigit(digit: mm[1], style: style),

          SizedBox(
            width: colonWidth,
            child: Text(':', textAlign: TextAlign.center, style: style),
          ),

          // Seconds (Tens & Units separately - فقط یکان می‌چرخه، دهگان فقط سر ۱۰، ۲۰، ...)
          _CubeRollDigit(digit: ss[0], style: style),
          _CubeRollDigit(digit: ss[1], style: style),
        ],
      ),
    );
  }
}

// ── 3D Cube Roll Text (برای متون شمارش معکوس و تاریخ‌ها) ──
class _RollUpText extends StatelessWidget {
  const _RollUpText({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.center,
    this.duration = const Duration(milliseconds: 380),
    this.curve = Curves.easeOutCubic,
  });

  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: curve,
      switchOutCurve: curve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final isIncoming = (child.key as ValueKey<String>?)?.value == text;

        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final double angle;
            final double yShift;
            final double opacity;

            if (isIncoming) {
              angle = (1.0 - t) * (math.pi / 2);
              yShift = (1.0 - t) * 14.0;
              opacity = (t * 1.4).clamp(0.0, 1.0);
            } else {
              angle = -(1.0 - t) * (math.pi / 2);
              yShift = -(1.0 - t) * 14.0;
              opacity = (t * 1.4).clamp(0.0, 1.0);
            }

            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.0025)
              ..translate(0.0, yShift, 0.0)
              ..rotateX(angle);

            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: Opacity(
                opacity: opacity,
                child: child,
              ),
            );
          },
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        textAlign: textAlign,
        style: style,
      ),
    );
  }
}

