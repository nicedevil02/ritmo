import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// انتخابگر ۵ سطحی شدت تمرین با برچسب‌های متنی و ارقام فارسی
class IntensityPicker extends StatelessWidget {
  const IntensityPicker({
    super.key,
    required this.selectedIntensity,
    required this.onIntensityChanged,
  });

  final int selectedIntensity; // 1 to 5
  final ValueChanged<int> onIntensityChanged;

  static const List<String> _labels = [
    MovementStrings.intensityVeryLight,
    MovementStrings.intensityLight,
    MovementStrings.intensityModerate,
    MovementStrings.intensityHard,
    MovementStrings.intensityVeryHard,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'شدت تمرین:',
          style: RitmoTextStyles.body(colors.textPrimary).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        Row(
          children: List.generate(5, (index) {
            final level = index + 1;
            final isSelected = selectedIntensity == level;
            final label = _labels[index];

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 4 ? 0 : 4,
                  right: index == 0 ? 0 : 4,
                ),
                child: InkWell(
                  onTap: () => onIntensityChanged(level),
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? sportsColor.withValues(alpha: 0.2)
                          : colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      border: Border.all(
                        color: isSelected ? sportsColor : colors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          toPersianDigits(level),
                          style: RitmoTextStyles.label(
                            isSelected ? sportsColor : colors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: RitmoTextStyles.caption(
                            isSelected ? sportsColor : colors.textSecondary,
                          ).copyWith(fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
