import 'package:flutter/foundation.dart';
import 'package:ritmo/core/domain/engines/ritmo_cross_module_engine.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'mv_cant_today_use_case.dart';
import 'mv_finish_session_use_case.dart';
import 'mv_quick_log_use_case.dart';
import 'mv_readiness_use_case.dart';
import 'mv_start_session_use_case.dart';
import 'mv_week_regen_use_case.dart';

/// Application Controller: Orchestrates state loading and actions for MvHubScreen (Clean Architecture).
class MvHubController extends ChangeNotifier {
  final MvProfileRepository _profileRepo;
  final MvPrescriptionRepository _prescriptionRepo;
  final MvSessionRepository _sessionRepo;
  final MvExerciseRepository _exerciseRepo;
  final MvPrRepository _prRepo;
  final MvCommitmentRepository _commitmentRepo;
  final MvKindRepository _kindRepo;
  final MvCampaignRepository _campaignRepo;

  MvCommitmentRepository get commitmentRepo => _commitmentRepo;
  MvKindRepository get kindRepo => _kindRepo;
  MvCampaignRepository get campaignRepo => _campaignRepo;

  // Use Cases
  final MvStartSessionUseCase startSessionUseCase;
  final MvFinishSessionUseCase finishSessionUseCase;
  final MvQuickLogUseCase quickLogUseCase;
  final MvCantTodayUseCase cantTodayUseCase;
  final MvReadinessUseCase readinessUseCase;
  final MvWeekRegenUseCase weekRegenUseCase;

  // Engines
  final BudgetEngine _budgetEngine;
  final InsightEngine _insightEngine;
  final LoadEngine _loadEngine;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  MvLoadSnapshot? _loadSnapshot;
  MvLoadSnapshot? get loadSnapshot => _loadSnapshot;

  MvCampaign? _activeCampaign;
  MvCampaign? get activeCampaign => _activeCampaign;

  late MvUserProfile _profile;
  MvUserProfile get profile => _profile;

  List<MvSlot> _weekSlots = [];
  List<MvSlot> get weekSlots => _weekSlots;

  List<MvCommitment> _commitments = const [];
  List<MvCommitment> get commitments => _commitments;

  int _cycleWeek = 1;
  int get cycleWeek => _cycleWeek;

  List<MvExercise> _allExercises = [];
  List<MvExercise> get allExercises => _allExercises;

  List<MvPersonalRecord> _prs = [];
  List<MvPersonalRecord> get prs => _prs;

  MvSession? _activeSession;
  MvSession? get activeSession => _activeSession;

  MvDecision<MvReadinessTier>? _readinessDecision;
  MvDecision<MvReadinessTier>? get readinessDecision => _readinessDecision;

  RitmoCrossModuleSnapshot? _crossModuleSnapshot;
  RitmoCrossModuleSnapshot? get crossModuleSnapshot => _crossModuleSnapshot;

  MvWeeklyBudgetProgress? _budgetProgress;
  MvWeeklyBudgetProgress? get budgetProgress => _budgetProgress;

  MvBodyMapDistribution? _bodyMapDistribution;
  MvBodyMapDistribution? get bodyMapDistribution => _bodyMapDistribution;

  String _selectedDateIso = MvCalendar.formatDateIso(DateTime.now());
  String get selectedDateIso => _selectedDateIso;

  int? _continuousActiveWeeks;
  int? get continuousActiveWeeks => _continuousActiveWeeks;

  int _totalSessionsCount = 0;
  int get totalSessionsCount => _totalSessionsCount;

  double _totalHistoricalMetMinutes = 0;
  double get totalHistoricalMetMinutes => _totalHistoricalMetMinutes;

  List<MvInsight> _insights = const [];
  List<MvInsight> get insights => _insights;

  bool _isFetching = false;

