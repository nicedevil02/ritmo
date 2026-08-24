import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_absence_status.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_stats.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_summary.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_status_indicators.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// سه حالت اصلی نمای مرکز حرکت (P-08 / P-09)
enum MovementCenterView { hasSession, restDay, noPlan }

/// وضعیت‌های ۸ گانهٔ ورودی مرکز حرکت (P-08 / Entry States)
enum MovementCenterEntryState {
  brandNewUser,
  hasPlanTodaySession,
  todaySessionCompleted,
  pastPlannedTime,
  multiSessionsToday,
  recoveryDay,
  inProgressLiveSession,
  firstLaunchAfterCutover,
}

/// وضعیت‌های سه‌گانهٔ کنترلر مرکز حرکت (P-09)
sealed class MovementCenterState {
  const MovementCenterState();
}

class MovementCenterLoading extends MovementCenterState {
  const MovementCenterLoading();
}

class MovementCenterReady extends MovementCenterState {
  const MovementCenterReady({
    required this.view,
    required this.readiness,
    required this.weekStats,
    required this.tier,
    required this.selectedDate,
    required this.railDays,
    this.todayOccurrence,
    this.dayOccurrences = const [],
    this.activeLiveSession,
    this.absenceStatus = AbsenceStatus.none,
  });

  final MovementCenterView view; // hasSession | restDay | noPlan
  final ReadinessResult readiness;
  final MovementWeekStats weekStats;
  final MovementTier tier;
  final DateTime selectedDate;
  final List<MovementDayData> railDays;
  final MovementOccurrence? todayOccurrence;
  final List<MovementOccurrence> dayOccurrences;
  final MovementLiveSession? activeLiveSession;
  final AbsenceStatus absenceStatus;
}

class MovementCenterError extends MovementCenterState {
  const MovementCenterError(this.message);
  final String message;
}

/// کنترلر صفحهٔ مرکز حرکت (P-09)
class MovementCenterController extends ChangeNotifier {
  MovementCenterController({
    required this.occurrenceService,
    MovementSessionService? sessionService,
    StrengthProgramService? strengthProgramService,
    dynamic crossModuleFeedbackService,
    MovementReadinessService? readinessService,
    MovementPreferencesService? preferencesService,
    DateTime? initialDate,
    this._isFirstLaunchAfterCutover = false,
  })  : sessionService = sessionService ?? MovementSessionService(),
        strengthProgramService = strengthProgramService ?? StrengthProgramService(),
        readinessService = readinessService ?? MovementReadinessService(),
        preferencesService = preferencesService ?? MovementPreferencesService() {
    final now = initialDate ?? DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _initEventSubscriptions();
  }

  final MovementOccurrenceService occurrenceService;
  final MovementSessionService sessionService;
  final StrengthProgramService strengthProgramService;
  final MovementReadinessService readinessService;
  final MovementPreferencesService preferencesService;

  bool _isFirstLaunchAfterCutover;
  late DateTime _selectedDate;
  MovementCenterState _state = const MovementCenterLoading();
  StreamSubscription? _eventSub;

  List<MovementOccurrence> _weekOccurrences = [];
  List<MovementOccurrence> _currentDayOccurrences = [];
  MovementWeekSummary _summary = const MovementWeekSummary();
  MovementStrengthProgram? _strengthProgram;
  MovementLiveSession? _activeLiveSession;
  ReadinessResult _readiness = const ReadinessNoData();
  MovementWeekStats _weekStats = const MovementWeekStats.empty();
  MovementTier _tier = MovementTier.one;
  AbsenceStatus _absenceStatus = AbsenceStatus.none;
  DateTime? _cachedSaturday;
  DateTime? _cachedFriday;

  MovementCenterState get state => _state;
  DateTime get selectedDate => _selectedDate;
  bool get isFirstLaunchAfterCutover => _isFirstLaunchAfterCutover;
  MovementWeekSummary get summary => _summary;
  MovementStrengthProgram? get strengthProgram => _strengthProgram;
  List<MovementOccurrence> get selectedDayOccurrences => _currentDayOccurrences;
  List<MovementDayData> get weekDays =>
      state is MovementCenterReady ? (state as MovementCenterReady).railDays : const [];

