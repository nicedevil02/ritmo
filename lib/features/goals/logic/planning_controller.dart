import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/goals/logic/capacity_models.dart';
import 'package:ritmo/features/goals/logic/execution_factor.dart';
import 'package:ritmo/features/goals/logic/goals_repository.dart';
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
          agendaMap = await DayAgendaService.instance.agendaForRange(
            startDate,
            endDate,
            options: const AgendaQueryOptions(
              excludeDomains: {AgendaDomain.commitment},
            ),
          );
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

      int wakingMinutes = 960;
      if (DatabaseHelper.rawDatabase != null) {
        try {
          final sRows = await DatabaseHelper.rawDatabase!.query(
            'app_settings',
            where: "key = 'sleep_target_duration_minutes'",
            limit: 1,
          );
          if (sRows.isNotEmpty) {
            final dur = int.tryParse(sRows.first['value']?.toString() ?? '');
            if (dur != null && dur > 0) {
              wakingMinutes = (1440 - dur).clamp(720, 1140);
            }
          }
        } catch (_) {}
      }

      const calc = WeekCapacityCalculator();
      capacities = calc.computeWeek(
        loads: dayLoads,
        wakingMinutes: wakingMinutes,
        profile: reserveProfile,
        executionFactor: executionFactorValue,
      );

      if (activeCycle != null) {
        commitments = await _repo.commitmentsOf(activeCycle!.id);
        allocations = await _repo.allocationsOf(activeCycle!.id);

        if (allocations.isNotEmpty) {
          // Single source of truth: Load saved allocations!
          final placedIds = allocations.map((a) => a.commitmentId).toSet();
          final unplaced = commitments
              .where((c) => !placedIds.contains(c.id))
              .map((c) => UnplacedCommitment(
                    commitment: c,
                    reason: UnplacedReason.capacityExceeded,
                    detailFa: c.planningReason ?? 'ظرفیت کافی در روزهای مجاز پیدا نشد',
                  ))
              .toList();

          final explMap = <String, String>{};
          for (final a in allocations) {
            final c = commitments.firstWhere(
              (comm) => comm.id == a.commitmentId,
              orElse: () => PlanningCommitment(
                id: a.commitmentId,
                cycleId: activeCycle!.id,
                title: 'تعهد',
                createdAt: 0,
                updatedAt: 0,
              ),
            );
            explMap[a.id] = c.planningReason ?? 'اولویت عادی';
          }

          allocationResult = AllocationPlanResult(
            placed: allocations,
            partial: const [],
            unplaced: unplaced,
            explanations: explMap,
          );
        } else if (commitments.isNotEmpty) {
          final goals = await GoalsRepository.instance.getGoals();
          final goalById = {for (final g in goals) g.id: g};

          final daysToDeadlines = <String, int>{};
          final paceGaps = <String, double>{};
          final daysSinceLastProgress = <String, int>{};

          for (final c in commitments) {
            final g = c.goalId == null ? null : goalById[c.goalId];
            if (g == null) continue;

            if (g.targetDate != null) {
              final parsedTarget = DateTime.tryParse(g.targetDate!);
              if (parsedTarget != null) {
                daysToDeadlines[c.id] = parsedTarget.difference(now).inDays;
              }
            }
            final createdAtDt = DateTime.fromMillisecondsSinceEpoch(g.createdAt);
            final targetDt = g.targetDate != null ? DateTime.tryParse(g.targetDate!) : null;
            double expected = 0.5;
            if (targetDt != null && targetDt.isAfter(createdAtDt)) {
              final totalDuration = targetDt.difference(createdAtDt).inSeconds;
              final elapsed = now.difference(createdAtDt).inSeconds;
              if (totalDuration > 0) {
                expected = (elapsed / totalDuration).clamp(0.0, 1.0);
              }
            }
            final actual = g.progressCache;
            final gap = (expected - actual).clamp(0.0, 1.0);
            paceGaps[c.id] = gap;
            if (c.goalId != null) {
              paceGaps[c.goalId!] = gap;
            }
            if (g.lastActivityAt != null && g.lastActivityAt! > 0) {
              daysSinceLastProgress[c.id] = now.difference(DateTime.fromMillisecondsSinceEpoch(g.lastActivityAt!)).inDays;
            }
          }

          int energySamples = 0;
          if (DatabaseHelper.rawDatabase != null) {
            try {
              final energyLogs = await DatabaseHelper.rawDatabase!.query('energy_logs');
              energySamples = energyLogs.length;
            } catch (_) {}
          }

          const engine = WeekAllocationEngine();
          allocationResult = engine.allocate(
            commitments: commitments,
            capacities: capacities,
            dayLoads: dayLoads,
            todayKey: todayKey,
            daysToDeadlines: daysToDeadlines,
            paceGaps: paceGaps,
            daysSinceLastProgress: daysSinceLastProgress,
            energySamples: energySamples,
          );
          for (final a in allocationResult!.placed) {
            await _repo.insertAllocation(a);
          }
          allocations = allocationResult!.placed;
        } else {
          allocationResult = null;
        }
      } else {
        commitments = [];
        allocations = [];
        allocationResult = null;
      }

      status = PlanningStateStatus.ready;
    } catch (e, st) {
      RitmoLogger.error('PlanningController loadHorizon failed: $e', error: e, stack: st);
      status = PlanningStateStatus.failed;
      errorMessage = 'بارگذاری برنامه ناموفق بود.';
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
