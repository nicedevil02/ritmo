import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/services/ritmo_timer_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/goals/logic/capacity_models.dart';
import 'package:ritmo/features/goals/logic/planning_controller.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/models/goal_models.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:ritmo/features/goals/presentation/widgets/create_commitment_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/quick_capture_planning_bar.dart';
import 'package:ritmo/features/goals/presentation/widgets/week_planner_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/week_review_sheet.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// بوم تعاملی بصری هفته (Visual Week Board)
/// نمایش ۷ روز هفته بر پایه تقویم شمسی (RTL: شنبه در راست، جمعه در چپ)
/// با نشانگرهای بار روز، جابه‌جایی سریع تک‌لمسی و صندوق گام‌های پیش‌رو.
class VisualWeekBoard extends StatefulWidget {
  const VisualWeekBoard({
    super.key,
    required this.controller,
    required this.colors,
    required this.isDark,
    this.header,
    this.backlogSteps = const [],
    this.goalTitlesMap = const {},
    this.onRefresh,
  });

  final PlanningController controller;
  final RitmoColors colors;
  final bool isDark;
  final Widget? header;
  final List<GoalStep> backlogSteps;
  final Map<String, String> goalTitlesMap;
  final VoidCallback? onRefresh;

  @override
  State<VisualWeekBoard> createState() => _VisualWeekBoardState();
}

class _VisualWeekBoardState extends State<VisualWeekBoard> {
  String? _selectedDayKey;
  bool _isBacklogExpanded = false;

  @override
  void initState() {
    super.initState();
    _initSelectedDay();
  }

