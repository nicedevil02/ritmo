import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
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
  });

  final DateTime selectedDate;
  final Map<String, DayAgendaSnapshot> rangeSnapshots;
  final ValueChanged<DateTime> onSelectDate;
  final void Function(DateTime date)? onLongPressDayCell;

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
            const SizedBox(height: RitmoSpacing.xs),

            // Month Grid Cells
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 3,
                  crossAxisSpacing: 3,
                  childAspectRatio: 0.85,
                ),
                itemCount: gridDays.length,
                itemBuilder: (context, index) {
                  final day = gridDays[index];
                  final jDay = Jalali.fromDateTime(day);
                  final isCurrentMonth = jDay.year == jalaliSelected.year && jDay.month == jalaliSelected.month;
                  final isSelected = _isSameDay(day, widget.selectedDate);
                  final isToday = _isSameDay(day, now);
                  final isFriday = jDay.weekDay == 7;

                  final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                  final snapshot = widget.rangeSnapshots[dateKey];
                  final items = snapshot?.items ?? [];
                  final overload = snapshot?.overloadScore ?? 0.0;
                  final hasConflicts = (snapshot?.conflicts.length ?? 0) > 0;

                  // Unique domain colors (up to 3 + more indicator)
                  final presentDomains = <AgendaDomain>{};
                  for (final item in items) {
                    presentDomains.add(item.domain);
                  }
                  final displayDomains = presentDomains.take(3).toList();
                  final extraDomainsCount = presentDomains.length - displayDomains.length;

                  // Occasions-based holiday tinting from cache
                  final occasions = _occasionsCache[dateKey] ?? const [];
                  final isHoliday = occasions.any((o) => o.isHoliday);

                  // 3-step Workload Heatmap Tint
                  double tintAlpha = 0.0;
                  if (isCurrentMonth && !isSelected) {
                    if (overload > 0.6) {
                      tintAlpha = 0.20; // heavy
                    } else if (overload > 0.2) {
                      tintAlpha = 0.10; // normal
                    } else if (items.isNotEmpty) {
                      tintAlpha = 0.04; // light
                    }
                  }

                  final cellBgColor = isSelected
                      ? colors.primary
                      : (tintAlpha > 0
                          ? colors.primary.withValues(alpha: tintAlpha)
                          : (isCurrentMonth ? colors.surfaceElevated : colors.surfaceSubtle));

                  final dayNumStr = toPersianDigits(jDay.day.toString());

                  final semanticsLabel = '${jDay.formatter.wN} $dayNumStr ${jDay.formatter.mN}، ${toPersianDigits(items.length)} برنامه${isHoliday || isFriday ? '، تعطیل' : ''}';

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
                          color: cellBgColor,
                          borderRadius: BorderRadius.circular(RitmoRadius.badge),
                          border: isToday && !isSelected
                              ? Border.all(color: colors.primary, width: 1.5)
                              : Border.all(
                                  color: isSelected ? colors.primary : colors.borderSubtle,
                                  width: 1.0,
                                ),
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
