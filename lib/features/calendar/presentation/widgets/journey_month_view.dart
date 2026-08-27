import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/data/occasions_calendar_source.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Redesigned Month View in Apple HIG & Neumorphic Design Language:
/// Features tactile day tiles with soft dual-shadows, Apple glow hero selected day,
/// glowing jewel domain beads, and refined typography.
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
    if (_cachedYear == jalaliSelected.year &&
        _cachedMonth == jalaliSelected.month) {
      return;
    }
    _cachedYear = jalaliSelected.year;
    _cachedMonth = jalaliSelected.month;
    _occasionsCache.clear();
    for (final day in days) {
      final key = DateKey.of(day);
      _occasionsCache[key] = OccasionsCalendarSource.occasionsForDate(day);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final jalaliSelected = Jalali.fromDateTime(widget.selectedDate);
    final jalaliFirst = Jalali(jalaliSelected.year, jalaliSelected.month, 1);
    final monthLength = jalaliFirst.monthLength;

    final firstOfMonthDate = jalaliFirst.toDateTime();
    final lastOfMonthDate = Jalali(
      jalaliSelected.year,
      jalaliSelected.month,
      monthLength,
    ).toDateTime();

    final firstGridDay = ShamsiWeek.saturdayOf(firstOfMonthDate);
    final totalDays = lastOfMonthDate.difference(firstGridDay).inDays + 1;
    final gridDayCount = (totalDays / 7).ceil() * 7;

    final gridDays = List.generate(
      gridDayCount,
      (i) => firstGridDay.add(Duration(days: i)),
    );
    _ensureOccasionsCache(gridDays, jalaliSelected);

    // RTL Weekday headers order: شنبه تا جمعه
    const weekHeadersRtl = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.xs,
        ),
        child: Column(
          children: [
            // ─── Apple HIG / Neumorphic Weekday Header Pill ───
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141822).withValues(alpha: 0.7)
                    : const Color(0xFFE5EAF1).withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.85),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0xFFCAD2DC).withValues(alpha: 0.4),
                    offset: const Offset(0, 1.5),
                    blurRadius: 2.5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (idx) {
                  final isFridayHeader = idx == 6;
                  return Expanded(
                    child: Center(
                      child: Text(
                        weekHeadersRtl[idx],
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: isFridayHeader ? FontWeight.w800 : FontWeight.w700,
                          color: isFridayHeader
                              ? const Color(0xFFFF3B30)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ─── Month Days Grid (Apple Tactile Cells) ───
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 7;
                  const spacing = 6.0;
                  final rows = (gridDays.length / 7).ceil();
                  final availableHeight =
                      constraints.maxHeight - (rows - 1) * spacing;
                  final cellHeight = rows > 0
                      ? (availableHeight / rows).clamp(42.0, 80.0)
                      : 50.0;

                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
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

                      final key = DateKey.of(day);
                      final snapshot = widget.rangeSnapshots[key];
                      final items = snapshot?.items ?? [];
                      final distinctDomains = items
                          .map((i) => i.domain)
                          .toSet()
                          .toList();
                      final displayDomains = distinctDomains.take(3).toList();
                      final extraDomainsCount =
                          distinctDomains.length - displayDomains.length;
                      final hasConflicts =
                          snapshot != null && snapshot.conflicts.isNotEmpty;

                      final occasions = _occasionsCache[key] ?? [];
                      final isHoliday = occasions.any((o) => o.isHoliday);

                      // Density tinting for heavy workload days
                      final densityLevel = items.length >= 7
                          ? 3
                          : (items.length >= 4 ? 2 : (items.isNotEmpty ? 1 : 0));

                      final dayNumStr = toPersianDigits(jDay.day.toString());

                      final semanticsLabel =
                          '${ShamsiWeek.nameOf(jDay.weekDay)} $dayNumStr ${jDay.formatter.mN}، ${toPersianDigits(items.length)} برنامه${isHoliday || isFriday ? '، تعطیل' : ''}';

                      return DragTarget<AgendaItem>(
                        onWillAcceptWithDetails: (details) =>
                            DateKey.of(day) != details.data.dateStr,
                        onAcceptWithDetails: (details) {
                          widget.onMoveItemToDate?.call(details.data, day);
                        },
                        builder: (ctx, candidateData, rejectedData) {
                          final isHovered = candidateData.isNotEmpty;

                          return Semantics(
                            label: semanticsLabel,
                            button: true,
                            selected: isSelected,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.onSelectDate(day);
                              },
                              onLongPress: () =>
                                  widget.onLongPressDayCell?.call(day),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                decoration: _buildCellDecoration(
                                  colors: colors,
                                  isDark: isDark,
                                  isSelected: isSelected,
                                  isToday: isToday,
                                  isCurrentMonth: isCurrentMonth,
                                  isHovered: isHovered,
                                  densityLevel: densityLevel,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3.5,
                                  vertical: 3.5,
                                ),
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Top Row: Day Number + Holiday / Friday Ruby Jewel Dot
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (isFriday || isHoliday)
                                          Container(
                                            width: 4.5,
                                            height: 4.5,
                                            margin: const EdgeInsets.only(
                                              right: 2,
                                              top: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFFFF3B30),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isSelected
                                                          ? Colors.white
                                                          : const Color(0xFFFF3B30))
                                                      .withValues(alpha: 0.55),
                                                  blurRadius: 2.5,
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          const SizedBox(width: 4.5),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 2,
                                            top: 0.5,
                                          ),
                                          child: Text(
                                            dayNumStr,
                                            style: TextStyle(
                                              fontSize: isSelected ? 12.5 : 12.0,
                                              fontWeight: isSelected || isToday
                                                  ? FontWeight.w900
                                                  : (isCurrentMonth
                                                      ? FontWeight.w700
                                                      : FontWeight.w500),
                                              color: isSelected
                                                  ? Colors.white
                                                  : (isCurrentMonth
                                                      ? (isFriday || isHoliday
                                                          ? const Color(0xFFFF3B30)
                                                          : colors.textPrimary)
                                                      : colors.textTertiary.withValues(alpha: 0.45)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Center / Middle Indicator: Today Beacon Dot (when not selected)
                                    if (isToday && !isSelected)
                                      Container(
                                        width: 4.5,
                                        height: 4.5,
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.primary.withValues(alpha: 0.6),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                      )
                                    else if (densityLevel > 0 && !isSelected)
                                      const SizedBox(height: 1)
                                    else
                                      const SizedBox.shrink(),

                                    // Bottom Row: Glowing Jewel Domain Beads + Extra indicator
                                    if (displayDomains.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 1),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            ...displayDomains.map((d) {
                                              final dColor = domainColor(context, d);
                                              return Container(
                                                width: 4.5,
                                                height: 4.5,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 1.0,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : dColor,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (isSelected
                                                              ? Colors.white
                                                              : dColor)
                                                          .withValues(alpha: 0.55),
                                                      blurRadius: 2.0,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            if (extraDomainsCount > 0)
                                              Text(
                                                '+',
                                                style: TextStyle(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : colors.textTertiary,
                                                  height: 0.8,
                                                ),
                                              ),
                                          ],
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 4),

                                    // Bottom Glow Bar: Conflict Underline (Apple Amber)
                                    if (hasConflicts)
                                      Container(
                                        height: 2.5,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFFFF9500),
                                          borderRadius: BorderRadius.circular(2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isSelected
                                                      ? Colors.white
                                                      : const Color(0xFFFF9500))
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 1),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ─── Neumorphic Workload Legend Row ───
            Container(
              margin: const EdgeInsets.only(top: RitmoSpacing.xs),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF131720).withValues(alpha: 0.6)
                    : const Color(0xFFE5EAF1).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.white.withValues(alpha: 0.8),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(
                    colors.primary.withValues(alpha: 0.08),
                    'کم',
                    colors,
                    isDark,
                  ),
                  const SizedBox(width: RitmoSpacing.lg),
                  _legendDot(
                    colors.primary.withValues(alpha: 0.16),
                    'متوسط',
                    colors,
                    isDark,
                  ),
                  const SizedBox(width: RitmoSpacing.lg),
                  _legendDot(
                    colors.primary.withValues(alpha: 0.28),
                    'فشرده',
                    colors,
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Neumorphic & Apple HIG Cell Decoration Algorithm
  BoxDecoration _buildCellDecoration({
    required dynamic colors,
    required bool isDark,
    required bool isSelected,
    required bool isToday,
    required bool isCurrentMonth,
    required bool isHovered,
    required int densityLevel,
  }) {
    final borderRadius = BorderRadius.circular(14);

    // 1. Drag Hover State
    if (isHovered) {
      return BoxDecoration(
        color: colors.primary.withValues(alpha: 0.35),
        borderRadius: borderRadius,
        border: Border.all(color: colors.primary, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }

    // 2. Apple Glow Selected Day State
    if (isSelected) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary as Color,
            (colors.primary as Color).withValues(alpha: 0.88),
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (colors.primary as Color).withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 0.5,
          ),
          const BoxShadow(
            color: Colors.white24,
            offset: Offset(-1, -1),
            blurRadius: 2,
          ),
        ],
      );
    }

    // 3. Apple Today Indicator State (when not selected)
    if (isToday && isCurrentMonth) {
      return BoxDecoration(
        color: (colors.primary as Color).withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: borderRadius,
        border: Border.all(
          color: (colors.primary as Color).withValues(alpha: 0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (colors.primary as Color).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          if (!isDark)
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-1, -1),
              blurRadius: 2,
            ),
        ],
      );
    }

    // 4. Regular Day in Current Month (Tactile Neumorphic Tile)
    if (isCurrentMonth) {
      final baseColor = isDark ? const Color(0xFF1B202B) : const Color(0xFFF7F9FC);
      final tintAlpha = densityLevel == 3
          ? 0.22
          : (densityLevel == 2 ? 0.12 : (densityLevel == 1 ? 0.05 : 0.0));

      return BoxDecoration(
        color: tintAlpha > 0
            ? Color.alphaBlend(
                (colors.primary as Color).withValues(alpha: tintAlpha),
                baseColor,
              )
            : baseColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.9),
          width: 0.8,
        ),
        boxShadow: [
          if (isDark) ...[
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.035),
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(1.5, 2.5),
              blurRadius: 4,
            ),
          ] else ...[
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-1.5, -1.5),
              blurRadius: 2.5,
            ),
            BoxShadow(
              color: const Color(0xFFD2DAE4).withValues(alpha: 0.7),
              offset: const Offset(1.5, 2.5),
              blurRadius: 4,
            ),
          ],
        ],
      );
    }

    // 5. Overflow Day (Previous or Next Month: Recessed Ghost)
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.015)
          : const Color(0xFFEDF1F6).withValues(alpha: 0.5),
      borderRadius: borderRadius,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : const Color(0xFFE2E7ED).withValues(alpha: 0.5),
        width: 0.5,
      ),
    );
  }

  Widget _legendDot(Color color, String label, dynamic colors, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFCAD2DC),
              width: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 4.5),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
