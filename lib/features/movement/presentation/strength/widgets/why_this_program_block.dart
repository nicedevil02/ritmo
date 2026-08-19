import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// بلوک تحلیل دلایل انطباق برنامه با اهداف کاربر با ۳ دلیل مشخص و عینی
class WhyThisProgramBlock extends StatelessWidget {
  const WhyThisProgramBlock({super.key, required this.program});

  final MovementStrengthProgram program;

  List<Map<String, String>> _deriveReasons() {
    final reasons = <Map<String, String>>[];

    // ۱. دلیل مبتنی بر هدف
    String goalReasonTitle = 'تطبیق با هدف شما';
    String goalReasonDesc =
        'دامنهٔ تکرارها و زمان استراحت دقیقاً برای هایپرتروفی و تناسب عضلانی پایدار طراحی شده است.';
    if (program.goal == 'strength') {
      goalReasonTitle = 'افزایش توان و رکورد قدرت';
      goalReasonDesc =
          'ست‌های سنگین‌تر با استراحت ۹۰ ثانیه‌ای برای ریکاوری کامل سیستم عصبی عضلانی چیده شده‌اند.';
    } else if (program.goal == 'endurance') {
      goalReasonTitle = 'افزایش استقامت و ظرفیت قلبی-عروقی';
      goalReasonDesc =
          'تکرارهای بالاتر با استراحت‌های کوتاه برای ارتقای ظرفیت کاری عضلات در نظر گرفته شده‌اند.';
    } else if (program.goal == 'rehab') {
      goalReasonTitle = 'حفاظت مفاصل و الگوهای ایمن';
      goalReasonDesc =
          'حرکات با فشار کنترل‌شده و بدون بار اضافه روی مفاصل آسیب‌پذیر انتخاب شده‌اند.';
    }
    reasons.add({
      'title': goalReasonTitle,
      'desc': goalReasonDesc,
      'icon': 'flag',
    });

    // ۲. دلیل مبتنی بر تجهیزات و ایمنی
    String eqTitle = 'متناسب با تجهیزات انتخابی شما';
    String eqDesc =
        'تمام حرکات با امکانات موجود شما در خانه قابل اجرا هستند و هیچ وسیلهٔ اضافی نیاز ندارند.';
    if (program.sensitiveAreas.isNotEmpty) {
      eqTitle = 'حذف حرکات پرخطر برای مفاصل حساس';
      eqDesc =
          'تمرینات پرفشار برای نواحی ${program.sensitiveAreas.length} گانهٔ اعلام‌شده به صورت خودکار با جایگزین‌های ایمن اصلاح شده‌اند.';
    }
    reasons.add({'title': eqTitle, 'desc': eqDesc, 'icon': 'build'});

    // ۳. دلیل مبتنی بر زمان‌بندی و پیشگیری از تمرین‌زدگی
    final deload = program.deloadWeekIndex ?? 4;
    final schedTitle =
        'زمان‌بندی ${toPersianDigits(program.daysPerWeek)} روزه با هفتهٔ دِلود';
    final schedDesc =
        'هفتهٔ ${toPersianDigits(deload)} به عنوان هفتهٔ دِلود (کاهش حجم) برنامه‌ریزی شده تا از خستگی مفرط مفاصل جلوگیری شود.';
    reasons.add({
      'title': schedTitle,
      'desc': schedDesc,
      'icon': 'calendar_today',
    });

    return reasons;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;
    final reasons = _deriveReasons();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: sportsColor, size: 20),
              const SizedBox(width: RitmoSpacing.sm),
              Text(
                MovementStrings.strengthWhyThisProgram,
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),
          ...reasons.map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: RitmoSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: sportsColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: sportsColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['title']!,
                          style: RitmoTextStyles.label(
                            colors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r['desc']!,
                          style: RitmoTextStyles.caption(colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
