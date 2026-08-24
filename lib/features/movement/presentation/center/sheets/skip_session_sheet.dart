import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

enum SkipActionChoice {
  skipTodayOnly,
  moveToOtherDay,
  shortVersion,
  editTemplate,
}

/// شیت رد کردن جلسه با گزینه‌های حمایتی و بدون کلمات سرزنش‌آمیز
class SkipSessionSheet extends StatelessWidget {
  const SkipSessionSheet({super.key, required this.onChoiceSelected});

  final ValueChanged<SkipActionChoice> onChoiceSelected;

  static Future<SkipActionChoice?> show(BuildContext context) {
    return showModalBottomSheet<SkipActionChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SkipSessionSheet(
        onChoiceSelected: (choice) => Navigator.of(ctx).pop(choice),
      ),
    );
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
            MovementStrings.skipTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.xs),
          Text(
            'استراحت بخشی از روند پیشرفت است. تصمیم مناسب خودت را انتخاب کن.',
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // گزینه‌های چهارگانه
          _buildOption(
            context,
            icon: Icons.check_circle_outline_rounded,
            title: MovementStrings.skipOptionTodayOnly,
            subtitle:
                'امروز به عنوان روز استراحت ثبت می‌شود و برنامه ادامه می‌یابد',
            choice: SkipActionChoice.skipTodayOnly,
            colors: colors,
            sportsColor: sportsColor,
          ),
          _buildOption(
            context,
            icon: Icons.calendar_month_rounded,
            title: MovementStrings.skipOptionMove,
            subtitle: 'انتقال این جلسه به یکی از روزهای خالی هفته',
            choice: SkipActionChoice.moveToOtherDay,
            colors: colors,
            sportsColor: sportsColor,
          ),
          _buildOption(
            context,
            icon: Icons.timer_outlined,
            title: MovementStrings.skipOptionShortVersion,
            subtitle: 'انجام یک نسخهٔ سریع و ۱۰ الی ۱۵ دقیقه‌ای',
            choice: SkipActionChoice.shortVersion,
            colors: colors,
            sportsColor: sportsColor,
          ),
          _buildOption(
            context,
            icon: Icons.edit_calendar_outlined,
            title: MovementStrings.skipOptionEditTemplate,
            subtitle: 'تغییر روزها یا سبک برنامه برای هفته‌های آینده',
            choice: SkipActionChoice.editTemplate,
            colors: colors,
            sportsColor: sportsColor,
          ),

          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required SkipActionChoice choice,
    required dynamic colors,
    required Color sportsColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: InkWell(
          onTap: () => onChoiceSelected(choice),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.md,
              vertical: RitmoSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: sportsColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: sportsColor, size: 22),
                ),
                const SizedBox(width: RitmoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: colors.textSecondary.withValues(alpha: 0.4),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
