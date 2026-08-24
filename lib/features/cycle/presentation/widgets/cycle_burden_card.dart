import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

class CycleBurdenCard extends StatelessWidget {
  const CycleBurdenCard({
    super.key,
    required this.burden,
    required this.advice,
  });

  final BodyBurdenScore burden;
  final CycleAdaptiveAdvice advice;

  static String _translateRecommendation(String code) {
    switch (code) {
      case 'reduce_heavy_workload':
        return 'کاهش حجم کارهای سنگین و فشرده';
      case 'split_focus_sessions':
        return 'تقسیم جلسات تمرکز به بخش‌های کوتاه‌تر';
      case 'plan_more_frequent_breaks':
        return 'برنامه‌ریزی برای استراحت‌های مکرر و کوتاه';
      case 'prioritize_comfort_hydration':
        return 'اولویت دادن به راحتی و نوشیدن آب کافی';
      case 'maintain_balanced_rhythm':
        return 'حفظ ریتم کاری متعادل و پایدار';
      case 'take_extra_five_min_break':
        return 'اختصاص ۵ دقیقه استراحت بیشتر در هر ساعت';
      case 'do_deep_work_early':
        return 'انجام کارهای نیازمند تمرکز عمیق در ساعات اولیه روز';
      case 'gentle_menstrual_rhythm':
        return 'رعایت ریتم آرام متناسب با دوران قاعدگی';
      case 'avoid_unnecessary_pressure':
        return 'پرهیز از فشارهای غیرضروری جسمی و فکری';
      case 'optimal_physical_rhythm':
        return 'ریتم بدنی عالی و پرانرژی';
      case 'ideal_for_demanding_tasks':
        return 'بازهٔ مناسب برای انجام فعالیت‌های پرچالش';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badgeColor = burden.level == 'HIGH'
        ? colors.primary
        : (burden.level == 'MODERATE' ? colors.warning : colors.success);

    final badgeTitleFa = burden.level == 'HIGH'
        ? 'بار بدنی بالا'
        : (burden.level == 'MODERATE' ? 'بار بدنی متوسط' : 'بار بدنی متوازن');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                size: 20,
                color: badgeColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'شاخص ریتم بدنی و تنظیم بار روزانه',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeTitleFa,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...(advice.recommendationsFa ??
                  advice.recommendationCodes.map(_translateRecommendation))
              .map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          rec,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textPrimary,
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