  MovementCenterEntryState get entryState {
    if (_isFirstLaunchAfterCutover) {
      return MovementCenterEntryState.firstLaunchAfterCutover;
    }
    if (_activeLiveSession != null) {
      return MovementCenterEntryState.inProgressLiveSession;
    }
    if (_currentDayOccurrences.length > 1) {
      return MovementCenterEntryState.multiSessionsToday;
    }
    if (_currentDayOccurrences.isNotEmpty) {
      final occ = _currentDayOccurrences.first;
      if (occ.isRestDay) {
        return MovementCenterEntryState.recoveryDay;
      }
      if (occ.isCompleted) {
        return MovementCenterEntryState.todaySessionCompleted;
      }
      if (occ.status == MovementOccurrenceStatus.late) {
        return MovementCenterEntryState.pastPlannedTime;
      }
      return MovementCenterEntryState.hasPlanTodaySession;
    }
    if (_weekOccurrences.isEmpty &&
        _summary.plannedCount == 0 &&
        _summary.completedCount == 0 &&
        _strengthProgram == null) {
      return MovementCenterEntryState.brandNewUser;
    }
    return MovementCenterEntryState.recoveryDay;
  }

  void dismissCutoverCallout() {
    _isFirstLaunchAfterCutover = false;
    notifyListeners();
  }

  /// ثبت خوش‌بینانه تکمیل جلسه با بازگشت آنی در صورت خطای دیتابیس
  Future<bool> optimisticCompleteOccurrence(String occurrenceId) async {
    MovementOccurrence? originalOcc;
    for (final o in _weekOccurrences) {
      if (o.id == occurrenceId) {
        originalOcc = o;
        break;
      }
    }
    if (originalOcc == null) return false;
    final originalStatus = originalOcc.status;

    final updated = originalOcc.copyWith(status: MovementOccurrenceStatus.completed);
    _weekOccurrences = _weekOccurrences.map((o) => o.id == occurrenceId ? updated : o).toList();
    _currentDayOccurrences = _currentDayOccurrences.map((o) => o.id == occurrenceId ? updated : o).toList();
    _applyCachedDaySelection();
    notifyListeners();

    try {
      await occurrenceService.updateOccurrenceStatus(occurrenceId, MovementOccurrenceStatus.completed);
      return true;
    } catch (_) {
      final reverted = originalOcc.copyWith(status: originalStatus);
      _weekOccurrences = _weekOccurrences.map((o) => o.id == occurrenceId ? reverted : o).toList();
      _currentDayOccurrences = _currentDayOccurrences.map((o) => o.id == occurrenceId ? reverted : o).toList();
      _applyCachedDaySelection();
      notifyListeners();
      return false;
    }
  }

