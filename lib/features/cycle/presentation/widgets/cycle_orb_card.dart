// C-43, C-44: CycleOrbCard (Pixel-Perfect Neumorphic Soft UI & Apple Glassmorphism)
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

class CycleOrbCard extends StatelessWidget {
  const CycleOrbCard({
    super.key,
    required this.phase,
    required this.isTodayPeriod,
    required this.activePeriodDay,
    required this.dayOfCycle,
    required this.totalCycleLength,
    required this.avgPeriodDuration,
    this.onMenuTap,
  });

  final CyclePhase phase;
  final bool isTodayPeriod;
  final int activePeriodDay;
  final int dayOfCycle;
  final double totalCycleLength;
  final double avgPeriodDuration;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var phaseText = '';
    var remainingText = '';
    var emoji = '✨';
    var statusTip = '';
    var phaseColor = const Color(0xFFF27A6D);

    switch (phase) {
      case CyclePhase.menstrual:
        phaseText = 'دوران قاعدگی (پریود)';
        remainingText =
            'روز ${PersianDigits.toFa(activePeriodDay.toString())} دوره خونریزی';
        phaseColor = isDark ? const Color(0xFFFF7E70) : const Color(0xFFEB6E60);
        emoji = '🩸';
        statusTip =
            'بدن شما در حال پاکسازی طبیعی است. استراحت کافی، نوشیدن آب ولرم و دمنوش‌های ملایم به کاهش انقباضات کمک می‌کند.';
      case CyclePhase.ovulation:
        phaseText = 'روز تخمک‌گذاری';
        remainingText = 'اوج هورمون‌های زنانه و باروری';
        phaseColor = isDark ? const Color(0xFFFFA048) : const Color(0xFFE88A2E);
        emoji = '🥚';
        statusTip =
            'تخمک‌گذاری رخ داده است. هورمون‌ها در بالاترین سطح خود هستند و آمادگی فیزیکی و سطح نشاط بدنی شما عالی است.';
      case CyclePhase.luteal:
        phaseText = 'روزهای پیش از عادت (PMS)';
        remainingText =
            'روز ${PersianDigits.toFa(dayOfCycle.toString())} چرخه بدنی';
        phaseColor = isDark ? const Color(0xFFE074C4) : const Color(0xFFC752A8);
        emoji = '🌸';
        statusTip =
            'روزهای قبل از پریود؛ نوسان هورمونی طبیعی است. یوگای آرام، کاهش مصرف نمک و خواب منظم بسیار موثر است.';
      case CyclePhase.dataStale:
        phaseText = 'نیاز به بازبینی وضعیت';
        remainingText = 'موعد تخمینی سپری شده است';
        phaseColor = isDark ? const Color(0xFFFFB84D) : const Color(0xFFE59828);
        emoji = '⏳';
        statusTip =
            'لطفاً وضعیت ثبت دورهٔ خود را مشخص کنید تا محاسبات و یادآوری‌ها دقیق بمانند.';
      case CyclePhase.pregnancy:
        phaseText = 'دوران بارداری';
        remainingText = 'محاسبات چرخه متوقف شده است';
        phaseColor = isDark ? const Color(0xFF72A6F8) : const Color(0xFF4C87E8);
        emoji = '🤰';
        statusTip =
            'حالت بارداری فعال است و ریتم متناسب با این دوران تنظیم شده است.';
      case CyclePhase.noData:
        phaseText = 'در انتظار ثبت داده';
        remainingText = 'اولین دورهٔ خود را ثبت کنید';
        phaseColor = colors.textSecondary;
        emoji = '📅';
        statusTip =
            'برای شروع تحلیل‌های هوشمند، اولین دورهٔ ریتم خود را ثبت کنید.';
      case CyclePhase.follicular:
        phaseText = 'فاز فولیکولار (رشد)';
        remainingText =
            'روز ${PersianDigits.toFa(dayOfCycle.toString())} چرخه بدنی';
        phaseColor = isDark ? const Color(0xFF5CC9A7) : const Color(0xFF38AA84);
        emoji = '✨';
        statusTip =
            'فاز فولیکولار با رشد فولیکول‌ها شروع شده است. سطح هورمون استروژن افزایش یافته و انرژی و تمرکز شما رو به رشد است.';
    }