  MvHubController({
    MvProfileRepository? profileRepo,
    MvPrescriptionRepository? prescriptionRepo,
    MvSessionRepository? sessionRepo,
    MvExerciseRepository? exerciseRepo,
    MvPrRepository? prRepo,
    MvCommitmentRepository? commitmentRepo,
    MvKindRepository? kindRepo,
    MvKindProfileRepository? kindProfileRepo,
    MvCampaignRepository? campaignRepo,
    MvDailyCheckinRepository? checkinRepo,
    SelectionEngine? selectionEngine,
    ProgressionEngine? progressionEngine,
    AdaptationEngine? adaptationEngine,
    ReadinessEngine? readinessEngine,
    PlanEngine? planEngine,
    BudgetEngine? budgetEngine,
    InsightEngine? insightEngine,
    LoadEngine? loadEngine,
  }) : _profileRepo = profileRepo ?? MvProfileRepository(),
       _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
       _sessionRepo = sessionRepo ?? MvSessionRepository(),
       _exerciseRepo = exerciseRepo ?? MvExerciseRepository(),
       _prRepo = prRepo ?? MvPrRepository(),
       _commitmentRepo = commitmentRepo ?? MvCommitmentRepositoryImpl(),
       _kindRepo = kindRepo ?? MvKindRepository(),
       _campaignRepo = campaignRepo ?? MvCampaignRepository(),
       startSessionUseCase = MvStartSessionUseCase(
         sessionRepo: sessionRepo,
         exerciseRepo: exerciseRepo,
         kindRepo: kindRepo,
         selectionEngine: selectionEngine,
       ),
       finishSessionUseCase = MvFinishSessionUseCase(
         sessionRepo: sessionRepo,
         prescriptionRepo: prescriptionRepo,
         prRepo: prRepo,
         progressionEngine: progressionEngine,
       ),
       quickLogUseCase = MvQuickLogUseCase(
         sessionRepo: sessionRepo,
         prescriptionRepo: prescriptionRepo,
         kindRepo: kindRepo,
       ),
       cantTodayUseCase = MvCantTodayUseCase(
         prescriptionRepo: prescriptionRepo,
         adaptationEngine: adaptationEngine,
       ),
       readinessUseCase = MvReadinessUseCase(
         checkinRepo: checkinRepo,
         readinessEngine: readinessEngine,
       ),
       weekRegenUseCase = MvWeekRegenUseCase(
         prescriptionRepo: prescriptionRepo,
         commitmentRepo: commitmentRepo,
         kindRepo: kindRepo,
         kindProfileRepo: kindProfileRepo,
         planEngine: planEngine,
       ),
       _budgetEngine = budgetEngine ?? const BudgetEngine(),
       _insightEngine = insightEngine ?? const InsightEngine(),
       _loadEngine = loadEngine ?? const LoadEngine();

