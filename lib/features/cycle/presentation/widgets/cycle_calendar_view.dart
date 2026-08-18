// C-43, C-44: CycleCalendarView
// Minimalist, modern, accessible Jalali cycle calendar with swipe gestures,
// animated month transitions, pre-computed day marks (F-25..F-34), and dynamic legend.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_grid.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_legend.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_empty_state_banner.dart';
import 'package:ritmo/l10n/app_localizations.dart';
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
  final void Function(DateTime date, CycleDayMark mark)? onDayTapped;

  @override
  State<CycleCalendarView> createState() => _CycleCalendarViewState();

  /// F-25: Pure builder for month day marks without in-cell iteration loops.
  @visibleForTesting
  static Map<String, CycleDayMark> buildMonthMarks({
    required Jalali month,
    required List<Map<String, dynamic>> periods,
    required Set<String> loggedDayKeys,
    required List<PredictedCycle> forecast,
    int defaultPeriodDuration = 6,
  }) {
    final marks = <String, CycleDayMark>{};
    final monthLength = month.monthLength;

    final firstJalali = Jalali(month.year, month.month, 1);
    final lastJalali = Jalali(month.year, month.month, monthLength);
    final monthStartGregorian = CycleDateContract.cleanDate(
      firstJalali.toDateTime(),
    );
    final monthEndGregorian = CycleDateContract.cleanDate(
      lastJalali.toDateTime(),
    );

    // 1. Process recorded periods
    final recordedPeriodDays = <String>{};
    for (final p in periods) {
      final rawStart = p['startDate']?.toString();
      final pStart = CycleDateContract.parseDayKey(rawStart);
      if (pStart == null) continue;

      final rawEnd = p['endDate']?.toString();
      final pEnd = CycleDateContract.parseDayKey(rawEnd);
      final effectiveEnd =
          pEnd ?? pStart.add(Duration(days: defaultPeriodDuration - 1));

      var curr = pStart;
      while (!curr.isAfter(effectiveEnd)) {
        if (CycleDateContract.isSameOrAfter(curr, monthStartGregorian) &&
            CycleDateContract.isSameOrBefore(curr, monthEndGregorian)) {
          recordedPeriodDays.add(CycleDateContract.toDayKey(curr));
        }
        curr = curr.add(const Duration(days: 1));
      }
    }

    // 2. Process forecast cycles
    final predictedDays =
        <String, ({PredictionConfidenceLevel level, PredictedCycle cycle})>{};
    final predictionWindowDays =
        <String, ({PredictionConfidenceLevel level, PredictedCycle cycle})>{};
    final ovulationDays = <String>{};
    final fertileDays = <String>{};
    final pmsDays = <String>{};

    for (final cycle in forecast) {
      // Window range: [windowStart, windowEnd]
      var wCurr = CycleDateContract.cleanDate(cycle.windowStart);
      final wEnd = CycleDateContract.cleanDate(cycle.windowEnd);
      while (!wCurr.isAfter(wEnd)) {
        if (CycleDateContract.isSameOrAfter(wCurr, monthStartGregorian) &&
            CycleDateContract.isSameOrBefore(wCurr, monthEndGregorian)) {
          final key = CycleDateContract.toDayKey(wCurr);
          predictionWindowDays[key] = (
            level: cycle.confidenceLevel,
            cycle: cycle,
          );
        }
        wCurr = wCurr.add(const Duration(days: 1));
      }

      // Predicted period days: [predictedStart, predictedEnd]
      var pCurr = CycleDateContract.cleanDate(cycle.predictedStart);
      final pEnd = CycleDateContract.cleanDate(cycle.predictedEnd);
      while (!pCurr.isAfter(pEnd)) {
        if (CycleDateContract.isSameOrAfter(pCurr, monthStartGregorian) &&
            CycleDateContract.isSameOrBefore(pCurr, monthEndGregorian)) {
          final key = CycleDateContract.toDayKey(pCurr);
          predictedDays[key] = (level: cycle.confidenceLevel, cycle: cycle);
        }
        pCurr = pCurr.add(const Duration(days: 1));
      }

      // Ovulation day
      if (cycle.ovulationDay != null) {
        final ovClean = CycleDateContract.cleanDate(cycle.ovulationDay!);
        if (CycleDateContract.isSameOrAfter(ovClean, monthStartGregorian) &&
            CycleDateContract.isSameOrBefore(ovClean, monthEndGregorian)) {
          ovulationDays.add(CycleDateContract.toDayKey(ovClean));
        }
      }

      // Fertile window
      if (cycle.fertileStart != null && cycle.fertileEnd != null) {
        var fCurr = CycleDateContract.cleanDate(cycle.fertileStart!);
        final fEnd = CycleDateContract.cleanDate(cycle.fertileEnd!);
        while (!fCurr.isAfter(fEnd)) {
          if (CycleDateContract.isSameOrAfter(fCurr, monthStartGregorian) &&
              CycleDateContract.isSameOrBefore(fCurr, monthEndGregorian)) {
            fertileDays.add(CycleDateContract.toDayKey(fCurr));
          }
          fCurr = fCurr.add(const Duration(days: 1));
        }
      }

      // PMS window
      if (cycle.pmsStart != null && cycle.pmsEnd != null) {
        var pmsCurr = CycleDateContract.cleanDate(cycle.pmsStart!);
        final pmsEnd = CycleDateContract.cleanDate(cycle.pmsEnd!);
        while (!pmsCurr.isAfter(pmsEnd)) {
          if (CycleDateContract.isSameOrAfter(pmsCurr, monthStartGregorian) &&
              CycleDateContract.isSameOrBefore(pmsCurr, monthEndGregorian)) {
            pmsDays.add(CycleDateContract.toDayKey(pmsCurr));
          }
          pmsCurr = pmsCurr.add(const Duration(days: 1));
        }
      }
    }

    // 3. Populate marks for each day of the Jalali month
    for (var day = 1; day <= monthLength; day++) {
      final jDay = Jalali(month.year, month.month, day);
      final gDay = CycleDateContract.cleanDate(jDay.toDateTime());
      final dayKey = CycleDateContract.toDayKey(gDay);
      final hasLog = loggedDayKeys.contains(dayKey);

      CycleDayKind kind;
      PredictionConfidenceLevel? confidence;
      PredictedCycle? matchedCycle;

      if (recordedPeriodDays.contains(dayKey)) {
        kind = CycleDayKind.recordedPeriod;
      } else if (predictedDays.containsKey(dayKey)) {
        kind = CycleDayKind.predictedPeriod;
        confidence = predictedDays[dayKey]!.level;
        matchedCycle = predictedDays[dayKey]!.cycle;
      } else if (ovulationDays.contains(dayKey)) {
        kind = CycleDayKind.ovulation;
      } else if (fertileDays.contains(dayKey)) {
        kind = CycleDayKind.fertileWindow;
      } else if (pmsDays.contains(dayKey)) {
        kind = CycleDayKind.pms;
      } else if (predictionWindowDays.containsKey(dayKey)) {
        kind = CycleDayKind.predictionWindow;
        confidence = predictionWindowDays[dayKey]!.level;
        matchedCycle = predictionWindowDays[dayKey]!.cycle;
      } else {
        kind = CycleDayKind.normal;
      }

      marks[dayKey] = CycleDayMark(
        kind: kind,
        confidenceLevel: confidence,
        hasLog: hasLog,
        predictedCycle: matchedCycle,
      );
    }

    return marks;
  }
}

