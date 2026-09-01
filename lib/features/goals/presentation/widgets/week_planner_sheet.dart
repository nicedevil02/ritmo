import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/goals/logic/capacity_models.dart';
import 'package:ritmo/features/goals/logic/execution_factor.dart';
import 'package:ritmo/features/goals/logic/goals_repository.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/logic/planning_week.dart';
import 'package:ritmo/features/goals/logic/week_allocation_engine.dart';
import 'package:ritmo/features/goals/logic/week_capacity_calculator.dart';
import 'package:ritmo/features/goals/models/goal_models.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';

class WeekPlannerSheet extends StatefulWidget {
  const WeekPlannerSheet({
    super.key,
    required this.onSaved,
  });

  final VoidCallback onSaved;

  static void show(BuildContext context, {required VoidCallback onSaved}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.94,
        minChildSize: 0.0,
        maxChildSize: 0.94,
        snap: true,
        expand: false,
        builder: (context, scrollController) =>
            WeekPlannerSheet(onSaved: onSaved),
      ),
    );
  }

  @override
  State<WeekPlannerSheet> createState() => _WeekPlannerSheetState();
}

enum CandidateSource {
  activeGoalSteps,
  overdueTasks,
  routines,
  monthFocus,
}

extension CandidateSourceExt on CandidateSource {
  String get titleFa {
    switch (this) {
      case CandidateSource.activeGoalSteps:
        return 'گام‌های هدف‌های فعال';
      case CandidateSource.overdueTasks:
        return 'کارهای معوق هفته';
      case CandidateSource.routines:
        return 'روتین‌های روزانه';
      case CandidateSource.monthFocus:
        return 'تمرکزهای ماه';
    }
  }
}

class _WeekPlannerSheetState extends State<WeekPlannerSheet> {
  ReserveProfile _selectedProfile = ReserveProfile.balanced;
  bool _isBuilding = false;
  bool _showWizard = false;

  // Marked light days
  final Set<String> _markedLightDays = {};

  final Map<CandidateSource, bool> _candidateSelection = {
    CandidateSource.activeGoalSteps: true,
    CandidateSource.overdueTasks: true,
    CandidateSource.routines: true,
    CandidateSource.monthFocus: true,
  };

  Map<String, DayAgenda> _cachedAgendaMap = {};
  double _executionFactorValue = 1.0;
  int _wakingMinutes = 960;

  final Map<String, int> _daysToDeadlines = {};
  final Map<String, double> _paceGaps = {};
  final Map<String, int> _daysSinceLastProgress = {};
  int _energySamples = 0;

  List<PlanningCommitment> _loadedCandidates = [];
  AllocationPlanResult? _previewResult;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final todayKey = DayKey.from(now).value;
    final candidates = <PlanningCommitment>[];

