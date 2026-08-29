import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    final contentTopPadding = topPadding + 190.0;
    const accentColor = Color(0xFF10B981);

    return RitmoTabbedMorphingScaffold(
      title: l10n.mv_hub_title,
      subtitle: 'حرکات اصلاحی، گرم‌کردن، کشش و تمرینات روزانه',
      accentColor: accentColor,
      useIndexedStack: true,
      initialIndex: _selectedTabIndex,
      onTabChanged: (index) => setState(() => _selectedTabIndex = index),
      onBack: () => Navigator.maybePop(context),
      actions: [
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.sparkles,
          iconColor: accentColor,
          isAiButton: true,
          accentColor: accentColor,
          tooltip: l10n.mv_coach_tooltip,
          onTap: () {
            MvAiCoachSheet.show(
              context: context,
              profile: _controller.profile,
              currentSlot: currentSlot,
            );
          },
        ),
        const SizedBox(width: 8),
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.square_grid_2x2,
          iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
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
        const SizedBox(width: 8),
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.lock_shield,
          iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
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
        const SizedBox(width: 8),
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.settings,
          iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
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
      ],
      tabItems: [
        RitmoTabItem(
          title: l10n.mv_tab_today,
          icon: CupertinoIcons.sun_max_fill,
          value: 0,
        ),
        RitmoTabItem(
          title: l10n.mv_tab_week,
          icon: CupertinoIcons.calendar,
          value: 1,
        ),
        RitmoTabItem(
          title: l10n.mv_tab_progress,
          icon: CupertinoIcons.chart_bar_alt_fill,
          value: 2,
        ),
      ],
      tabBuilders: [
        // Tab 0: امروز
        (ctx, scrollController) => MvTodayTab(
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
        (ctx, scrollController) => MvWeekTab(
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
        (ctx, scrollController) => MvProgressTab(
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
    );
  }
}
