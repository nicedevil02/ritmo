// C-43, C-44: CycleCalendarView
// Minimalist, modern, accessible Jalali cycle calendar with swipe gestures,
// animated month transitions, pre-computed day marks (F-25..F-34), and dynamic legend.
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_grid.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_header.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_legend.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_empty_state_banner.dart';
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
    int lutealPhaseDays = 14,
    int pmsWindowDays = 4,
    double avgCycleLength = 28.0,
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

    // 2. Process historical completed cycles from recorded periods (Retrospective fertile windows)
    final ovulationDays = <String>{};
    final fertileDays = <String>{};
    final pmsDays = <String>{};

    final distinctStarts = <DateTime>{};
    for (final p in periods) {
      final rawStart = p['startDate']?.toString();
      final pStart = CycleDateContract.parseDayKey(rawStart);
      if (pStart != null) {
        distinctStarts.add(pStart);
      }
    }
    final sortedStarts = distinctStarts.toList()
      ..sort((a, b) => a.compareTo(b));

    void markRetrospectiveCycle(
      DateTime start,
      DateTime endNext,
      int lutealDays,
      int pmsDaysCount,
    ) {
      final cycleL = CycleDateContract.daysBetween(start, endNext);
      if (cycleL < 10) return;

      final effectiveLuteal = math.min(lutealDays, math.max(1, cycleL - 5));
      final ovDate = endNext.subtract(Duration(days: effectiveLuteal));
      final fertStart = ovDate.subtract(const Duration(days: 5));
      final fertEnd = ovDate.add(const Duration(days: 1));
      final pmsStart = endNext.subtract(Duration(days: pmsDaysCount));
      final pmsEnd = endNext.subtract(const Duration(days: 1));

      // Ovulation
      final ovClean = CycleDateContract.cleanDate(ovDate);
      if (CycleDateContract.isSameOrAfter(ovClean, monthStartGregorian) &&
          CycleDateContract.isSameOrBefore(ovClean, monthEndGregorian)) {
        ovulationDays.add(CycleDateContract.toDayKey(ovClean));
      }

      // Fertile Window (6 days: ovDate - 5 days up to ovDate + 1 day)
      var fCurr = CycleDateContract.cleanDate(fertStart);
      final fEnd = CycleDateContract.cleanDate(fertEnd);
      while (!fCurr.isAfter(fEnd)) {
        if (CycleDateContract.isSameOrAfter(fCurr, monthStartGregorian) &&
            CycleDateContract.isSameOrBefore(fCurr, monthEndGregorian)) {
          fertileDays.add(CycleDateContract.toDayKey(fCurr));
        }
        fCurr = fCurr.add(const Duration(days: 1));
      }

      // PMS Window
      var pCurr = CycleDateContract.cleanDate(pmsStart);
      final pEnd = CycleDateContract.cleanDate(pmsEnd);
      while (!pCurr.isAfter(pEnd)) {
        if (CycleDateContract.isSameOrAfter(pCurr, monthStartGregorian) &&
            CycleDateContract.isSameOrBefore(pCurr, monthEndGregorian)) {
          pmsDays.add(CycleDateContract.toDayKey(pCurr));
        }
        pCurr = pCurr.add(const Duration(days: 1));
      }
    }

    final effectiveAvgCycle = avgCycleLength.round().clamp(21, 45);

    // 2.1 Process all recorded consecutive pairs (past cycles)
    for (var i = 0; i < sortedStarts.length - 1; i++) {
      final sCurrent = sortedStarts[i];
      final sNext = sortedStarts[i + 1];
      markRetrospectiveCycle(sCurrent, sNext, lutealPhaseDays, pmsWindowDays);
    }

    // 2.2 Process the cycle starting at the last recorded start up to the first forecast cycle
    if (sortedStarts.isNotEmpty) {
      final sLast = sortedStarts.last;
      final firstForecastStart = forecast.isNotEmpty
          ? CycleDateContract.cleanDate(forecast.first.predictedStart)
          : null;

      if (firstForecastStart == null) {
        final nextStart = sLast.add(Duration(days: effectiveAvgCycle));
        markRetrospectiveCycle(
          sLast,
          nextStart,
          lutealPhaseDays,
          pmsWindowDays,
        );
      } else {
        var currStart = sLast;
        while (currStart.isBefore(firstForecastStart)) {
          final nextStart = currStart.add(Duration(days: effectiveAvgCycle));
          if (nextStart.isAfter(firstForecastStart)) {
            markRetrospectiveCycle(
              currStart,
              firstForecastStart,
              lutealPhaseDays,
              pmsWindowDays,
            );
            break;
          } else {
            markRetrospectiveCycle(
              currStart,
              nextStart,
              lutealPhaseDays,
              pmsWindowDays,
            );
            currStart = nextStart;
          }
        }
      }
    }

    // 3. Process forecast cycles
    final predictedDays =
        <String, ({PredictionConfidenceLevel level, PredictedCycle cycle})>{};
    final predictionWindowDays =
        <String, ({PredictionConfidenceLevel level, PredictedCycle cycle})>{};

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

    // 4. Populate marks for each day of the Jalali month
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
  bool _isLegendExpanded = false;

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
    final lutealDays = CycleSettings.getLutealPhase(widget.settings);
    final pmsDays =
        int.tryParse(widget.settings[CycleSettings.keyPmsWindowDays] ?? '4') ??
        4;
    final avgL =
        widget.engineOutput?.stats.avgCycleLength ??
        (double.tryParse(
              widget.settings[CycleSettings.keyCycleLength] ?? '28',
            ) ??
            28.0);
    final forecast = widget.engineOutput?.forecast ?? const <PredictedCycle>[];

    _marks = CycleCalendarView.buildMonthMarks(
      month: widget.calendarMonth,
      periods: widget.periods,
      loggedDayKeys: _loggedDayKeys,
      forecast: forecast,
      defaultPeriodDuration: pDur,
      lutealPhaseDays: lutealDays,
      pmsWindowDays: pmsDays,
      avgCycleLength: avgL,
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

  Widget _buildCollapsibleLegend(RitmoColors colors, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: RitmoNeuSurface(
        sunken: true,
        radius: 14,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: 'راهنمای تقویم چرخه بدنی',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  RitmoHapticsPolicy.selection();
                  setState(() {
                    _isLegendExpanded = !_isLegendExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.info_circle,
                            size: 15,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'راهنمای رنگ‌ها و نشانه‌ها',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      AnimatedRotation(
                        turns: _isLegendExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeInOutCubic,
                        child: Icon(
                          CupertinoIcons.chevron_down,
                          size: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 240),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeInCubic,
              crossFadeState: _isLegendExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                child: CycleCalendarLegend(
                  marks: _marks,
                  settings: widget.settings,
                  activePhaseColor: widget.activePhaseColor,
                  showTitleAndDivider: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      child: RitmoCard.neumorphic(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            // Calendar Month Navigation Header
            CycleCalendarHeader(
              monthName: monthName,
              year: year,
              isCurrentMonth: isCurrentMonth,
              canJumpToNext: canJumpToNext,
              isPredictionOnlyMonth: isPredictionOnlyMonth,
              dominantConfidence: dominantConfidence,
              activePhaseColor: widget.activePhaseColor,
              onPreviousMonth: () => _changeMonth(-1),
              onNextMonth: () => _changeMonth(1),
              onGoToCurrentMonth: _goToCurrentMonth,
              onJumpToNextPeriod: _jumpToNextPredictedPeriod,
            ),

            const SizedBox(height: 10),

            // Weekday Headers Bar (شیار فرورفته نئومورفیک Debossed Trench)
            RitmoNeuSurface(
              sunken: true,
              radius: 12,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Row(
                children: weekdaysHeaders.map((header) {
                  final isFriday = header == 'جمعه';
                  return Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Text(
                            header,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isFriday
                                  ? colors.error.withValues(alpha: 0.85)
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 3),

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

            // Collapsible Accordion Legend (Default Collapsed)
            _buildCollapsibleLegend(colors, isDark),

            const SizedBox(height: 6),

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
    );
  }
}
