import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_preferences_service.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_absence_status.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_stats.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_status_indicators.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// سه حالت اصلی نمای مرکز حرکت (P-08 / P-09)
enum MovementCenterView { hasSession, restDay, noPlan }

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
    this.absenceStatus = AbsenceStatus.none,
  });

  final MovementCenterView view; // hasSession | restDay | noPlan
  final ReadinessResult readiness;
  final MovementWeekStats weekStats;
  final MovementTier tier;
  final DateTime selectedDate;
  final List<MovementDayData> railDays;
  final MovementOccurrence? todayOccurrence;
  final AbsenceStatus absenceStatus;
}

class MovementCenterError extends MovementCenterState {
  const MovementCenterError(this.message);
  final String message;
}

/// کنترلر صفحهٔ مرکز حرکت (P-09 — زیر ۲۵۰ خط)
class MovementCenterController extends ChangeNotifier {
  MovementCenterController({
    required this.occurrenceService,
    MovementReadinessService? readinessService,
    MovementPreferencesService? preferencesService,
    DateTime? initialDate,
  })  : readinessService = readinessService ?? MovementReadinessService(),
        preferencesService =
            preferencesService ?? MovementPreferencesService() {
    final now = initialDate ?? DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _initEventSubscriptions();
    loadData();
  }

  final MovementOccurrenceService occurrenceService;
  final MovementReadinessService readinessService;
  final MovementPreferencesService preferencesService;

  late DateTime _selectedDate;
  MovementCenterState _state = const MovementCenterLoading();
  StreamSubscription? _eventSub;

  MovementCenterState get state => _state;
  DateTime get selectedDate => _selectedDate;

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

  void setSelectedDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    loadData();
  }

  Future<void> refresh() async {
    await loadData();
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
      final fri = sat.add(const Duration(days: 6));
      final startIso = sat.toIso8601String().split('T').first;
      final endIso = fri.toIso8601String().split('T').first;
      final selectedIso = _selectedDate.toIso8601String().split('T').first;

      final weekOccurrences =
          await occurrenceService.getOccurrencesForRange(startIso, endIso);
      final weekStats = await occurrenceService.weekStats(_selectedDate);
      final readiness = await readinessService.getTodayReadinessResult(
        date: _selectedDate,
      );
      final tier = await preferencesService.resolveTier();
      final absenceStatus =
          await occurrenceService.checkAbsence(_selectedDate);

      // ۲. استخراج جلسهٔ امروز
      MovementOccurrence? todayOcc;
      for (final occ in weekOccurrences) {
        if (occ.dateIso == selectedIso) {
          todayOcc = occ;
          break;
        }
      }

      // ۳. تشخیص حالت View
      MovementCenterView view;
      if (todayOcc != null) {
        if (todayOcc.isRestDay) {
          view = MovementCenterView.restDay;
        } else {
          view = MovementCenterView.hasSession;
        }
      } else {
        view = MovementCenterView.noPlan;
      }

      // ۴. ساخت داده‌های ریل هفتگی
      final railDays = _buildRailDays(sat, weekOccurrences);

      _state = MovementCenterReady(
        view: view,
        readiness: readiness,
        weekStats: weekStats,
        tier: tier,
        selectedDate: _selectedDate,
        railDays: railDays,
        todayOccurrence: todayOcc,
        absenceStatus: absenceStatus,
      );
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
      final d = saturday.add(Duration(days: i));
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
