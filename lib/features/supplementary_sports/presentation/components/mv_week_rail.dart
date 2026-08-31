import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// 7-day horizontal Week Rail (Section 5.1 & 5.2).
class MvWeekRail extends StatelessWidget {
  final List<MvSlot> weekSlots;
  final String selectedDateIso;
  final ValueChanged<String>? onDateSelected;

  const MvWeekRail({
    super.key,
    required this.weekSlots,
    required this.selectedDateIso,
    this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final todayIso = MvCalendar.formatDateIso(DateTime.now());

    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg),
        itemCount: weekSlots.length,
        separatorBuilder: (_, _) => SizedBox(width: metrics.spaceSm),
        itemBuilder: (context, index) {
          final slot = weekSlots[index];
          final dt = MvCalendar.parseDateIso(slot.dateIso);
          final sat0 = MvCalendar.dateTimeToSat0(dt);
          final isSelected = slot.dateIso == selectedDateIso;
          final isToday = slot.dateIso == todayIso;

          final Color bgColor;
          final Color borderColor;

          if (isSelected) {
            bgColor = colors.primary;
            borderColor = colors.primary;
          } else if (isToday) {
            bgColor = colors.surfaceElevated;
            borderColor = colors.primary.withValues(alpha: 0.8);
          } else {
            bgColor = colors.surface;
            borderColor = colors.border;
          }

          final textColor = isSelected ? colors.onPrimary : colors.textPrimary;
          final subTextColor = isSelected
              ? colors.onPrimary.withValues(alpha: 0.8)
              : colors.textSecondary;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onDateSelected?.call(slot.dateIso),
              borderRadius: BorderRadius.circular(metrics.radiusCard),
              child: Container(
                width: 52,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(metrics.radiusCard),
                  border: Border.all(
                    color: borderColor,
                    width: isToday ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      MvCalendar.persianWeekdayShort(sat0),
                      style: textTheme.labelSmall?.copyWith(
                        color: subTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: metrics.spaceXs),
                    Text(
                      dt.day.toString(),
                      style: textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: metrics.spaceXs),
                    // Status dot or Lock indicator
                    if (slot.isLocked)
                      Icon(
                        Icons.lock_rounded,
                        size: metrics.spaceSm,
                        color: isSelected ? colors.onPrimary : colors.accent,
                      )
                    else
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: slot.isCompleted
                              ? (isSelected ? colors.onPrimary : colors.success)
                              : slot.isRest
                              ? Colors.transparent
                              : (isSelected
                                    ? colors.onPrimary.withValues(alpha: 0.4)
                                    : colors.primary.withValues(alpha: 0.4)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