  /// Loads all required data for the hub.
  Future<void> loadAllData({bool showLoadingIndicator = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (showLoadingIndicator) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _profile = await _profileRepo.getProfile();
      if (!_profile.onboardingCompleted) {
        _isLoading = false;
        _isFetching = false;
        notifyListeners();
        return;
      }

      final today = DateTime.now();
      final todayIso = MvCalendar.formatDateIso(today);
      final weekStartSat = MvCalendar.getWeekDays(today).first;
      final weekStartIso = MvCalendar.formatDateIso(weekStartSat);

      // Fetch commitments & active campaign
      _commitments = await _commitmentRepo.getActive();
      _activeCampaign = await _campaignRepo.getActive();

      // Compute cycleWeek
      final startDate = _profile.programStartDate != null
          ? MvCalendar.parseDateIso(_profile.programStartDate!)
          : weekStartSat;
      _cycleWeek = MvCalendar.cycleWeekFor(
        targetDate: weekStartSat,
        programStartDate: startDate,
        totalWeeks: _profile.deloadEveryNWeeks > 0 ? _profile.deloadEveryNWeeks : 4,
      );

      // Fetch exercises, PRs, active session
      _allExercises = await _exerciseRepo.getAllExercises();
      _prs = await _prRepo.getAllPrs();
      _activeSession = await _sessionRepo.getActiveSession();

      // Evaluate Readiness
      _readinessDecision = await readinessUseCase.execute(
        dateIso: todayIso,
        profile: _profile,
      );
      _crossModuleSnapshot =
          await RitmoCrossModuleEngine.instance.getSnapshot(date: today);

      // Calculate MET-min progress (week-bounded from Saturday 00:00 to Friday 23:59:59)
      final weekStart = DateTime(
        weekStartSat.year,
        weekStartSat.month,
        weekStartSat.day,
        0,
        0,
        0,
      );
      final weekEnd = DateTime(
        weekStartSat.year,
        weekStartSat.month,
        weekStartSat.day + 6,
        23,
        59,
        59,
        999,
      );
      final weekSessions = await _sessionRepo.getCompletedSessionsBetween(
        weekStart,
        weekEnd,
      );
      _budgetProgress = _budgetEngine
          .calculateWeeklyProgress(
            profile: _profile,
            weekCompletedSessions: weekSessions,
            currentDayOfWeekSat0: MvCalendar.dateTimeToSat0(today),
          )
          .value;

      // History sessions for streak, ACWR, PRs
      final historySessions = await _sessionRepo.getSessionHistory(limit: 200);
      _totalSessionsCount = historySessions.length;
      _totalHistoricalMetMinutes = historySessions.fold<double>(
        0.0,
        (acc, s) => acc + s.elapsedMinutes.toDouble(),
      );
      _continuousActiveWeeks = calculateContinuousWeeks(
        historySessions,
        referenceDate: today,
      );

      // Calculate Acute:Chronic Workload Ratio (LoadEngine / S8-T7)
      final sortedHistory = List<MvSession>.from(historySessions)
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      final daysOfHistory = _profile.programStartDate != null
          ? today.difference(MvCalendar.parseDateIso(_profile.programStartDate!)).inDays + 1
          : (sortedHistory.isNotEmpty
              ? today.difference(DateTime.fromMillisecondsSinceEpoch(sortedHistory.first.startedAt)).inDays + 1
              : 0);
      _loadSnapshot = _loadEngine.computeLoadSnapshot(
        completedSessions: historySessions,
        daysOfHistory: daysOfHistory,
        referenceDate: today,
      );

      // Generate Deterministic Progress Insights (InsightEngine / S8-T8)
      _insights = _insightEngine.generateInsights(
        completedSessions: historySessions,
        activeCommitments: _commitments,
        referenceDate: today,
      );

      // Fetch or generate week slots with live data
      _weekSlots = await _prescriptionRepo.getWeekSlots(weekStartIso);
      if (_weekSlots.isEmpty) {
        _weekSlots = await weekRegenUseCase.execute(
          profile: _profile,
          weekSaturday: weekStartSat,
          existingSlots: _weekSlots,
          commitments: _commitments,
          overrides: const [],
          budget: _budgetProgress != null
              ? MvBudgetSnapshot(
                  moderateEquivalentMinutes: _budgetProgress!.moderateEquivalentMinutes,
                  rawMetMinutes: _budgetProgress!.rawMetMinutes,
                  strengthDays: _budgetProgress!.strengthDays,
                )
              : const MvBudgetSnapshot(
                  moderateEquivalentMinutes: 0,
                  rawMetMinutes: 0,
                  strengthDays: 0,
                ),
          load: _loadSnapshot,
          readiness: _readinessDecision?.value ?? MvReadinessTier.full,
          activeCampaign: _activeCampaign,
        );
      }

      // Calculate Muscle distribution
      _bodyMapDistribution = _insightEngine
          .calculateMuscleDistribution(
            completedSlots: _weekSlots.where((s) => s.isCompleted).toList(),
          )
          .value;
    } finally {
      _isLoading = false;
      _isFetching = false;
      notifyListeners();
    }
  }

