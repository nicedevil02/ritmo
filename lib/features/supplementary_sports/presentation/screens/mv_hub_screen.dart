import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
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
  final VoidCallback? onOpenPlayer;

  const MvHubScreen({
    super.key,
    this.onOpenPlayer,
  });

  @override
  State<MvHubScreen> createState() => _MvHubScreenState();
}

class _MvHubScreenState extends State<MvHubScreen> {
  int _selectedTabIndex = 0;
  bool _isLoading = true;

  // Repositories
  final _profileRepo = MvProfileRepository();
  final _prescriptionRepo = MvPrescriptionRepository();
  final _sessionRepo = MvSessionRepository();
  final _exerciseRepo = MvExerciseRepository();
  final _prRepo = MvPrRepository();
  final _checkinRepo = MvDailyCheckinRepository();

  // Engines
  static const _planEngine = PlanEngine();
  static const _readinessEngine = ReadinessEngine();
  static const _budgetEngine = BudgetEngine();
  static const _insightEngine = InsightEngine();

  // State
  late MvUserProfile _profile;
  List<MvSlot> _weekSlots = [];
  List<MvExercise> _allExercises = [];
  List<MvPersonalRecord> _prs = [];
  MvDecision<MvReadinessTier>? _readinessDecision;
  MvWeeklyBudgetProgress? _budgetProgress;
  MvBodyMapDistribution? _bodyMapDistribution;
  String _selectedDateIso = MvCalendar.formatDateIso(DateTime.now());
  MvSession? _activeSession;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    _profile = await _profileRepo.getProfile();
    if (!_profile.onboardingCompleted) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final today = DateTime.now();
    final todayIso = MvCalendar.formatDateIso(today);
    final weekStartSat = MvCalendar.getWeekDays(today).first;

    // Load exercises & PRs
    _allExercises = await _exerciseRepo.getAllExercises();
    _prs = await _prRepo.getAllPrs();
    _activeSession = await _sessionRepo.getActiveSession();

    // Load or generate week plan
    _weekSlots = await _prescriptionRepo.getWeekSlots(MvCalendar.formatDateIso(weekStartSat));
    if (_weekSlots.isEmpty) {
      final generated = _planEngine.generateWeekPlan(
        profile: _profile,
        weekSaturday: weekStartSat,
      );
      _weekSlots = generated.value;
      for (final slot in _weekSlots) {
        await _prescriptionRepo.savePrescription(slot);
      }
    }

    // Load Daily Checkin & evaluate readiness
    final checkin = await _checkinRepo.getCheckinForDate(todayIso);
    _readinessDecision = _readinessEngine.evaluateReadiness(
      checkin: checkin,
      cycleConsentGranted: _profile.cycleConsentGranted,
    );

    // Calculate MET-min progress
    final weekSessions = await _sessionRepo.getRecentSessions(limit: 20);
    _budgetProgress = _budgetEngine.calculateWeeklyProgress(
      profile: _profile,
      weekCompletedSessions: weekSessions,
      currentDayOfWeekSat0: MvCalendar.dateTimeToSat0(today),
    ).value;

    // Calculate Muscle distribution
    _bodyMapDistribution = _insightEngine.calculateMuscleDistribution(
      completedSlots: _weekSlots.where((s) => s.isCompleted).toList(),
    ).value;

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleOnboardingComplete(MvUserProfile newProfile) async {
    await _profileRepo.saveProfile(newProfile);
    _profile = newProfile;
    final weekStartSat = MvCalendar.getWeekDays(DateTime.now()).first;
    final generated = _planEngine.generateWeekPlan(
      profile: newProfile,
      weekSaturday: weekStartSat,
    );
    _weekSlots = generated.value;
    for (final slot in _weekSlots) {
      await _prescriptionRepo.savePrescription(slot);
    }
    await _loadAllData();
  }

  Future<void> _handleSlotUpdated(MvSlot updated) async {
    await _prescriptionRepo.savePrescription(updated);
    final idx = _weekSlots.indexWhere((s) => s.id == updated.id || s.dateIso == updated.dateIso);
    if (idx != -1) {
      setState(() {
        _weekSlots[idx] = updated;
      });
    }
  }

