import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/worship/logic/worship_calendar_logic.dart';
import 'package:ritmo/features/worship/logic/worship_occasions_data.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_day_detail_panel.dart';

class WorshipSolarCalendar extends StatefulWidget {
  const WorshipSolarCalendar({
    super.key,
    this.initialJalali,
    this.hijriOffset = 0,
    this.qamariNightText,
    this.onDaySelected,
    this.onOpenTasbih,
    this.onChanged,
  });

  final Jalali? initialJalali;
  final int hijriOffset;
  final String? qamariNightText;
  final ValueChanged<WorshipCalendarDay>? onDaySelected;
  final VoidCallback? onOpenTasbih;
  final VoidCallback? onChanged;

  @override
  State<WorshipSolarCalendar> createState() => _WorshipSolarCalendarState();
}

class _WorshipSolarCalendarState extends State<WorshipSolarCalendar> {
  late int _selectedYear;
  late int _selectedMonth;

  late WorshipCalendarMonthData _monthData;
  late WorshipCalendarDay _selectedDay;
  bool _isCollapsed = true;

  @override
  void initState() {
    super.initState();
    final nowJ = widget.initialJalali ?? Jalali.now();
    _selectedYear = nowJ.year;
    _selectedMonth = nowJ.month;

    _loadMonthData();

    // Default selected day is today or 1st day of month
    _selectedDay = _monthData.days.firstWhere(
      (d) => d.isToday && d.isCurrentMonth,
      orElse: () => _monthData.days.firstWhere((d) => d.isCurrentMonth),
    );
  }

