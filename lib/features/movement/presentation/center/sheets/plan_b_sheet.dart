import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

enum PlanBOption { full, short, minEffectiveDose, move, recovery }

/// شیت انتخاب نسخهٔ جایگزین (Plan B) با پیش‌نمایش دقیق تغییرات
class PlanBSheet extends StatefulWidget {
  const PlanBSheet({
    super.key,
    required this.occurrence,
    required this.onApplyPlanB,
  });

  final MovementOccurrence occurrence;
  final Future<void> Function(PlanBOption option, double newGoalValue)
  onApplyPlanB;

  static Future<bool?> show(
    BuildContext context, {
    required MovementOccurrence occurrence,
    required Future<void> Function(PlanBOption option, double newGoalValue)
    onApplyPlanB,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlanBSheet(
        occurrence: occurrence,
        onApplyPlanB: (opt, val) async {
          await onApplyPlanB(opt, val);
          if (ctx.mounted) {
            Navigator.of(ctx).pop(true);
          }
        },
      ),
    );
  }

  @override
  State<PlanBSheet> createState() => _PlanBSheetState();
}

class _PlanBSheetState extends State<PlanBSheet> {
  PlanBOption _selectedOption = PlanBOption.short;
  bool _isSaving = false;

  double get _newDurationMinutes {
    final original = widget.occurrence.goalValue ?? 30.0;
    switch (_selectedOption) {
      case PlanBOption.full:
        return original;
      case PlanBOption.short:
        return 15.0;
      case PlanBOption.minEffectiveDose:
        return 5.0;
      case PlanBOption.move:
      case PlanBOption.recovery:
        return 0.0;
    }
  }

  String get _keptDescription {
    switch (_selectedOption) {
      case PlanBOption.full:
        return 'گرم کردن کامل، بدنهٔ اصلی تمرین و سرد کردن';
      case PlanBOption.short:
        return 'گرم کردن سریع ۳ دقیقه‌ای + حرکات پربازده اصلی';
      case PlanBOption.minEffectiveDose:
        return 'تنها ۵ دقیقه تحرک پیوسته و کشش فعال برای حفظ ریتم';
      case PlanBOption.move:
        return 'کل جلسه به روز دیگری منتقل می‌شود';
      case PlanBOption.recovery:
        return 'تمرین امروز به استراحت و کشش سبک تبدیل می‌شود';
    }
  }

  String get _droppedDescription {
    switch (_selectedOption) {
      case PlanBOption.full:
        return 'هیچ بخشی حذف نمی‌شود';
      case PlanBOption.short:
        return 'ست‌های فرعی و سرد کردن طولانی';
      case PlanBOption.minEffectiveDose:
        return 'بخش اعظم حجم تمرین و ست‌های سنگین';
      case PlanBOption.move:
      case PlanBOption.recovery:
        return 'تمرین امروز انجام نمی‌شود';
    }
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      await widget.onApplyPlanB(_selectedOption, _newDurationMinutes);
      MovementAnalyticsService.instance.logPlanBSelected(
        versionType: _selectedOption.name,
        trigger: 'plan_b_sheet',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RitmoRadius.sheet),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // دستگیره شیت
          Center(
            child: Container(
              width: MovementLayout.kSheetHandleSize.width,
              height: MovementLayout.kSheetHandleSize.height,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          Text(
            MovementStrings.planBTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'اگر امروز وقت کمی داری، به جای لغو کامل، نسخهٔ فشرده را انجام بده.',
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // انتخاب گزینه‌ها
          _buildOptionTile(
            context,
            option: PlanBOption.short,
            title: MovementStrings.planBShort,
            duration: '۱۵ دقیقه',
            colors: colors,
            sportsColor: sportsColor,
          ),
          _buildOptionTile(
            context,
            option: PlanBOption.minEffectiveDose,
            title: MovementStrings.planBMinDose,
            duration: '۵ دقیقه',
            colors: colors,
            sportsColor: sportsColor,
          ),
          _buildOptionTile(
            context,
            option: PlanBOption.full,
            title: MovementStrings.planBFull,
            duration:
                '${toPersianDigits(widget.occurrence.goalValue?.toInt() ?? 30)} دقیقه',
            colors: colors,
            sportsColor: sportsColor,
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // کارت پیش‌نمایش تغییرات
          Container(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              color: sportsColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: sportsColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'پیش‌نمایش تغییر:',
                  style: RitmoTextStyles.label(sportsColor),
                ),
                const SizedBox(height: 6),
                Text(
                  '• ${MovementStrings.planBKept}: $_keptDescription',
                  style: RitmoTextStyles.caption(colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '• ${MovementStrings.planBDropped}: $_droppedDescription',
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: RitmoSpacing.xl),

          // دکمهٔ اعمال
          SizedBox(
            width: double.infinity,
            height: MovementLayout.kFieldMinHeight,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: sportsColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'اعمال ${toPersianDigits(_newDurationMinutes.toInt())} دقیقه‌ای',
                      style: RitmoTextStyles.label(Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required PlanBOption option,
    required String title,
    required String duration,
    required dynamic colors,
    required Color sportsColor,
  }) {
    final isSelected = _selectedOption == option;

    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: InkWell(
          onTap: () => setState(() => _selectedOption = option),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.md,
              vertical: RitmoSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(
                color: isSelected ? sportsColor : colors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? sportsColor : colors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sportsColor,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: RitmoSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ),
                Text(duration, style: RitmoTextStyles.label(sportsColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
