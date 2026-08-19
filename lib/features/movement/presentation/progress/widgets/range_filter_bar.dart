import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_progress_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// نوار فیلتر بازهٔ زمانی پیشرفت (RangeFilterBar)
class RangeFilterBar extends StatelessWidget {
  const RangeFilterBar({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  final MovementProgressRange selectedRange;
  final ValueChanged<MovementProgressRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final options = [
      {'range': MovementProgressRange.week, 'label': MovementStrings.rangeWeek},
      {
        'range': MovementProgressRange.month,
        'label': MovementStrings.rangeMonth,
      },
      {
        'range': MovementProgressRange.threeMonths,
        'label': MovementStrings.rangeThreeMonths,
      },
      {'range': MovementProgressRange.all, 'label': MovementStrings.rangeAll},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: options.map((opt) {
          final range = opt['range'] as MovementProgressRange;
          final label = opt['label'] as String;
          final isSelected = selectedRange == range;

          return Expanded(
            child: InkWell(
              onTap: () => onRangeChanged(range),
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? sportsColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                ),
                child: Text(
                  label,
                  style:
                      RitmoTextStyles.caption(
                        isSelected ? Colors.white : colors.textSecondary,
                      ).copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
