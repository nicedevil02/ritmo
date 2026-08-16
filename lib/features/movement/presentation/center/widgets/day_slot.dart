import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_status_indicators.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_semantics.dart';

/// حالت‌های ۶ گانهٔ اسلات روز در ریل هفته
enum MovementDaySlotState {
  today,
  selected,
  todayAndSelected,
  normal,
  pastEmpty,
  outOfRange,
}

/// خانهٔ یک روز در ریل هفته با رعایت کامل دسترس‌پذیری، انیمیشن و تمایز امروز از انتخاب‌شده
class DaySlot extends StatelessWidget {
  const DaySlot({
    super.key,
    required this.dayName,
    required this.dayNumber,
    required this.monthName,
    required this.state,
    required this.statuses,
    this.sessionCount = 0,
    this.completedCount = 0,
    required this.onTap,
    this.onReselect,
  });

  final String dayName;
  final int dayNumber;
  final String monthName;
  final MovementDaySlotState state;
  final List<MovementDayStatus> statuses;
  final int sessionCount;
  final int completedCount;
  final VoidCallback onTap;
  final VoidCallback? onReselect;

  bool get isSelected =>
      state == MovementDaySlotState.selected ||
      state == MovementDaySlotState.todayAndSelected;

  bool get isToday =>
      state == MovementDaySlotState.today ||
      state == MovementDaySlotState.todayAndSelected;

  bool get isOutOfRange => state == MovementDaySlotState.outOfRange;

  bool get isPastEmpty => state == MovementDaySlotState.pastEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final semanticsText = MovementSemantics.dayLabel(
      dayName: dayName,
      dayNumber: dayNumber,
      monthName: monthName,
      sessionCount: sessionCount,
      completedCount: completedCount,
      isSelected: isSelected,
      isToday: isToday,
    );

    // رنگ‌ها بر اساس حالت
    Color textColor = colors.textPrimary;
    Color subtitleColor = colors.textSecondary;
    if (isOutOfRange) {
      textColor = colors.disabled;
      subtitleColor = colors.disabled;
    } else if (isPastEmpty) {
      textColor = colors.textTertiary;
      subtitleColor = colors.textTertiary;
    }

    // پس‌زمینه و حاشیه انتخاب
    BoxDecoration decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: sportsColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        border: Border.all(
          color: sportsColor,
          width: 1.5,
        ),
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.5),
          width: 1.0,
        ),
      );
    } else {
      decoration = BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
      );
    }

    return Semantics(
      button: !isOutOfRange,
      selected: isSelected,
      label: semanticsText,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOutOfRange
              ? null
              : () {
                  RitmoHapticsPolicy.selection();
                  if (isSelected && onReselect != null) {
                    onReselect!();
                  } else {
                    onTap();
                  }
                },
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          child: AnimatedContainer(
            duration: RitmoMotion.effective(context, RitmoMotion.state),
            curve: Curves.easeInOut,
            constraints: BoxConstraints(
              minWidth: MovementLayout.kDaySlotMinSize.width,
              minHeight: MovementLayout.kDaySlotMinSize.height,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 2.0,
              vertical: 2.0,
            ),
            decoration: decoration,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // نام کوتاه روز
                Text(
                  dayName,
                  style: RitmoTextStyles.caption(subtitleColor).copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.05,
                  ),
                  maxLines: 1,
                ),

                // شماره روز جلالی
                Text(
                  toPersianDigits(dayNumber),
                  style: RitmoTextStyles.titleMedium(textColor).copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.05,
                  ),
                  maxLines: 1,
                ),

                // نشانگر «امروز»
                if (isToday)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 1.0),
                    width: 3.5,
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 5.5),

                // نشانگرهای وضعیت
                DayStatusIndicators(statuses: statuses),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
