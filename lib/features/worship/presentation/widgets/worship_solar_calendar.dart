import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/worship/logic/worship_calendar_logic.dart';
import 'package:ritmo/features/worship/logic/worship_occasions_data.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
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
  bool _isCollapsed = false;

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
      (d) => d.jalali.year == _selectedDay.jalali.year &&
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

    return Column(
      children: [
        // Main Premium Solar Calendar Surface Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Navigation, Month Title & Subtitle + Collapse Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title & Subtitle Range + Today Button
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
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                                fontFamily: 'Vazirmatn',
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Today Button Shortcut (Active whenever selected day is not today)
                            if (!isSelectedToday)
                              InkWell(
                                onTap: _goToToday,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colors.primary.withValues(alpha: 0.25),
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
                                          fontWeight: FontWeight.bold,
                                          color: colors.primary,
                                          fontFamily: 'Vazirmatn',
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
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                            fontFamily: 'Vazirmatn',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Collapse Toggle + Prev / Next Month Controls
                  Row(
                    children: [
                      // Collapse / Expand Toggle Button
                      IconButton(
                        onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                        icon: Icon(
                          _isCollapsed ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_up,
                          size: 20,
                        ),
                        color: colors.textPrimary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        tooltip: _isCollapsed ? 'باز کردن تقویم' : 'جمع کردن تقویم',
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        onPressed: _goToNextMonth,
                        icon: const Icon(CupertinoIcons.chevron_forward, size: 20),
                        color: colors.textPrimary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        tooltip: 'ماه بعد',
                      ),
                      IconButton(
                        onPressed: _goToPrevMonth,
                        icon: const Icon(CupertinoIcons.chevron_back, size: 20),
                        color: colors.textPrimary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                        tooltip: 'ماه قبل',
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 7-Column Weekday Headers (Saturday to Friday)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildWeekdayHeader('ش', colors, isFriday: false),
                  _buildWeekdayHeader('ی', colors, isFriday: false),
                  _buildWeekdayHeader('د', colors, isFriday: false),
                  _buildWeekdayHeader('س', colors, isFriday: false),
                  _buildWeekdayHeader('چ', colors, isFriday: false),
                  _buildWeekdayHeader('پ', colors, isFriday: false),
                  _buildWeekdayHeader('ج', colors, isFriday: true),
                ],
              ),

              const SizedBox(height: 10),
              Divider(height: 1, color: colors.divider),
              const SizedBox(height: 10),

              // 7-Column Grid (Month View or Collapsed Week View)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: GridView.builder(
                  key: ValueKey('${_monthData.year}-${_monthData.month}-collapsed:$_isCollapsed-week:$weekStart'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedDays.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final day = displayedDays[index];
                    return _buildDayCell(context, colors, day);
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

  Widget _buildWeekdayHeader(String label, RitmoColors colors, {required bool isFriday}) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isFriday ? colors.error : colors.textTertiary,
            fontFamily: 'Vazirmatn',
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, RitmoColors colors, WorshipCalendarDay day) {
    final isSelected = day.jalali.year == _selectedDay.jalali.year &&
        day.jalali.month == _selectedDay.jalali.month &&
        day.jalali.day == _selectedDay.jalali.day;

    final isToday = day.isToday;
    final isCurrentMonth = day.isCurrentMonth;
    final isHoliday = day.isHoliday;

    // Card background, border, shadow, text color
    Color bgColor;
    Border? border;
    List<BoxShadow>? boxShadow;
    Color mainTextColor;

    if (isSelected) {
      if (isHoliday) {
        // Modern Red Accent / Glow for Holiday selection
        bgColor = colors.error;
        border = Border.all(
          color: colors.error.withValues(alpha: 0.9),
          width: 1.8,
        );
        boxShadow = [
          BoxShadow(
            color: colors.error.withValues(alpha: 0.40),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ];
        mainTextColor = Colors.white;
      } else {
        // Dynamic Theme Primary Color for standard day selection
        bgColor = colors.primary;
        border = Border.all(
          color: colors.primary.withValues(alpha: 0.6),
          width: 1.5,
        );
        boxShadow = [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ];
        mainTextColor = colors.onPrimary;
      }
    } else {
      if (isToday) {
        bgColor = (isHoliday ? colors.error : colors.primary).withValues(alpha: 0.08);
        border = Border.all(
          color: isHoliday ? colors.error : colors.primary,
          width: 1.6,
        );
        boxShadow = null;
      } else {
        bgColor = Colors.transparent;
        border = null;
        boxShadow = null;
      }

      if (!isCurrentMonth) {
        mainTextColor = isHoliday
            ? colors.error.withValues(alpha: 0.40)
            : colors.textTertiary.withValues(alpha: 0.35);
      } else if (isHoliday) {
        mainTextColor = colors.error;
      } else {
        mainTextColor = colors.textPrimary;
      }
    }

    return GestureDetector(
      onTap: () => _onSelectDay(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: border,
          boxShadow: boxShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Single Primary Solar Day Number (20pt)
            Text(
              toPersianDigits(day.jalali.day.toString()),
              style: TextStyle(
                fontSize: 20,
                fontWeight: (isToday || isSelected || isHoliday) ? FontWeight.bold : FontWeight.w600,
                color: mainTextColor,
                fontFamily: 'Vazirmatn',
              ),
            ),

            const SizedBox(height: 3),

            // Occasion Dot Indicators (Max 2 dots)
            if (isCurrentMonth && day.hasOccasions)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: day.occasions.take(2).map((occ) {
                  Color dotColor;
                  if (isSelected) {
                    dotColor = isHoliday ? Colors.white : colors.onPrimary;
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
                        dotColor = colors.warning;
                        break;
                      case WorshipOccasionCategory.national:
                        dotColor = colors.accent;
                        break;
                    }
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