  @override
  void didUpdateWidget(covariant VisualWeekBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDayKey == null ||
        !widget.controller.capacities.any((c) => c.dayKey == _selectedDayKey)) {
      _initSelectedDay();
    }
  }

  void _initSelectedDay() {
    final todayKey = RitmoDate.dayKey(DateTime.now());
    final hasToday = widget.controller.capacities.any((c) => c.dayKey == todayKey);
    if (hasToday) {
      _selectedDayKey = todayKey;
    } else if (widget.controller.capacities.isNotEmpty) {
      _selectedDayKey = widget.controller.capacities.first.dayKey;
    } else {
      _selectedDayKey = todayKey;
    }
  }

  static String _persianWeekday(int w) {
    switch (w) {
      case 1:
        return 'شنبه';
      case 2:
        return '۱شنبه';
      case 3:
        return '۲شنبه';
      case 4:
        return '۳شنبه';
      case 5:
        return '۴شنبه';
      case 6:
        return '۵شنبه';
      case 7:
        return 'جمعه';
      default:
        return '';
    }
  }

  static String _shortWeekday(int w) {
    switch (w) {
      case 1:
        return 'ش';
      case 2:
        return '۱ش';
      case 3:
        return '۲ش';
      case 4:
        return '۳ش';
      case 5:
        return '۴ش';
      case 6:
        return '۵ش';
      case 7:
        return 'ج';
      default:
        return '';
    }
  }

  static String _persianMonthName(int m) {
    const names = [
      'فروردین', 'اردیبهشت', 'خرداد',
      'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر',
      'دی', 'بهمن', 'اسفند'
    ];
    if (m >= 1 && m <= 12) return names[m - 1];
    return '';
  }

  (String label, Color color) _dayLoadStatus(DayLoad? dLoad, int totalMinutes) {
    if (dLoad?.userMarkedLight == true) {
      return ('روز سبک', widget.colors.secondary);
    }
    if (totalMinutes == 0) {
      return ('آزاد', widget.colors.textSecondary);
    }
    if (totalMinutes <= 60) {
      return ('سبک', widget.colors.success);
    }
    if (totalMinutes <= 150) {
      return ('متعادل', widget.colors.warning);
    }
    return ('متراکم', widget.colors.error);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final ctrl = widget.controller;
    final active = ctrl.activeCycle;
    final totalCommittable = ctrl.capacities.fold<int>(0, (acc, c) => acc + c.committableMinutes);
    final totalCommitmentMinutes = ctrl.commitments.fold<int>(0, (acc, c) => acc + c.effortMinutes);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header != null) ...[
            widget.header!,
            const SizedBox(height: 16),
          ],

          // 1. Cycle status and AI action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: active != null ? colors.success : colors.warning,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              active != null
                                  ? 'برنامهٔ هفتهٔ جاری (نسخهٔ ${PersianDigits.toPersian(active.version.toString())})'
                                  : 'برنامه‌ای برای این هفته تنظیم نشده',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (active != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 16),
                          child: Text(
                            'ظرفیت: ${PersianDigits.toPersian(totalCommittable.toString())}د · تعهدات: ${PersianDigits.toPersian(totalCommitmentMinutes.toString())}د',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (active == null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                    onPressed: () {
                      WeekPlannerSheet.show(
                        context,
                        onSaved: () => ctrl.loadHorizon(PlanningHorizon.week),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('ساخت هوشمند', style: TextStyle(fontSize: 11.5)),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'افزودن تعهد دستی',
                        icon: Icon(Icons.add_circle_outline, color: colors.primary, size: 22),
                        onPressed: () {
                          CreateCommitmentSheet.show(
                            context,
                            initialHorizon: PlanningHorizon.week,
                            onSaved: () => ctrl.loadHorizon(PlanningHorizon.week),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'مرور و ارزیابی هفته',
                        icon: Icon(Icons.rate_review_outlined, color: colors.textSecondary, size: 20),
                        onPressed: () {
                          WeekReviewSheet.show(
                            context,
                            cycle: active,
                            allocations: ctrl.allocations,
                            commitments: ctrl.commitments,
                            onClosed: () => ctrl.loadHorizon(PlanningHorizon.week),
                          );
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. 7-Day Visual Strip (Saturday on Right -> Friday on Left in RTL)
          _buildSevenDayStrip(context),

          const SizedBox(height: 16),

          // 3. Active Day Allocations List
          _buildSelectedDaySection(context),

          const SizedBox(height: 16),

          // 4. Quick Capture Planning Bar (Slice 4)
          QuickCapturePlanningBar(
            controller: ctrl,
            colors: colors,
            isDark: widget.isDark,
            onCommitted: () => ctrl.loadHorizon(PlanningHorizon.week),
          ),

          const SizedBox(height: 16),

          // 5. Backlog / Ready Goal Steps Pool (Slice 3)
          _buildBacklogSection(context),
        ],
      ),
    );
  }

  Widget _buildSevenDayStrip(BuildContext context) {
    final colors = widget.colors;
    final ctrl = widget.controller;
    final dayKeys = ctrl.capacities.map((c) => c.dayKey).toList();
    final todayKey = RitmoDate.dayKey(DateTime.now());

    if (dayKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 98,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: dayKeys.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final dKey = dayKeys[index];
          final isSelected = dKey == _selectedDayKey;
          final isToday = dKey == todayKey;

          final dt = RitmoDate.tryParseDayKey(dKey) ?? DateTime.now();
          final j = Jalali.fromDateTime(dt);
          final weekdayStr = _persianWeekday(j.weekDay);
          final dayNumStr = toPersianDigits(j.day.toString());

          final dLoad = ctrl.dayLoads.firstWhere(
            (l) => l.dayKey == dKey,
            orElse: () => DayLoad(
              dayKey: dKey,
              occupiedMinutes: 0,
              fixedCount: 0,
              deepCount: 0,
            ),
          );
          final dayAllocs = ctrl.allocations.where((a) => a.dayKey == dKey).toList();
          final totalMin = dayAllocs.fold<int>(0, (acc, a) => acc + a.plannedMinutes);
          final (statusText, statusColor) = _dayLoadStatus(dLoad, totalMin);

          return SizedBox(
            width: 76,
            child: RitmoCard.neumorphic(
              isSelected: isSelected,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              onTap: () {
                RitmoHaptics.selection();
                setState(() {
                  _selectedDayKey = dKey;
                });
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Weekday title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isToday)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary,
                          ),
                        ),
                      Text(
                        weekdayStr,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                          fontFamily: 'Vazirmatn',
                          color: isSelected ? colors.primary : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  // Day Number
                  Text(
                    dayNumStr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Vazirmatn',
                      color: isSelected ? colors.primary : colors.textPrimary,
                    ),
                  ),

                  // Load status chip (Color dot + accessible text)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Vazirmatn',
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedDaySection(BuildContext context) {
    final colors = widget.colors;
    final ctrl = widget.controller;
    final dKey = _selectedDayKey ?? RitmoDate.dayKey(DateTime.now());

    final dt = RitmoDate.tryParseDayKey(dKey) ?? DateTime.now();
    final j = Jalali.fromDateTime(dt);
    final title = '${_persianWeekday(j.weekDay)}، ${toPersianDigits(j.day.toString())} ${_persianMonthName(j.month)}';

    final dayAllocs = ctrl.allocations.where((a) => a.dayKey == dKey).toList();
    final totalPlannedMinutes = dayAllocs.fold<int>(0, (acc, a) => acc + a.plannedMinutes);

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Row(
            children: [
              Expanded(
                child: Text(
                  'کارهای $title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RitmoCardBadge(
                label: '${toPersianDigits(dayAllocs.length.toString())} مورد · ${toPersianDigits(totalPlannedMinutes.toString())} دقیقه',
                color: colors.primary,
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (dayAllocs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(CupertinoIcons.sun_max, size: 36, color: colors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Text(
                    'هنوز کاری برای این روز در نظر گرفته نشده',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.textSecondary,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.border.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      CreateCommitmentSheet.show(
                        context,
                        initialHorizon: PlanningHorizon.day,
                        onSaved: () => ctrl.loadHorizon(PlanningHorizon.week),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'تعهد برای این روز',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Vazirmatn',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: dayAllocs.map((alloc) {
                final comm = ctrl.commitments.firstWhere(
                  (c) => c.id == alloc.commitmentId,
                  orElse: () => PlanningCommitment(
                    id: alloc.commitmentId,
                    cycleId: '',
                    title: 'تعهد',
                    createdAt: 0,
                    updatedAt: 0,
                  ),
                );
                return _buildAllocationItem(context, alloc, comm);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAllocationItem(
    BuildContext context,
    PlanningAllocation alloc,
    PlanningCommitment comm,
  ) {
    final colors = widget.colors;
    final ctrl = widget.controller;
    final isDone = alloc.status == AllocationStatus.done;
    final goalTitle = comm.goalId != null ? widget.goalTitlesMap[comm.goalId] : null;

    final weekDays = ctrl.capacities.map((c) => c.dayKey).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RitmoCard.neumorphicSunken(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // Toggle Checkbox
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    RitmoHaptics.tap();
                    final newStatus = isDone ? AllocationStatus.planned : AllocationStatus.done;
                    final updated = alloc.copyWith(
                      status: newStatus,
                      updatedAt: DateTime.now().millisecondsSinceEpoch,
                    );
                    await PlanningRepository.instance.insertAllocation(updated);
                    await ctrl.loadHorizon(PlanningHorizon.week);
                  },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDone ? colors.success : colors.textSecondary,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comm.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDone ? colors.textSecondary : colors.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${PersianDigits.toPersian(alloc.plannedMinutes.toString())} دقیقه',
                          style: TextStyle(fontSize: 11, color: colors.textSecondary),
                        ),
                        if (goalTitle != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#$goalTitle',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Start Focus Timer button (Slice 3)
              IconButton(
                tooltip: 'شروع سشن تمرکز ۲۵ دقیقه‌ای',
                icon: Icon(CupertinoIcons.timer, color: colors.primary, size: 19),
                onPressed: () async {
                  await HapticFeedback.mediumImpact();
                  await RitmoTimerService.instance.startTimer(
                    id: 'focus_${alloc.id}',
                    domain: 'commitment',
                    itemId: alloc.id,
                    mode: 'FOCUS',
                    durationMinutes: alloc.plannedMinutes > 0 ? alloc.plannedMinutes : 25,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('سشن تمرکز برای "${comm.title}" آغاز شد ⏱️'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quick Move Day Chips: 1-tap reschedule to other week days
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'انتقال به:',
                style: TextStyle(fontSize: 10, color: colors.textSecondary),
              ),
              for (final targetDay in weekDays)
                if (targetDay != alloc.dayKey)
                  _buildQuickMoveChip(alloc.id, targetDay),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildQuickMoveChip(String allocationId, String targetDayKey) {
    final colors = widget.colors;
    final dt = RitmoDate.tryParseDayKey(targetDayKey) ?? DateTime.now();
    final j = Jalali.fromDateTime(dt);
    final label = _shortWeekday(j.weekDay);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        await HapticFeedback.selectionClick();
        await widget.controller.moveAllocationToDay(allocationId, targetDayKey);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('کار به ${_persianWeekday(j.weekDay)} منتقل شد'),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBacklogSection(BuildContext context) {
    final colors = widget.colors;
    final ctrl = widget.controller;
    final weekDays = ctrl.capacities.map((c) => c.dayKey).toList();
    final backlog = widget.backlogSteps;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collapsible header
          InkWell(
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            onTap: () {
              setState(() {
                _isBacklogExpanded = !_isBacklogExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(CupertinoIcons.tray_full, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'صندوق گام‌های پیش‌رو (${PersianDigits.toPersian(backlog.length.toString())} گام آماده)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _isBacklogExpanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (_isBacklogExpanded) ...[
            const Divider(height: 1),
            if (backlog.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'هیچ گام تعیین‌نشده‌ای در اهداف فعال وجود ندارد ✨',
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: backlog.map((step) {
                    final goalTitle = widget.goalTitlesMap[step.goalId];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : colors.bg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.title,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    if (goalTitle != null)
                                      Text(
                                        'از هدف: $goalTitle',
                                        style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'شروع سشن تمرکز ۲۵ دقیقه‌ای',
                                icon: Icon(CupertinoIcons.timer, color: colors.primary, size: 18),
                                onPressed: () async {
                                  await HapticFeedback.mediumImpact();
                                  await RitmoTimerService.instance.startTimer(
                                    id: 'focus_step_${step.id}',
                                    domain: 'goal_step',
                                    itemId: step.id,
                                    mode: 'FOCUS',
                                    durationMinutes: 25,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('سشن تمرکز ۲۵ دقیقه‌ای برای "${step.title}" آغاز شد ⏱️'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'تخصیص به:',
                                style: TextStyle(fontSize: 10, color: colors.textSecondary),
                              ),
                              for (final dKey in weekDays)
                                _buildScheduleStepChip(step.id, dKey),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleStepChip(String stepId, String targetDayKey) {
    final colors = widget.colors;
    final dt = RitmoDate.tryParseDayKey(targetDayKey) ?? DateTime.now();
    final j = Jalali.fromDateTime(dt);
    final label = _shortWeekday(j.weekDay);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        await HapticFeedback.selectionClick();
        await widget.controller.scheduleStepToDay(stepId, targetDayKey);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('گام برای ${_persianWeekday(j.weekDay)} برنامه‌ریزی شد 📅'),
            duration: const Duration(milliseconds: 1200),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}
