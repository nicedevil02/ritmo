// C-43, C-44: CycleOrbCard (Redesigned with Apple HIG & Neumorphic Soft UI)
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_animated_background.dart';

class CycleOrbCard extends StatelessWidget {
  const CycleOrbCard({
    super.key,
    required this.phase,
    required this.isTodayPeriod,
    required this.activePeriodDay,
    required this.dayOfCycle,
    required this.totalCycleLength,
    required this.avgPeriodDuration,
  });

  final CyclePhase phase;
  final bool isTodayPeriod;
  final int activePeriodDay;
  final int dayOfCycle;
  final double totalCycleLength;
  final double avgPeriodDuration;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var phaseText = '';
    var remainingText = '';
    var emoji = '✨';
    var statusTip = '';
    var phaseColor = colors.accent;

    switch (phase) {
      case CyclePhase.menstrual:
        phaseText = 'دوران قاعدگی (پریود)';
        remainingText =
            'روز ${PersianDigits.toFa(activePeriodDay.toString())} دوره خونریزی';
        phaseColor = colors.error;
        emoji = '🩸';
        statusTip =
            'بدن شما در حال پاکسازی طبیعی است. استراحت کافی، نوشیدن آب ولرم و دمنوش‌های ملایم به کاهش انقباضات کمک می‌کند.';
      case CyclePhase.ovulation:
        phaseText = 'روز تخمک‌گذاری';
        remainingText = 'اوج هورمون‌های زنانه و باروری';
        phaseColor = colors.accent;
        emoji = '🥚';
        statusTip =
            'تخمک‌گذاری رخ داده است. هورمون‌ها در بالاترین سطح خود هستند و آمادگی فیزیکی و سطح نشاط بدنی شما عالی است.';
      case CyclePhase.luteal:
        phaseText = 'روزهای پیش از عادت (PMS)';
        remainingText =
            'روز ${PersianDigits.toFa(dayOfCycle.toString())} چرخه بدنی';
        phaseColor = colors.primary;
        emoji = '🌸';
        statusTip =
            'روزهای قبل از پریود؛ نوسان هورمونی طبیعی است. یوگای آرام، کاهش مصرف نمک و خواب منظم بسیار موثر است.';
      case CyclePhase.dataStale:
        phaseText = 'نیاز به بازبینی وضعیت';
        remainingText = 'موعد تخمینی سپری شده است';
        phaseColor = colors.warning;
        emoji = '⏳';
        statusTip =
            'لطفاً وضعیت ثبت دورهٔ خود را مشخص کنید تا محاسبات و یادآوری‌ها دقیق بمانند.';
      case CyclePhase.pregnancy:
        phaseText = 'دوران بارداری';
        remainingText = 'محاسبات چرخه متوقف شده است';
        phaseColor = colors.primary;
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
        phaseColor = colors.accent;
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: m.spaceXl,
            horizontal: m.spaceLg,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceElevated.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.75),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : const Color(0xFFA3B1C6).withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ۱. گیج حلقوی پیشرفت با عمق نئومورفیک و انیمیشن پر شدن نرم
              _buildNeumorphicGauge(
                context: context,
                targetProgress: targetProgress,
                phaseColor: phaseColor,
                currentDay: currentDay,
                isDark: isDark,
                densityFactor: m.densityFactor,
              ),
              SizedBox(height: m.spaceLg),

              // ۲. کپسول شیشه‌ای نشان فاز (Apple Translucent Pill Badge)
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: phaseColor.withValues(alpha: isDark ? 0.16 : 0.10),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: phaseColor.withValues(alpha: isDark ? 0.38 : 0.25),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      phaseText,
                      style: RitmoTextStyles.bodyMedium(phaseColor).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: m.spaceSm),

              // ۳. عنوان وضعیت روز
              Text(
                remainingText,
                textAlign: TextAlign.center,
                style: RitmoTextStyles.cardTitle(colors.textPrimary).copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              SizedBox(height: m.spaceSm),

              // ۴. متن راهنما و نکته فاز
              Padding(
                padding: EdgeInsets.symmetric(horizontal: m.spaceMd),
                child: Text(
                  statusTip,
                  textAlign: TextAlign.center,
                  style: RitmoTextStyles.caption(colors.textSecondary).copyWith(
                    height: 1.6,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicGauge({
    required BuildContext context,
    required double targetProgress,
    required Color phaseColor,
    required int currentDay,
    required bool isDark,
    required double densityFactor,
  }) {
    final gaugeSize = 148 * densityFactor;
    final trackSize = 140 * densityFactor;
    final innerDiscSize = 98 * densityFactor;

    return SizedBox(
      height: gaugeSize,
      width: gaugeSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // لایه هاله نور پس‌زمینه رنگی
          Container(
            height: gaugeSize,
            width: gaugeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: phaseColor.withValues(alpha: isDark ? 0.22 : 0.14),
                  blurRadius: 36,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

          // شیار فرورفته نئومورفیک (Concave Recessed Track)
          Container(
            height: trackSize,
            width: trackSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFF16181B)
                  : const Color(0xFFEBF0F5),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.80)
                      : const Color(0xFFBCC7D4).withValues(alpha: 0.70),
                  offset: const Offset(2.5, 2.5),
                  blurRadius: 5,
                ),
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF282C34)
                      : Colors.white,
                  offset: const Offset(-2.5, -2.5),
                  blurRadius: 5,
                ),
              ],
            ),
          ),

          // نوار پیشرفت حلقوی همراه با انیمیشن Sweep نرم
          SizedBox(
            height: trackSize,
            width: trackSize,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: targetProgress),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, animValue, child) {
                return CustomPaint(
                  painter: CycleProgressRingPainter(
                    percentage: animValue,
                    activeColor: phaseColor,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // دیسک برجسته نئومورفیک میانی (Convex Elevated Core)
          Container(
            height: innerDiscSize,
            width: innerDiscSize,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF21252C)
                  : const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.60)
                      : const Color(0xFFA6B5C5).withValues(alpha: 0.45),
                  offset: const Offset(3.5, 3.5),
                  blurRadius: 7,
                ),
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF2C323B)
                      : Colors.white,
                  offset: const Offset(-3.5, -3.5),
                  blurRadius: 7,
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF86868B),
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
                          fontSize: 28,
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
}