    try {
      final savedLightDays = await PlanningRepository.instance.getLightDays();
      _markedLightDays.addAll(savedLightDays);

      final weekKeys = PlanningWeek.dayKeysOfWeekContaining(now);
      final startDate = (weekKeys.isNotEmpty ? DateTime.tryParse(weekKeys.first) : null) ?? now;
      final endDate = (weekKeys.isNotEmpty ? DateTime.tryParse(weekKeys.last) : null) ?? now.add(const Duration(days: 6));

      if (DatabaseHelper.rawDatabase != null) {
        try {
          _cachedAgendaMap = await DayAgendaService.instance.agendaForRange(
            startDate,
            endDate,
            options: const AgendaQueryOptions(
              excludeDomains: {AgendaDomain.commitment},
            ),
          );
        } catch (_) {}

        try {
          final ef = await ExecutionFactor.computeForPastDays(daysHistory: 21);
          _executionFactorValue = ef.value;
        } catch (_) {}

        try {
          final sRows = await DatabaseHelper.rawDatabase!.query(
            'app_settings',
            where: "key = 'sleep_target_duration_minutes'",
            limit: 1,
          );
          if (sRows.isNotEmpty) {
            final dur = int.tryParse(sRows.first['value']?.toString() ?? '');
            if (dur != null && dur > 0) {
              _wakingMinutes = (1440 - dur).clamp(720, 1140);
            }
          }
        } catch (_) {}
      }

      final goals = await GoalsRepository.instance.getGoals();
      final goalById = {for (final g in goals) g.id: g};
      final activeGoals = goals.where((g) => g.status == 'ACTIVE').toList();
      final stepsMap = await GoalsRepository.instance.getGoalSteps();

      _daysToDeadlines.clear();
      _paceGaps.clear();
      _daysSinceLastProgress.clear();

      for (final g in goals) {
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
        _paceGaps[g.id] = gap;
      }

      // 1. Fetch active goals steps
      if (_candidateSelection[CandidateSource.activeGoalSteps] == true) {
        for (final g in activeGoals) {
          final steps = stepsMap[g.id] ?? [];
          for (final step in steps) {
            if (!step.isCompleted) {
              final estMin = (step.estimatedMinutes ?? 30).clamp(15, 180);
              final workKind = (estMin >= 45 && (g.weight >= 1.5 || g.goalType == GoalLevel.daily))
                  ? WorkKind.deep
                  : WorkKind.light;
              candidates.add(
                PlanningCommitment(
                  id: 'commit_step_${step.id}_$nowMs',
                  cycleId: '',
                  title: step.title,
                  sourceType: CommitmentSourceType.goalStep,
                  sourceId: step.id,
                  goalId: g.id,
                  importance: (g.weight >= 1.5 || g.goalType == GoalLevel.daily)
                      ? CommitmentImportance.must
                      : CommitmentImportance.should,
                  effortMinutes: estMin,
                  workKind: workKind,
                  createdAt: nowMs,
                  updatedAt: nowMs,
                ),
              );
            }
          }
        }
      }

      // 2. Fetch month cycle commitments if active
      if (_candidateSelection[CandidateSource.monthFocus] == true) {
        final monthCycle = await PlanningRepository.instance.activeCycle(PlanningHorizon.month, todayKey);
        if (monthCycle != null) {
          final monthCommits = await PlanningRepository.instance.commitmentsOf(monthCycle.id);
          for (final mc in monthCommits) {
            if (mc.status != CommitmentStatus.done && mc.status != CommitmentStatus.dropped) {
              candidates.add(
                PlanningCommitment(
                  id: 'commit_month_${mc.id}_$nowMs',
                  cycleId: '',
                  title: mc.title,
                  sourceType: CommitmentSourceType.manual,
                  importance: mc.importance,
                  effortMinutes: (mc.effortMinutes / 4).round().clamp(15, 180),
                  workKind: mc.workKind,
                  createdAt: nowMs,
                  updatedAt: nowMs,
                ),
              );
            }
          }
        }
      }

      // 3. Fetch overdue tasks if selected
      if (_candidateSelection[CandidateSource.overdueTasks] == true && DatabaseHelper.rawDatabase != null) {
        final taskRows = await DatabaseHelper.rawDatabase!.query(
          'simple_tasks',
          where: 'isDone = 0 AND dueDate IS NOT NULL AND dueDate < ?',
          whereArgs: [todayKey],
          limit: 10,
        );
        for (final tr in taskRows) {
          final taskId = tr['id'] as String;
          final title = tr['title'] as String;
          candidates.add(
            PlanningCommitment(
              id: 'commit_task_${taskId}_$nowMs',
              cycleId: '',
              title: title,
              sourceType: CommitmentSourceType.task,
              sourceId: taskId,
              importance: CommitmentImportance.should,
              effortMinutes: 30,
              workKind: WorkKind.light,
              createdAt: nowMs,
              updatedAt: nowMs,
            ),
          );
        }
      }

      // 4. Fetch routines if selected
      if (_candidateSelection[CandidateSource.routines] == true && DatabaseHelper.rawDatabase != null) {
        final rRows = await DatabaseHelper.rawDatabase!.query(
          'routines',
          where: 'isArchived = 0 AND routineType = ?',
          whereArgs: ['flexible'],
          limit: 5,
        );
        for (final rr in rRows) {
          final rid = rr['id'] as String;
          final title = rr['title'] as String;
          final targetDuration = (rr['targetDurationMinutes'] as num?)?.toInt() ?? 30;
          candidates.add(
            PlanningCommitment(
              id: 'commit_routine_${rid}_$nowMs',
              cycleId: '',
              title: title,
              sourceType: CommitmentSourceType.routine,
              sourceId: rid,
              importance: CommitmentImportance.could,
              effortMinutes: targetDuration.clamp(15, 90),
              workKind: WorkKind.light,
              createdAt: nowMs,
              updatedAt: nowMs,
            ),
          );
        }
      }

      for (final c in candidates) {
        final g = c.goalId == null ? null : goalById[c.goalId];
        if (g != null) {
          if (g.targetDate != null) {
            final parsedTarget = DateTime.tryParse(g.targetDate!);
            if (parsedTarget != null) {
              _daysToDeadlines[c.id] = parsedTarget.difference(now).inDays;
            }
          }
          if (_paceGaps[g.id] != null) {
            _paceGaps[c.id] = _paceGaps[g.id]!;
          }
          if (g.lastActivityAt != null && g.lastActivityAt! > 0) {
            _daysSinceLastProgress[c.id] = now.difference(DateTime.fromMillisecondsSinceEpoch(g.lastActivityAt!)).inDays;
          }
        }
      }

      if (DatabaseHelper.rawDatabase != null) {
        try {
          final energyLogs = await DatabaseHelper.rawDatabase!.query('energy_logs');
          _energySamples = energyLogs.length;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[WeekPlannerSheet] loadCandidates error: $e');
    }

    if (candidates.isEmpty) {
      // Fallback foundational commitments if none defined yet
      candidates.add(
        PlanningCommitment(
          id: 'comm_default_1_$nowMs',
          cycleId: '',
          title: 'پیشبرد اهداف کاری و درسی',
          importance: CommitmentImportance.must,
          effortMinutes: 90,
          workKind: WorkKind.deep,
          createdAt: nowMs,
          updatedAt: nowMs,
        ),
      );
      candidates.add(
        PlanningCommitment(
          id: 'comm_default_2_$nowMs',
          cycleId: '',
          title: 'مرور و بازبینی هفتگی',
          importance: CommitmentImportance.should,
          effortMinutes: 45,
          workKind: WorkKind.light,
          createdAt: nowMs,
          updatedAt: nowMs,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _loadedCandidates = candidates;
      });
      _runAllocationPreview();
    }
  }

  void _runAllocationPreview() {
    final now = DateTime.now();
    final todayKey = DayKey.from(now).value;
    final weekKeys = PlanningWeek.dayKeysOfWeekContaining(now);

    const calc = WeekCapacityCalculator();
    final dayLoads = weekKeys.map((k) {
      final dayAgenda = _cachedAgendaMap[k];
      final items = (dayAgenda?.items as List?) ?? [];
      final occupiedMin = items.fold<int>(0, (acc, item) => acc + ((item.durationMinutes as int?) ?? 30));
      final fixedCount = items.where((i) => i.itemType == AgendaItemType.fixed || i.timeOfDay != null).length;
      final deepCount = items.where((i) => ((i.durationMinutes as int?) ?? 0) >= 45).length;

      return DayLoad(
        dayKey: k,
        occupiedMinutes: occupiedMin,
        fixedCount: fixedCount,
        deepCount: deepCount,
        userMarkedLight: _markedLightDays.contains(k),
      );
    }).toList();

    final capacities = calc.computeWeek(
      loads: dayLoads,
      wakingMinutes: _wakingMinutes,
      profile: _selectedProfile,
      executionFactor: _executionFactorValue,
    );

    const engine = WeekAllocationEngine();
    _previewResult = engine.allocate(
      commitments: _loadedCandidates,
      capacities: capacities,
      dayLoads: dayLoads,
      todayKey: todayKey,
      daysToDeadlines: _daysToDeadlines,
      paceGaps: _paceGaps,
      daysSinceLastProgress: _daysSinceLastProgress,
      energySamples: _energySamples,
    );
  }

  Future<void> _buildAndSavePlan() async {
    if (_isBuilding) return;
    setState(() => _isBuilding = true);

    try {
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;
      final weekKeys = PlanningWeek.dayKeysOfWeekContaining(now);

      _runAllocationPreview();
      final allocResult = _previewResult;

      if (allocResult == null) {
        throw Exception('امکان تخصیص ظرفیت وجود ندارد');
      }

      final repo = PlanningRepository.instance;
      final draft = await repo.createDraft(
        horizon: PlanningHorizon.week,
        startDayKey: weekKeys.first,
        endDayKey: weekKeys.last,
        title: 'برنامهٔ هفته',
        nowMs: nowMs,
      );
      final activeCycle = await repo.activate(draft, nowMs: nowMs);

      for (final c in _loadedCandidates) {
        final expl = allocResult.placed
            .where((a) => a.commitmentId == c.id)
            .map((a) => allocResult.explanations[a.id])
            .firstOrNull;
        final cycleCommitment = c.copyWith(
          cycleId: activeCycle.id,
          status: CommitmentStatus.accepted,
          planningReason: expl,
          updatedAt: nowMs,
        );
        await repo.upsertCommitment(cycleCommitment);
      }

      for (final a in allocResult.placed) {
        await repo.insertAllocation(a);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      RitmoToast.show(context, 'برنامهٔ هفته با موفقیت ثبت شد ⚡');
    } catch (e, st) {
      debugPrint('[WeekPlannerSheet] build plan error: $e\n$st');
      if (mounted) {
        RitmoToast.show(context, 'خطا در ساخت برنامه هفته ❌');
      }
    } finally {
      if (mounted) setState(() => _isBuilding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final content = Column(
      children: [
        // Handle
        Center(
          child: Container(
            width: 38,
            height: 4.5,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: colors.textPrimary.withValues(alpha: isDark ? 0.18 : 0.22),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),

        // Canonical Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Leading (Right in RTL): Circular Tactile Close (X) Button
              GestureDetector(
                onTap: () {
                  RitmoHaptics.tap();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceElevated.withValues(alpha: 0.85)
                        : colors.textPrimary.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? colors.border.withValues(alpha: 0.35)
                          : colors.border.withValues(alpha: 0.15),
                      width: 0.85,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 15,
                    color: colors.textSecondary,
                  ),
                ),
              ),

              // Center: Title + Subtitle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'برنامه‌ریزی هوشمند هفته ✨',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تخصیص ظرفیت و چیدمان الگوریتمی',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Trailing (Left in RTL): 34x34 spacer
              const SizedBox(width: 34, height: 34),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _showWizard ? _buildWizardView(colors) : _buildQuickFlowView(colors),
          ),
        ),

        // Footer
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    setState(() {
                      _showWizard = !_showWizard;
                    });
                  },
                  child: Text(
                    _showWizard ? 'مسیر سریع' : 'شخصی‌سازی دقیق',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isBuilding ? null : _buildAndSavePlan,
                    child: _isBuilding
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text(
                            'ثبت و فعال‌سازی هفته',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
          ),
          child: RitmoGlassSheet(
            borderRadius: sheetRadius,
            padding: EdgeInsets.zero,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFlowView(RitmoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'برنامه‌ریزی سریع هفته (۹۰ ثانیه) ⚡',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'تخصیص هوشمند و متوازن تعهدات به روزهای هفته بدون تداخل.',
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          'پروفایل ذخیرهٔ زمان:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            _buildProfileChip('سبک (۳۵٪)', ReserveProfile.light, colors),
            const SizedBox(width: 8),
            _buildProfileChip('متعادل (۲۵٪)', ReserveProfile.balanced, colors),
            const SizedBox(width: 8),
            _buildProfileChip('فشرده (۱۵٪)', ReserveProfile.dense, colors),
          ],
        ),

        const SizedBox(height: 24),

        Text(
          'منابع و نامزدهای برنامه:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        ..._candidateSelection.keys.map((source) {
          final isChecked = _candidateSelection[source] ?? true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: CheckboxListTile(
                value: isChecked,
                activeColor: colors.primary,
                title: Text(
                  source.titleFa,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _candidateSelection[source] = val ?? true;
                  });
                  _loadCandidates();
                },
              ),
            ),
          );
        }),

