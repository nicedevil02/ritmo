import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/goals/logic/capacity_models.dart';
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
      builder: (context) => WeekPlannerSheet(onSaved: onSaved),
    );
  }

  @override
  State<WeekPlannerSheet> createState() => _WeekPlannerSheetState();
}

class _WeekPlannerSheetState extends State<WeekPlannerSheet> {
  ReserveProfile _selectedProfile = ReserveProfile.balanced;
  bool _isBuilding = false;
  bool _showWizard = false;
  int _wizardStep = 0;

  // Marked light days
  final Set<String> _markedLightDays = {};

  final Map<String, bool> _candidateSelection = {
    'گام‌های هدف‌های فعال': true,
    'کارهای معوق هفته': true,
    'روتین‌های روزانه': true,
    'تمرکزهای ماه': true,
  };

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
    final candidates = <PlanningCommitment>[];

    try {
      // 1. Fetch active goals steps
      final goals = await GoalsRepository.instance.getGoals();
      final activeGoals = goals.where((g) => g.status == 'ACTIVE').toList();
      final stepsMap = await GoalsRepository.instance.getGoalSteps();

      for (final g in activeGoals) {
        final steps = stepsMap[g.id] ?? [];
        for (final step in steps) {
          if (!step.isCompleted) {
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
                effortMinutes: (step.estimatedMinutes ?? 30).clamp(15, 180),
                workKind: WorkKind.deep,
                createdAt: nowMs,
                updatedAt: nowMs,
              ),
            );
          }
        }
      }

      // 2. Fetch month cycle commitments if active
      final todayKey = DayKey.from(now).value;
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
      return DayLoad(
        dayKey: k,
        occupiedMinutes: 120,
        fixedCount: 1,
        deepCount: 0,
        userMarkedLight: _markedLightDays.contains(k),
      );
    }).toList();

    final capacities = calc.computeWeek(
      loads: dayLoads,
      wakingMinutes: 960,
      profile: _selectedProfile,
      executionFactor: 1.0,
    );

    const engine = WeekAllocationEngine();
    _previewResult = engine.allocate(
      commitments: _loadedCandidates,
      capacities: capacities,
      dayLoads: dayLoads,
      todayKey: todayKey,
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
        final cycleCommitment = c.copyWith(
          cycleId: activeCycle.id,
          status: CommitmentStatus.accepted,
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
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
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
        ),
      ),
    ),);
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

        ..._candidateSelection.keys.map((title) {
          final isChecked = _candidateSelection[title] ?? true;
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
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _candidateSelection[title] = val ?? true;
                  });
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
                  const SizedBox(height: 4),
                  Text(
                    '! ${PersianDigits.toPersian(_previewResult!.unplaced.length.toString())} تعهد در ظرفیت جا نشد.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.error,
                    ),
                  ),
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
          'شخصی‌سازی دقیق هفته (ویزارد ۴ مرحله‌ای)',
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
