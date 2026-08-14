import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:shamsi_date/shamsi_date.dart';

class JourneyYearView extends StatelessWidget {
  const JourneyYearView({
    super.key,
    required this.selectedDate,
    required this.rangeSnapshots,
    required this.onSelectMonth,
  });

  final DateTime selectedDate;
  final Map<String, DayAgendaSnapshot> rangeSnapshots;
  final ValueChanged<DateTime> onSelectMonth;

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
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: colors.primary),
                const SizedBox(width: RitmoSpacing.sm),
                Text(
                  'نمای سال $jalaliYearStr',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
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
                  childAspectRatio: 1.15,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final monthIndex = index + 1;
                  final isCurrentMonth = (jalaliYear == jalaliNow.year && monthIndex == jalaliNow.month);
                  final isSelectedMonth = (jalaliYear == jalaliSelected.year && monthIndex == jalaliSelected.month);

                  int monthTaskCount = 0;
                  int monthCompletedCount = 0;

                  for (int d = 1; d <= 31; d++) {
                    try {
                      final jDate = Jalali(jalaliYear, monthIndex, d);
                      final gDate = jDate.toDateTime();
                      final dateStr =
                          '${gDate.year}-${gDate.month.toString().padLeft(2, '0')}-${gDate.day.toString().padLeft(2, '0')}';
                      final snapshot = rangeSnapshots[dateStr];
                      if (snapshot != null) {
                        monthTaskCount += snapshot.items.length;
                        monthCompletedCount += snapshot.completedCount;
                      }
                    } catch (_) {}
                  }

                  final progressRatio = monthTaskCount > 0 ? (monthCompletedCount / monthTaskCount) : 0.0;

                  return InkWell(
                    onTap: () {
                      final firstDay = Jalali(jalaliYear, monthIndex, 1).toDateTime();
                      onSelectMonth(firstDay);
                    },
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelectedMonth
                            ? colors.primary.withValues(alpha: 0.12)
                            : (isCurrentMonth
                                ? colors.primary.withValues(alpha: 0.06)
                                : colors.surfaceSubtle),
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        border: Border.all(
                          color: isSelectedMonth
                              ? colors.primary
                              : (isCurrentMonth
                                  ? colors.primary.withValues(alpha: 0.40)
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrentMonth || isSelectedMonth
                                      ? colors.primary
                                      : colors.textPrimary,
                                ),
                              ),
                              if (isCurrentMonth)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                monthTaskCount > 0
                                    ? '${toPersianDigits((progressRatio * 100).round())}٪'
                                    : '—',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.w600,
                                  color: monthTaskCount > 0
                                      ? (isCurrentMonth || isSelectedMonth
                                          ? colors.primary
                                          : colors.textSecondary)
                                      : colors.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: monthTaskCount > 0 ? progressRatio : 0.0,
                                  minHeight: 3,
                                  backgroundColor: colors.borderSubtle,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    monthTaskCount == 0
                                        ? colors.disabled
                                        : (monthCompletedCount == monthTaskCount
                                            ? colors.success
                                            : colors.primary),
                                  ),
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
          ],
        ),
      ),
    );
  }
}