        if (_previewResult != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'پیش‌نمایش تخصیص:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '+ ${PersianDigits.toPersian(_previewResult!.placed.length.toString())} تخصیص برای ${_previewResult!.placed.map((a) => a.dayKey).toSet().length} روز آماده شد.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textPrimary,
                  ),
                ),
                if (_previewResult!.unplaced.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '! ${PersianDigits.toPersian(_previewResult!.unplaced.length.toString())} تعهد در ظرفیت جا نشد:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._previewResult!.unplaced.map((unp) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ${unp.commitment.title}: ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                unp.detailFa,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWizardView(RitmoColors colors) {
    final weekKeys = PlanningWeek.dayKeysOfWeekContaining(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'شخصی‌سازی دقیق هفته (۲ مرحله)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'تنظیم روزهای سبک (Light Days):',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weekKeys.map((dk) {
            final isLight = _markedLightDays.contains(dk);
            return FilterChip(
              label: Text(_getDayNameShort(dk)),
              selected: isLight,
              selectedColor: colors.primary.withValues(alpha: 0.2),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _markedLightDays.add(dk);
                  } else {
                    _markedLightDays.remove(dk);
                  }
                  _runAllocationPreview();
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        Text(
          'تعهدات فعال برای این هفته (${PersianDigits.toPersian(_loadedCandidates.length.toString())} مورد):',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        ..._loadedCandidates.map((c) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    c.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${PersianDigits.toPersian(c.effortMinutes.toString())} دقیقه',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProfileChip(String label, ReserveProfile profile, RitmoColors colors) {
    final isSelected = _selectedProfile == profile;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _selectedProfile = profile;
            _runAllocationPreview();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.3),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getDayNameShort(String dayKey) {
    final dt = DateTime.tryParse(dayKey) ?? DateTime.now();
    switch (dt.weekday) {
      case DateTime.saturday: return 'شنبه';
      case DateTime.sunday: return '۱شنبه';
      case DateTime.monday: return '۲شنبه';
      case DateTime.tuesday: return '۳شنبه';
      case DateTime.wednesday: return '۴شنبه';
      case DateTime.thursday: return '۵شنبه';
      case DateTime.friday: return 'جمعه';
      default: return '';
    }
  }
}
