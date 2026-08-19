import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_status_indicators.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// مدل داده برای نمایش یک روز در ریل هفته
class MovementDayData {
  const MovementDayData({
    required this.date,
    required this.dayName,
    required this.dayNumber,
    required this.monthName,
    required this.state,
    this.statuses = const [],
    this.sessionCount = 0,
    this.completedCount = 0,
  });

  final DateTime date;
  final String dayName;
  final int dayNumber;
  final String monthName;
  final MovementDaySlotState state;
  final List<MovementDayStatus> statuses;
  final int sessionCount;
  final int completedCount;
}

/// ریل هفته شامل ۷ روز شنبه تا جمعه با توزیع مساوی در چیدمان RTL.
/// در عرض‌های بسیار باریک (کمتر از ۷ برابر حداقل عرض اسلات + پدینگ)
/// به‌جای کوچک‌شدن زیر حداقل هدف لمس، اسکرول افقی محافظت‌شده فعال می‌شود.
class WeekRail extends StatelessWidget {
  const WeekRail({
    super.key,
    required this.days,
    required this.onDaySelected,
    this.onDayReselected,
  });

  final List<MovementDayData> days;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime>? onDayReselected;

  @override
  Widget build(BuildContext context) {
    if (days.length != 7) {
      return const SizedBox(height: MovementLayout.kWeekRailHeight);
    }
    final colors = context.colors;

    final decoration = BoxDecoration(
      color: colors.background,
      border: Border(
        bottom: BorderSide(
          color: colors.border,
          width: RitmoElevation.borderWidthDark,
        ),
      ),
    );

    final slots = [
      for (final day in days)
        DaySlot(
          dayName: day.dayName,
          dayNumber: day.dayNumber,
          monthName: day.monthName,
          state: day.state,
          statuses: day.statuses,
          sessionCount: day.sessionCount,
          completedCount: day.completedCount,
          onTap: () => onDaySelected(day.date),
          onReselect: onDayReselected != null
              ? () => onDayReselected!(day.date)
              : null,
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final minRequiredWidth =
            (MovementLayout.kDaySlotMinSize.width * 7) + (RitmoSpacing.lg * 2);

        if (constraints.maxWidth < minRequiredWidth) {
          // حالت محافظت‌شده: اسکرول افقی به‌جای نقض حداقل هدف لمس
          return Container(
            height: MovementLayout.kWeekRailHeight,
            decoration: decoration,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
              child: Row(
                children: [
                  for (final slot in slots)
                    SizedBox(
                      width: MovementLayout.kDaySlotMinSize.width,
                      child: slot,
                    ),
                ],
              ),
            ),
          );
        }

        return Container(
          height: MovementLayout.kWeekRailHeight,
          padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
          decoration: decoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [for (final slot in slots) Expanded(child: slot)],
          ),
        );
      },
    );
  }
}
