// C-43, C-44: CycleOrbCard
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
    final progress = totalDays > 0
        ? (currentDay / totalDays).clamp(0.05, 1.0)
        : 0.1;
    final m = context.metrics;

    return RitmoTheme.glassCardLight(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: m.spaceXl, horizontal: m.spaceLg),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 146 * m.densityFactor,
                  width: 146 * m.densityFactor,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: phaseColor.withValues(alpha: 0.12),
                        blurRadius: 35,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 136 * m.densityFactor,
                  width: 136 * m.densityFactor,
                  child: CustomPaint(
                    painter: CycleProgressRingPainter(
                      percentage: progress,
                      activeColor: phaseColor,
                      isDark: isDark,
                    ),
                  ),
                ),
                Container(
                  height: 104 * m.densityFactor,
                  width: 104 * m.densityFactor,
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.2 : 0.04,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          phase == CyclePhase.menstrual
                              ? 'روز پریود'
                              : 'روز چرخه',
                          style: RitmoTextStyles.caption(colors.textSecondary),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              PersianDigits.toFa(
                                phase == CyclePhase.menstrual
                                    ? activePeriodDay.toString()
                                    : dayOfCycle.toString(),
                              ),
                              style: RitmoTextStyles.displayLarge(phaseColor).copyWith(
                                fontWeight: FontWeight.bold,
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
            SizedBox(height: m.spaceXl),
            Container(
              padding: EdgeInsets.symmetric(horizontal: m.spaceMd, vertical: m.spaceXs),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                border: Border.all(
                  color: phaseColor.withValues(alpha: isDark ? 0.3 : 0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: RitmoTextStyles.label(phaseColor)),
                  SizedBox(width: m.spaceXs),
                  Text(
                    phaseText,
                    style: RitmoTextStyles.bodyMedium(phaseColor).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: m.spaceSm),
            Text(
              remainingText,
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
            ),
            SizedBox(height: m.spaceSm),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: m.spaceMd),
              child: Text(
                statusTip,
                textAlign: TextAlign.center,
                style: RitmoTextStyles.caption(colors.textSecondary).copyWith(
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
