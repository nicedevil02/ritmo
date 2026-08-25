import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../player/player.dart';
import '../sheets/sheets.dart';
import 'mv_library_screen.dart';
import 'mv_onboarding_screen.dart';
import 'mv_progress_tab.dart';
import 'mv_settings_screen.dart';
import 'mv_today_tab.dart';
import 'mv_week_tab.dart';

/// Screen 1: "هاب ورزشی ریتمو" (Section 4, 5.1, 5.2, 5.3).
/// Unified hub hosting the 3 tabs (امروز، هفته، پیشرفت) and direct actions.
class MvHubScreen extends StatefulWidget {
  final MvHubController? controller;

  const MvHubScreen({
    super.key,
    this.controller,
  });

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

  void _onControllerUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _handleStartOrResumeSession(MvSlot slot) async {
    final result = await _controller.startSessionUseCase.execute(
      slot: slot,
      profile: _controller.profile,
      preloadedPool: _controller.allExercises,
    );

    setState(() {
      _heroAnimationAsset = result.heroAnimationAsset;
    });

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MvSessionPlayerScreen(
          initialSession: result.session,
          plannedExercises: result.exercises,
          allCandidatePool: _controller.allExercises,
          onSessionCompleted: (session, setLogs, feeling, note) async {
            await _controller.finishSessionUseCase.execute(
              session: session,
              setLogs: setLogs,
              feeling: feeling,
              note: note,
            );
            await _controller.loadAllData();
          },
        ),
      ),
    );

    await _controller.loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
    final currentSlot = _controller.weekSlots.where((s) => s.dateIso == _controller.selectedDateIso).firstOrNull ??
        _controller.weekSlots.where((s) => s.dateIso == todayIso).firstOrNull ??
        MvSlot(
          id: 'temp_$todayIso',
          dateIso: todayIso,
          headlineFa: 'تمرین روز',
          createdAt: 0,
          updatedAt: 0,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ورزش و حرکت',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center_rounded),
            tooltip: 'کتابخانهٔ حرکات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MvLibraryScreen(allExercises: _controller.allExercises),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'مربی هوشمند',
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
            tooltip: 'تنظیمات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MvSettingsScreen(
                    initialProfile: _controller.profile,
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
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          // Tab 0: امروز
          MvTodayTab(
            weekSlots: _controller.weekSlots,
            todaySlot: currentSlot,
            readinessDecision: _controller.readinessDecision ??
                const MvDecision<MvReadinessTier>(
                  value: MvReadinessTier.full,
                  reasonFa: 'آمادگی کامل برای تمرین',
                ),
            budgetProgress: _controller.budgetProgress ??
                const MvWeeklyBudgetProgress(
                  targetMetMinutes: 500,
                  targetActiveDays: 3,
                  currentMetMinutes: 0,
                  currentActiveDays: 0,
                ),
            bodyMapDistribution: _controller.bodyMapDistribution ??
                const MvBodyMapDistribution(muscleSessionCounts: {}),
            heroAnimationAsset: _heroAnimationAsset,
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
            cycleWeek: 1,
            onSlotUpdated: _controller.updateSlot,
            onRegenerateWeek: _controller.regenerateWeek,
          ),

          // Tab 2: پیشرفت
          MvProgressTab(
            continuousActiveWeeks: _controller.continuousActiveWeeks,
            totalSessionsCount: _controller.weekSlots.where((s) => s.isCompleted).length,
            totalMetMinutes: _controller.budgetProgress?.currentMetMinutes ?? 0,
            personalRecords: _controller.prs,
            bodyMapDistribution: _controller.bodyMapDistribution ??
                const MvBodyMapDistribution(muscleSessionCounts: {}),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
        indicatorColor: colors.primary.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'امروز',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week_rounded),
            label: 'هفته',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'پیشرفت',
          ),
        ],
      ),
    );
  }
}
