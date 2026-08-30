import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ritmo/core/analytics/goals_engine.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/goals/logic/goals_controller.dart';
import 'package:ritmo/features/goals/logic/goals_repository.dart';
import 'package:ritmo/features/goals/models/goal_models.dart';
import 'package:ritmo/features/goals/presentation/planning_screen.dart';
import 'package:ritmo/features/goals/presentation/widgets/create_commitment_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/create_goal_sheet.dart';
import 'package:ritmo/features/goals/presentation/widgets/goals_archive_section.dart';
import 'package:ritmo/features/goals/presentation/widgets/goals_card_list_section.dart';
import 'package:ritmo/features/goals/presentation/widgets/goals_formatters.dart';
import 'package:ritmo/features/goals/presentation/widgets/goals_tree_section.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late GoalsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GoalsController();
    _controller.init();
    _controller.addListener(_onControllerChanged);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      _controller.setTabIndex(_tabController.index);
      if (mounted) setState(() {});
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    void applyUpdate() {
      if (!mounted) return;
      if (_tabController.index != _controller.selectedTabIndex) {
        _tabController.animateTo(_controller.selectedTabIndex);
      }
      setState(() {});
    }

    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => applyUpdate());
    } else {
      applyUpdate();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleToggleStep(GoalStep step, String goalId) async {
    await GoalsRepository.instance.toggleStep(step.id, step.isCompleted, goalId);

    // T3 Check if goal became auto-completed
    final goals = await GoalsRepository.instance.getGoals();
    final target = goals.firstWhere((g) => g.id == goalId, orElse: () => Goal(id: '', title: '', goalType: GoalLevel.daily, createdAt: 0, updatedAt: 0));

    if (target.id.isNotEmpty && target.status == 'COMPLETED' && !step.isCompleted && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هدف «${target.title}» به صورت کامل تکمیل شد! 🎉',
            style: const TextStyle(),
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'بازگردانی (Undo)',
            textColor: Colors.white,
            onPressed: () async {
              await GoalsRepository.instance.toggleStep(step.id, true, goalId);
            },
          ),
        ),
      );
    }
  }

  void _showCreateGoalSheet({Goal? editGoal, Map<String, dynamic>? templateData}) {
    final readyState = _controller.state is GoalsReady ? _controller.state as GoalsReady : null;
    final activeGoals = readyState?.goals.where((g) => g.status == 'ACTIVE').toList() ?? [];
    final routines = readyState?.routines ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) => CreateGoalSheet(
        activeGoals: activeGoals,
        routines: routines,
        goalToEdit: editGoal,
        templateData: templateData,
        onSaved: () => _controller.reload(force: true),
      ),
    );
  }

  void _showAiAssistantSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AssistantSheet(persona: PersonaRegistry.instance.getPersona('goals')!),
    );
  }

  void _showArchiveSheet(List<Goal> completedGoals, Map<String, List<GoalStep>> stepsByGoal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.94,
        minChildSize: 0.0,
        maxChildSize: 0.94,
        expand: false,
        snap: true,
        snapSizes: const [0.0, 0.94],
        builder: (context, scrollController) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final colors = context.colors;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 38,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: isDark ? 0.30 : 0.22),
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

                        // Center: Title
                        Text(
                          'آرشیو اهداف تکمیل شده',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Vazirmatn',
                            color: colors.textPrimary,
                          ),
                        ),

                        // Trailing (Left in RTL): 34x34 spacer
                        const SizedBox(width: 34, height: 34),
                      ],
                    ),
                  ),

                  Divider(color: colors.border.withValues(alpha: 0.15)),
                  Expanded(
                    child: GoalsArchiveSection(
                      completedGoals: completedGoals,
                      stepsByGoal: stepsByGoal,
                      onRefresh: () => _controller.reload(force: true),
                      onRestoreGoal: (goalId) async {
                        await GoalsRepository.instance.updateGoalStatus(goalId, 'ACTIVE');
                      },
                      onDeleteGoal: (goalId) async {
                        await GoalsRepository.instance.deleteGoal(goalId);
                      },
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


  int _calculateMomentum(Goal goal, Map<String, List<GoalStep>> stepsByGoal) {
    var count = 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sevenDaysAgoMs = nowMs - (7 * 24 * 60 * 60 * 1000);

    final steps = stepsByGoal[goal.id] ?? [];
    for (final step in steps) {
      if (step.isCompleted && step.completedAt != null) {
        if (step.completedAt! >= sevenDaysAgoMs && step.completedAt! <= nowMs) {
          count++;
        }
      }
    }
    return count;
  }

  Goal? _findPolarisGoal(List<Goal> activeGoals, Map<String, List<GoalStep>> stepsByGoal) {
    if (activeGoals.isEmpty) return null;
    
    Goal? best;
    var bestScore = -999999.0;
    
    for (final goal in activeGoals) {
      var score = 0.0;
      final days = goal.daysUntilTarget;
      if (days >= 0 && days < 30) {
        score += ((30 - days) / 30.0) * 50.0;
      }
      final momentum = _calculateMomentum(goal, stepsByGoal);
      score += (momentum.clamp(0, 10) / 10.0) * 30.0;
      score += (goal.weight.clamp(0.1, 3.0) / 3.0) * 20.0;
      
      if (score > bestScore) {
        bestScore = score;
        best = goal;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 190.0;

    final viewState = _controller.state;
    if (viewState is GoalsFailed) {
      return RitmoTabbedMorphingScaffold(
        title: 'اهداف و برنامه‌ها',
        subtitle: 'مدیریت استراتژیک، زنجیره عادت‌ها و دستیابی به رویاها',
        onBack: () => Navigator.maybePop(context),
        tabItems: const [
          RitmoTabItem(title: 'خطا', icon: Icons.error_outline, value: 0),
        ],
        tabBuilders: [
          (ctx, scrollController) => Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 48, color: colors.warning),
                  const SizedBox(height: 16),
                  Text(
                    'خطا در بارگذاری اهداف و برنامه‌ها',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    viewState.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('تلاش مجدد', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _controller.reload(force: true),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final isLoading = viewState is GoalsLoading;
    final readyState = viewState is GoalsReady ? viewState : null;

    final goals = readyState?.goals ?? [];
    final activeGoals = goals.where((g) => g.status == 'ACTIVE').toList();
    final completedGoals = goals.where((g) => g.status == 'COMPLETED').toList();
    final stepsByGoal = readyState?.stepsByGoal ?? {};
    final routines = readyState?.routines ?? [];
    final courses = readyState?.courses ?? [];
    final engineOutput = readyState?.engineOutput;

    return RitmoTabbedMorphingScaffold(
      title: 'اهداف و برنامه‌ها',
      subtitle: 'مدیریت استراتژیک، زنجیره عادت‌ها و دستیابی به رویاها',
      externalTabController: _tabController,
      onBack: () => Navigator.maybePop(context),
      actions: [
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.sparkles,
          iconColor: colors.primary,
          isAiButton: true,
          accentColor: colors.primary,
          tooltip: 'دستیار هوشمند برنامه‌ریزی',
          onTap: _showAiAssistantSheet,
        ),
        const SizedBox(width: 8),
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.add,
          iconColor: isDarkMode ? Colors.white : const Color(0xFF1D2129),
          tooltip: _tabController.index == 0 ? 'افزودن تعهد جدید' : 'ثبت هدف جدید',
          onTap: () {
            if (_tabController.index == 0) {
              CreateCommitmentSheet.show(
                context,
                onSaved: () => _controller.reload(force: true),
              );
            } else {
              _showCreateGoalSheet();
            }
          },
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          tooltip: 'گزینه‌ها',
          onSelected: (val) {
            if (val == 'archive') {
              _showArchiveSheet(completedGoals, stepsByGoal);
            } else if (val == 'toggle_view') {
              _controller.toggleViewMode(!_controller.showTreeView);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle_view',
              child: Text(
                _controller.showTreeView ? 'نمای کارت نتیجه‌محور' : 'نمای درختی اهداف',
              ),
            ),
            const PopupMenuItem(
              value: 'archive',
              child: Text('آرشیو اهداف'),
            ),
          ],
          child: RitmoVibrancyActionButton(
            icon: CupertinoIcons.ellipsis_vertical,
            iconColor: isDarkMode ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
            onTap: () {},
          ),
        ),
      ],
      tabItems: const [
        RitmoTabItem(
          title: 'هفتهٔ من',
          icon: CupertinoIcons.calendar_today,
          value: 0,
        ),
        RitmoTabItem(
          title: 'اهداف',
          icon: CupertinoIcons.flag_fill,
          value: 1,
        ),
      ],
      tabBuilders: [
        // Tab 0: Planning Horizons
        (ctx, scrollController) => isLoading
            ? Padding(
                padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 80),
                child: const RitmoSkeletonList(itemCount: 3),
              )
            : PlanningScreen(
                embedded: true,
                upcomingTimeline: engineOutput?.upcomingTimeline ?? [],
                topPadding: contentTopPadding,
              ),

        // Tab 1: Goals Card List or Tree View
        (ctx, scrollController) => isLoading
            ? Padding(
                padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 80),
                child: const RitmoSkeletonList(itemCount: 3),
              )
            : _controller.showTreeView
                ? GoalsTreeSection(
                    header: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildHeroSection(
                        activeGoals,
                        stepsByGoal,
                        engineOutput,
                        colors,
                        isDarkMode,
                      ),
                    ),
                    topPadding: contentTopPadding,
                    goals: activeGoals,
                    stepsByGoal: stepsByGoal,
                    progressMap: engineOutput?.goalProgress ?? {},
                    routineStatusMap: engineOutput?.linkedRoutineStatus ?? {},
                    routines: routines,
                    onRefresh: () => _controller.reload(force: true),
                    onToggleStep: (step, goalId) => _handleToggleStep(step, goalId),
                    onDeleteGoal: (goalId) async {
                      await GoalsRepository.instance.deleteGoal(goalId);
                    },
                    onEditGoal: (goal) {
                      _showCreateGoalSheet(editGoal: goal);
                    },
                  )
                : GoalsCardListSection(
                    header: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildHeroSection(
                        activeGoals,
                        stepsByGoal,
                        engineOutput,
                        colors,
                        isDarkMode,
                      ),
                    ),
                    topPadding: contentTopPadding,
                    goals: goals,
                    stepsByGoal: stepsByGoal,
                    progressMap: engineOutput?.goalProgress ?? {},
                    routineStatusMap: engineOutput?.linkedRoutineStatus ?? {},
                    routines: routines,
                    courses: courses,
                    onRefresh: () => _controller.reload(force: true),
                    onToggleStep: (step, goalId) => _handleToggleStep(step, goalId),
                    onDeleteGoal: (goalId) async {
                      await GoalsRepository.instance.deleteGoal(goalId);
                    },
                    onEditGoal: (goal) {
                      _showCreateGoalSheet(editGoal: goal);
                    },
                  ),
      ],
    );
  }

  Widget _buildHeroSection(List<Goal> activeGoals, Map<String, List<GoalStep>> stepsByGoal, GoalsEngineOutput? engineOutput, RitmoColors colors, bool isDarkMode) {
    final polarisGoal = _findPolarisGoal(activeGoals, stepsByGoal);

    if (polarisGoal != null) {
      // 1. Polaris Goal Card
      final progress = engineOutput?.goalProgress[polarisGoal.id] ?? 0.0;
      final percent = (progress * 100).toInt();

      final momentum = _calculateMomentum(polarisGoal, stepsByGoal);

      var deadlineSummary = 'بدون مهلت تعیین‌شده';
      if (polarisGoal.targetDate != null && polarisGoal.targetDate!.isNotEmpty) {
        if (polarisGoal.isOverdue) {
          deadlineSummary = 'مهلت به پایان رسیده ⏳';
        } else {
          deadlineSummary = '${toPersianDigits(polarisGoal.daysUntilTarget)} روز مانده تا پایان مهلت';
        }
      }

      return RitmoCard.neumorphic(
        padding: const EdgeInsets.all(18),
        onTap: () {
          RitmoHaptics.tap();
          _showCreateGoalSheet(editGoal: polarisGoal);
        },
        child: Row(
          children: [
            // Left: Progress Ring
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5.5,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    backgroundColor: colors.surfaceSunken.withValues(alpha: 0.5),
                  ),
                  Text(
                    '${toPersianDigits(percent.toString())}٪',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Vazirmatn',
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),

            // Right: Goal Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RitmoCardBadge(
                        label: 'ستاره قطبی فعال',
                        color: colors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    polarisGoal.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Vazirmatn',
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deadlineSummary,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    momentum > 0
                        ? 'این هفته ${toPersianDigits(momentum)} گام جلو رفتی 🚀'
                        : 'این هفته هنوز گامی برنداشتی؛ شروع کن!',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.success,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 2. Motivational Template Cards when empty
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'یک هدف جدید انتخاب کنید:',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              fontFamily: 'Vazirmatn',
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            reverse: true, // RTL horizontal list view scroll direction
            children: [
              _buildTemplateCard('پروژه شخصی', 'راه‌اندازی پروژه شخصی جدید', CupertinoIcons.folder, 'MONTHLY', ['تعریف MVP پروژه', 'طراحی اولیه ایده', 'پیاده‌سازی نسخه اول', 'دریافت اولین بازخوردها'], colors),
              _buildTemplateCard('یادگیری مهارت', 'تسلط بر مهارت یا زبان جدید', CupertinoIcons.infinite, 'MONTHLY', ['انتخاب منبع آموزشی معتبر', 'مطالعه و تمرین روزانه ۳۰ دقیقه', 'انجام اولین پروژه آزمایشی', 'ارزیابی پیشرفت'], colors),
              _buildTemplateCard('پس‌انداز مالی', 'بهبود جریان درآمدی و پس‌انداز', CupertinoIcons.money_dollar, 'ANNUAL', ['ثبت و بودجه‌بندی هزینه‌ها', 'پس‌انداز ۱۰٪ درآمد ماهانه', 'سرمایه‌گذاری در بورس یا طلا', 'کاهش مخارج غیرضروری'], colors),
              _buildTemplateCard('کتاب‌خوانی', 'ایجاد عادت مطالعه مستمر کتاب', CupertinoIcons.book, 'WEEKLY', ['انتخاب اولین کتاب مطالعه', 'مطالعه قبل از خواب (۱۵ دقیقه)', 'خلاصه‌نویسی نکات کلیدی', 'اشتراک‌گذاری خلاصه'], colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(
    String title,
    String desc,
    IconData icon,
    String goalType,
    List<String> steps,
    RitmoColors colors,
  ) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(left: 12),
      child: RitmoCard.neumorphic(
        padding: const EdgeInsets.all(12),
        onTap: () {
          RitmoHaptics.tap();
          _showCreateGoalSheet(templateData: {
            'title': title,
            'description': desc,
            'goalType': goalType,
            'steps': steps,
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: TextStyle(
                fontSize: 10.5,
                color: colors.textSecondary,
                fontFamily: 'Vazirmatn',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
