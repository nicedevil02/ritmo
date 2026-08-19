// C-43, C-44: CycleCalendarGrid
// F-26, F-29, F-30, F-34: Accessible, high-performance Jalali month grid with O(1) mark lookup.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleCalendarGrid extends StatelessWidget {
  const CycleCalendarGrid({
    super.key,
    required this.cal,
    required this.marks,
    required this.selectedDay,
    required this.activePhaseColor,
    this.onDayTapped,
  });

  final Jalali cal;
  final Map<String, CycleDayMark> marks;
  final DateTime? selectedDay;
  final Color activePhaseColor;
  final void Function(DateTime date, CycleDayMark mark)? onDayTapped;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final year = cal.year;
    final month = cal.month;
    final monthLength = cal.monthLength;

    final firstDay = Jalali(year, month);
    final emptyCells = firstDay.weekDay - 1;

    final todayJalali = Jalali.fromDateTime(CycleClock.now);

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
        final dayGregorian = CycleDateContract.cleanDate(
          dayJalali.toDateTime(),
        );
        final dayKey = CycleDateContract.toDayKey(dayGregorian);

        // F-26: O(1) read from precomputed marks with ZERO loops
        final mark =
            marks[dayKey] ?? const CycleDayMark(kind: CycleDayKind.normal);

        final isToday =
            dayJalali.year == todayJalali.year &&
            dayJalali.month == todayJalali.month &&
            dayJalali.day == todayJalali.day;

        final isSelected =
            selectedDay != null &&
            selectedDay!.year == dayGregorian.year &&
            selectedDay!.month == dayGregorian.month &&
            selectedDay!.day == dayGregorian.day;

        Color? cellBg;
        Border? cellBorder;
        var textColor = colors.textPrimary;
        FontWeight textWeight = FontWeight.w700;

        // F-29 & F-30: Style determination based on day kind & confidence
        switch (mark.kind) {
          case CycleDayKind.recordedPeriod:
            cellBg = colors.error.withValues(alpha: isDark ? 0.38 : 0.30);
            textColor = colors.textPrimary;
            textWeight = FontWeight.w900;
            cellBorder = Border.all(
              color: colors.error.withValues(alpha: 0.7),
              width: 1.2,
            );
            break;
          case CycleDayKind.predictedPeriod:
            if (mark.confidenceLevel == PredictionConfidenceLevel.high) {
              cellBg = colors.error.withValues(alpha: isDark ? 0.20 : 0.15);
              cellBorder = Border.all(
                color: colors.error.withValues(alpha: 0.6),
                width: 1.3,
              );
            } else if (mark.confidenceLevel ==
                PredictionConfidenceLevel.medium) {
              cellBg = colors.error.withValues(alpha: isDark ? 0.12 : 0.08);
              cellBorder = Border.all(
                color: colors.error.withValues(alpha: 0.4),
                width: 1.0,
              );
            } else {
              // Low confidence (F-30)
              cellBg = Colors.transparent;
              cellBorder = Border.all(
                color: colors.error.withValues(alpha: 0.35),
                width: 1.0,
              );
              textColor = colors.textSecondary;
            }
            break;
          case CycleDayKind.predictionWindow:
            // F-29: Possible window shift range (no fill, dashed style)
            cellBg = Colors.transparent;
            cellBorder = Border.all(
              color: colors.error.withValues(alpha: 0.25),
              width: 1.0,
            );
            textColor = colors.textSecondary;
            break;
          case CycleDayKind.ovulation:
            cellBg = colors.accent.withValues(alpha: isDark ? 0.45 : 0.35);
            cellBorder = Border.all(color: colors.accent, width: 1.8);
            textWeight = FontWeight.w900;
            break;
          case CycleDayKind.fertileWindow:
            cellBg = colors.accent.withValues(alpha: isDark ? 0.26 : 0.20);
            cellBorder = Border.all(
              color: colors.accent.withValues(alpha: 0.55),
              width: 1.1,
            );
            textWeight = FontWeight.w800;
            break;
          case CycleDayKind.pms:
            cellBg = colors.primary.withValues(alpha: isDark ? 0.18 : 0.12);
            break;
          case CycleDayKind.normal:
            break;
        }

        if (isToday) {
          cellBorder = Border.all(color: activePhaseColor, width: 2.2);
          textWeight = FontWeight.w900;
        }

        if (isSelected && !isToday) {
          cellBorder = Border.all(
            color: colors.textPrimary.withValues(alpha: 0.8),
            width: 1.8,
          );
        }

        // F-34: Screen-reader semantics
        final l10n = AppLocalizations.of(context);
        final semanticsLabel = _buildSemanticsLabel(dayJalali, mark, isToday, l10n);

        return Semantics(
          label: semanticsLabel,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () {
              HapticFeedback.lightImpact();
              onDayTapped?.call(dayGregorian, mark);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: cellBg,
                border: cellBorder,
                borderRadius: BorderRadius.circular(13),
                boxShadow:
                    (mark.kind == CycleDayKind.recordedPeriod ||
                        mark.kind == CycleDayKind.ovulation)
                    ? [
                        BoxShadow(
                          color:
                              (mark.kind == CycleDayKind.recordedPeriod
                                      ? colors.error
                                      : colors.accent)
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
                      style: RitmoTextStyles.cardTitle(
                        textColor,
                      ).copyWith(fontWeight: textWeight),
                    ),
                  ),
                  if (mark.hasLog)
                    Positioned(
                      bottom: 3,
                      child: Container(
                        height: 5,
                        width: 5,
                        decoration: BoxDecoration(
                          color: mark.kind == CycleDayKind.recordedPeriod
                              ? colors.textPrimary
                              : activePhaseColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildSemanticsLabel(
    Jalali jDay,
    CycleDayMark mark,
    bool isToday,
    AppLocalizations? l10n,
  ) {
    final buffer = StringBuffer();
    buffer.write(
      '${PersianDigits.toFa(jDay.day.toString())} ${jDay.formatter.mN}',
    );
    if (isToday) buffer.write(l10n?.cycleSemanticsToday ?? '، امروز');
    switch (mark.kind) {
      case CycleDayKind.recordedPeriod:
        buffer.write(l10n?.cycleSemanticsRecordedPeriod ?? '، قاعدگی ثبت شده');
        break;
      case CycleDayKind.predictedPeriod:
        buffer.write(l10n?.cycleSemanticsPredictedPeriod ?? '، پیش‌بینی قاعدگی');
        if (mark.confidenceLevel == PredictionConfidenceLevel.low) {
          buffer.write(l10n?.cycleSemanticsLowConfidence ?? ' با اطمینان کم');
        } else if (mark.confidenceLevel == PredictionConfidenceLevel.high) {
          buffer.write(l10n?.cycleSemanticsHighConfidence ?? ' با اطمینان بالا');
        }
        break;
      case CycleDayKind.predictionWindow:
        buffer.write(l10n?.cycleSemanticsPredictionWindow ?? '، بازه احتمالی جابجایی قاعدگی');
        break;
      case CycleDayKind.ovulation:
        buffer.write(l10n?.cycleSemanticsOvulation ?? '، روز تخمک‌گذاری');
        break;
      case CycleDayKind.fertileWindow:
        buffer.write(l10n?.cycleSemanticsFertileWindow ?? '، پنجره باروری');
        break;
      case CycleDayKind.pms:
        buffer.write(l10n?.cycleSemanticsPms ?? '، روزهای پیش از عادت');
        break;
      case CycleDayKind.normal:
        break;
    }
    if (mark.hasLog) buffer.write(l10n?.cycleSemanticsHasLogs ?? '، دارای علائم ثبت‌شده');
    return buffer.toString();
  }
}
