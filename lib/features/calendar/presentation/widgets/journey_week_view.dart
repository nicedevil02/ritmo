import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:shamsi_date/shamsi_date.dart';

class JourneyWeekView extends StatelessWidget {
  const JourneyWeekView({
    super.key,
    required this.selectedDate,
    required this.rangeSnapshots,
    required this.onSelectDate,
    this.onMoveItemToDate,
  });

  final DateTime selectedDate;
  final Map<String, DayAgendaSnapshot> rangeSnapshots;
  final ValueChanged<DateTime> onSelectDate;
  final void Function(AgendaItem item, DateTime targetDate)? onMoveItemToDate;

  static const double miniPxPerMin = 0.35; // ~504px total timeline height

  static const List<String> weekDayShortFa = ['ش', '۱ش', '۲ش', '۳ش', '۴ش', '۵ش', 'ج'];

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();

    final sat = ShamsiWeek.saturdayOf(selectedDate);
    final weekDays = List.generate(7, (i) => sat.add(Duration(days: i)));

    final nowMinutes = (now.hour * 60) + now.minute;
    final nowTop = nowMinutes * miniPxPerMin;

    int weekTotal = 0;
    int weekCompleted = 0;
    for (final day in weekDays) {
      final k = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final snap = rangeSnapshots[k];
      if (snap != null) {
        weekTotal += snap.completedCount + snap.remainingCount;
        weekCompleted += snap.completedCount;
      }
    }
    final weekRatio = weekTotal > 0 ? (weekCompleted / weekTotal).clamp(0.0, 1.0) : 0.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.sm,
        ),
        child: Column(
          children: [
            // K27 — Weekly Progress Bar
            Padding(
              padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
              child: Row(
                children: [
                  Text(
                    'پیشرفت هفته: ${toPersianDigits(weekCompleted)} از ${toPersianDigits(weekTotal)}',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: weekRatio,
                        minHeight: 4,
                        backgroundColor: colors.border.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          weekCompleted == weekTotal && weekTotal > 0
                              ? colors.success
                              : colors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Week Header Row (7 mini headers)
            Row(
              children: List.generate(7, (index) {
                final day = weekDays[index];
                final isToday = _isSameDay(day, now);
                final isSelected = _isSameDay(day, selectedDate);
                final isFriday = index == 6;

                final jalaliDay = Jalali.fromDateTime(day);
                final dayNumStr = toPersianDigits(jalaliDay.day.toString());

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onSelectDate(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : (isToday ? colors.primaryContainer.withValues(alpha: 0.3) : colors.surface),
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        border: Border.all(
                          color: isToday && !isSelected
                              ? colors.primary
                              : (isSelected ? colors.primary : colors.border),
                          width: (isToday || isSelected) ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            weekDayShortFa[index],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? colors.onPrimary
                                  : (isFriday ? colors.error : colors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayNumStr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? colors.onPrimary : colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // 7 Mini Timeline Columns in a Single Scroll View
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  border: Border.all(color: colors.border),
                ),
                child: SingleChildScrollView(
                  child: SizedBox(
                    height: 1440 * miniPxPerMin,
                    child: Row(
                      children: List.generate(7, (index) {
                        final day = weekDays[index];
                        final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                        final snapshot = rangeSnapshots[dateKey];
                        final isToday = _isSameDay(day, now);
                        final isSelected = _isSameDay(day, selectedDate);

                        final timedItems = (snapshot?.items ?? []).where((i) => i.isTimed).toList();

                        return Expanded(
                          child: DragTarget<AgendaItem>(
                            onWillAcceptWithDetails: (details) => DateKey.of(day) != details.data.dateStr,
                            onAcceptWithDetails: (details) {
                              onMoveItemToDate?.call(details.data, day);
                            },
                            builder: (ctx, candidateData, rejectedData) {
                              final isHovered = candidateData.isNotEmpty;
                              return GestureDetector(
                                onTap: () => onSelectDate(day),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isHovered
                                        ? colors.primary.withValues(alpha: 0.22)
                                        : (isSelected ? colors.primaryContainer.withValues(alpha: 0.15) : null),
                                    border: Border(
                                      left: BorderSide(
                                        color: isHovered ? colors.primary : colors.divider,
                                        width: isHovered ? 1.5 : 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      // Grid Hour Lines (every 3 hours)
                                      for (int h = 3; h < 24; h += 3)
                                        Positioned(
                                          top: (h * 60) * miniPxPerMin,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 0.5,
                                            color: colors.divider.withValues(alpha: 0.3),
                                          ),
                                        ),

                                      // Mini Item Blocks (Compact tier with LongPressDraggable)
                                      for (final item in timedItems) _buildMiniItemBlock(context, item),

                                      // Live Now Line (drawn ONLY on today's column)
                                      if (isToday)
                                        Positioned(
                                          top: nowTop,
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 1.5,
                                            color: colors.accent,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniItemBlock(BuildContext context, AgendaItem item) {
    final colors = context.colors;
    final startM = TimeOfDayMinutes.tryParse(item.timeOfDay) ?? 0;
    final durM = item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes;

    final top = startM * miniPxPerMin;
    final height = (durM * miniPxPerMin).clamp(4.0, 1440 * miniPxPerMin);

    final color = domainColor(context, item.domain);

    final block = Container(
      decoration: BoxDecoration(
        color: item.isCompleted ? colors.disabled : color,
        borderRadius: BorderRadius.circular(3.0),
      ),
    );

    return Positioned(
      top: top,
      left: 1.5,
      right: 1.5,
      height: height,
      child: LongPressDraggable<AgendaItem>(
        data: item,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(RitmoRadius.badge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              item.title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.onPrimary),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: block),
        child: block,
      ),
    );
  }
}
