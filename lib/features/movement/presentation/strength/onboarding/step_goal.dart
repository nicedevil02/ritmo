import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// گام ۱ از ۵ آنبوردینگ قدرت: انتخاب هدف تمرینی
class StepGoal extends StatelessWidget {
  const StepGoal({
    super.key,
    required this.selectedGoal,
    required this.onGoalSelected,
  });

  final String selectedGoal;
  final ValueChanged<String> onGoalSelected;

  static const List<Map<String, String>> _goals = [
    {
      'id': 'muscle',
      'title': 'عضله‌سازی و فرم‌دهی',
      'subtitle': 'تمرکز بر هایپرتروفی، حجم عضلانی متوازن و تفکیک عضلات',
      'icon': 'fitness_center',
    },
    {
      'id': 'strength',
      'title': 'افزایش قدرت و توان عضلانی',
      'subtitle': 'تمرکز بر افزایش رکورد وزنه‌ها و قدرت عملکردی کل بدن',
      'icon': 'bolt',
    },
    {
      'id': 'health',
      'title': 'سلامت عمومی، تندرستی و نشاط',
      'subtitle': 'تمرکز بر حفظ تودهٔ عضلانی، سلامت مفاصل و انرژی روزمره',
      'icon': 'favorite',
    },
    {
      'id': 'endurance',
      'title': 'استقامت عضلانی و چربی‌سوزی',
      'subtitle': 'تکرارهای بالاتر، استراحت کوتاه‌تر و بهبود توان هوازی-عضلانی',
      'icon': 'timer',
    },
    {
      'id': 'rehab',
      'title': 'توانبخشی سبک و تحرک‌پذیری',
      'subtitle': 'تمرینات کم‌فشار برای تقویت مفاصل و بهبود الگوهای حرکتی',
      'icon': 'accessibility_new',
    },
  ];

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'bolt':
        return Icons.bolt_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'timer':
        return Icons.timer_rounded;
      case 'accessibility_new':
        return Icons.accessibility_new_rounded;
      case 'fitness_center':
      default:
        return Icons.fitness_center_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MovementStrings.strengthGoalTitle,
          style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Text(
          'برنامهٔ شما دقیقاً بر اساس هدف انتخابی بهینه‌سازی خواهد شد.',
          style: RitmoTextStyles.body(colors.textSecondary),
        ),
        const SizedBox(height: RitmoSpacing.lg),
        ..._goals.map((g) {
          final isSelected = selectedGoal == g['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: RitmoSpacing.md),
            child: InkWell(
              onTap: () => onGoalSelected(g['id']!),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              child: Container(
                padding: const EdgeInsets.all(RitmoSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? sportsColor.withValues(alpha: 0.1)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(
                    color: isSelected ? sportsColor : colors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: MovementLayout.kIconContainerSize,
                      height: MovementLayout.kIconContainerSize,
                      decoration: BoxDecoration(
                        color: isSelected ? sportsColor : colors.surfaceSunken,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(g['icon']!),
                        color: isSelected ? Colors.white : sportsColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g['title']!,
                            style: RitmoTextStyles.cardTitle(
                              isSelected ? sportsColor : colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            g['subtitle']!,
                            style: RitmoTextStyles.caption(
                              colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: sportsColor,
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
