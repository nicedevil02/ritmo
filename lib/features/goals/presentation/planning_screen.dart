import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';
import 'package:ritmo/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart';
import 'package:ritmo/features/goals/logic/goals_repository.dart';
import 'package:ritmo/features/goals/logic/planning_controller.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/logic/planning_week.dart';
import 'package:ritmo/features/goals/models/goal_models.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:ritmo/features/goals/presentation/widgets/create_commitment_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/month_plan_section.dart';
import 'package:ritmo/features/goals/presentation/widgets/visual_week_board.dart';
import 'package:ritmo/features/goals/presentation/widgets/week_planner_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/week_review_sheet.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({
    super.key,
    this.upcomingTimeline = const [],
    this.embedded = false,
    this.topPadding,
    this.controller,
  });

  final List<dynamic> upcomingTimeline;
  final bool embedded;
  final double? topPadding;
  final PlanningController? controller;

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  late final PlanningController _controller;
  final Set<String> _expandedDayKeys = {};
  List<GoalStep> _backlogSteps = [];
  Map<String, String> _goalTitlesMap = {};

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PlanningController();
    _controller.initListener();
    _controller.addListener(_onControllerChanged);
    if (widget.controller == null) {
      _controller.loadHorizon(PlanningHorizon.week);
      _loadBacklog();
    }
  }

  Future<void> _loadBacklog() async {
    try {
      final goals = await GoalsRepository.instance.getGoals();
      final stepsMap = await GoalsRepository.instance.getGoalSteps();
      final activeGoalIds = goals.where((g) => g.status == 'ACTIVE').map((g) => g.id).toSet();
      final goalTitles = {for (final g in goals) g.id: g.title};
      final backlog = <GoalStep>[];
      for (final gId in activeGoalIds) {
        final steps = stepsMap[gId] ?? [];
        for (final s in steps) {
          if (!s.isCompleted && (s.scheduledDate == null || s.scheduledDate!.isEmpty)) {
            backlog.add(s);
          }
        }
      }
      if (mounted) {
        setState(() {
          _goalTitlesMap = goalTitles;
          _backlogSteps = backlog;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  Widget _buildSegmentedControl(RitmoColors colors) {
    return CupertinoSlidingSegmentedControl<PlanningHorizon>(
      groupValue: _controller.selectedHorizon,
      thumbColor: colors.primary,
      backgroundColor: colors.card,
      children: {
        PlanningHorizon.day: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'امروز',
            style: TextStyle(
              fontSize: 13,
              fontWeight: _controller.selectedHorizon == PlanningHorizon.day
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _controller.selectedHorizon == PlanningHorizon.day
                  ? Colors.white
                  : colors.textPrimary,
            ),
          ),
        ),
        PlanningHorizon.week: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'این هفته',
            style: TextStyle(
              fontSize: 13,
              fontWeight: _controller.selectedHorizon == PlanningHorizon.week
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _controller.selectedHorizon == PlanningHorizon.week
                  ? Colors.white
                  : colors.textPrimary,
            ),
          ),
        ),
        PlanningHorizon.month: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'این ماه',
            style: TextStyle(
              fontSize: 13,
              fontWeight: _controller.selectedHorizon == PlanningHorizon.month
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _controller.selectedHorizon == PlanningHorizon.month
                  ? Colors.white
                  : colors.textPrimary,
            ),
          ),
        ),
      },
      onValueChanged: (val) {
        if (val != null) {
          _controller.changeHorizon(val);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (widget.embedded) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: _buildBody(context, header: _buildSegmentedControl(colors)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: RitmoGlassHeader(
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Center(child: _buildSegmentedControl(colors)),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, {Widget? header}) {
    final colors = context.colors;

    if (_controller.status == PlanningStateStatus.loading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_controller.status == PlanningStateStatus.failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                _controller.errorMessage ?? 'خطا در بارگذاری داده‌ها',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('تلاش مجدد'),
                onPressed: () =>
                    _controller.loadHorizon(_controller.selectedHorizon),
              ),
            ],
          ),
        ),
      );
    }

    switch (_controller.selectedHorizon) {
      case PlanningHorizon.day:
        return _buildTodayView(context, header: header);
      case PlanningHorizon.week:
        return _buildWeekView(context, header: header);
      case PlanningHorizon.month:
        return MonthPlanSection(
          controller: _controller,
          upcomingTimeline: widget.upcomingTimeline,
          header: header,
          topPadding: widget.topPadding,
        );
    }
  }

  Widget _buildTodayView(BuildContext context, {Widget? header}) {
    final colors = context.colors;
    final effectiveTop = widget.topPadding ?? 16.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(10, effectiveTop, 10, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null) ...[
            header,
            const SizedBox(height: 16),
          ],
          // Command card for today (U-03)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary.withValues(alpha: 0.2), colors.card],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'از برنامهٔ هفته: ${_controller.commitments.length} تعهد برای امروز مانده',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'می‌توانی فعالیت‌های امروزت را هوشمندانه بچینی.',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final todayKey = DayKey.from(DateTime.now()).value;
                    final todayDraft = DayPlanDraft(
                      planDate: todayKey,
                      items: _controller.commitments
                          .map(
                            (c) => DayPlanItemDraft(
                              title: c.title,
                              targetModule: 'goals',
                              startKind: 'FLEXIBLE',
                              durationMin: c.effortMinutes,
                              durationSource: 'USER_EXPLICIT',
                              recurrence: 'ONCE',
                              category: 'WORK',
                              confidence: 1.0,
                            ),
                          )
                          .toList(),
                      questions: const [],
                      suggestions: const [],
                    );

                    AiDayPlannerPreviewSheet.show(
                      context,
                      initialDraft: todayDraft,
                      mode: DayPlannerMode.standaloneCommit,
                      onSaved: () {
                        _controller.loadHorizon(PlanningHorizon.day);
                      },
                    );
                  },
                  icon: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'چیدمان امروز با ✨',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'تعهدات امروز:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (_controller.commitments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 44,
                    color: colors.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'امروز هیچ تعهدی نداری. نیازی به هدف قبلی نیست؛ می‌توانی هر کاری را برای امروز ثبت کنی.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            CreateCommitmentSheet.show(
                              context,
                              initialHorizon: PlanningHorizon.day,
                              onSaved: () =>
                                  _controller.loadHorizon(PlanningHorizon.day),
                            );
                          },
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            '+ افزودن تعهد برای امروز',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          WeekPlannerSheet.show(
                            context,
                            onSaved: () =>
                                _controller.loadHorizon(PlanningHorizon.day),
                          );
                        },
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text(
                          'برنامه‌ریزی هفته',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else ...[
            Column(
              children: _controller.commitments.map((c) {
                final isDone = c.status == CommitmentStatus.done;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDone
                          ? colors.primary.withValues(alpha: 0.3)
                          : colors.border.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          await HapticFeedback.lightImpact();
                          final updated = c.copyWith(
                            status: isDone
                                ? CommitmentStatus.accepted
                                : CommitmentStatus.done,
                            updatedAt: DateTime.now().millisecondsSinceEpoch,
                          );
                          await PlanningRepository.instance.upsertCommitment(
                            updated,
                          );
                          await _controller.loadHorizon(PlanningHorizon.day);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isDone
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: isDone
                                ? colors.primary
                                : colors.textSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style:
                                  RitmoTextStyles.body(
                                    isDone
                                        ? colors.textSecondary
                                        : colors.textPrimary,
                                  ).copyWith(
                                    fontWeight: FontWeight.bold,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                            Text(
                              '${PersianDigits.toPersian(c.effortMinutes.toString())} دقیقه · اولویت: ${c.importance.name.toUpperCase()}',
                              style: RitmoTextStyles.caption(
                                colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: colors.textSecondary,
                          size: 18,
                        ),
                        onSelected: (val) async {
                          if (val == 'drop') {
                            await PlanningRepository.instance.dropCommitment(
                              c.id,
                              reason: 'حذف دستی از امروز',
                              nowMs: DateTime.now().millisecondsSinceEpoch,
                            );
                            await _controller.loadHorizon(PlanningHorizon.day);
                          } else if (val == 'shrink') {
                            final half = (c.effortMinutes * 0.5).round().clamp(
                              15,
                              240,
                            );
                            await PlanningRepository.instance.upsertCommitment(
                              c.copyWith(effortMinutes: half),
                            );
                            await _controller.loadHorizon(PlanningHorizon.day);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'shrink',
                            child: Text('کوچک‌تر کن (۵۰٪)'),
                          ),
                          const PopupMenuItem(
                            value: 'drop',
                            child: Text('حذف از امروز'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                CreateCommitmentSheet.show(
                  context,
                  initialHorizon: PlanningHorizon.day,
                  onSaved: () => _controller.loadHorizon(PlanningHorizon.day),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                '+ افزودن تعهد دیگر برای امروز',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekView(BuildContext context, {Widget? header}) {
    final colors = context.colors;
    final effectiveTop = widget.topPadding ?? 16.0;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(10, effectiveTop, 10, 80),
            child: VisualWeekBoard(
              controller: _controller,
              colors: colors,
              isDark: Theme.of(context).brightness == Brightness.dark,
              header: header,
              backlogSteps: _backlogSteps,
              goalTitlesMap: _goalTitlesMap,
              onRefresh: () {
                _controller.loadHorizon(PlanningHorizon.week);
                _loadBacklog();
              },
            ),
          ),
        ),
      ],
    );
  }

  @visibleForTesting
  Widget buildLegacyWeekView(BuildContext context, {Widget? header}) {
    final colors = context.colors;
    final active = _controller.activeCycle;
    final totalCommittable = _controller.capacities.fold<int>(
      0,
      (acc, c) => acc + c.committableMinutes,
    );
    final totalCommitmentMinutes = _controller.commitments.fold<int>(
      0,
      (acc, c) => acc + c.effortMinutes,
    );
    final effectiveTop = widget.topPadding ?? 16.0;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.fromLTRB(10, effectiveTop, 10, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[
                  header,
                  const SizedBox(height: 16),
                ],
                // 1. Cycle status bar (U-04)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          active != null
                              ? 'برنامهٔ این هفته: فعال · نسخهٔ ${PersianDigits.toPersian(active.version.toString())}'
                              : 'هنوز برنامه‌ای برای این هفته نداری',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      if (active == null)
                        TextButton.icon(
                          onPressed: () {
                            WeekPlannerSheet.show(
                              context,
                              onSaved: () {
                                _controller.loadHorizon(PlanningHorizon.week);
                              },
                            );
                          },
                          icon: const Icon(Icons.auto_awesome, size: 14),
                          label: const Text('ساخت سریع'),
                        )
                      else
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'افزودن تعهد به این هفته',
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: colors.primary,
                                size: 20,
                              ),
                              onPressed: () {
                                CreateCommitmentSheet.show(
                                  context,
                                  initialHorizon: PlanningHorizon.week,
                                  onSaved: () => _controller.loadHorizon(
                                    PlanningHorizon.week,
                                  ),
                                );
                              },
                            ),
                            TextButton.icon(
                              onPressed: () {
                                WeekReviewSheet.show(
                                  context,
                                  cycle: active,
                                  allocations: _controller.allocations,
                                  commitments: _controller.commitments,
                                  onClosed: () {
                                    _controller.loadHorizon(
                                      PlanningHorizon.week,
                                    );
                                  },
                                );
                              },
                              icon: const Icon(
                                Icons.rate_review_outlined,
                                size: 16,
                              ),
                              label: const Text('مرور هفته'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Capacity bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ظرفیت هفته: ${PersianDigits.toPersian(totalCommittable.toString())} دقیقه',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            'تعهدها: ${PersianDigits.toPersian(totalCommitmentMinutes.toString())} دقیقه',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: totalCommitmentMinutes > totalCommittable
                                  ? colors.error
                                  : colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: totalCommittable > 0
                              ? (totalCommitmentMinutes / totalCommittable)
                                    .clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 8,
                          backgroundColor: colors.bg,
                          color: totalCommitmentMinutes > totalCommittable
                              ? colors.error
                              : colors.primary,
                        ),
                      ),
                      if (totalCommitmentMinutes > totalCommittable) ...[
                        const SizedBox(height: 6),
                        Text(
                          '${PersianDigits.toPersian((totalCommitmentMinutes - totalCommittable).toString())} دقیقه بیشتر از ظرفیت برنامه‌ریزی شده است.',
                          style: TextStyle(fontSize: 11, color: colors.error),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Seven Day Rows (Saturday to Friday)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'برنامهٔ روزهای هفته:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      'برای مشاهده یا ویرایش تعهدات روی روز بزنید',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Column(
                  children: _controller.dayLoads.map((dLoad) {
                    final dayAllocations = _controller.allocations
                        .where((a) => a.dayKey == dLoad.dayKey)
                        .toList();
                    final dayMinutes = dayAllocations.fold<int>(
                      0,
                      (acc, a) => acc + a.plannedMinutes,
                    );
                    final isExpanded = _expandedDayKeys.contains(dLoad.dayKey);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isExpanded
                              ? colors.primary.withValues(alpha: 0.3)
                              : colors.border.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedDayKeys.remove(dLoad.dayKey);
                                } else {
                                  _expandedDayKeys.add(dLoad.dayKey);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 70,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.bg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          _getDayNameFa(dLoad.dayKey),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        if (dLoad.userMarkedLight)
                                          const Text(
                                            'سبک 🌙',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.indigoAccent,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${PersianDigits.toPersian(dayAllocations.length.toString())} تعهد · ${PersianDigits.toPersian(dayMinutes.toString())} دقیقه',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: dLoad.userMarkedLight
                                        ? 'تبدیل به روز عادی'
                                        : 'تنظیم به عنوان روز سبک (Light Day)',
                                    icon: Icon(
                                      dLoad.userMarkedLight
                                          ? Icons.nightlight_round
                                          : Icons.nightlight_outlined,
                                      size: 18,
                                      color: dLoad.userMarkedLight
                                          ? Colors.indigoAccent
                                          : colors.textSecondary,
                                    ),
                                    onPressed: () async {
                                      await HapticFeedback.selectionClick();
                                      await PlanningRepository.instance
                                          .setDayLight(
                                            dLoad.dayKey,
                                            !dLoad.userMarkedLight,
                                          );
                                      await _controller.loadHorizon(
                                        PlanningHorizon.week,
                                      );
                                    },
                                  ),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: colors.textSecondary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Expanded area showing individual allocations
                          if (isExpanded) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  if (dayAllocations.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'تعهدی برای این روز تخصیص نیافته است.',
                                        style: RitmoTextStyles.caption(
                                          colors.textSecondary,
                                        ),
                                      ),
                                    )
                                  else
                                    ...dayAllocations.map((alloc) {
                                      final commitment = _controller.commitments
                                          .firstWhere(
                                            (c) => c.id == alloc.commitmentId,
                                            orElse: () => PlanningCommitment(
                                              id: alloc.commitmentId,
                                              cycleId: '',
                                              title: 'تعهد',
                                              createdAt: 0,
                                              updatedAt: 0,
                                            ),
                                          );
                                      final isDone =
                                          alloc.status == AllocationStatus.done;

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.bg,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            InkWell(
                                              onTap: () async {
                                                await HapticFeedback.lightImpact();
                                                final newStatus = isDone
                                                    ? AllocationStatus.planned
                                                    : AllocationStatus.done;
                                                await PlanningRepository
                                                    .instance
                                                    .insertAllocation(
                                                      alloc.copyWith(
                                                        status: newStatus,
                                                        materializedEntityType:
                                                            'planning_allocation',
                                                        materializedEntityId:
                                                            alloc.id,
                                                        updatedAt: DateTime.now()
                                                            .millisecondsSinceEpoch,
                                                      ),
                                                    );
                                                RitmoEventBus().fire(RitmoEvent(
                                                  type: 'commitmentChanged',
                                                  timestamp: DateTime.now(),
                                                  payload: {
                                                    'allocationId': alloc.id,
                                                    'status': newStatus.name,
                                                  },
                                                ));
                                                await _controller.loadHorizon(
                                                  PlanningHorizon.week,
                                                );
                                              },
                                              child: Icon(
                                                isDone
                                                    ? Icons.check_circle
                                                    : Icons
                                                          .radio_button_unchecked,
                                                color: isDone
                                                    ? colors.primary
                                                    : colors.textSecondary,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                   Row(
                                                     children: [
                                                       Expanded(
                                                         child: Text(
                                                           commitment.title,
                                                           style:
                                                               RitmoTextStyles.bodyMedium(
                                                                 isDone
                                                                     ? colors
                                                                           .textSecondary
                                                                     : colors
                                                                           .textPrimary,
                                                               ).copyWith(
                                                                 fontWeight:
                                                                     FontWeight.bold,
                                                                 decoration: isDone
                                                                     ? TextDecoration
                                                                           .lineThrough
                                                                     : null,
                                                               ),
                                                         ),
                                                       ),
                                                       if (commitment.isUserLocked) ...[
                                                         const SizedBox(width: 4),
                                                         Icon(
                                                           Icons.lock_rounded,
                                                           size: 13,
                                                           color: colors.primary,
                                                         ),
                                                       ],
                                                     ],
                                                   ),
                                                   Text(
                                                     '${PersianDigits.toPersian(alloc.plannedMinutes.toString())} دقیقه · اولویت: ${commitment.importance.name.toUpperCase()}',
                                                     style:
                                                         RitmoTextStyles.caption(
                                                           colors.textSecondary,
                                                         ),
                                                   ),
                                                   if ((_controller.allocationResult?.explanations[alloc.id] ?? commitment.planningReason) != null &&
                                                       (_controller.allocationResult?.explanations[alloc.id] ?? commitment.planningReason)!.isNotEmpty) ...[
                                                     const SizedBox(height: 2),
                                                     Row(
                                                       children: [
                                                         Icon(
                                                           Icons.lightbulb_outline_rounded,
                                                           size: 12,
                                                           color: colors.warning,
                                                         ),
                                                         const SizedBox(width: 4),
                                                         Expanded(
                                                           child: Text(
                                                             (_controller.allocationResult?.explanations[alloc.id] ?? commitment.planningReason)!,
                                                             style: RitmoTextStyles.caption(colors.textSecondary).copyWith(
                                                               fontSize: 10,
                                                             ),
                                                             maxLines: 1,
                                                             overflow: TextOverflow.ellipsis,
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                                   ],
                                                 ],
                                               ),
                                             ),
                                            PopupMenuButton<String>(
                                              icon: Icon(
                                                Icons.more_vert,
                                                color: colors.textSecondary,
                                                size: 16,
                                              ),
                                              onSelected: (val) {
                                                _handleContextMenuAction(
                                                  val,
                                                  dLoad.dayKey,
                                                  [alloc],
                                                );
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(
                                                  value: 'move',
                                                  child: Text('انتقال به روز…'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'split',
                                                  child: Text(
                                                    'تقسیم به دو بخش',
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'shrink',
                                                  child: Text(
                                                    'کوچک‌تر کن (۵۰٪)',
                                                  ),
                                                ),
                                                 PopupMenuItem(
                                                   value: 'lock',
                                                   child: Text(
                                                     commitment.isUserLocked
                                                         ? 'باز کردن قفل 🔓'
                                                         : 'قفل در همین روز 🔒',
                                                   ),
                                                 ),
                                                const PopupMenuItem(
                                                  value: 'drop',
                                                  child: Text(
                                                    'حذف از این هفته',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        side: BorderSide(
                                          color: colors.border.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        CreateCommitmentSheet.show(
                                          context,
                                          initialHorizon: PlanningHorizon.week,
                                          initialDayKey: dLoad.dayKey,
                                          onSaved: () =>
                                              _controller.loadHorizon(
                                                PlanningHorizon.week,
                                              ),
                                        );
                                      },
                                      icon: const Icon(Icons.add, size: 14),
                                      label: Text(
                                        '+ افزودن تعهد به ${_getDayNameFa(dLoad.dayKey)}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),

                // 4. Unplaced Queue
                if (_controller.allocationResult?.unplaced.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: colors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'صف «جا نشد» (${PersianDigits.toPersian(_controller.allocationResult!.unplaced.length.toString())} مورد)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: _controller.allocationResult!.unplaced.map((
                            unp,
                          ) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colors.card,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          unp.commitment.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: colors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          unp.detailFa,
                                          style: RitmoTextStyles.caption(
                                            colors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final half =
                                          (unp.commitment.effortMinutes * 0.5)
                                              .round()
                                              .clamp(15, 240);
                                      await PlanningRepository.instance
                                          .upsertCommitment(
                                            unp.commitment.copyWith(
                                              effortMinutes: half,
                                            ),
                                          );
                                      await _controller.loadHorizon(
                                        PlanningHorizon.week,
                                      );
                                      if (mounted)
                                        RitmoToast.show(
                                          this.context,
                                          'زمان تعهد به $half دقیقه کاهش یافت.',
                                        );
                                    },
                                    child: Text(
                                      'نصف کردن',
                                      style: RitmoTextStyles.badge(
                                        colors.primary,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () async {
                                      await PlanningRepository.instance
                                          .dropCommitment(
                                            unp.commitment.id,
                                            reason: 'حذف به علت عدم گنجایش',
                                            nowMs: DateTime.now()
                                                .millisecondsSinceEpoch,
                                          );
                                      await _controller.loadHorizon(
                                        PlanningHorizon.week,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom CTA bar
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  WeekPlannerSheet.show(
                    context,
                    onSaved: () {
                      _controller.loadHorizon(PlanningHorizon.week);
                    },
                  );
                },
                icon: const Icon(
                  Icons.auto_awesome,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  _controller.allocations.isNotEmpty
                      ? 'بازطراحی و بهینه‌سازی هفته ✨'
                      : 'پیشنهاد هوشمند و چیدمان هفته ✨',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleContextMenuAction(
    String action,
    String dayKey,
    List<PlanningAllocation> dayAllocations,
  ) async {
    if (dayAllocations.isEmpty) {
      RitmoToast.show(context, 'تعهدی برای این روز وجود ندارد.');
      return;
    }

    final repo = PlanningRepository.instance;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final firstAlloc = dayAllocations.first;
    final commitment = _controller.commitments.firstWhere(
      (c) => c.id == firstAlloc.commitmentId,
      orElse: () => PlanningCommitment(
        id: firstAlloc.commitmentId,
        cycleId: '',
        title: 'تعهد',
        createdAt: 0,
        updatedAt: 0,
      ),
    );

    try {
      switch (action) {
        case 'move':
          final weekDays = PlanningWeek.dayKeysOfWeekContaining(DateTime.now());
          final picked = await showDialog<String>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text(
                'انتقال به کدام روز؟',
                textAlign: TextAlign.right,
              ),
              children: weekDays.map((dk) {
                return SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, dk),
                  child: Text(
                    '${_getDayNameFa(dk)} ($dk)',
                    textAlign: TextAlign.right,
                  ),
                );
              }).toList(),
            ),
          );
          if (picked != null && picked != dayKey) {
            await repo.moveAllocation(firstAlloc.id, picked, nowMs: nowMs);
            await _controller.loadHorizon(PlanningHorizon.week);
            if (mounted)
              RitmoToast.show(
                context,
                'تخصیص به ${_getDayNameFa(picked)} منتقل شد.',
              );
          }
          break;

        case 'split':
          if (firstAlloc.plannedMinutes < 30) {
            if (mounted) {
              RitmoToast.show(
                context,
                'زمان تخصیص کمتر از ۳۰ دقیقه است و قابل شکستن نیست.',
              );
            }
            break;
          }
          final part1 = (firstAlloc.plannedMinutes / 2).floor();
          final part2 = (firstAlloc.plannedMinutes / 2).ceil();

          // 1. Update current allocation with part1
          await repo.insertAllocation(
            firstAlloc.copyWith(
              plannedMinutes: part1,
              updatedAt: nowMs,
            ),
          );

          // 2. Find next day in week
          final cycle = _controller.activeCycle;
          final weekDays = cycle != null
              ? PlanningWeek.dayKeysOfWeekContaining(
                  DateTime.tryParse(firstAlloc.dayKey) ?? DateTime.now(),
                )
              : [firstAlloc.dayKey];
          final curIdx = weekDays.indexOf(firstAlloc.dayKey);
          final nextDayKey = (curIdx != -1 && curIdx + 1 < weekDays.length)
              ? weekDays[curIdx + 1]
              : firstAlloc.dayKey;

          // 3. Create second allocation with part2
          final secondAlloc = PlanningAllocation(
            id: 'alloc_${nowMs}_split',
            commitmentId: firstAlloc.commitmentId,
            dayKey: nextDayKey,
            plannedMinutes: part2,
            idempotencyKey: 'split_${firstAlloc.id}_$nowMs',
            status: AllocationStatus.planned,
            createdAt: nowMs,
            updatedAt: nowMs,
          );
          await repo.insertAllocation(secondAlloc);

          await _controller.loadHorizon(PlanningHorizon.week);
          if (mounted) {
            RitmoToast.show(
              context,
              'تخصیص به دو بخش $part1 و $part2 دقیقه‌ای تقسیم شد.',
            );
          }
          break;

        case 'shrink':
          final shrunkMin = (firstAlloc.plannedMinutes * 0.5).round().clamp(
            15,
            240,
          );
          await repo.insertAllocation(
            firstAlloc.copyWith(
              plannedMinutes: shrunkMin,
              updatedAt: nowMs,
            ),
          );
          await _controller.loadHorizon(PlanningHorizon.week);
          if (mounted) {
            RitmoToast.show(
              context,
              'زمان تخصیص به $shrunkMin دقیقه کاهش یافت.',
            );
          }
          break;

        case 'lock':
          final newLocked = !commitment.isUserLocked;
          final updatedComm = commitment.copyWith(isUserLocked: newLocked);
          await repo.upsertCommitment(updatedComm);
          await _controller.loadHorizon(PlanningHorizon.week);
          if (mounted) {
            RitmoToast.show(
              context,
              newLocked ? 'تعهد در این روز قفل شد 🔒' : 'قفل تعهد باز شد 🔓',
            );
          }
          break;

        case 'drop':
          await repo.dropCommitment(
            commitment.id,
            reason: 'حذف دستی از هفته',
            nowMs: nowMs,
          );
          await _controller.loadHorizon(PlanningHorizon.week);
          if (mounted)
            RitmoToast.show(context, 'تعهد از برنامهٔ این هفته حذف شد.');
          break;
      }
    } catch (e) {
      debugPrint('[PlanningScreen] Context menu action failed: $e');
      if (mounted) RitmoToast.show(context, 'خطا در اعمال تغییرات ❌');
    }
  }

  String _getDayNameFa(String dayKey) {
    final dt = DateTime.tryParse(dayKey) ?? DateTime.now();
    switch (dt.weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return 'یکشنبه';
      case DateTime.monday:
        return 'دوشنبه';
      case DateTime.tuesday:
        return 'سه‌شنبه';
      case DateTime.wednesday:
        return 'چهارشنبه';
      case DateTime.thursday:
        return 'پنجشنبه';
      case DateTime.friday:
        return 'جمعه';
      default:
        return '';
    }
  }
}