    final currentDay = isTodayPeriod ? activePeriodDay : dayOfCycle;
    final totalDays = isTodayPeriod ? avgPeriodDuration : totalCycleLength;
    final targetProgress = totalDays > 0
        ? (currentDay / totalDays).clamp(0.05, 1.0)
        : 0.1;
    final m = context.metrics;

    // Neumorphic surface palette
    final cardBgColor = isDark ? const Color(0xFF1E2127) : const Color(0xFFF1F3F6);
    final cardLightShadow = isDark
        ? const Color(0xFF2B3039)
        : Colors.white;
    final cardDarkShadow = isDark
        ? Colors.black.withValues(alpha: 0.65)
        : const Color(0xFFBAC4D0).withValues(alpha: 0.70);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final dialSize = isCompact ? 116.0 : 134.0 * m.densityFactor;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              // Highlight top-left
              BoxShadow(
                color: cardLightShadow,
                offset: const Offset(-8, -8),
                blurRadius: 18,
              ),
              // Shadow bottom-right
              BoxShadow(
                color: cardDarkShadow,
                offset: const Offset(8, 8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 20 * m.densityFactor,
              horizontal: 20 * m.densityFactor,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // بخش اصلی چیدمان افقی (Horizontal Layout: دیال در یک سو و محتوا در سوی دیگر)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ۱. دیال حلقوی نئومورفیک با لایه شیشه‌ای و انیمیشن
                    _buildNeumorphicAcrylicDial(
                      context: context,
                      dialSize: dialSize,
                      targetProgress: targetProgress,
                      phaseColor: phaseColor,
                      currentDay: currentDay,
                      isDark: isDark,
                      phase: phase,
                    ),

                    SizedBox(width: isCompact ? 12 : 18),

                    // ۲. ستون اطلاعات، بج شیشه‌ای و متن‌ها
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // سطر بالایی: کپسول شیشه‌ای فاز + دکمه گرد سه‌نقطه نئومورفیک
                          Row(
                            children: [
                              // کپسول نشان فاز شیشه‌ای و درخشان (Apple Jelly Pill)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: phaseColor.withValues(
                                      alpha: isDark ? 0.22 : 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: phaseColor.withValues(
                                        alpha: isDark ? 0.40 : 0.28,
                                      ),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        emoji,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          phaseText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? phaseColor
                                                : Color.lerp(
                                                    phaseColor,
                                                    Colors.black,
                                                    0.25,
                                                  ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // دکمه سه‌نقطه نئومورفیک برجسته
                              _buildNeumorphicMenuButton(
                                isDark: isDark,
                                cardBgColor: cardBgColor,
                                onTap: onMenuTap,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // عنوان روز دوره
                          Text(
                            remainingText,
                            style: TextStyle(
                              fontSize: isCompact ? 16 : 18.5,
                              fontWeight: FontWeight.w900,
                              color: isDark
                                  ? const Color(0xFFF5F5F7)
                                  : const Color(0xFF1D2129),
                              height: 1.25,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // متن راهنما و نکته فاز
                          Text(
                            statusTip,
                            style: TextStyle(
                              fontSize: isCompact ? 11.5 : 12.2,
                              height: 1.55,
                              color: isDark
                                  ? const Color(0xFFA1A8B3)
                                  : const Color(0xFF6B7280),
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ۳. نشانگرهای وضعیت ۳ نقطه در پایین کارت (Glowing Status Dots)
                _buildBottomStatusDots(
                  phaseColor: phaseColor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ساخت دیال حلقوی نئومورفیک با افکت شیشه‌ای آکریلیک
  Widget _buildNeumorphicAcrylicDial({
    required BuildContext context,
    required double dialSize,
    required double targetProgress,
    required Color phaseColor,
    required int currentDay,
    required bool isDark,
    required CyclePhase phase,
  }) {
    final outerRingSize = dialSize;
    final innerDiscSize = dialSize * 0.62;

    return SizedBox(
      height: outerRingSize,
      width: outerRingSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ۱. شیار فرورفته زیرین (Outer Concave Ring Shadow)
          Container(
            height: outerRingSize,
            width: outerRingSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF181B20)
                  : const Color(0xFFE8EBF0),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.85)
                      : const Color(0xFFB5C0CD).withValues(alpha: 0.85),
                  offset: const Offset(3.5, 3.5),
                  blurRadius: 7,
                ),
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF282D36)
                      : Colors.white,
                  offset: const Offset(-3.5, -3.5),
                  blurRadius: 7,
                ),
              ],
            ),
          ),

          // ۲. نوار حلقوی شیشه‌ای و انیمیشن پیشرفت ژله‌ای درخشان
          SizedBox(
            height: outerRingSize,
            width: outerRingSize,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: targetProgress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, child) {
                return CustomPaint(
                  painter: _NeumorphicGlowRingPainter(
                    percentage: animValue,
                    activeColor: phaseColor,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // ۳. دیسک میانی برجسته نئومورفیک (Convex Center Island)
          Container(
            height: innerDiscSize,
            width: innerDiscSize,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF20242B)
                  : const Color(0xFFF3F5F8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.65)
                      : const Color(0xFFA8B5C4).withValues(alpha: 0.55),
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF2D333D)
                      : Colors.white,
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    phase == CyclePhase.menstrual ? 'روز پریود' : 'روز چرخه',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF9096A2)
                          : const Color(0xFF7A828E),
                    ),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        PersianDigits.toFa(currentDay.toString()),
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: phaseColor,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ساخت دکمه سه‌نقطه گرد نئومورفیک
  Widget _buildNeumorphicMenuButton({
    required bool isDark,
    required Color cardBgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: cardBgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color(0xFFBAC4D0).withValues(alpha: 0.6),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: isDark ? const Color(0xFF2D333D) : Colors.white,
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(
          Icons.more_vert_rounded,
          size: 16,
          color: isDark ? const Color(0xFF8E95A2) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  /// ساخت سه نقطه پایین با درخشش نقطه فعال
  Widget _buildBottomStatusDots({
    required Color phaseColor,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // نقطه فعال با هاله نورانی
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: phaseColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: phaseColor.withValues(alpha: 0.75),
                blurRadius: 7,
                spreadRadius: 1.5,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // نقطه غیرفعال ۱
        Container(
          width: 5.5,
          height: 5.5,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF383E4A) : const Color(0xFFCBD2DC),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        // نقطه غیرفعال ۲
        Container(
          width: 5.5,
          height: 5.5,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF383E4A) : const Color(0xFFCBD2DC),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

/// نقاش پیشرفته نوار حلقوی نئومورفیک ژله‌ای درخشان
class _NeumorphicGlowRingPainter extends CustomPainter {
  _NeumorphicGlowRingPainter({
    required this.percentage,
    required this.activeColor,
    required this.isDark,
  });

  final double percentage;
  final Color activeColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const strokeWidth = 12.0;

    // ۱. شیار شیشه‌ای شفاف بیرونی (Translucent Glass Tube)
    final glassTrackPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, glassTrackPaint);

    if (percentage <= 0) return;

    // ۲. نوار پیشرفت ژله‌ای درخشان (Luminous Jelly Arc)
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * math.pi * percentage;

    final jellyArcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          activeColor.withValues(alpha: 0.35),
          activeColor.withValues(alpha: 0.75),
          activeColor,
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, jellyArcPaint);

    // ۳. نشانگر انتهایی با افکت مرواریدی درخشان (Glow Pip / Thumb)
    final thumbAngle = -math.pi / 2 + sweepAngle;
    final thumbX = center.dx + radius * math.cos(thumbAngle);
    final thumbY = center.dy + radius * math.sin(thumbAngle);
    final thumbCenter = Offset(thumbX, thumbY);

    // هاله نئونی عریض
    final outerGlowPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 9, outerGlowPaint);

    // بدنه دایره سفید مرواریدی
    final whiteCorePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 5.0, whiteCorePaint);

    // نقطه مرکزی کوچک همرنگ فاز
    final innerDotPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbCenter, 2.2, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _NeumorphicGlowRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isDark != isDark;
  }
}
