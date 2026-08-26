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

    final colors = context.ritmoColors;
    final textTheme = Theme.of(context).textTheme;

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.mv_hub_title,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center_rounded),
            tooltip: l10n.mv_library_tooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MvLibraryScreen(allExercises: _controller.allExercises),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: l10n.mv_coach_tooltip,
            onPressed: () {
              MvAiCoachSheet.show(
                context: context,
                profile: _controller.profile,
                currentSlot: currentSlot,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.mv_settings_tooltip,
            onPressed: () {
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
          IconButton(
            key: const ValueKey('mv_open_commitments'),
            icon: const Icon(Icons.lock_clock),
            tooltip: l10n.mv_commitments_title,
            onPressed: () {
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
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          // Tab 0: امروز
          MvTodayTab(
            weekSlots: _controller.weekSlots,
            todaySlot: currentSlot,
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
            bodyMapDistribution:
                _controller.bodyMapDistribution ??
                const MvBodyMapDistribution(muscleSessionCounts: {}),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today_rounded),
            label: l10n.mv_tab_today,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_view_week_outlined),
            selectedIcon: const Icon(Icons.calendar_view_week_rounded),
            label: l10n.mv_tab_week,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: l10n.mv_tab_progress,
          ),
        ],
      ),
    );
  }
}
