import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_absence_status.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';

/// وضعیت C صفحهٔ اصلی: بدون برنامه برای امروز (P-08 State C & P-15)
class MovementNoPlanView extends StatelessWidget {
  const MovementNoPlanView({
    super.key,
    required this.tier,
    required this.railDays,
    this.absenceStatus = AbsenceStatus.none,
    required this.onOpenPicker,
    required this.onOpenPlanEditor,
    required this.onSelectDay,
  });

  final MovementTier tier;
  final List<MovementDayData> railDays;
  final AbsenceStatus absenceStatus;
  final VoidCallback onOpenPicker;
  final VoidCallback onOpenPlanEditor;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    // انتخاب پیام بر اساس وضعیت غیبت (P-15)
    final String headline;
    final String bodyText;
    final String primaryActionLabel;

    switch (absenceStatus) {
      case AbsenceStatus.shortAbsence:
        headline = 'یه مدت نبودی. مهم نیست —';
        bodyText = 'بریم از یه تمرین سبک شروع کنیم و ریتم رو برگردونیم.';
        primaryActionLabel = 'یه تمرین سبک ثبت کن';
        break;
      case AbsenceStatus.longAbsence:
        headline = 'بعد از مدتی برگشتی. خوش اومدی!';
        bodyText = 'قدم‌های کوچک بهترین شروع برای بازگشت به تحرک هستند.';
        primaryActionLabel = 'یه تمرین کوتاه ثبت کن';
        break;
      case AbsenceStatus.none:
        headline = 'امروز چی‌کار کنیم؟';
        bodyText = 'هنوز برای امروز تمرینی ثبت نشده است.';
        primaryActionLabel = 'یه فعالیت ثبت کن';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeekRail(
          days: railDays,
          onDaySelected: onSelectDay,
        ),
        const SizedBox(height: RitmoSpacing.xl),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: sportsColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_run_rounded,
                      size: 38,
                      color: sportsColor,
                    ),
                  ),
                ),
                const SizedBox(height: RitmoSpacing.lg),

                Text(
                  headline,
                  style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RitmoSpacing.sm),

                Text(
                  bodyText,
                  style: RitmoTextStyles.body(colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RitmoSpacing.xxl),

                // دکمهٔ ثبت فعالیت
                ElevatedButton.icon(
                  onPressed: onOpenPicker,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(primaryActionLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                ),

                // دکمهٔ تنظیم برنامه (فقط برای تیر ۲ و ۳)
                if (tier.isPlannerAvailable) ...[
                  const SizedBox(height: RitmoSpacing.md),
                  OutlinedButton.icon(
                    onPressed: onOpenPlanEditor,
                    icon: const Icon(Icons.calendar_today_rounded),
                    label: const Text('تنظیم برنامهٔ هفتگی'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textPrimary,
                      side: BorderSide(color: colors.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