  void _initEventSubscriptions() {
    _eventSub = RitmoEventBus().onEvents.listen((event) {
      if (event.type == RitmoEventType.workoutLogChanged.code ||
          event.type == RitmoEventType.occurrenceCompleted.code ||
          event.type == RitmoEventType.occurrenceSkipped.code) {
        refresh();
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  void selectDay(DateTime date) {
    setSelectedDate(date);
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    if (_cachedSaturday != null &&
        _cachedFriday != null &&
        !_selectedDate.isBefore(_cachedSaturday!) &&
        !_selectedDate.isAfter(_cachedFriday!)) {
      _applyCachedDaySelection();
      notifyListeners();
      return;
    }
    loadData();
  }

  Future<void> refresh() async {
    await loadData();
  }

  void _applyCachedDaySelection() {
    final selectedIso = _selectedDate.toIso8601String().split('T').first;
    _currentDayOccurrences = _weekOccurrences
        .where((occ) => occ.dateIso == selectedIso)
        .toList();

    MovementOccurrence? primaryOcc;
    if (_currentDayOccurrences.isNotEmpty) {
      primaryOcc = _currentDayOccurrences.firstWhere(
        (o) => o.isInProgress,
        orElse: () => _currentDayOccurrences.firstWhere(
          (o) => !o.isCompleted && !o.isRestDay && !o.isSkipped,
          orElse: () => _currentDayOccurrences.first,
        ),
      );
    }

    MovementCenterView view;
    if (_currentDayOccurrences.isEmpty) {
      view = MovementCenterView.noPlan;
    } else if (_currentDayOccurrences.every((o) => o.isRestDay)) {
      view = MovementCenterView.restDay;
    } else {
      view = MovementCenterView.hasSession;
    }

    final railDays = _buildRailDays(_cachedSaturday!, _weekOccurrences);

    _state = MovementCenterReady(
      view: view,
      readiness: _readiness,
      weekStats: _weekStats,
      tier: _tier,
      selectedDate: _selectedDate,
      railDays: railDays,
      todayOccurrence: primaryOcc,
      dayOccurrences: _currentDayOccurrences,
      activeLiveSession: _activeLiveSession,
      absenceStatus: _absenceStatus,
    );
  }

  /// بارگذاری موازی داده‌های مرکز حرکت
  Future<void> loadData() async {
    _state = const MovementCenterLoading();
    notifyListeners();

    try {
      final sat = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ).subtract(Duration(days: (_selectedDate.weekday % 7 + 1) % 7));
      final fri = DateTime(sat.year, sat.month, sat.day + 6);
      final startIso = sat.toIso8601String().split('T').first;
      final endIso = fri.toIso8601String().split('T').first;

      _cachedSaturday = sat;
      _cachedFriday = fri;

      final allSevenDaysIso = List.generate(7, (i) {
        final d = DateTime(sat.year, sat.month, sat.day + i);
        return d.toIso8601String().split('T').first;
      });

      final fGrouped = occurrenceService.getWeekOccurrencesGrouped(startIso, endIso).catchError((_) async {
        try {
          final list = await occurrenceService.getOccurrencesForRange(startIso, endIso);
          final Map<String, List<MovementOccurrence>> map = {};
          for (final occ in list) {
            map.putIfAbsent(occ.dateIso, () => []).add(occ);
          }
          return map;
        } catch (_) {
          return <String, List<MovementOccurrence>>{};
        }
      });

      final fWeekStats = occurrenceService.weekStats(_selectedDate).catchError((_) => const MovementWeekStats.empty());
      final fReadiness = readinessService.getTodayReadinessResult(date: _selectedDate).catchError((_) => const ReadinessNoData());
      final fTier = preferencesService.resolveTier().catchError((_) => MovementTier.one);
      final fAbsence = occurrenceService.checkAbsence(_selectedDate).catchError((_) => AbsenceStatus.none);
      final fSession = sessionService.getActiveOrPausedSession().catchError((_) async {
        try {
          return await sessionService.getActiveSession();
        } catch (_) {
          return null;
        }
      });
      final fStrength = strengthProgramService.getCurrentProgram().catchError((_) => null);
      final fSummary = occurrenceService.getWeekSummary(startIso, endIso, allSevenDaysIso).catchError((_) => const MovementWeekSummary());

      final results = await Future.wait([
        fGrouped,
        fWeekStats,
        fReadiness,
        fTier,
        fAbsence,
        fSession,
        fStrength,
        fSummary,
      ]);

      final grouped = results[0] as Map<String, List<MovementOccurrence>>;
      _weekOccurrences = grouped.values.expand((list) => list).toList();
      _weekStats = results[1] as MovementWeekStats;
      _readiness = results[2] as ReadinessResult;
      _tier = results[3] as MovementTier;
      _absenceStatus = results[4] as AbsenceStatus;
      _activeLiveSession = results[5] as MovementLiveSession?;
      _strengthProgram = results[6] as MovementStrengthProgram?;
      _summary = results[7] as MovementWeekSummary;

      _applyCachedDaySelection();
    } catch (e) {
      _state = MovementCenterError(e.toString());
    }

    notifyListeners();
  }

  List<MovementDayData> _buildRailDays(
    DateTime saturday,
    List<MovementOccurrence> occurrences,
  ) {
    const dayNames = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = today.toIso8601String().split('T').first;
    final selectedIso = _selectedDate.toIso8601String().split('T').first;

    final occByDate = <String, List<MovementOccurrence>>{};
    for (final occ in occurrences) {
      occByDate.putIfAbsent(occ.dateIso, () => []).add(occ);
    }

    return List.generate(7, (i) {
      final d = DateTime(saturday.year, saturday.month, saturday.day + i);
      final j = Jalali.fromDateTime(d);
      final dIso = d.toIso8601String().split('T').first;
      final dayOccs = occByDate[dIso] ?? [];

      MovementDaySlotState slotState;
      if (dIso == selectedIso && dIso == todayIso) {
        slotState = MovementDaySlotState.todayAndSelected;
      } else if (dIso == selectedIso) {
        slotState = MovementDaySlotState.selected;
      } else if (dIso == todayIso) {
        slotState = MovementDaySlotState.today;
      } else if (dayOccs.isEmpty && d.isBefore(today)) {
        slotState = MovementDaySlotState.pastEmpty;
      } else {
        slotState = MovementDaySlotState.normal;
      }

      final statuses = dayOccs.map<MovementDayStatus>((o) {
        if (o.isCompleted) return MovementDayStatus.completed;
        if (o.isRestDay) return MovementDayStatus.recovery;
        return MovementDayStatus.planned;
      }).toList();

      final completedCount = dayOccs.where((o) => o.isCompleted).length;

      return MovementDayData(
        date: d,
        dayName: dayNames[i],
        dayNumber: j.day,
        monthName: j.formatter.mN,
        state: slotState,
        statuses: statuses,
        sessionCount: dayOccs.length,
        completedCount: completedCount,
      );
    });
  }
}
