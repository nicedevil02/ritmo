import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/data/occasions_calendar_source.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:shamsi_date/shamsi_date.dart';

class JourneyMonthView extends StatefulWidget {
  const JourneyMonthView({
    super.key,
    required this.selectedDate,
    required this.rangeSnapshots,
    required this.onSelectDate,
    this.onLongPressDayCell,
    this.onMoveItemToDate,
  });

  final DateTime selectedDate;
  final Map<String, DayAgendaSnapshot> rangeSnapshots;
  final ValueChanged<DateTime> onSelectDate;
  final void Function(DateTime date)? onLongPressDayCell;
  final void Function(AgendaItem item, DateTime targetDate)? onMoveItemToDate;

  @override
  State<JourneyMonthView> createState() => _JourneyMonthViewState();
}

class _JourneyMonthViewState extends State<JourneyMonthView> {
  // Occasions cache per month to prevent repeated Hijri computations
  int? _cachedYear;
  int? _cachedMonth;
  final Map<String, List<CalendarOccasion>> _occasionsCache = {};

  void _ensureOccasionsCache(List<DateTime> days, Jalali jalaliSelected) {
    if (_cachedYear == jalaliSelected.year && _cachedMonth == jalaliSelected.month) {
      return;
    }
    _cachedYear = jalaliSelected.year;
    _cachedMonth = jalaliSelected.month;
    _occasionsCache.clear();
    for (final day in days) {
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      _occasionsCache[key] = OccasionsCalendarSource.occasionsForDate(day);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();

    final jalaliSelected = Jalali.fromDateTime(widget.selectedDate);
    final jalaliFirst = Jalali(jalaliSelected.year, jalaliSelected.month, 1);
    final monthLength = jalaliFirst.monthLength;

    final firstOfMonthDate = jalaliFirst.toDateTime();
    final lastOfMonthDate = Jalali(jalaliSelected.year, jalaliSelected.month, monthLength).toDateTime();

    final firstGridDay = ShamsiWeek.saturdayOf(firstOfMonthDate);
    final totalDays = lastOfMonthDate.difference(firstGridDay).inDays + 1;
    final gridDayCount = (totalDays / 7).ceil() * 7;

    final gridDays = List.generate(gridDayCount, (i) => firstGridDay.add(Duration(days: i)));
    _ensureOccasionsCache(gridDays, jalaliSelected);

    // RTL Weekday headers order
    const weekHeadersRtl = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: RitmoSpacing.sm,
        ),
        child: Column(
          children: [
            // Weekday Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (idx) {
                final isFridayHeader = idx == 6;
                return Expanded(
                  child: Text(
                    weekHeadersRtl[idx],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: isFridayHeader ? colors.error : colors.textSecondary,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            // Month Days Grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 7;
                  const spacing = 5.0;
                  final rows = (gridDays.length / 7).ceil();
                  final availableHeight = constraints.maxHeight - (rows - 1) * spacing;
                  final cellHeight = rows > 0 ? (availableHeight / rows).clamp(38.0, 75.0) : 48.0;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: cellHeight,
                    ),
                    itemCount: gridDays.length,
                    itemBuilder: (context, index) {
                  final day = gridDays[index];
                  final jDay = Jalali.fromDateTime(day);
                  final isCurrentMonth = jDay.month == jalaliSelected.month;
                  final isToday = _isSameDay(day, now);
                  final isSelected = _isSameDay(day, widget.selectedDate);
                  final isFriday = (day.weekday == DateTime.friday);

                  final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                  final snapshot = widget.rangeSnapshots[key];
                  final items = snapshot?.items ?? [];
                  final distinctDomains = items.map((i) => i.domain).toSet().toList();
                  final displayDomains = distinctDomains.take(3).toList();
                  final extraDomainsCount = distinctDomains.length - displayDomains.length;
                  final hasConflicts = snapshot != null && snapshot.conflicts.isNotEmpty;

                  final occasions = _occasionsCache[key] ?? [];
                  final isHoliday = occasions.any((o) => o.isHoliday);

                  // Density tinting
                  final tintAlpha = isCurrentMonth
                      ? (items.length >= 7 ? 0.20 : (items.length >= 4 ? 0.10 : (items.isNotEmpty ? 0.04 : 0.0)))
                      : 0.0;

                  final cellBgColor = isSelected
                      ? colors.primary
                      : (tintAlpha > 0
                          ? colors.primary.withValues(alpha: tintAlpha)
                          : (isCurrentMonth ? colors.surfaceElevated : colors.surfaceSubtle));

                  final dayNumStr = toPersianDigits(jDay.day.toString());

                  final semanticsLabel = '${jDay.formatter.wN} $dayNumStr ${jDay.formatter.mN}، ${toPersianDigits(items.length)} برنامه${isHoliday || isFriday ? '، تعطیل' : ''}';

                  return DragTarget<AgendaItem>(
                    onWillAcceptWithDetails: (details) => DateKey.of(day) != details.data.dateStr,
                    onAcceptWithDetails: (details) {
                      widget.onMoveItemToDate?.call(details.data, day);
                    },
                    builder: (ctx, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      final effectiveBg = isHovered
                          ? colors.primary.withValues(alpha: 0.35)
                          : cellBgColor;

                      return Semantics(
                        label: semanticsLabel,
                        button: true,
                        selected: isSelected,
                        child: InkWell(
                          onTap: () => widget.onSelectDate(day),
                          onLongPress: () => widget.onLongPressDayCell?.call(day),
                          borderRadius: BorderRadius.circular(RitmoRadius.badge),
                          child: Container(
                            decoration: BoxDecoration(
                              color: effectiveBg,
                              borderRadius: BorderRadius.circular(RitmoRadius.badge),
                              border: isHovered
                                  ? Border.all(color: colors.primary, width: 2.0)
                                  : (isToday && !isSelected
                                      ? Border.all(color: colors.primary, width: 1.5)
                                      : Border.all(
                                          color: isSelected ? colors.primary : colors.borderSubtle,
                                          width: 1.0,
                                        )),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Day Number + Holiday Dot Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (isFriday || isHoliday)
                                      Container(
                                        width: 4,
                                        height: 4,
                                        margin: const EdgeInsets.only(right: 2, top: 2),
                                        decoration: BoxDecoration(
                                          color: isSelected ? colors.onPrimary : colors.error,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 2, top: 1),
                                      child: Text(
                                        dayNumStr,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isToday || isSelected || isFriday || isHoliday
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? colors.onPrimary
                                              : (isCurrentMonth
                                                  ? (isFriday || isHoliday ? colors.error : colors.textPrimary)
                                                  : colors.disabled),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Today Indicator dot (when not selected)
                                if (isToday && !isSelected)
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),

                                // Domain Dots (up to 3) + Extra indicator
                                if (displayDomains.isNotEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ...displayDomains.map((d) {
                                        return Container(
                                          width: 4,
                                          height: 4,
                                          margin: const EdgeInsets.symmetric(horizontal: 0.8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? colors.onPrimary : domainColor(context, d),
                                            shape: BoxShape.circle,
                                          ),
                                        );
                                      }),
                                      if (extraDomainsCount > 0)
                                        Text(
                                          '+',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? colors.onPrimary : colors.textTertiary,
                                            height: 0.8,
                                          ),
                                        ),
                                    ],
                                  ),

                                // Conflict Underline
                                if (hasConflicts)
                                  Container(
                                    height: 2,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected ? colors.onPrimary : colors.warning,
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  )
                                else
                                  const SizedBox(height: 2),
                              ],
                            ),
                          ),
                        ),
                    },
                  );
                },
              );
            },
          ),
        ),

            // Workload Legend Row
            Padding(
              padding: const EdgeInsets.only(top: RitmoSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendDot(colors.primary.withValues(alpha: 0.04), 'کم', colors),
                  const SizedBox(width: RitmoSpacing.md),
                  _legendDot(colors.primary.withValues(alpha: 0.10), 'متوسط', colors),
                  const SizedBox(width: RitmoSpacing.md),
                  _legendDot(colors.primary.withValues(alpha: 0.20), 'فشرده', colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label, dynamic colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: colors.borderSubtle, width: 0.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
