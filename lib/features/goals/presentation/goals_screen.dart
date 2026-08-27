import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  bool _isTabsVisible = true;

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
    if (mounted) {
      if (_tabController.index != _controller.selectedTabIndex) {
        _tabController.animateTo(_controller.selectedTabIndex);
      }
      setState(() {});
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
      useSafeArea: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.40,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.60, 0.94],
        expand: false,
        builder: (context, scrollController) => CreateGoalSheet(
          activeGoals: activeGoals,
          routines: routines,
          goalToEdit: editGoal,
          templateData: templateData,
          onSaved: () => _controller.reload(force: true),
        ),
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
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.40,
        maxChildSize: 0.94,
        expand: false,
        snap: true,
        snapSizes: const [0.60, 0.94],
        builder: (context, scrollController) {
          return RitmoTheme.glassCardLight(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'آرشیو اهداف تکمیل شده',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                    ),
                  ),
                  const Divider(color: Colors.white10),
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
    final contentTopPadding = topPadding + 142.0;

    final viewState = _controller.state;
    if (viewState is GoalsFailed) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: colors.bg,
          body: Stack(
            children: [
              Center(
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: _buildCapsuleHeader(
                      context,
                      isDarkMode,
                      colors,
                      [],
                      {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Stack(
          children: [
            // Layer 1: Body Content (NotificationListener for Instant Quick-Return Header)
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.vertical) {
                    if (notification.metrics.pixels <= 15) {
                      if (!_isTabsVisible) {
                        setState(() => _isTabsVisible = true);
                      }
                    } else if (notification is UserScrollNotification) {
                      if (notification.direction == ScrollDirection.reverse) {
                        if (_isTabsVisible) {
                          setState(() => _isTabsVisible = false);
                        }
                      } else if (notification.direction == ScrollDirection.forward) {
                        if (!_isTabsVisible) {
                          setState(() => _isTabsVisible = true);
                        }
                      }
                    }
                  }
                  return false;
                },
                child: isLoading
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 80),
                        child: const RitmoSkeletonList(itemCount: 3),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // Tab 0: Planning Horizons
                          Padding(
                            padding: EdgeInsets.only(top: contentTopPadding),
                            child: PlanningScreen(
                              embedded: true,
                              upcomingTimeline: engineOutput?.upcomingTimeline ?? [],
                            ),
                          ),

                          // Tab 1: Goals Card List or Tree View
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 4),
                                child: _buildHeroSection(
                                  activeGoals,
                                  stepsByGoal,
                                  engineOutput,
                                  colors,
                                  isDarkMode,
                                ),
                              ),
                              Expanded(
                                child: _controller.showTreeView
                                    ? GoalsTreeSection(
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
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),

            // Layer 2: Floating Capsule Header Island
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: _buildCapsuleHeader(
                    context,
                    isDarkMode,
                    colors,
                    completedGoals,
                    stepsByGoal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleHeader(
    BuildContext context,
    bool isDark,
    RitmoColors colors,
    List<Goal> completedGoals,
    Map<String, List<GoalStep>> stepsByGoal,
  ) {
    final capsuleBgColor = isDark
        ? const Color(0xFF1E222A).withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.90);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.50)
                : const Color(0xFFCBD5E1).withValues(alpha: 0.65),
            offset: const Offset(0, 5),
            blurRadius: 14,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.90),
            offset: const Offset(0, -1),
            blurRadius: 3,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            decoration: BoxDecoration(
              color: capsuleBgColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Back Button, Title, AI, Add, Menu
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      if (Navigator.canPop(context))
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                          icon: Icon(
                            CupertinoIcons.arrow_right,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1D2129),
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'اهداف و دستاوردها',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.4,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1D2129),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.sparkles,
                        iconColor: colors.primary,
                        isAiButton: true,
                        isDark: isDark,
                        tooltip: 'دستیار هوشمند برنامه‌ریزی',
                        onTap: _showAiAssistantSheet,
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.add,
                        iconColor: isDark
                            ? Colors.white
                            : const Color(0xFF1D2129),
                        isDark: isDark,
                        tooltip: _tabController.index == 0
                            ? 'افزودن تعهد جدید'
                            : 'ثبت هدف جدید',
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
                              _controller.showTreeView
                                  ? 'نمای کارت نتیجه‌محور'
                                  : 'نمای درختی اهداف',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('آرشیو اهداف'),
                          ),
                        ],
                        child: _buildHeaderActionButtonContent(
                          icon: CupertinoIcons.ellipsis_vertical,
                          iconColor: isDark
                              ? const Color(0xFF9096A2)
                              : const Color(0xFF6B7280),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                ),

                // Bottom Collapsible Segmented Tabs
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  height: _isTabsVisible ? 54.0 : 0.0,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isTabsVisible ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                      child: Align(
                        alignment: Alignment.center,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: _buildSegmentedTabs(colors, isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs(RitmoColors colors, bool isDark) {
    final trackBgColor = isDark ? const Color(0xFF16191E) : const Color(0xFFEFF2F6);
    final pillBgColor = isDark
        ? const Color(0xFF22262F)
        : Color.lerp(Colors.white, colors.primary, 0.12)!;
    final activeIndex = _tabController.index.clamp(0, 1);

    const tabs = [
      (title: 'برنامه‌ها', icon: CupertinoIcons.calendar_today),
      (title: 'اهداف', icon: CupertinoIcons.flag_fill),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const outerPadding = 4.0;
        final availableWidth = totalWidth - (outerPadding * 2);
        final tabWidth = availableWidth / 2;
        const trackHeight = 44.0;
        const pillHeight = trackHeight - (outerPadding * 2);

        return Container(
          height: trackHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: trackBgColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.90),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.70)
                    : const Color(0xFFB8C2CE).withValues(alpha: 0.55),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: isDark
                    ? const Color(0xFF222630)
                    : Colors.white.withValues(alpha: 0.95),
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Sliding Pill Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                right: outerPadding + (activeIndex * tabWidth),
                top: outerPadding,
                width: tabWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: pillBgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: isDark ? 0.40 : 0.28),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.60)
                            : const Color(0xFFB2BDCB).withValues(alpha: 0.65),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                      BoxShadow(
                        color: isDark ? const Color(0xFF2E3440) : Colors.white,
                        offset: const Offset(-2, -2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Buttons
              Row(
                children: List.generate(2, (index) {
                  final item = tabs[index];
                  final isSelected = activeIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _tabController.animateTo(index);
                        setState(() {});
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? colors.primary
                                : (isDark
                                    ? const Color(0xFF8A93A4)
                                    : const Color(0xFF6B7280)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 14,
                                color: isSelected
                                    ? colors.primary
                                    : (isDark
                                        ? const Color(0xFF8A93A4)
                                        : const Color(0xFF6B7280)),
                              ),
                              const SizedBox(width: 6),
                              Text(item.title),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
    String? tooltip,
    bool isAiButton = false,
  }) {
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: _buildHeaderActionButtonContent(
        icon: icon,
        iconColor: iconColor,
        isDark: isDark,
        isAiButton: isAiButton,
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildHeaderActionButtonContent({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    bool isAiButton = false,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? (isAiButton
                ? iconColor.withValues(alpha: 0.18)
                : const Color(0xFF22262E))
            : (isAiButton
                ? iconColor.withValues(alpha: 0.12)
                : const Color(0xFFF3F5F8)),
        border: Border.all(
          color: isDark
              ? (isAiButton
                  ? iconColor.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.08))
              : (isAiButton
                  ? iconColor.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.90)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFFB5C0CD).withValues(alpha: 0.65),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          if (isAiButton)
            BoxShadow(
              color: iconColor.withValues(alpha: isDark ? 0.35 : 0.22),
              blurRadius: 10,
              spreadRadius: 1.0,
            ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 18,
          color: isAiButton
              ? iconColor
              : (isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280)),
        ),
      ),
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

      return RitmoTheme.glassCardLight(
        color: colors.primary.withValues(alpha: isDarkMode ? 0.08 : 0.12),
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                      strokeWidth: 5,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                      backgroundColor: Colors.white10,
                    ),
                    Text(
                      '$percent٪',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
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
                    Text(
                      'ستاره قطبی فعال',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                        ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      polarisGoal.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                        ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      deadlineSummary,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                        ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      momentum > 0 ? 'این هفته ${toPersianDigits(momentum)} گام جلو رفتی 🚀' : 'این هفته هنوز گامی برنداشتی؛ شروع کن!',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
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
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _showCreateGoalSheet(templateData: {
            'title': title,
            'description': desc,
            'goalType': goalType,
            'steps': steps,
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                    style: TextStyle(fontSize: 12.5, color: colors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