  /// Calculates real consecutive active weeks (>= 2 completed sessions per week).
  /// Returns null if no completed sessions exist.
  static int? calculateContinuousWeeks(
    List<MvSession> sessions, {
    DateTime? referenceDate,
  }) {
    final completed = sessions
        .where(
          (s) =>
              s.status == MvSessionStatus.completed ||
              s.status == MvSessionStatus.partial,
        )
        .toList();
    if (completed.isEmpty) return null;

    final ref = referenceDate ?? DateTime.now();
    var currentWeekSat = MvCalendar.getWeekSaturday(ref);

    final currentWeekStartMs = DateTime(
      currentWeekSat.year,
      currentWeekSat.month,
      currentWeekSat.day,
    ).millisecondsSinceEpoch;
    final currentWeekEndMs = DateTime(
      currentWeekSat.year,
      currentWeekSat.month,
      currentWeekSat.day + 6,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;
    final currentWeekCount = completed
        .where((s) => s.startedAt >= currentWeekStartMs && s.startedAt <= currentWeekEndMs)
        .length;

    int streak = 0;
    if (currentWeekCount >= 2) {
      streak = 1;
      currentWeekSat = currentWeekSat.subtract(const Duration(days: 7));
    } else {
      // Current week is in progress, check from last finished week
      currentWeekSat = currentWeekSat.subtract(const Duration(days: 7));
    }

    for (int w = 0; w < 52; w++) {
      final weekStartMs = DateTime(
        currentWeekSat.year,
        currentWeekSat.month,
        currentWeekSat.day,
      ).millisecondsSinceEpoch;
      final weekEndMs = DateTime(
        currentWeekSat.year,
        currentWeekSat.month,
        currentWeekSat.day + 6,
        23,
        59,
        59,
        999,
      ).millisecondsSinceEpoch;

      final count = completed
          .where((s) => s.startedAt >= weekStartMs && s.startedAt <= weekEndMs)
          .length;

      if (count >= 2) {
        streak++;
        currentWeekSat = currentWeekSat.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }

    return streak;
  }

  void selectDate(String dateIso) {
    _selectedDateIso = dateIso;
    notifyListeners();
  }

  Future<void> saveProfile(MvUserProfile newProfile) async {
    await _profileRepo.saveProfile(newProfile);
    _profile = newProfile;
    await loadAllData();
  }

  Future<void> updateSlot(MvSlot updated) async {
    await _prescriptionRepo.savePrescription(updated);
    final idx = _weekSlots.indexWhere(
      (s) => s.id == updated.id || s.dateIso == updated.dateIso,
    );
    if (idx != -1) {
      _weekSlots[idx] = updated;
    } else {
      _weekSlots.add(updated);
    }
    _bodyMapDistribution = _insightEngine
        .calculateMuscleDistribution(
          completedSlots: _weekSlots.where((s) => s.isCompleted).toList(),
        )
        .value;
    notifyListeners();
  }

  /// Deletes or clears a scheduled workout for a day and resets it to Rest.
  /// If [deleteRecurringCommitment] is true and a commitment is associated with this day,
  /// that recurring commitment is deleted from the database.
  /// Returns a record with previous state `(MvSlot, MvCommitment?)` to enable full Undo.
  Future<({MvSlot previousSlot, MvCommitment? previousCommitment})> deleteWorkoutPlan({
    required MvSlot slot,
    bool deleteRecurringCommitment = false,
  }) async {
    final previousSlot = slot;
    MvCommitment? previousCommitment;

    // Find any commitment on this weekday
    final dt = MvCalendar.parseDateIso(slot.dateIso);
    final sat0 = MvCalendar.dateTimeToSat0(dt);
    final matchingCommitment = _commitments
        .where((c) => c.dayOfWeekSat0 == sat0 && c.isActive)
        .firstOrNull;

    if (deleteRecurringCommitment && matchingCommitment != null && matchingCommitment.id != null) {
      previousCommitment = matchingCommitment;
      await _commitmentRepo.delete(matchingCommitment.id!);
      _commitments = await _commitmentRepo.getActive();
    }

    // Reset this day's slot to Rest and lock it so regeneration won't override it for this week
    final now = DateTime.now().millisecondsSinceEpoch;
    final restSlot = MvSlot(
      id: 'slot_${slot.dateIso}_rest',
      dateIso: slot.dateIso,
      cycleWeek: slot.cycleWeek,
      slotType: MvSlotType.rest,
      targetMinutes: 0,
      intensityTier: MvIntensityTier.light,
      headlineFa: 'روز استراحت و ریکاوری',
      coachNoteFa: 'به عضلاتت فرصت بازسازی بده یا با پیاده‌روی سبک جریان خون را تقویت کن.',
      source: 'MANUAL',
      reasonKey: MvReasonKeys.restGuaranteed,
      isLocked: true,
      status: MvSlotStatus.planned,
      createdAt: now,
      updatedAt: now,
    );

    // Save to repository
    await _prescriptionRepo.savePrescription(restSlot);

    // Update in-memory weekSlots
    final idx = _weekSlots.indexWhere(
      (s) => s.id == slot.id || s.dateIso == slot.dateIso,
    );
    if (idx != -1) {
      _weekSlots[idx] = restSlot;
    } else {
      _weekSlots.add(restSlot);
    }

    _bodyMapDistribution = _insightEngine
        .calculateMuscleDistribution(
          completedSlots: _weekSlots.where((s) => s.isCompleted).toList(),
        )
        .value;

    notifyListeners();

    return (previousSlot: previousSlot, previousCommitment: previousCommitment);
  }

  /// Restores a previously deleted workout plan and recurring commitment (Undo mechanism).
  Future<void> restoreWorkoutPlan({
    required MvSlot previousSlot,
    MvCommitment? previousCommitment,
  }) async {
    if (previousCommitment != null) {
      await _commitmentRepo.upsert(previousCommitment);
      _commitments = await _commitmentRepo.getActive();
    }

    await _prescriptionRepo.deletePrescriptionForDate(previousSlot.dateIso);
    await _prescriptionRepo.savePrescription(previousSlot);

    final idx = _weekSlots.indexWhere(
      (s) => s.id == previousSlot.id || s.dateIso == previousSlot.dateIso,
    );
    if (idx != -1) {
      _weekSlots[idx] = previousSlot;
    } else {
      _weekSlots.add(previousSlot);
    }

    _bodyMapDistribution = _insightEngine
        .calculateMuscleDistribution(
          completedSlots: _weekSlots.where((s) => s.isCompleted).toList(),
        )
        .value;

    notifyListeners();
  }

  /// Quick action: converts any day's scheduled slot directly into a Rest day.
  Future<({MvSlot previousSlot, MvCommitment? previousCommitment})> convertSlotToRest(MvSlot slot) async {
    return deleteWorkoutPlan(slot: slot, deleteRecurringCommitment: false);
  }

  /// Quick action: moves a day's slot to tomorrow.
  Future<void> moveSlotToTomorrow(MvSlot slot) async {
    final dt = MvCalendar.parseDateIso(slot.dateIso);
    final tomorrowIso = MvCalendar.formatDateIso(dt.add(const Duration(days: 1)));
    final moved = slot.copyWith(
      status: MvSlotStatus.moved,
      movedToDateIso: tomorrowIso,
    );
    await updateSlot(moved);
  }

  Future<void> saveCheckin(MvDailyCheckin checkin) async {
    await readinessUseCase.saveCheckin(checkin);
    _readinessDecision = await readinessUseCase.execute(
      dateIso: checkin.dateIso,
      profile: _profile,
    );
    notifyListeners();
  }

  Future<void> saveQuickLog(
    String kindCode,
    int durationMinutes,
    MvSessionFeeling? feeling,
    String? note,
  ) async {
    await quickLogUseCase.execute(
      kindCode: kindCode,
      durationMinutes: durationMinutes,
      feeling: feeling,
      note: note,
      dateIso: _selectedDateIso,
    );
    await loadAllData();
  }

  Future<void> saveCampaign(MvCampaign c) async {
    await _campaignRepo.upsert(c);
    _activeCampaign = c;
    await regenerateWeek();
    await loadAllData();
  }

  Future<void> saveCommitment(MvCommitment c) async {
    await _commitmentRepo.upsert(c);
    _commitments = await _commitmentRepo.getActive();
    await regenerateWeek();
    await loadAllData();
  }

  Future<void> deleteCommitment(int id) async {
    await _commitmentRepo.delete(id);
    _commitments = await _commitmentRepo.getActive();
    await regenerateWeek();
    await loadAllData();
  }

  Future<void> toggleCommitmentActive(int id, bool active) async {
    await _commitmentRepo.toggleActive(id, active);
    _commitments = await _commitmentRepo.getActive();
    await regenerateWeek();
    await loadAllData();
  }

  Future<void> regenerateWeek() async {
    final weekStartSat = MvCalendar.getWeekDays(DateTime.now()).first;
    _weekSlots = await weekRegenUseCase.execute(
      profile: _profile,
      weekSaturday: weekStartSat,
      existingSlots: _weekSlots,
      commitments: _commitments,
      overrides: const [],
      budget: _budgetProgress != null
          ? MvBudgetSnapshot(
              moderateEquivalentMinutes: _budgetProgress!.moderateEquivalentMinutes,
              rawMetMinutes: _budgetProgress!.rawMetMinutes,
              strengthDays: _budgetProgress!.strengthDays,
            )
          : const MvBudgetSnapshot(
              moderateEquivalentMinutes: 0,
              rawMetMinutes: 0,
              strengthDays: 0,
            ),
      load: _loadSnapshot,
      readiness: _readinessDecision?.value ?? MvReadinessTier.full,
      activeCampaign: _activeCampaign,
    );
    notifyListeners();
  }
}
