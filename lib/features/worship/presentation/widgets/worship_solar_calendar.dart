import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
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
    });
    if (widget.onDaySelected != null) {
      widget.onDaySelected!(_selectedDay);
    }
  }

  void _selectFirstValidDay() {
    _selectedDay = _monthData.days.firstWhere(
      (d) => d.isToday && d.isCurrentMonth,
      orElse: () => _monthData.days.firstWhere((d) => d.isCurrentMonth),
    );
    if (widget.onDaySelected != null) {
      widget.onDaySelected!(_selectedDay);
    }
  }

  void _onSelectDay(WorshipCalendarDay day) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selectedDay = day;
    });
    if (widget.onDaySelected != null) {
      widget.onDaySelected!(day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

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

    final nowJ = Jalali.now();
    final isSelectedToday = _selectedDay.isToday &&
        _selectedDay.isCurrentMonth &&
        _selectedYear == nowJ.year &&
        _selectedMonth == nowJ.month;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Main Premium Solar Calendar Surface Card
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: isDark ? colors.surface : colors.surface,
            border: Border.all(
              color: isDark ? colors.border : colors.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : colors.shadow.withValues(alpha: 0.08),
                blurRadius: 35,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER: Month Title & Subtitle + Modern Navigation Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title + Subtitle Range + Today Shortcut (Tap to Toggle Collapse)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        setState(() => _isCollapsed = !_isCollapsed);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_monthData.monthName} ${toPersianDigits(_monthData.year.toString())}',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: colors.textPrimary,
                                  ),
                              ),
                              const SizedBox(width: 8),
                              // Today Button Shortcut (Active whenever selected day is not today)
                              if (!isSelectedToday)
                                InkWell(
                                  onTap: _goToToday,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colors.primary.withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.arrow_counterclockwise,
                                          size: 11,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'امروز',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: colors.primary,
                                            ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_monthData.gregorianRangeText}  •  ${_monthData.hijriRangeText}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary.withValues(alpha: 0.85),
                              ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 36x36 Modern Navigation Badges (Collapse Toggle + Prev / Next Month)
                  Row(
                    children: [
                      _buildNavBadge(
                        icon: _isCollapsed ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_up,
                        tooltip: _isCollapsed ? 'نمای کامل ماه' : 'نمای هفته',
                        onTap: () => setState(() => _isCollapsed = !_isCollapsed),
                        isDark: isDark,
                        colors: colors,
                      ),
                      const SizedBox(width: 6),
                      _buildNavBadge(
                        icon: CupertinoIcons.chevron_forward,
                        tooltip: 'ماه بعد',
                        onTap: _goToNextMonth,
                        isDark: isDark,
                        colors: colors,
                      ),
                      const SizedBox(width: 6),
                      _buildNavBadge(
                        icon: CupertinoIcons.chevron_back,
                        tooltip: 'ماه قبل',
                        onTap: _goToPrevMonth,
                        isDark: isDark,
                        colors: colors,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. WEEKDAY BAR (Saturday to Friday) with full names
              Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: colors.surfaceSunken,
                  borderRadius: BorderRadius.circular(14),
                ),
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

              const SizedBox(height: 8),

              // 3. MONTH GRID (7 Columns) with Modern Squircle Selection
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: LayoutBuilder(
                  key: ValueKey('${_monthData.year}-${_monthData.month}-collapsed:$_isCollapsed-week:$weekStart'),
                  builder: (context, constraints) {
                    const columns = 7;
                    const spacing = 5.0;
                    final cellWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                    final scale = context.textScale;
                    final cellHeight = (cellWidth * 1.02).clamp(38.0 * scale, 58.0 * scale);

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

  Widget _buildNavBadge({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    required RitmoColors colors,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.border,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 17,
              color: colors.textPrimary,
            ),
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
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isFriday
                    ? colors.error
                    : colors.textSecondary.withValues(alpha: 0.8),
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
    Decoration decoration;
    Color mainTextColor;

    if (isSelected) {
      if (isHoliday) {
        // Luxury Rose/Coral Gradient for Holiday/Friday selection
        decoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.error,
              colors.error,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.error.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
        mainTextColor = Colors.white;
      } else {
        // Luxury Warm Gold Gradient for standard day selection
        decoration = BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primary,
              colors.primaryPressed,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
        mainTextColor = Colors.white;
      }
    } else if (isToday && isCurrentMonth) {
      // Elegant Today indicator when not selected
      decoration = BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary,
          width: 1.5,
        ),
      );
      mainTextColor = colors.primary;
    } else {
      decoration = const BoxDecoration(color: Colors.transparent);

      if (!isCurrentMonth) {
        mainTextColor = isHoliday
            ? colors.error.withValues(alpha: 0.28)
            : colors.textSecondary.withValues(alpha: 0.25);
      } else if (isHoliday) {
        mainTextColor = isDark ? colors.error : colors.error;
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
            // Single Primary Solar Day Number
            Text(
              toPersianDigits(day.jalali.day.toString()),
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: (isToday || isSelected)
                    ? FontWeight.w900
                    : (isHoliday ? FontWeight.w800 : FontWeight.w700),
                color: mainTextColor,
                height: 1.1,
              ),
            ),

            const SizedBox(height: 3),

            // Occasion Micro-Dots
            if (isCurrentMonth && day.hasOccasions)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: day.occasions.take(3).map((occ) {
                  Color dotColor;
                  if (isSelected) {
                    dotColor = Colors.white.withValues(alpha: 0.9);
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
