import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_plan_schedule.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت پیش‌نمایش خلاصهٔ برنامه، تعداد جلسات هفتگی، هدف و دکمه‌های تأیید و ویرایش
class PlanPreviewCard extends StatelessWidget {
  const PlanPreviewCard({
    super.key,
    required this.activityKind,
    required this.schedules,
    required this.goalType,
    required this.goalValue,
    required this.goalUnit,
    required this.reminderType,
    required this.onConfirm,
    required this.onEdit,
    this.isSaving = false,
    this.disabledReason,
  });

  final MovementActivityKind activityKind;
  final List<MovementPlanSchedule> schedules;
  final String goalType;
  final double goalValue;
  final String goalUnit;
  final String reminderType;
  final VoidCallback? onConfirm;
  final VoidCallback onEdit;
  final bool isSaving;
  final String? disabledReason;

  static const _weekdayFullNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  String get _summarySentence {
    final daysCount = schedules.length;
    final daysNames = schedules.map((s) => _weekdayFullNames[s.weekday]).join('، ');
    final goalStr = '${toPersianDigits(goalValue.toInt())} $goalUnit';

    return 'هفته‌ای ${toPersianDigits(daysCount)} جلسه $goalStr $daysNames برای ${activityKind.nameFa}';
  }

  @override
  Widget build(BuildContext context) {
    MovementAnalyticsService.instance.logPlanPreviewed(
      family: activityKind.family,
      daysCount: schedules.length,
      hasConflict: disabledReason != null,
    );

    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // سربرگ پیش‌نمایش
          Text(
            MovementStrings.plannerStepPreview,
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // جملهٔ خلاصهٔ روان
          Container(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              color: sportsColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: sportsColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.summarize_outlined, color: sportsColor, size: 22),
                const SizedBox(width: RitmoSpacing.sm),
                Expanded(
                  child: Text(
                    _summarySentence,
                    style: RitmoTextStyles.body(colors.textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // علت غیرفعال بودن دکمه (در صورت وجود)
          if (disabledReason != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
              child: Text(
                disabledReason!,
                style: RitmoTextStyles.caption(colors.error),
              ),
            ),
          ],

          // دکمه‌های اقدام: تأیید و ذخیره (Primary) و ویرایش (Secondary)
          Row(
            children: [
              // ویرایش
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: isSaving ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, MovementLayout.kFieldMinHeight),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  child: Text(
                    MovementStrings.plannerEditButton,
                    style: RitmoTextStyles.label(colors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: RitmoSpacing.md),

              // تأیید و ذخیره
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isSaving ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(48, MovementLayout.kFieldMinHeight),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          MovementStrings.plannerSaveButton,
                          style: RitmoTextStyles.label(Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