class _CycleCalendarViewState extends State<CycleCalendarView> {
  int _slideDirection = 1;
  DateTime? _selectedDay;
  Map<String, CycleDayMark> _marks = const {};
  Set<String> _loggedDayKeys = const {};

  @override
  void initState() {
    super.initState();
    _recomputeMarks();
  }

  @override
  void didUpdateWidget(CycleCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calendarMonth != widget.calendarMonth ||
        oldWidget.periods != widget.periods ||
        oldWidget.dayLogs != widget.dayLogs ||
        oldWidget.engineOutput != widget.engineOutput ||
        oldWidget.settings != widget.settings) {
      _recomputeMarks();
    }
  }

  void _recomputeMarks() {
    // F-27: Convert logs to normalized Set<String> dayKeys once
    _loggedDayKeys = <String>{};
    for (final l in widget.dayLogs) {
      final raw = (l['logDate'] ?? l['dateIso'])?.toString();
      final dt = CycleDateContract.parseDayKey(raw);
      if (dt != null) {
        _loggedDayKeys.add(CycleDateContract.toDayKey(dt));
      }
    }

    final pDur = CycleSettings.getPeriodDuration(widget.settings);
    final forecast = widget.engineOutput?.forecast ?? const <PredictedCycle>[];

    _marks = CycleCalendarView.buildMonthMarks(
      month: widget.calendarMonth,
      periods: widget.periods,
      loggedDayKeys: _loggedDayKeys,
      forecast: forecast,
      defaultPeriodDuration: pDur,
    );
  }

  void _clearSelectedDayIfNotInMonth(Jalali targetMonth) {
    if (_selectedDay != null) {
      final selectedJalali = Jalali.fromDateTime(_selectedDay!);
      if (selectedJalali.year != targetMonth.year ||
          selectedJalali.month != targetMonth.month) {
        _selectedDay = null;
      }
    }
  }

  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    final target = widget.calendarMonth.addMonths(delta);
    _clearSelectedDayIfNotInMonth(target);
    setState(() {
      _slideDirection = delta;
    });
    widget.onMonthChanged(target);
  }

  void _goToCurrentMonth() {
    HapticFeedback.mediumImpact();
    final now = Jalali.fromDateTime(CycleClock.now);
    final currentFirst = Jalali(now.year, now.month, 1);
    final isAfter = currentFirst.toDateTime().isAfter(
      widget.calendarMonth.toDateTime(),
    );
    _clearSelectedDayIfNotInMonth(currentFirst);
    setState(() {
      _slideDirection = isAfter ? 1 : -1;
    });
    widget.onMonthChanged(currentFirst);
  }

  void _jumpToNextPredictedPeriod() {
    final forecast = widget.engineOutput?.forecast ?? const [];
    if (forecast.isEmpty) return;
    HapticFeedback.mediumImpact();
    final nextPeriodStart = forecast.first.predictedStart;
    final nextJalali = Jalali.fromDateTime(nextPeriodStart);
    final targetMonth = Jalali(nextJalali.year, nextJalali.month, 1);
    final isAfter = targetMonth.toDateTime().isAfter(
      widget.calendarMonth.toDateTime(),
    );
    _clearSelectedDayIfNotInMonth(targetMonth);
    setState(() {
      _slideDirection = isAfter ? 1 : -1;
    });
    widget.onMonthChanged(targetMonth);
  }

  PredictionConfidenceLevel? _getDominantConfidenceLevel() {
    final levels = _marks.values
        .where(
          (m) =>
              m.kind == CycleDayKind.predictedPeriod &&
              m.confidenceLevel != null,
        )
        .map((m) => m.confidenceLevel!)
        .toList();
    if (levels.isEmpty) return null;
    if (levels.any((l) => l == PredictionConfidenceLevel.low)) {
      return PredictionConfidenceLevel.low;
    }
    if (levels.any((l) => l == PredictionConfidenceLevel.medium)) {
      return PredictionConfidenceLevel.medium;
    }
    return PredictionConfidenceLevel.high;
  }

  bool _hasOnlyPredictionsInMonth() {
    final hasRecorded = _marks.values.any(
      (m) => m.kind == CycleDayKind.recordedPeriod,
    );
    final hasPredicted = _marks.values.any(
      (m) => m.kind == CycleDayKind.predictedPeriod,
    );
    return !hasRecorded && hasPredicted;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final cal = widget.calendarMonth;
    final year = cal.year;
    final monthName = cal.formatter.mN;

    final nowJalali = Jalali.fromDateTime(CycleClock.now);
    final isCurrentMonth =
        cal.year == nowJalali.year && cal.month == nowJalali.month;

    // Check if next predicted period is in another month (F-37)
    final firstForecast = widget.engineOutput?.forecast.firstOrNull;
    bool canJumpToNext = false;
    if (firstForecast != null) {
      final nextJ = Jalali.fromDateTime(firstForecast.predictedStart);
      canJumpToNext = (nextJ.year != cal.year || nextJ.month != cal.month);
    }

    final dominantConfidence = _getDominantConfidenceLevel();
    final isPredictionOnlyMonth = _hasOnlyPredictionsInMonth();

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
          _changeMonth(1);
        } else if (velocity > 120) {
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
                  // Previous Month Button (pointing right in RTL)
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

                  // Month & Year Center Display + Action Buttons
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
                          // F-36: Confidence Badge for Future Estimated Months
                          if (isPredictionOnlyMonth &&
                              dominantConfidence != null) ...[
                            const SizedBox(width: 8),
                            _buildConfidenceBadge(
                              dominantConfidence,
                              colors,
                              l10n,
                            ),
                          ],
                        ],
                      ),
                      if (!isCurrentMonth || canJumpToNext) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isCurrentMonth)
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _goToCurrentMonth,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
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
                                        size: 11,
                                        color: widget.activePhaseColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n?.cycleCurrentMonth ?? 'ماه جاری',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: widget.activePhaseColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (!isCurrentMonth && canJumpToNext)
                              const SizedBox(width: 6),
                            if (canJumpToNext)
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: _jumpToNextPredictedPeriod,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.error.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colors.error.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.calendar_today,
                                        size: 11,
                                        color: colors.error,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n?.cycleJumpToNext ??
                                            'پرش به دوره بعد',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: colors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),

                  // Next Month Button (pointing left in RTL)
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

              // Animated Days Grid (F-26: Zero loops in itemBuilder)
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
                  child: CycleCalendarGrid(
                    cal: cal,
                    marks: _marks,
                    selectedDay: _selectedDay,
                    activePhaseColor: widget.activePhaseColor,
                    onDayTapped: (day, mark) {
                      setState(() {
                        _selectedDay = day;
                      });
                      widget.onDayTapped?.call(day, mark);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Dynamic Legend (F-35, F-31)
              CycleCalendarLegend(
                marks: _marks,
                settings: widget.settings,
                activePhaseColor: widget.activePhaseColor,
              ),

              // Reasoned Empty State Banner (F-39)
              CycleEmptyStateBanner(
                periodsCount: widget.periods.length,
                isPregnancyMode:
                    widget.settings['cycle_pregnancy_mode'] == 'true',
                calendarMonth: cal,
                forecast: widget.engineOutput?.forecast ?? const [],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(
    PredictionConfidenceLevel level,
    RitmoColors colors,
    AppLocalizations? l10n,
  ) {
    final String label;
    final Color badgeColor;
    switch (level) {
      case PredictionConfidenceLevel.high:
        label = l10n?.cycleConfidenceHigh ?? 'اطمینان بالا';
        badgeColor = colors.accent;
        break;
      case PredictionConfidenceLevel.medium:
        label = l10n?.cycleConfidenceMedium ?? 'اطمینان متوسط';
        badgeColor = colors.primary;
        break;
      case PredictionConfidenceLevel.low:
        label = l10n?.cycleConfidenceLow ?? 'اطمینان کم';
        badgeColor = colors.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}
