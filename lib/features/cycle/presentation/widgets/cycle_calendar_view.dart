// C-43, C-44: CycleCalendarView
// Minimalist, modern, accessible Jalali cycle calendar with swipe gestures,
// animated month transitions, explicit directional arrows, and maximized typography.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleCalendarView extends StatefulWidget {
  const CycleCalendarView({
    super.key,
    required this.calendarMonth,
    required this.onMonthChanged,
    required this.periods,
    required this.dayLogs,
    required this.engineOutput,
    required this.settings,
    required this.activePhaseColor,
    this.onDayTapped,
  });

  final Jalali calendarMonth;
  final ValueChanged<Jalali> onMonthChanged;
  final List<Map<String, dynamic>> periods;
  final List<Map<String, dynamic>> dayLogs;
  final CycleEngineOutput? engineOutput;
  final Map<String, String> settings;
  final Color activePhaseColor;
  final ValueChanged<DateTime>? onDayTapped;

  @override
  State<CycleCalendarView> createState() => _CycleCalendarViewState();
}

class _CycleCalendarViewState extends State<CycleCalendarView> {
  int _slideDirection = 1;
  DateTime? _selectedDay;

  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _slideDirection = delta;
    });
    widget.onMonthChanged(widget.calendarMonth.addMonths(delta));
  }

  void _goToCurrentMonth() {
    HapticFeedback.mediumImpact();
    final now = Jalali.now();
    final currentFirst = Jalali(now.year, now.month, 1);
    final isAfter = currentFirst.toDateTime().isAfter(
      widget.calendarMonth.toDateTime(),
    );
    setState(() {
      _slideDirection = isAfter ? 1 : -1;
    });
    widget.onMonthChanged(currentFirst);
  }

  bool _checkIsPeriodDay(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    for (final p in widget.periods) {
      final pStart = DateTime.parse(p['startDate'] as String);
      final start = DateTime(pStart.year, pStart.month, pStart.day);
      final endStr = p['endDate'] as String?;
      final end = endStr != null ? DateTime.parse(endStr) : null;
      final cleanEnd = end != null
          ? DateTime(end.year, end.month, end.day)
          : null;

      if (!cleanDate.isBefore(start)) {
        if (cleanEnd != null) {
          if (!cleanDate.isAfter(cleanEnd)) return true;
        } else {
          final pDur = CycleSettings.getPeriodDuration(widget.settings);
          if (cleanDate.difference(start).inDays < pDur) return true;
        }
      }
    }
    return false;
  }

  bool _checkIsPredictedDay(DateTime date) {
    if (widget.engineOutput == null) return false;
    final nextPeriod = widget.engineOutput!.nextPeriodPrediction;
    if (nextPeriod == null) return false;
    final cleanNextPeriod = DateTime(
      nextPeriod.year,
      nextPeriod.month,
      nextPeriod.day,
    );
    final cleanDate = DateTime(date.year, date.month, date.day);
    final pDur = CycleSettings.getPeriodDuration(widget.settings);
    final diff = cleanDate.difference(cleanNextPeriod).inDays;
    return diff >= 0 && diff < pDur;
  }

  bool _checkIsOvulationDay(DateTime date) {
    if (widget.engineOutput == null || !widget.engineOutput!.hasData) {
      return false;
    }
    final ovDay = widget.engineOutput!.ovulationDay;
    if (ovDay == null) return false;
    final cleanDate = DateTime(date.year, date.month, date.day);
    final ovulation = DateTime(ovDay.year, ovDay.month, ovDay.day);
    return cleanDate.isAtSameMomentAs(ovulation);
  }

  bool _checkIsFertileDay(DateTime date) {
    if (widget.engineOutput == null || !widget.engineOutput!.hasData) {
      return false;
    }
    final fStart = widget.engineOutput!.fertileWindowStart;
    final fEnd = widget.engineOutput!.fertileWindowEnd;
    if (fStart == null || fEnd == null) return false;
    final cleanDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(fStart.year, fStart.month, fStart.day);
    final end = DateTime(fEnd.year, fEnd.month, fEnd.day);
    return !cleanDate.isBefore(start) && !cleanDate.isAfter(end);
  }

  bool _checkIsPmsDay(DateTime date) {
    if (widget.engineOutput == null || !widget.engineOutput!.hasData) {
      return false;
    }
    final pStart = widget.engineOutput!.pmsWindowStart;
    final pEnd = widget.engineOutput!.pmsWindowEnd;
    if (pStart == null || pEnd == null) return false;
    final cleanDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(pStart.year, pStart.month, pStart.day);
    final end = DateTime(pEnd.year, pEnd.month, pEnd.day);
    return !cleanDate.isBefore(start) && !cleanDate.isAfter(end);
  }

  bool _checkHasLog(String dateStr) {
    for (final l in widget.dayLogs) {
      if (l['logDate'] == dateStr || l['dateIso'] == dateStr) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cal = widget.calendarMonth;
    final year = cal.year;
    final monthName = cal.formatter.mN;

    final nowJalali = Jalali.now();
    final isCurrentMonth =
        cal.year == nowJalali.year && cal.month == nowJalali.month;

    final weekdaysHeaders = <String>[
      'شنبه',
      'یک‌شنبه',
      'دوشنبه',
      'سه‌شنبه',
      'چهارشنبه',
      'پنج‌شنبه',
      'جمعه',
    ];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120) {
          // Drag left -> in Persian RTL: next month (+1)
          _changeMonth(1);
        } else if (velocity > 120) {
          // Drag right -> in Persian RTL: previous month (-1)
          _changeMonth(-1);
        }
      },
      child: RitmoTheme.glassCardLight(
        borderRadius: 24,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.activePhaseColor.withValues(alpha: isDark ? 0.08 : 0.04),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              // Calendar Month Navigation Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Right Button: Previous Month (-1) with arrow pointing RIGHT (>)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _changeMonth(-1),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: colors.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  // Month & Year Center Display + "امروز" Return Pill
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            monthName,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: colors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            PersianDigits.toFa(year.toString()),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (!isCurrentMonth) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _goToCurrentMonth,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: widget.activePhaseColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: widget.activePhaseColor.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.arrow_counterclockwise,
                                  size: 12,
                                  color: widget.activePhaseColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'بازگشت به ماه جاری',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: widget.activePhaseColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Left Button: Next Month (+1) with arrow pointing LEFT (<)
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _changeMonth(1),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Icon(
                          Icons.chevron_left_rounded,
                          color: colors.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Weekday Headers Bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.035),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: weekdaysHeaders.map((header) {
                    final isFriday = header == 'جمعه';
                    return Expanded(
                      child: Center(
                        child: Text(
                          header,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isFriday
                                ? colors.error.withValues(alpha: 0.85)
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Animated Days Grid
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offsetAnim = Tween<Offset>(
                    begin: Offset(_slideDirection * 0.15, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offsetAnim, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('${cal.year}_${cal.month}'),
                  child: _buildDaysGrid(cal, colors, isDark),
                ),
              ),

              const SizedBox(height: 16),

              _buildCalendarLegend(colors, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaysGrid(Jalali cal, RitmoColors colors, bool isDark) {
    final year = cal.year;
    final month = cal.month;
    final monthLength = cal.monthLength;

    final firstDay = Jalali(year, month);
    final emptyCells = firstDay.weekDay - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 0.96,
      ),
      itemCount: emptyCells + monthLength,
      itemBuilder: (context, index) {
        if (index < emptyCells) {
          return const SizedBox();
        }

        final dayNum = index - emptyCells + 1;
        final dayJalali = Jalali(year, month, dayNum);
        final dayGregorian = dayJalali.toDateTime();
        final dateStr = dayGregorian.toIso8601String().substring(0, 10);

        final isPeriodDay = _checkIsPeriodDay(dayGregorian);
        final isPredictedDay = _checkIsPredictedDay(dayGregorian);
        final isOvulationDay = _checkIsOvulationDay(dayGregorian);
        final isFertileDay = _checkIsFertileDay(dayGregorian);
        final isPmsDay = _checkIsPmsDay(dayGregorian);
        final hasLog = _checkHasLog(dateStr);

        final todayJalali = Jalali.now();
        final isToday =
            dayJalali.year == todayJalali.year &&
            dayJalali.month == todayJalali.month &&
            dayJalali.day == todayJalali.day;

        final isSelected =
            _selectedDay != null &&
            _selectedDay!.year == dayGregorian.year &&
            _selectedDay!.month == dayGregorian.month &&
            _selectedDay!.day == dayGregorian.day;

        Color? cellBg;
        Border? cellBorder;
        var textColor = colors.textPrimary;
        FontWeight textWeight = FontWeight.w700;

        if (isPeriodDay) {
          cellBg = colors.error.withValues(alpha: isDark ? 0.35 : 0.28);
          textColor = colors.textPrimary;
          textWeight = FontWeight.w900;
          cellBorder = Border.all(
            color: colors.error.withValues(alpha: 0.5),
            width: 1,
          );
        } else if (isPredictedDay) {
          cellBg = colors.error.withValues(alpha: isDark ? 0.12 : 0.08);
          cellBorder = Border.all(
            color: colors.error.withValues(alpha: 0.55),
            width: 1.5,
          );
        } else if (isOvulationDay) {
          cellBg = colors.accent.withValues(alpha: isDark ? 0.40 : 0.30);
          cellBorder = Border.all(color: colors.accent, width: 1.5);
          textWeight = FontWeight.w900;
        } else if (isFertileDay) {
          cellBg = colors.accent.withValues(alpha: isDark ? 0.16 : 0.12);
        } else if (isPmsDay) {
          cellBg = colors.primary.withValues(alpha: isDark ? 0.18 : 0.12);
        }

        if (isToday) {
          cellBorder = Border.all(color: widget.activePhaseColor, width: 2.2);
          textWeight = FontWeight.w900;
        }

        if (isSelected && !isToday) {
          cellBorder = Border.all(
            color: colors.textPrimary.withValues(alpha: 0.8),
            width: 1.8,
          );
        }

        return InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedDay = dayGregorian;
            });
            widget.onDayTapped?.call(dayGregorian);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: cellBg,
              border: cellBorder,
              borderRadius: BorderRadius.circular(13),
              boxShadow: (isPeriodDay || isOvulationDay)
                  ? [
                      BoxShadow(
                        color: (isPeriodDay ? colors.error : colors.accent)
                            .withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    PersianDigits.toFa(dayNum.toString()),
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: textWeight,
                      color: textColor,
                    ),
                  ),
                ),
                if (hasLog)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      height: 5,
                      width: 5,
                      decoration: BoxDecoration(
                        color: isPeriodDay
                            ? colors.textPrimary
                            : widget.activePhaseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarLegend(RitmoColors colors, bool isDarkTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.border.withValues(alpha: 0.6), height: 28),
        Text(
          'راهنمای تقویم چرخه بدنی:',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildLegendItem(
              colors.error.withValues(alpha: isDarkTheme ? 0.35 : 0.28),
              'قاعدگی (پریود)',
              colors.textPrimary,
              borderColor: colors.error.withValues(alpha: 0.5),
            ),
            _buildLegendItem(
              colors.error.withValues(alpha: 0.10),
              'پیش‌بینی دوره بعدی',
              colors.textPrimary,
              borderColor: colors.error.withValues(alpha: 0.6),
            ),
            _buildLegendItem(
              colors.primary.withValues(alpha: 0.15),
              'روزهای پیش از عادت (PMS)',
              colors.textPrimary,
            ),
            _buildLegendItem(
              colors.accent.withValues(alpha: 0.35),
              'روز تخمک‌گذاری',
              colors.textPrimary,
              borderColor: colors.accent,
            ),
            _buildLegendItem(
              colors.accent.withValues(alpha: 0.15),
              'پنجره باروری (Fertile)',
              colors.textPrimary,
            ),
            _buildLegendItem(
              Colors.transparent,
              'امروز',
              colors.textPrimary,
              borderColor: widget.activePhaseColor,
              borderWidth: 2,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: widget.activePhaseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'علائم ثبت شده',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(
    Color bg,
    String text,
    Color textColor, {
    Color? borderColor,
    double borderWidth = 1.3,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            border: borderColor != null
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
