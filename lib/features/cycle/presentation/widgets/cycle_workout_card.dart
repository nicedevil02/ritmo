import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class CycleWorkoutCard extends StatelessWidget {
  const CycleWorkoutCard({super.key, required this.phase});

  final CyclePhase phase;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var title = '';
    var description = '';
    var icon = CupertinoIcons.sparkles;
    var phaseColor = colors.primary;

    switch (phase) {
      case CyclePhase.menstrual:
        title = 'ورزش مناسب: کشش و یوگا 🌸';
        description =
            'با توجه به فاز قاعدگی، امروز تمرینات سبک مانند یوگا، حرکات کششی و پیاده‌روی ملایم را انتخاب کنید تا بدن بازسازی شود.';
        icon = CupertinoIcons.heart_fill;
        phaseColor = colors.error;
      case CyclePhase.ovulation:
        title = 'ورزش مناسب: قدرت و استقامت 🔥';
        description =
            'شما در فاز تخمک‌گذاری و اوج انرژی هستید. بهترین زمان برای تمرینات قدرتی پرفشار، پلایومتریک و چالش عضلات است.';
        icon = CupertinoIcons.flame_fill;
        phaseColor = colors.accent;
      case CyclePhase.luteal:
        title = 'ورزش مناسب: تمرینات تعادلی 🧘‍♀️';
        description =
            'در فاز لوتئال انرژی به مرور کاهش می‌یابد. تمرینات با شدت متوسط، ورزش‌های تعادلی و روتین‌های کششی آرام‌بخش توصیه می‌شوند.';
        icon = CupertinoIcons.waveform_path_ecg;
        phaseColor = colors.warning;
      case CyclePhase.follicular:
        title = 'ورزش مناسب: کاردیو و هوازی ⚡';
        description =
            'در فاز فولیکولار سطح انرژی رو به افزایش است. زمان عالی برای ورزش‌های هوازی، دویدن و بالا بردن ضربان قلب است.';
        icon = CupertinoIcons.bolt_fill;
        phaseColor = colors.success;
      case CyclePhase.pregnancy:
        title = 'ورزش مناسب بارداری 🤰';
        description =
            'تمرینات تنفسی، پیاده‌روی سبک و حرکات تقویتی مجاز دوران بارداری با نظر پزشک توصیه می‌شود.';
        icon = CupertinoIcons.heart_circle_fill;
        phaseColor = colors.accent;
      case CyclePhase.dataStale:
      case CyclePhase.noData:
        title = 'ورزش متناسب با ریتم بدنی 🌸';
        description =
            'با ثبت اطلاعات دوره، برنامه و حرکات پیشنهادی ورزشی شما به طور خودکار متناسب با فاز چرخه بدنتان همگام می‌شود.';
        icon = Icons.auto_awesome;
        phaseColor = colors.primary;
    }

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: phaseColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
