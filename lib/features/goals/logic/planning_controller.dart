import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/goals/logic/capacity_models.dart';
import 'package:ritmo/features/goals/logic/execution_factor.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/logic/planning_week.dart';
import 'package:ritmo/features/goals/logic/week_allocation_engine.dart';
import 'package:ritmo/features/goals/logic/week_capacity_calculator.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';

enum PlanningStateStatus { loading, ready, failed }

class PlanningController extends ChangeNotifier {
  PlanningController({
    RitmoClock? clock,
    PlanningRepository? repo,
  })  : _clock = clock ?? const SystemClock(),
        _repo = repo ?? PlanningRepository.instance;

  final RitmoClock _clock;
  final PlanningRepository _repo;

  PlanningHorizon selectedHorizon = PlanningHorizon.week;
  PlanningStateStatus status = PlanningStateStatus.loading;
  String? errorMessage;

  PlanningCycle? activeCycle;
  List<PlanningCommitment> commitments = [];
  List<PlanningAllocation> allocations = [];
  List<DayCapacity> capacities = [];
  List<DayLoad> dayLoads = [];
  AllocationPlanResult? allocationResult;

  ReserveProfile reserveProfile = ReserveProfile.balanced;
  double executionFactorValue = 1.0;

  Future<void> loadHorizon(PlanningHorizon horizon) async {
    selectedHorizon = horizon;
    status = PlanningStateStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final now = _clock.now();
      final todayKey = DayKey.from(now).value;

      activeCycle = await _repo.activeCycle(horizon, todayKey);

      final weekDayKeys = PlanningWeek.dayKeysOfWeekContaining(now);
      final startDate = (weekDayKeys.isNotEmpty ? DateTime.tryParse(weekDayKeys.first) : null) ?? now;
      final endDate = (weekDayKeys.isNotEmpty ? DateTime.tryParse(weekDayKeys.last) : null) ?? now.add(const Duration(days: 6));

      Map<String, dynamic> agendaMap = {};
      if (DatabaseHelper.rawDatabase != null) {
        try {
          agendaMap = await DayAgendaService.instance.agendaForRange(startDate, endDate);
        } catch (e, st) {
          RitmoLogger.warning(
            'PlanningController agendaForRange error: $e',
            error: e,
            stack: st,
          );
        }
      }

      final lightDays = await _repo.getLightDays();
      final loads = <DayLoad>[];
      for (final key in weekDayKeys) {
        final dayAgenda = agendaMap[key];
        final items = (dayAgenda?.items as List?) ?? [];
        final occupiedMin = items.fold<int>(0, (acc, item) => acc + ((item.durationMinutes as int?) ?? 30));
        final fixedCount = items.where((i) => i.itemType == AgendaItemType.fixed || i.timeOfDay != null).length;
        final deepCount = items.where((i) => ((i.durationMinutes as int?) ?? 0) >= 45).length;

        loads.add(DayLoad(
          dayKey: key,
          occupiedMinutes: occupiedMin,
          fixedCount: fixedCount,
          deepCount: deepCount,
          userMarkedLight: lightDays.contains(key),
        ));
      }
      dayLoads = loads;

      if (DatabaseHelper.rawDatabase != null) {
        try {
          final ef = await ExecutionFactor.computeForPastDays(daysHistory: 21);
          executionFactorValue = ef.value;
        } catch (e, st) {
          RitmoLogger.warning(
            'PlanningController ExecutionFactor error: $e',
            error: e,
            stack: st,
          );
          executionFactorValue = 1.0;
        }
      } else {
        executionFactorValue = 1.0;
      }

      const calc = WeekCapacityCalculator();
      capacities = calc.computeWeek(
        loads: dayLoads,
        wakingMinutes: 960,
        profile: reserveProfile,
        executionFactor: executionFactorValue,
      );

      if (activeCycle != null) {
        commitments = await _repo.commitmentsOf(activeCycle!.id);
        allocations = await _repo.allocationsOf(activeCycle!.id);

        const engine = WeekAllocationEngine();
        allocationResult = engine.allocate(
          commitments: commitments,
          capacities: capacities,
          dayLoads: dayLoads,
          todayKey: todayKey,
        );
      } else {
        commitments = [];
        allocations = [];
        allocationResult = null;
      }

      status = PlanningStateStatus.ready;
    } catch (e, st) {
      debugPrint('[PlanningController] error loading horizon: $e\n$st');
      status = PlanningStateStatus.ready;
      commitments = [];
      allocations = [];
      capacities = [];
      dayLoads = [];
      allocationResult = null;
    }

    notifyListeners();
  }

  void changeHorizon(PlanningHorizon horizon) {
    if (selectedHorizon != horizon) {
      loadHorizon(horizon);
    }
  }
}
