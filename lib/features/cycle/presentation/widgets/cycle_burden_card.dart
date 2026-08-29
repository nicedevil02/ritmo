import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';

class CycleBurdenCard extends StatelessWidget {
  const CycleBurdenCard({
    super.key,
    required this.burden,
    required this.advice,
    this.phase,
    this.onOpenGuide,
  });

  final BodyBurdenScore burden;
  final CycleAdaptiveAdvice advice;
  final CyclePhase? phase;
  final VoidCallback? onOpenGuide;

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
    final p = phase ?? CyclePhase.follicular;

    var emoji = '⚡';
    var phaseTitle = 'تقویت انرژی و تنظیم بار روزانه';
    var actionText = 'راهکارها و روتین‌های فاز فولیکولار';
    var phaseColor = colors.accent;

    if (p == CyclePhase.ovulation) {
      emoji = '✨';
      phaseTitle = 'سلامت و شادابی در فاز باروری';
      actionText = 'راهکارها و رژیم‌های فاز باروری';
      phaseColor = colors.accent;
    } else if (p == CyclePhase.luteal) {
      emoji = '💆';
      phaseTitle = 'مدیریت علائم پیش‌قاعدگی (PMS)';
      actionText = 'راهکارهای تسکین علائم PMS';
      phaseColor = colors.primary;
    } else if (p == CyclePhase.menstrual) {
      emoji = '🆘';
      phaseTitle = 'تنظیم بار بدنی و تسکین درد (SOS)';
      actionText = 'راهکارهای سریع تسکین درد';
      phaseColor = colors.primary;
    }

    final badgeColor = burden.level == 'HIGH'
        ? colors.primary
        : (burden.level == 'MODERATE' ? colors.warning : colors.success);

    final badgeTitleFa = burden.level == 'HIGH'
        ? 'بار بدنی بالا'
        : (burden.level == 'MODERATE' ? 'بار بدنی متوسط' : 'بار بدنی متوازن');

    return RitmoCard.neumorphic(
      onTap: onOpenGuide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ۱. هدر استاندارد سیستم مرجع کارت
          RitmoCardHeader(
            title: '$emoji $phaseTitle',
            subtitle: 'تنظیم فشار کاری و خودمراقبتی هوشمند',
            icon: CupertinoIcons.sparkles,
            iconColor: phaseColor,
            trailing: RitmoCardBadge(
              label: badgeTitleFa,
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 12),

          // ۲. محفظه فرورفته توصیه‌ها و وضعیت تحلیلی بار بدنی
          RitmoNeuSurface(
            sunken: true,
            radius: 14,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...(advice.recommendationsFa ??
                        advice.recommendationCodes.map(_translateRecommendation))
                    .map(
                      (rec) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                rec,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),

          // ۳. نوار تعاملی فوتر برای باز کردن راهنما و شیت کامل
          if (onOpenGuide != null) ...[
            const RitmoCardDivider(),
            Row(
              children: [
                Icon(
                  CupertinoIcons.sparkles,
                  size: 15,
                  color: phaseColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    actionText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'مشاهده راهنما',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  CupertinoIcons.chevron_left,
                  size: 13,
                  color: colors.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