  @override
  void didUpdateWidget(WorshipSolarCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.hijriOffset) != (widget.hijriOffset)) {
      setState(() {
        _loadMonthData();
        _selectedDay = _monthData.days.firstWhere(
          (d) =>
              d.jalali.year == _selectedDay.jalali.year &&
              d.jalali.month == _selectedDay.jalali.month &&
              d.jalali.day == _selectedDay.jalali.day,
          orElse: () => _monthData.days.firstWhere(
            (d) => d.isToday && d.isCurrentMonth,
            orElse: () => _monthData.days.firstWhere((d) => d.isCurrentMonth),
          ),
        );
      });
    }
  }

  void _loadMonthData() {
    _monthData = WorshipCalendarLogic.generateMonthData(
      _selectedYear,
      _selectedMonth,
      hijriOffset: widget.hijriOffset,
    );
  }

  void _goToPrevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedYear--;
        _selectedMonth = 12;
      } else {
        _selectedMonth--;
      }
      _loadMonthData();
      _selectFirstValidDay();
    });
  }

  void _goToNextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedYear++;
        _selectedMonth = 1;
      } else {
        _selectedMonth++;
      }
      _loadMonthData();
      _selectFirstValidDay();
    });
  }

  void _goToToday() {
    unawaited(HapticFeedback.selectionClick());
    final nowJ = Jalali.now();
    setState(() {
      _selectedYear = nowJ.year;
      _selectedMonth = nowJ.month;
      _loadMonthData();
      _selectedDay = _monthData.days.firstWhere(
        (d) => d.isToday && d.isCurrentMonth,
        orElse: () => _monthData.days.firstWhere((d) => d.isCurrentMonth),
      );
      widget.onDaySelected?.call(_selectedDay);
    });
  }

  void _selectFirstValidDay() {
    _selectedDay = _monthData.days.firstWhere(
      (d) => d.isToday && d.isCurrentMonth,
      orElse: () => _monthData.days.firstWhere((d) => d.isCurrentMonth),
    );
    widget.onDaySelected?.call(_selectedDay);
  }

  void _onSelectDay(WorshipCalendarDay day) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selectedDay = day;
    });
    widget.onDaySelected?.call(day);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isSelectedToday = _selectedDay.isToday && _selectedDay.isCurrentMonth;

    // Calculate displayed days: Full month or selected week row
    final selectedIdx = _monthData.days.indexWhere(
      (d) =>
          d.jalali.year == _selectedDay.jalali.year &&
          d.jalali.month == _selectedDay.jalali.month &&
          d.jalali.day == _selectedDay.jalali.day,
    );
    final validIdx = selectedIdx >= 0 ? selectedIdx : 0;
    final weekStart = (validIdx ~/ 7) * 7;
    final displayedDays = _isCollapsed
        ? _monthData.days.sublist(weekStart, weekStart + 7)
        : _monthData.days;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Main Premium Solar Calendar Surface Card
        RitmoCard.neumorphic(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER: Month Title & Subtitle + Apple-Style Capsule Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title + Subtitle Range + Today Shortcut
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${_monthData.monthName} ${toPersianDigits(_monthData.year.toString())}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (!isSelectedToday) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _goToToday,
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: isDark ? 0.2 : 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colors.primary.withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.arrow_counterclockwise,
                                        size: 10,
                                        color: colors.primary,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'امروز',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_monthData.gregorianRangeText}  •  ${_monthData.hijriRangeText}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Tactile Capsule Navigation Group [ > (ماه بعد) | تغییر نما | < (ماه قبل) ]
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.border.withValues(alpha: isDark ? 0.3 : 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Next Month Button
                        _buildCapsuleNavButton(
                          icon: CupertinoIcons.chevron_forward,
                          onTap: _goToPrevMonth,
                          colors: colors,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 2),

                        // Collapse/Expand View Toggle
                        _buildCapsuleNavButton(
                          icon: _isCollapsed ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_up,
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() => _isCollapsed = !_isCollapsed);
                          },
                          colors: colors,
                          isDark: isDark,
                          highlightColor: colors.primary,
                        ),
                        const SizedBox(width: 2),

                        // Prev Month Button
                        _buildCapsuleNavButton(
                          icon: CupertinoIcons.chevron_back,
                          onTap: _goToNextMonth,
                          colors: colors,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. WEEKDAY BAR (Saturday to Friday) with full names & micro-typography
              RitmoCard.neumorphicSunken(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeekdayHeader('شنبه', colors, isFriday: false),
                    _buildWeekdayHeader('یکشنبه', colors, isFriday: false),
                    _buildWeekdayHeader('دوشنبه', colors, isFriday: false),
                    _buildWeekdayHeader('سه‌شنبه', colors, isFriday: false),
                    _buildWeekdayHeader('چهارشنبه', colors, isFriday: false),
                    _buildWeekdayHeader('پنج‌شنبه', colors, isFriday: false),
                    _buildWeekdayHeader('جمعه', colors, isFriday: true),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 3. MONTH GRID (7 Columns) with Neumorphic Squircle Selection
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: LayoutBuilder(
                  key: ValueKey('${_monthData.year}-${_monthData.month}-collapsed:$_isCollapsed-week:$weekStart'),
                  builder: (context, constraints) {
                    const columns = 7;
                    const spacing = 5.0;
                    final cellWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                    final scale = context.textScale;
                    final cellHeight = (cellWidth * 1.05).clamp(42.0 * scale, 58.0 * scale);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedDays.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        mainAxisExtent: cellHeight,
                      ),
                      itemBuilder: (context, index) {
                        final day = displayedDays[index];
                        return _buildDayCell(context, colors, day, isDark);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Reactive Detail Panel for Selected Day
        WorshipDayDetailPanel(
          selectedDay: _selectedDay,
          qamariNightText: widget.qamariNightText,
          onOpenTasbih: widget.onOpenTasbih,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }

  Widget _buildCapsuleNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required RitmoColors colors,
    required bool isDark,
    Color? highlightColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: isDark ? 0.6 : 0.85),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 15,
            color: highlightColor ?? colors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader(String label, RitmoColors colors, {required bool isFriday}) {
    return Expanded(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isFriday
                    ? colors.error
                    : colors.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, RitmoColors colors, WorshipCalendarDay day, bool isDark) {
    final isSelected = day.jalali.year == _selectedDay.jalali.year &&
        day.jalali.month == _selectedDay.jalali.month &&
        day.jalali.day == _selectedDay.jalali.day;

    final isToday = day.isToday;
    final isCurrentMonth = day.isCurrentMonth;
    final isHoliday = day.isHoliday;

    // Card background, border, shadow, text color
    BoxDecoration decoration;
    Color mainTextColor;

    if (isSelected) {
      final baseAccent = isHoliday ? colors.error : colors.primary;
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(baseAccent, Colors.white, isDark ? 0.12 : 0.25)!,
            baseAccent,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.45),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: baseAccent.withValues(alpha: isDark ? 0.40 : 0.32),
            blurRadius: 10,
            offset: const Offset(0, 3.5),
          ),
        ],
      );
      mainTextColor = Colors.white;
    } else if (isToday && isCurrentMonth) {
      // Elegant Today indicator when unselected
      decoration = BoxDecoration(
        color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.65),
          width: 1.2,
        ),
      );
      mainTextColor = colors.primary;
    } else {
      decoration = const BoxDecoration(color: Colors.transparent);

      if (!isCurrentMonth) {
        mainTextColor = isHoliday
            ? colors.error.withValues(alpha: 0.25)
            : colors.textSecondary.withValues(alpha: 0.25);
      } else if (isHoliday) {
        mainTextColor = colors.error;
      } else {
        mainTextColor = colors.textPrimary;
      }
    }

    return GestureDetector(
      onTap: () => _onSelectDay(day),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: decoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Solar Day Number
            Text(
              toPersianDigits(day.jalali.day.toString()),
              style: TextStyle(
                fontSize: 17.5,
                fontWeight: (isToday || isSelected)
                    ? FontWeight.w900
                    : (isHoliday ? FontWeight.w800 : FontWeight.w700),
                color: mainTextColor,
                height: 1.1,
              ),
            ),

            const SizedBox(height: 3),

            // Occasion Micro-Jewel Indicators
            if (isCurrentMonth && day.hasOccasions)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: day.occasions.take(3).map((occ) {
                  Color dotColor;
                  if (isSelected) {
                    dotColor = Colors.white.withValues(alpha: 0.95);
                  } else {
                    switch (occ.category) {
                      case WorshipOccasionCategory.celebration:
                        dotColor = colors.success;
                        break;
                      case WorshipOccasionCategory.mourning:
                        dotColor = colors.error;
                        break;
                      case WorshipOccasionCategory.fasting:
                      case WorshipOccasionCategory.worshipDeed:
                        dotColor = colors.accent;
                        break;
                      case WorshipOccasionCategory.national:
                        dotColor = colors.primary;
                        break;
                    }
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      boxShadow: isSelected ? null : [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.4),
                          blurRadius: 2,
                          offset: const Offset(0, 0.5),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else
              const SizedBox(height: 4.5),
          ],
        ),
      ),
    );
  }
}
