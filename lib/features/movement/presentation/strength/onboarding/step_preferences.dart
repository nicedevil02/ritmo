import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// گام ۵ از ۵ آنبوردینگ قدرت: ترجیحات محیطی و سبک تمرین
class StepPreferences extends StatelessWidget {
  const StepPreferences({
    super.key,
    required this.quietMode,
    required this.onQuietModeChanged,
    required this.smallSpace,
    required this.onSmallSpaceChanged,
    required this.bodyweightFocus,
    required this.onBodyweightFocusChanged,
  });

  final bool quietMode;
  final ValueChanged<bool> onQuietModeChanged;
  final bool smallSpace;
  final ValueChanged<bool> onSmallSpaceChanged;
  final bool bodyweightFocus;
  final ValueChanged<bool> onBodyweightFocusChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MovementStrings.strengthPreferencesTitle,
          style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Text(
          'این ترجیحات به انتخاب حرکات متناسب با فضای زندگی شما کمک می‌کنند.',
          style: RitmoTextStyles.body(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        _buildPreferenceTile(
          title: 'تمرین کم‌صدا و بدون پرش (آپارتمانی)',
          desc: 'حذف کامل حرکات ضربه‌ای، پرشی و تولیدکنندهٔ صدا برای همسایه‌ها',
          value: quietMode,
          onChanged: onQuietModeChanged,
          sportsColor: sportsColor,
          colors: colors,
        ),
        const SizedBox(height: RitmoSpacing.md),

        _buildPreferenceTile(
          title: 'تمرین در فضای محدود',
          desc: 'انتخاب حرکاتی که به فضایی کمتر از ۲ در ۱ متر نیاز دارند',
          value: smallSpace,
          onChanged: onSmallSpaceChanged,
          sportsColor: sportsColor,
          colors: colors,
        ),
        const SizedBox(height: RitmoSpacing.md),

        _buildPreferenceTile(
          title: 'تمرکز بر حرکات کنترل وزن بدن (کالیستنیکس)',
          desc: 'اولویت دادن به کنترل بدن، تعادل و پیشرفت‌های مهارتی وزن بدن',
          value: bodyweightFocus,
          onChanged: onBodyweightFocusChanged,
          sportsColor: sportsColor,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildPreferenceTile({
    required String title,
    required String desc,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color sportsColor,
    required dynamic colors,
  }) {
    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: value ? sportsColor.withValues(alpha: 0.1) : colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: value ? sportsColor : colors.border,
          width: value ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RitmoTextStyles.label(
                    value ? sportsColor : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: sportsColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
