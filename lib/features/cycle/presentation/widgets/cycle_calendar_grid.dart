// C-43, C-44: CycleCalendarGrid
// F-26, F-29, F-30, F-34: Accessible, high-performance Jalali month grid with O(1) mark lookup.
import 'package:flutter/cupertino.dart';
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 7;
        const mainSpacing = 3.5;
        final cellWidth = constraints.maxWidth / columns;
        final scale = context.textScale;
        final cellHeight = (cellWidth * 0.90).clamp(32.0 * scale, 46.0 * scale);

        // کمکی دسته‌بندی دوره‌ها برای پیوستگی نوارهای افقی (Flow Bands)
        int getStreakGroup(CycleDayMark? m) {
          if (m == null) return 0;
          switch (m.kind) {
            case CycleDayKind.recordedPeriod:
              return 1;
            case CycleDayKind.predictedPeriod:
              return 2;
            case CycleDayKind.fertileWindow:
            case CycleDayKind.ovulation:
              return 3;
            case CycleDayKind.pms:
              return 4;
            default:
              return 0;
          }
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: mainSpacing,
            crossAxisSpacing: 0.0,
            mainAxisExtent: cellHeight,
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
            Color bandBorderColor = Colors.transparent;
            var textColor = colors.textPrimary;
            FontWeight textWeight = FontWeight.w700;

            // F-29 & F-30: Style determination based on day kind & confidence (Apple HIG & Neumorphic)
            List<BoxShadow>? cellShadows;

            switch (mark.kind) {
              case CycleDayKind.recordedPeriod:
                cellBg = isDark
                    ? const Color(0xFF3F1922)
                    : const Color(0xFFFFEDF0);
                textColor = isDark
                    ? const Color(0xFFFF8FA2)
                    : const Color(0xFFDC284E);
                textWeight = FontWeight.w900;
                bandBorderColor = colors.error.withValues(alpha: 0.65);
                cellShadows = [
                  BoxShadow(
                    color: colors.error.withValues(alpha: isDark ? 0.25 : 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ];
                break;
              case CycleDayKind.predictedPeriod:
                if (mark.confidenceLevel == PredictionConfidenceLevel.high) {
                  cellBg = colors.error.withValues(alpha: isDark ? 0.20 : 0.12);
                  bandBorderColor = colors.error.withValues(alpha: 0.55);
                  textColor = isDark
                      ? const Color(0xFFFF8FA2)
                      : const Color(0xFFDC284E);
                } else if (mark.confidenceLevel ==
                    PredictionConfidenceLevel.medium) {
                  cellBg = colors.error.withValues(alpha: isDark ? 0.12 : 0.07);
                  bandBorderColor = colors.error.withValues(alpha: 0.38);
                  textColor = colors.textPrimary;
                } else {
                  // Low confidence (F-30)
                  cellBg = Colors.transparent;
                  bandBorderColor = colors.error.withValues(alpha: 0.30);
                  textColor = colors.textSecondary;
                }
                break;
              case CycleDayKind.predictionWindow:
                // F-29: Possible window shift range
                cellBg = Colors.transparent;
                bandBorderColor = colors.error.withValues(alpha: 0.25);
                textColor = colors.textSecondary;
                break;
              case CycleDayKind.ovulation:
                cellBg = isDark
                    ? const Color(0xFF3F3014)
                    : const Color(0xFFFFE8B8);
                bandBorderColor = colors.accent.withValues(alpha: 0.65);
                textColor = isDark
                    ? const Color(0xFFFFDF94)
                    : const Color(0xFF8A5500);
                textWeight = FontWeight.w900;
                cellShadows = [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: isDark ? 0.30 : 0.22),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ];
                break;
              case CycleDayKind.fertileWindow:
                cellBg = isDark
                    ? const Color(0xFF2C2415)
                    : const Color(0xFFFFF5DF);
                bandBorderColor = colors.accent.withValues(alpha: 0.50);
                textColor = isDark
                    ? const Color(0xFFFFD57A)
                    : const Color(0xFFA36700);
                textWeight = FontWeight.w800;
                break;
              case CycleDayKind.pms:
                cellBg = colors.primary.withValues(alpha: isDark ? 0.16 : 0.10);
                bandBorderColor = colors.primary.withValues(alpha: 0.28);
                textColor = colors.primary;
                break;
              case CycleDayKind.normal:
                cellBg = isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.015);
                bandBorderColor = isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : colors.border.withValues(alpha: 0.25);
                break;
            }

            if (isToday) {
              textColor = Colors.white;
              textWeight = FontWeight.w900;
            }

            // محاسبه پیوستگی نوار افقی دوره (Flow Bands) درون سطر جاری
            final colIndex = index % 7;
            final currentGroup = getStreakGroup(mark);
            bool connectsToRight = false; // در RTL راست یعنی روز قبل
            bool connectsToLeft = false;  // در RTL چپ یعنی روز بعد

            if (currentGroup != 0) {
              if (colIndex > 0 && dayNum > 1) {
                final prevJ = Jalali(year, month, dayNum - 1);
                final prevGreg = CycleDateContract.cleanDate(prevJ.toDateTime());
                final prevKey = CycleDateContract.toDayKey(prevGreg);
                if (getStreakGroup(marks[prevKey]) == currentGroup) {
                  connectsToRight = true;
                }
              }
              if (colIndex < 6 && dayNum < monthLength) {
                final nextJ = Jalali(year, month, dayNum + 1);
                final nextGreg = CycleDateContract.cleanDate(nextJ.toDateTime());
                final nextKey = CycleDateContract.toDayKey(nextGreg);
                if (getStreakGroup(marks[nextKey]) == currentGroup) {
                  connectsToLeft = true;
                }
              }
            }

            BorderRadius cellRadius;
            EdgeInsets cellMargin;
            Border cellBorder;

            if (currentGroup != 0 && (connectsToRight || connectsToLeft)) {
              final side = BorderSide(color: bandBorderColor, width: 1.0);
              if (connectsToRight && connectsToLeft) {
                // وسط باند پیوسته
                cellRadius = BorderRadius.zero;
                cellMargin = const EdgeInsets.symmetric(vertical: 2.0);
                cellBorder = Border(top: side, bottom: side);
              } else if (!connectsToRight && connectsToLeft) {
                // شروع باند در RTL (لبه راست گرد)
                cellRadius = const BorderRadius.only(
                  topRight: Radius.circular(13),
                  bottomRight: Radius.circular(13),
                );
                cellMargin = const EdgeInsets.only(right: 2.5, top: 2.0, bottom: 2.0);
                cellBorder = Border(top: side, bottom: side, right: side);
              } else {
                // انتهای باند در RTL (لبه چپ گرد)
                cellRadius = const BorderRadius.only(
                  topLeft: Radius.circular(13),
                  bottomLeft: Radius.circular(13),
                );
                cellMargin = const EdgeInsets.only(left: 2.5, top: 2.0, bottom: 2.0);
                cellBorder = Border(top: side, bottom: side, left: side);
              }
            } else {
              // سلول عادی یا تک‌دوره مجزا
              cellRadius = BorderRadius.circular(13);
              cellMargin = const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.0);
              cellBorder = Border.all(
                color: bandBorderColor,
                width: mark.kind == CycleDayKind.normal ? 0.6 : 1.0,
              );
            }

            // F-34: Screen-reader semantics
            final l10n = AppLocalizations.of(context);
            final semanticsLabel = _buildSemanticsLabel(
              dayJalali,
              mark,
              isToday,
              l10n,
            );

            return Semantics(
              label: semanticsLabel,
              button: true,
              child: InkWell(
                borderRadius: cellRadius,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDayTapped?.call(dayGregorian, mark);
                },
                child: Container(
                  margin: cellMargin,
                  decoration: BoxDecoration(
                    color: cellBg,
                    border: cellBorder,
                    borderRadius: cellRadius,
                    boxShadow: cellShadows,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // نشانگر توپر استاندارد اپل برای روز امروز (Apple Calendar Solid Today Badge)
                      if (isToday)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.45),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),

                      // هاله متمایز روز تخمک‌گذاری (Ovulation Halo)
                      if (mark.kind == CycleDayKind.ovulation)
                        Container(
                          width: 27,
                          height: 27,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accent.withValues(alpha: isDark ? 0.28 : 0.20),
                            border: Border.all(
                              color: colors.accent,
                              width: 1.6,
                            ),
                          ),
                        ),

                      // رینگ روز انتخاب‌شده
                      if (isSelected && !isToday)
                        Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.textPrimary.withValues(alpha: 0.85),
                              width: 1.8,
                            ),
                          ),
                        ),

                      // عدد روز
                      Center(
                        child: Text(
                          PersianDigits.toFa(dayNum.toString()),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: isToday ? FontWeight.w900 : textWeight,
                            color: textColor,
                          ),
                        ),
                      ),

                      // نقطه لاگ علائم
                      if (mark.hasLog)
                        Positioned(
                          bottom: 2.5,
                          child: Container(
                            height: 4.5,
                            width: 4.5,
                            decoration: BoxDecoration(
                              color: mark.kind == CycleDayKind.recordedPeriod
                                  ? textColor
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
        buffer.write(
          l10n?.cycleSemanticsPredictedPeriod ?? '، پیش‌بینی قاعدگی',
        );
        if (mark.confidenceLevel == PredictionConfidenceLevel.low) {
          buffer.write(l10n?.cycleSemanticsLowConfidence ?? ' با اطمینان کم');
        } else if (mark.confidenceLevel == PredictionConfidenceLevel.high) {
          buffer.write(
            l10n?.cycleSemanticsHighConfidence ?? ' با اطمینان بالا',
          );
        }
        break;
      case CycleDayKind.predictionWindow:
        buffer.write(
          l10n?.cycleSemanticsPredictionWindow ??
              '، بازه احتمالی جابجایی قاعدگی',
        );
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
    if (mark.hasLog)
      buffer.write(l10n?.cycleSemanticsHasLogs ?? '، دارای علائم ثبت‌شده');
    return buffer.toString();
  }
}
