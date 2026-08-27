import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../player/player.dart';
import '../sheets/sheets.dart';
import 'mv_library_screen.dart';
import 'mv_onboarding_screen.dart';
import 'mv_progress_tab.dart';
import 'mv_settings_screen.dart';
import 'mv_today_tab.dart';
import 'mv_week_tab.dart';
import 'mv_commitments_screen.dart';

/// Screen 1: "هاب ورزشی ریتمو" (Section 4, 5.1, 5.2, 5.3).
/// Unified hub hosting the 3 tabs (امروز، هفته، پیشرفت) and direct actions.
class MvHubScreen extends StatefulWidget {
  final MvHubController? controller;

  const MvHubScreen({super.key, this.controller});

  @override
  State<MvHubScreen> createState() => _MvHubScreenState();
}

class _MvHubScreenState extends State<MvHubScreen> {
  late final MvHubController _controller;
  int _selectedTabIndex = 0;
  bool _isTabsVisible = true;
  String? _heroAnimationAsset;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MvHubController();
    _controller.addListener(_onControllerUpdated);
    _controller.loadAllData();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onControllerUpdated);
    }
    super.dispose();
  }

  late final MvKindUseCase _kindUseCase = MvKindUseCase(_controller.kindRepo);

  void _onControllerUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _handleStartOrResumeSession(MvSlot slot) async {
    final activeSession = _controller.activeSession;
    final MvSession session;
    final List<MvExercise> exercises;
    final String? heroAsset;

    if (activeSession != null) {
      session = activeSession;
      exercises = _controller.allExercises;
      heroAsset = null;
    } else {
      final result = await _controller.startSessionUseCase.execute(
        slot: slot,
        profile: _controller.profile,
        preloadedPool: _controller.allExercises,
      );
      session = result.session;
      exercises = result.exercises;
      heroAsset = result.heroAnimationAsset;
    }

    setState(() {
      _heroAnimationAsset = heroAsset;
    });

    if (!mounted) return;

    MvSessionFeeling deriveFeeling(int rpe) {
      if (rpe <= 4) return MvSessionFeeling.easy;
      if (rpe <= 7) return MvSessionFeeling.good;
      return MvSessionFeeling.hard;
    }

    Widget playerWidget;
    switch (session.sessionMode) {
      case MvSessionMode.route:
        playerWidget = MvRouteTemplate(
          session: session,
          onFinish: ({
            required elapsedSeconds,
            required distanceM,
            required elevationGainM,
            required packWeightKg,
            required rpe1To10,
            routeId,
          }) async {
            final now = DateTime.now().millisecondsSinceEpoch;
            final finished = session.copyWith(
              distanceM: distanceM,
              elevationGainM: elevationGainM,
              packWeightKg: packWeightKg,
              rpe1To10: rpe1To10,
              routeId: routeId,
              status: MvSessionStatus.completed,
              endedAt: elapsedSeconds > 0
                  ? (session.startedAt + (elapsedSeconds * 1000))
                  : now,
            );
            await _controller.finishSessionUseCase.execute(
              session: finished,
              setLogs: const [],
              feeling: deriveFeeling(rpe1To10),
              rpe1To10: rpe1To10,
            );
            await _controller.loadAllData();
            if (mounted) {
              setState(() => _heroAnimationAsset = null);
              Navigator.pop(context);
            }
          },
        );
        break;
      case MvSessionMode.laps:
        playerWidget = MvLapsTemplate(
          session: session,
          onFinish: (elapsedSeconds, totalLaps, rpe1To10) async {
            final now = DateTime.now().millisecondsSinceEpoch;
            final finished = session.copyWith(
              laps: totalLaps,
              rpe1To10: rpe1To10,
              status: MvSessionStatus.completed,
              endedAt: elapsedSeconds > 0
                  ? (session.startedAt + (elapsedSeconds * 1000))
                  : now,
            );
            await _controller.finishSessionUseCase.execute(
              session: finished,
              setLogs: const [],
              feeling: deriveFeeling(rpe1To10),
              rpe1To10: rpe1To10,
            );
            await _controller.loadAllData();
            if (mounted) {
              setState(() => _heroAnimationAsset = null);
              Navigator.pop(context);
            }
          },
        );
        break;
      case MvSessionMode.match:
        playerWidget = MvMatchTemplate(
          session: session,
          onFinish: (elapsedSeconds, rpe1To10, note) async {
            final now = DateTime.now().millisecondsSinceEpoch;
            final finished = session.copyWith(
              rpe1To10: rpe1To10,
              note: note,
              status: MvSessionStatus.completed,
              endedAt: elapsedSeconds > 0
                  ? (session.startedAt + (elapsedSeconds * 1000))
                  : now,
            );
            await _controller.finishSessionUseCase.execute(
              session: finished,
              setLogs: const [],
              feeling: deriveFeeling(rpe1To10),
              rpe1To10: rpe1To10,
              note: note,
            );
            await _controller.loadAllData();
            if (mounted) {
              setState(() => _heroAnimationAsset = null);
              Navigator.pop(context);
            }
          },
        );
        break;
      case MvSessionMode.distance:
        playerWidget = MvDistanceTemplate(
          session: session,
          onFinish: (elapsedSeconds, distanceM, rpe1To10) async {
            final now = DateTime.now().millisecondsSinceEpoch;
            final finished = session.copyWith(
              distanceM: distanceM,
              rpe1To10: rpe1To10,
              status: MvSessionStatus.completed,
              endedAt: elapsedSeconds > 0
                  ? (session.startedAt + (elapsedSeconds * 1000))
                  : now,
            );
            await _controller.finishSessionUseCase.execute(
              session: finished,
              setLogs: const [],
              feeling: deriveFeeling(rpe1To10),
              rpe1To10: rpe1To10,
            );
            await _controller.loadAllData();
            if (mounted) {
              setState(() => _heroAnimationAsset = null);
              Navigator.pop(context);
            }
          },
        );
        break;
      case MvSessionMode.timed:
        playerWidget = MvTimedTemplate(
          session: session,
          onFinish: (elapsedSeconds, rpe1To10) async {
            final now = DateTime.now().millisecondsSinceEpoch;
            final finished = session.copyWith(
              rpe1To10: rpe1To10,
              status: MvSessionStatus.completed,
              endedAt: elapsedSeconds > 0
                  ? (session.startedAt + (elapsedSeconds * 1000))
                  : now,
            );
            await _controller.finishSessionUseCase.execute(
              session: finished,
              setLogs: const [],
              feeling: deriveFeeling(rpe1To10),
              rpe1To10: rpe1To10,
            );
            await _controller.loadAllData();
            if (mounted) {
              setState(() => _heroAnimationAsset = null);
              Navigator.pop(context);
            }
          },
        );
        break;
      case MvSessionMode.guided:
      case MvSessionMode.structured:
      case MvSessionMode.quickLog:
        playerWidget = MvSessionPlayerScreen(
          initialSession: session,
          plannedExercises: exercises,
          allCandidatePool: _controller.allExercises,
          onSessionCompleted: (completedSession, setLogs, feeling, note) async {
            await _controller.finishSessionUseCase.execute(
              session: completedSession,
              setLogs: setLogs,
              feeling: feeling,
              note: note,
            );
            await _controller.loadAllData();
            if (mounted) {
              setState(() => _heroAnimationAsset = null);
            }
          },
        );
        break;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => playerWidget),
    );

    if (mounted) {
      setState(() => _heroAnimationAsset = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If onboarding not completed, route directly to 20-second Onboarding
    if (!_controller.profile.onboardingCompleted) {
      return MvOnboardingScreen(
        onComplete: (profile) async {
          await _controller.saveProfile(profile);
        },
      );
    }

    final colors = context.ritmoColors;

    final todayIso = MvCalendar.formatDateIso(DateTime.now());
    final currentSlot =
        _controller.weekSlots
            .where((s) => s.dateIso == _controller.selectedDateIso)
            .firstOrNull ??
        _controller.weekSlots.where((s) => s.dateIso == todayIso).firstOrNull ??
        MvSlot(
          id: 'temp_$todayIso',
          dateIso: todayIso,
          headlineFa: '',
          createdAt: 0,
          updatedAt: 0,
        );

    final l10n = AppLocalizations.of(context)!;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 142.0;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Layer 1: Body Content
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
              child: IndexedStack(
                index: _selectedTabIndex,
                children: [
                  // Tab 0: امروز
                  MvTodayTab(
                    weekSlots: _controller.weekSlots,
                    todaySlot: currentSlot,
                    topPadding: contentTopPadding,
                    readinessDecision:
                        _controller.readinessDecision ??
                        const MvDecision<MvReadinessTier>(
                          value: MvReadinessTier.full,
                          reasonFa: '',
                        ),
                    budgetProgress:
                        _controller.budgetProgress ??
                        const MvWeeklyBudgetProgress(
                          moderateEquivalentMinutes: 0,
                          rawMetMinutes: 0,
                          strengthDays: 0,
                          targetMin: 150,
                          targetOptimal: 300,
                          strengthDaysTarget: 2,
                        ),
                    bodyMapDistribution:
                        _controller.bodyMapDistribution ??
                        const MvBodyMapDistribution(muscleSessionCounts: {}),
                    heroAnimationAsset: _heroAnimationAsset,
                    kindUseCase: _kindUseCase,
                    onStartSession: () => _handleStartOrResumeSession(currentSlot),
                    onContinueSession: () => _handleStartOrResumeSession(currentSlot),
                    isSessionInProgress: _controller.activeSession != null,
                    onSlotUpdated: _controller.updateSlot,
                    onCheckinSaved: _controller.saveCheckin,
                    onQuickLogSaved: _controller.saveQuickLog,
                    onDateSelected: _controller.selectDate,
                  ),

                  // Tab 1: هفته
                  MvWeekTab(
                    weekSlots: _controller.weekSlots,
                    cycleWeek: _controller.cycleWeek,
                    commitments: _controller.commitments,
                    kindUseCase: _kindUseCase,
                    topPadding: contentTopPadding,
                    onSlotUpdated: _controller.updateSlot,
                    onRegenerateWeek: _controller.regenerateWeek,
                    onOpenCommitments: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MvCommitmentsScreen(
                            controller: _controller,
                          ),
                        ),
                      );
                    },
                  ),

                  // Tab 2: پیشرفت
                  MvProgressTab(
                    continuousActiveWeeks: _controller.continuousActiveWeeks,
                    totalSessionsCount: _controller.totalSessionsCount,
                    totalMetMinutes: _controller.budgetProgress?.currentMetMinutes ?? 0,
                    weeklyBudget: _controller.budgetProgress,
                    loadSnapshot: _controller.loadSnapshot,
                    insights: _controller.insights,
                    personalRecords: _controller.prs,
                    activeCampaign: _controller.activeCampaign,
                    onCreateCampaign: _controller.saveCampaign,
                    topPadding: contentTopPadding,
                    bodyMapDistribution:
                        _controller.bodyMapDistribution ??
                        const MvBodyMapDistribution(muscleSessionCounts: {}),
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
                child: _buildCapsuleHeader(context, isDark, colors, l10n, currentSlot),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleHeader(
    BuildContext context,
    bool isDark,
    dynamic colors,
    AppLocalizations l10n,
    MvSlot currentSlot,
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
                // Top Row: Back Button, Title, AI Coach, Library, Commitments, Settings
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
                            color: isDark ? Colors.white : const Color(0xFF1D2129),
                            size: 20,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        )
                      else
                        const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.mv_hub_title,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17.5,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1D2129),
                          ),
                        ),
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.sparkles,
                        iconColor: const Color(0xFF10B981),
                        isAiButton: true,
                        isDark: isDark,
                        tooltip: l10n.mv_coach_tooltip,
                        onTap: () {
                          MvAiCoachSheet.show(
                            context: context,
                            profile: _controller.profile,
                            currentSlot: currentSlot,
                          );
                        },
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.square_grid_2x2,
                        iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                        isDark: isDark,
                        tooltip: l10n.mv_library_tooltip,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MvLibraryScreen(allExercises: _controller.allExercises),
                            ),
                          );
                        },
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.lock_shield,
                        iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                        isDark: isDark,
                        tooltip: l10n.mv_commitments_title,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MvCommitmentsScreen(
                                controller: _controller,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.settings,
                        iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                        isDark: isDark,
                        tooltip: l10n.mv_settings_tooltip,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MvSettingsScreen(
                                initialProfile: _controller.profile,
                                controller: _controller,
                                onProfileSaved: (p) async {
                                  await _controller.saveProfile(p);
                                },
                                onRegenerateProgram: _controller.regenerateWeek,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                ),

                // Bottom Collapsible 3-Tier Segmented Tabs
                ClipRect(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    height: _isTabsVisible ? 54.0 : 0.0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isTabsVisible ? 1.0 : 0.0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                        child: Align(
                          alignment: Alignment.center,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: _buildSegmentedTabs(colors, isDark, l10n),
                          ),
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

  Widget _buildSegmentedTabs(
    dynamic colors,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final trackBgColor = isDark ? const Color(0xFF16191E) : const Color(0xFFEFF2F6);
    const accentColor = Color(0xFF10B981);
    final pillBgColor = isDark
        ? const Color(0xFF22262F)
        : Color.lerp(Colors.white, accentColor, 0.12)!;
    final activeIndex = _selectedTabIndex.clamp(0, 2);

    final tabs = [
      (title: l10n.mv_tab_today, icon: CupertinoIcons.sun_max_fill),
      (title: l10n.mv_tab_week, icon: CupertinoIcons.calendar),
      (title: l10n.mv_tab_progress, icon: CupertinoIcons.chart_bar_alt_fill),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const outerPadding = 4.0;
        final availableWidth = totalWidth - (outerPadding * 2);
        final tabWidth = availableWidth / 3;
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
                      color: accentColor.withValues(alpha: isDark ? 0.40 : 0.28),
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
                children: List.generate(3, (index) {
                  final item = tabs[index];
                  final isSelected = activeIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedTabIndex = index);
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? accentColor
                                : (isDark
                                    ? const Color(0xFF8A93A4)
                                    : const Color(0xFF6B7280)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 13,
                                  color: isSelected
                                      ? accentColor
                                      : (isDark
                                          ? const Color(0xFF8A93A4)
                                          : const Color(0xFF6B7280)),
                                ),
                                const SizedBox(width: 4),
                                Text(item.title),
                              ],
                            ),
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
}
