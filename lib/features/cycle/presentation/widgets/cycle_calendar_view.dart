// C-43, C-44: CycleCalendarView
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
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
  });

  final Jalali calendarMonth;
  final ValueChanged<Jalali> onMonthChanged;
  final List<Map<String, dynamic>> periods;
  final List<Map<String, dynamic>> dayLogs;
  final CycleEngineOutput? engineOutput;
  final Map<String, String> settings;
  final Color activePhaseColor;

  @override
  State<CycleCalendarView> createState() => _CycleCalendarViewState();
}

class _CycleCalendarViewState extends State<CycleCalendarView> {
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
          final pDur =
              int.tryParse(widget.settings['cycle_avg_period'] ?? '6') ?? 6;
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
    final pDur = int.tryParse(widget.settings['cycle_avg_period'] ?? '6') ?? 6;
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
    final month = cal.month;
    final monthName = cal.formatter.mN;
    final monthLength = cal.monthLength;

    final firstDay = Jalali(year, month);
    final emptyCells = firstDay.weekDay - 1;

    final weekdaysHeaders = <String>[
      'شنبه',
      'یکشنبه',
      'دوشنبه',
      'سه شنبه',
      'چهارشنبه',
      'پنجشنبه',
      'جمعه',
    ];

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        child: Column(
          children: [
            // Calendar month selector header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    CupertinoIcons.right_chevron,
                    color: widget.activePhaseColor,
                    size: 16,
                  ),
                  onPressed: () =>
                      widget.onMonthChanged(widget.calendarMonth.addMonths(-1)),
                ),
                Column(
                  children: [
                    Text(
                      monthName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      PersianDigits.toFa(year.toString()),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    CupertinoIcons.left_chevron,
                    color: widget.activePhaseColor,
                    size: 16,
                  ),
                  onPressed: () =>
                      widget.onMonthChanged(widget.calendarMonth.addMonths(1)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Weekday Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: weekdaysHeaders.map((header) {
                return Expanded(
                  child: Center(
                    child: Text(
                      header,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // Days grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
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

                Color? cellBg;
                Border? cellBorder;
                var textColor = colors.textPrimary;

                if (isPeriodDay) {
                  cellBg = colors.error.withValues(alpha: 0.35);
                  textColor = colors.textPrimary;
                } else if (isPredictedDay) {
                  cellBorder = Border.all(
                    color: colors.error.withValues(alpha: 0.6),
                    width: 1.5,
                  );
                } else if (isOvulationDay) {
                  cellBg = colors.accent.withValues(alpha: 0.4);
                  cellBorder = Border.all(color: colors.accent, width: 1.5);
                  textColor = colors.textPrimary;
                } else if (isFertileDay) {
                  cellBg = colors.accent.withValues(alpha: 0.15);
                } else if (isPmsDay) {
                  cellBg = colors.primary.withValues(alpha: 0.15);
                }

                if (isToday) {
                  cellBorder = Border.all(
                    color: widget.activePhaseColor,
                    width: 2,
                  );
                }

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: cellBg,
                        border: cellBorder,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          PersianDigits.toFa(dayNum.toString()),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                    if (hasLog)
                      Positioned(
                        bottom: 3,
                        child: Container(
                          height: 4,
                          width: 4,
                          decoration: BoxDecoration(
                            color: widget.activePhaseColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            _buildCalendarLegend(colors, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLegend(RitmoColors colors, bool isDarkTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.border, height: 24),
        Text(
          'راهنمای تقویم چرخه بدنی:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildLegendItem(
              colors.error.withValues(alpha: 0.35),
              'قاعدگی (پریود)',
              colors.textPrimary,
            ),
            _buildLegendItem(
              Colors.transparent,
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
              colors.accent.withValues(alpha: 0.4),
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
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.activePhaseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'علائم ثبت شده',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
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
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bg,
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }
}