  Future<void> _handleCheckinSaved(MvDailyCheckin checkin) async {
    await _checkinRepo.saveCheckin(checkin);
    _readinessDecision = _readinessEngine.evaluateReadiness(
      checkin: checkin,
      cycleConsentGranted: _profile.cycleConsentGranted,
    );
    setState(() {});
  }

  Future<void> _handleQuickLogSaved(String kindCode, int duration, MvSessionFeeling? feeling, String? note) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = MvSession(
      id: 'log_$now',
      kindCode: kindCode,
      sessionMode: MvSessionMode.quickLog,
      status: MvSessionStatus.completed,
      startedAt: now - (duration * 60000),
      endedAt: now,
      overallFeeling: feeling,
      note: note,
      createdAt: now,
      updatedAt: now,
    );
    await _sessionRepo.finishSession(session);

    // Update today's slot as completed
    final todayIso = MvCalendar.formatDateIso(DateTime.now());
    final slot = _weekSlots.where((s) => s.dateIso == todayIso).firstOrNull;
    if (slot != null) {
      final doneSlot = slot.copyWith(status: MvSlotStatus.done);
      await _handleSlotUpdated(doneSlot);
    }
    await _loadAllData();
  }

  Future<void> _regenerateWeek() async {
    final weekStartSat = MvCalendar.getWeekDays(DateTime.now()).first;
    final generated = _planEngine.generateWeekPlan(
      profile: _profile,
      weekSaturday: weekStartSat,
      existingSlots: _weekSlots.where((s) => s.isLocked).toList(),
    );
    _weekSlots = generated.value;
    for (final slot in _weekSlots) {
      await _prescriptionRepo.savePrescription(slot);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If onboarding not completed, route directly to 20-second Onboarding
    if (!_profile.onboardingCompleted) {
      return MvOnboardingScreen(onComplete: _handleOnboardingComplete);
    }

    final colors = context.ritmoColors;
    final textTheme = Theme.of(context).textTheme;

    final todayIso = MvCalendar.formatDateIso(DateTime.now());
    final currentSlot = _weekSlots.where((s) => s.dateIso == _selectedDateIso).firstOrNull ??
        _weekSlots.where((s) => s.dateIso == todayIso).firstOrNull ??
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
                  builder: (_) => MvLibraryScreen(allExercises: _allExercises),
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
                profile: _profile,
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
                    initialProfile: _profile,
                    onProfileSaved: (p) async {
                      await _profileRepo.saveProfile(p);
                      _profile = p;
                      await _loadAllData();
                    },
                    onRegenerateProgram: _regenerateWeek,
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
            weekSlots: _weekSlots,
            todaySlot: currentSlot,
            readinessDecision: _readinessDecision ??
                const MvDecision<MvReadinessTier>(
                  value: MvReadinessTier.full,
                  reasonFa: 'آمادگی کامل برای تمرین',
                ),
            budgetProgress: _budgetProgress ??
                const MvWeeklyBudgetProgress(
                  targetMetMinutes: 500,
                  targetActiveDays: 3,
                  currentMetMinutes: 0,
                  currentActiveDays: 0,
                ),
            bodyMapDistribution: _bodyMapDistribution ??
                const MvBodyMapDistribution(muscleSessionCounts: {}),
            onStartSession: () => widget.onOpenPlayer?.call(),
            onContinueSession: () => widget.onOpenPlayer?.call(),
            isSessionInProgress: _activeSession != null,
            onSlotUpdated: _handleSlotUpdated,
            onCheckinSaved: _handleCheckinSaved,
            onQuickLogSaved: _handleQuickLogSaved,
            onDateSelected: (dateIso) => setState(() => _selectedDateIso = dateIso),
          ),

          // Tab 1: هفته
          MvWeekTab(
            weekSlots: _weekSlots,
            cycleWeek: 1,
            onSlotUpdated: _handleSlotUpdated,
            onRegenerateWeek: _regenerateWeek,
          ),

          // Tab 2: پیشرفت
          MvProgressTab(
            continuousActiveWeeks: 3,
            totalSessionsCount: _weekSlots.where((s) => s.isCompleted).length,
            totalMetMinutes: _budgetProgress?.currentMetMinutes ?? 0,
            personalRecords: _prs,
            bodyMapDistribution: _bodyMapDistribution ??
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
