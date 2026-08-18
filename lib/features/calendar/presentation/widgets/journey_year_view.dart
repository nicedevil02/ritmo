import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:shamsi_date/shamsi_date.dart';

class JourneyYearView extends StatelessWidget {
  const JourneyYearView({
    super.key,
    required this.selectedDate,
    required this.rangeSnapshots,
    required this.onSelectMonth,
    this.onSelectDay,
  });

  final DateTime selectedDate;
  final Map<String, DayAgendaSnapshot> rangeSnapshots;
  final ValueChanged<DateTime> onSelectMonth;
  final ValueChanged<DateTime>? onSelectDay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();

    final jalaliSelected = Jalali.fromDateTime(selectedDate);
    final jalaliYear = jalaliSelected.year;
    final jalaliYearStr = toPersianDigits(jalaliYear.toString());
    final jalaliNow = Jalali.fromDateTime(now);

    const jalaliMonthNames = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: RitmoSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 18, color: colors.primary),
                    const SizedBox(width: RitmoSpacing.sm),
                    Text(
                      'نقشهٔ حرارتی و نمای سال $jalaliYearStr',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.md),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final monthIndex = index + 1;
                  final isCurrentMonth = (jalaliYear == jalaliNow.year && monthIndex == jalaliNow.month);
                  final isSelectedMonth = (jalaliYear == jalaliSelected.year && monthIndex == jalaliSelected.month);

                  int monthTaskCount = 0;
                  int monthCompletedCount = 0;

                  final monthLength = Jalali(jalaliYear, monthIndex, 1).monthLength;
                  final daySnapshots = <int, DayAgendaSnapshot?>{};

                  for (int d = 1; d <= monthLength; d++) {
                    final jDate = Jalali(jalaliYear, monthIndex, d);
                    final gDate = jDate.toDateTime();
                    final dateStr = DateKey.of(gDate);
                    final snapshot = rangeSnapshots[dateStr];
                    daySnapshots[d] = snapshot;
                    if (snapshot != null) {
                      monthTaskCount += snapshot.items.length;
                      monthCompletedCount += snapshot.completedCount;
                    }
                  }

                  final progressRatio = monthTaskCount > 0 ? (monthCompletedCount / monthTaskCount) : 0.0;

                  return InkWell(
                    onTap: () {
                      final firstDay = Jalali(jalaliYear, monthIndex, 1).toDateTime();
                      onSelectMonth(firstDay);
                    },
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelectedMonth
                            ? colors.primary.withValues(alpha: 0.10)
                            : (isCurrentMonth
                                ? colors.primary.withValues(alpha: 0.05)
                                : colors.surfaceSubtle),
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        border: Border.all(
                          color: isSelectedMonth
                              ? colors.primary
                              : (isCurrentMonth
                                  ? colors.primary.withValues(alpha: 0.35)
                                  : colors.borderSubtle),
                          width: isSelectedMonth ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                jalaliMonthNames[index],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentMonth || isSelectedMonth
                                      ? colors.primary
                                      : colors.textPrimary,
                                ),
                              ),
                              if (isCurrentMonth)
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Mini-heatmap grid of the days in the month
                          Expanded(
                            child: _buildMonthHeatmapGrid(
                              context: context,
                              jalaliYear: jalaliYear,
                              monthIndex: monthIndex,
                              monthLength: monthLength,
                              daySnapshots: daySnapshots,
                              colors: colors,
                            ),
                          ),

                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                monthTaskCount > 0
                                    ? '${toPersianDigits((progressRatio * 100).round())}٪'
                                    : '—',
                                style: TextStyle(
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w600,
                                  color: monthTaskCount > 0
                                      ? (isCurrentMonth || isSelectedMonth
                                          ? colors.primary
                                          : colors.textSecondary)
                                      : colors.textTertiary,
                                ),
                              ),
                              Text(
                                monthTaskCount > 0
                                    ? '${toPersianDigits(monthCompletedCount)}/${toPersianDigits(monthTaskCount)}'
                                    : '',
                                style: TextStyle(
                                  fontSize: 9.0,
                                  color: colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: RitmoSpacing.sm),

            // Heatmap Legend (راهنمای نقشهٔ حرارتی)
            _buildHeatmapLegend(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeatmapGrid({
    required BuildContext context,
    required int jalaliYear,
    required int monthIndex,
    required int monthLength,
    required Map<int, DayAgendaSnapshot?> daySnapshots,
    required RitmoColors colors,
  }) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final availableWidth = constraints.maxWidth;
        const cellSpacing = 2.0;
        final cellSize = ((availableWidth - (6 * cellSpacing)) / 7).clamp(4.0, 16.0);

        return Wrap(
          spacing: cellSpacing,
          runSpacing: cellSpacing,
          children: List.generate(monthLength, (dIdx) {
            final dayNum = dIdx + 1;
            final snap = daySnapshots[dayNum];
            final total = snap?.items.length ?? 0;
            final completed = snap?.completedCount ?? 0;
            final ratio = total > 0 ? (completed / total) : 0.0;

            Color cellColor;
            if (total == 0) {
              cellColor = colors.borderSubtle.withValues(alpha: 0.35);
            } else if (ratio == 1.0) {
              cellColor = colors.success;
            } else if (ratio >= 0.66) {
              cellColor = colors.primary;
            } else if (ratio >= 0.33) {
              cellColor = colors.primary.withValues(alpha: 0.60);
            } else {
              cellColor = colors.primary.withValues(alpha: 0.28);
            }

            final semanticsText = total > 0
                ? 'روز ${toPersianDigits(dayNum)}: ${toPersianDigits(completed)} از ${toPersianDigits(total)} انجام شده'
                : 'روز ${toPersianDigits(dayNum)}: بدون رویداد';

            return Semantics(
              label: semanticsText,
              child: GestureDetector(
                onTap: () {
                  final gDate = Jalali(jalaliYear, monthIndex, dayNum).toDateTime();
                  onSelectDay?.call(gDate);
                },
                child: Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildHeatmapLegend(RitmoColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(RitmoRadius.badge),
        border: Border.all(color: colors.borderSubtle.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('فعالیت: کمتر', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
          const SizedBox(width: 6),
          _buildLegendBox(colors.borderSubtle.withValues(alpha: 0.35), 'صفر'),
          const SizedBox(width: 3),
          _buildLegendBox(colors.primary.withValues(alpha: 0.28), 'کم'),
          const SizedBox(width: 3),
          _buildLegendBox(colors.primary.withValues(alpha: 0.60), 'متوسط'),
          const SizedBox(width: 3),
          _buildLegendBox(colors.primary, 'زیاد'),
          const SizedBox(width: 3),
          _buildLegendBox(colors.success, 'کامل'),
          const SizedBox(width: 6),
          Text('بیشتر', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildLegendBox(Color color, String label) {
    return Semantics(
      label: label,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
