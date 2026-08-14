import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/worship/logic/worship_calendar_logic.dart';
import 'package:ritmo/features/worship/logic/worship_occasions_data.dart';
import 'package:ritmo/features/worship/models/worship_models.dart' hide toPersianDigits;
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
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: isDark ? const Color(0xFF151A18) : const Color(0xFFFFFEFB),
            border: Border.all(
              color: isDark ? const Color(0xFF25443A) : const Color(0xFFE8E0CD),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : const Color(0xFFB79B62).withValues(alpha: 0.08),
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
                                  fontFamily: 'Vazirmatn',
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
                                      color: isDark ? const Color(0xFF23382D) : const Color(0xFFF1E8D5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF3B6B55)
                                            : const Color(0xFFD4A843).withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.arrow_counterclockwise,
                                          size: 11,
                                          color: isDark ? const Color(0xFFE8C46D) : const Color(0xFF9E7018),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'امروز',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? const Color(0xFFE8C46D) : const Color(0xFF9E7018),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary.withValues(alpha: 0.85),
                              fontFamily: 'Vazirmatn',
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
                  color: isDark ? const Color(0xFF101614) : const Color(0xFFF7F4EC),
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
                child: GridView.builder(
                  key: ValueKey('${_monthData.year}-${_monthData.month}-collapsed:$_isCollapsed-week:$weekStart'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedDays.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    childAspectRatio: 0.98,
                  ),
                  itemBuilder: (context, index) {
                    final day = displayedDays[index];
                    return _buildDayCell(context, colors, day, isDark);
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
              color: isDark ? const Color(0xFF19221E) : const Color(0xFFF4F0E6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF28463B) : const Color(0xFFE2D9C5),
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
                    ? const Color(0xFFEF4444)
                    : colors.textSecondary.withValues(alpha: 0.8),
                fontFamily: 'Vazirmatn',
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF43F5E),
              Color(0xFFBE123C),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        );
        mainTextColor = Colors.white;
      } else {
        // Luxury Warm Gold Gradient for standard day selection
        decoration = BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFC38D29),
              Color(0xFF9E7018),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC38D29).withValues(alpha: 0.35),
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
        color: isDark ? const Color(0xFF1E2F26) : const Color(0xFFF8F3E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF437A61) : const Color(0xFFD4A843),
          width: 1.5,
        ),
      );
      mainTextColor = isDark ? const Color(0xFFE8C46D) : const Color(0xFF9E7018);
    } else {
      decoration = const BoxDecoration(color: Colors.transparent);

      if (!isCurrentMonth) {
        mainTextColor = isHoliday
            ? const Color(0xFFEF4444).withValues(alpha: 0.28)
            : colors.textSecondary.withValues(alpha: 0.25);
      } else if (isHoliday) {
        mainTextColor = isDark ? const Color(0xFFFB7185) : const Color(0xFFEF4444);
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
                fontFamily: 'Vazirmatn',
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
                        dotColor = const Color(0xFF10B981);
                        break;
                      case WorshipOccasionCategory.mourning:
                        dotColor = const Color(0xFFEF4444);
                        break;
                      case WorshipOccasionCategory.fasting:
                      case WorshipOccasionCategory.worshipDeed:
                        dotColor = const Color(0xFFD4A843);
                        break;
                      case WorshipOccasionCategory.national:
                        dotColor = const Color(0xFF6366F1);
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
