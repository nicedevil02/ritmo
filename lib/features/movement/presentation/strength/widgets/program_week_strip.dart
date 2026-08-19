import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// نوار انتخاب هفته‌های دوره با علامت‌گذاری هفتهٔ دِلود
class ProgramWeekStrip extends StatelessWidget {
  const ProgramWeekStrip({
    super.key,
    required this.totalWeeks,
    required this.currentProgramWeek,
    required this.selectedWeek,
    required this.onWeekSelected,
    this.deloadWeekIndex = 4,
  });

  final int totalWeeks;
  final int currentProgramWeek;
  final int selectedWeek;
  final ValueChanged<int> onWeekSelected;
  final int? deloadWeekIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
      child: Row(
        children: List.generate(totalWeeks, (index) {
          final weekNum = index + 1;
          final isSelected = selectedWeek == weekNum;
          final isCurrent = currentProgramWeek == weekNum;
          final isPast = weekNum < currentProgramWeek;
          final isDeload = deloadWeekIndex == weekNum;

          return Padding(
            padding: const EdgeInsets.only(left: RitmoSpacing.sm),
            child: InkWell(
              onTap: () => onWeekSelected(weekNum),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? sportsColor.withValues(alpha: 0.15)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(
                    color: isSelected
                        ? sportsColor
                        : (isCurrent ? colors.accent : colors.border),
                    width: isSelected || isCurrent ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'هفتهٔ ${toPersianDigits(weekNum)}',
                      style:
                          RitmoTextStyles.label(
                            isSelected ? sportsColor : colors.textPrimary,
                          ).copyWith(
                            fontWeight: isCurrent || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (isDeload)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(RitmoRadius.pill),
                        ),
                        child: Text(
                          'دِلود',
                          style: RitmoTextStyles.caption(
                            colors.accent,
                          ).copyWith(fontSize: 10),
                        ),
                      )
                    else if (isPast)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: colors.success,
                      )
                    else if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: sportsColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(RitmoRadius.pill),
                        ),
                        child: Text(
                          'جاری',
                          style: RitmoTextStyles.caption(
                            sportsColor,
                          ).copyWith(fontSize: 10),
                        ),
                      )
                    else
                      const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
