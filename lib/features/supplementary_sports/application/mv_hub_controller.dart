import 'package:flutter/foundation.dart';
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

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  late MvUserProfile _profile;
  MvUserProfile get profile => _profile;

  List<MvSlot> _weekSlots = [];
  List<MvSlot> get weekSlots => _weekSlots;

  List<MvExercise> _allExercises = [];
  List<MvExercise> get allExercises => _allExercises;

  List<MvPersonalRecord> _prs = [];
  List<MvPersonalRecord> get prs => _prs;

  MvSession? _activeSession;
  MvSession? get activeSession => _activeSession;

  MvDecision<MvReadinessTier>? _readinessDecision;
  MvDecision<MvReadinessTier>? get readinessDecision => _readinessDecision;

  MvWeeklyBudgetProgress? _budgetProgress;
  MvWeeklyBudgetProgress? get budgetProgress => _budgetProgress;

  MvBodyMapDistribution? _bodyMapDistribution;
  MvBodyMapDistribution? get bodyMapDistribution => _bodyMapDistribution;

  String _selectedDateIso = MvCalendar.formatDateIso(DateTime.now());
  String get selectedDateIso => _selectedDateIso;

  int _continuousActiveWeeks = 0;
  int get continuousActiveWeeks => _continuousActiveWeeks;

  MvHubController({
    MvProfileRepository? profileRepo,
    MvPrescriptionRepository? prescriptionRepo,
    MvSessionRepository? sessionRepo,
    MvExerciseRepository? exerciseRepo,
    MvPrRepository? prRepo,
    MvDailyCheckinRepository? checkinRepo,
    SelectionEngine? selectionEngine,
    ProgressionEngine? progressionEngine,
    AdaptationEngine? adaptationEngine,
    ReadinessEngine? readinessEngine,
    PlanEngine? planEngine,
    BudgetEngine? budgetEngine,
    InsightEngine? insightEngine,
  })  : _profileRepo = profileRepo ?? MvProfileRepository(),
        _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
        _sessionRepo = sessionRepo ?? MvSessionRepository(),
        _exerciseRepo = exerciseRepo ?? MvExerciseRepository(),
        _prRepo = prRepo ?? MvPrRepository(),
        startSessionUseCase = MvStartSessionUseCase(
          sessionRepo: sessionRepo,
          exerciseRepo: exerciseRepo,
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
          planEngine: planEngine,
        ),
        _budgetEngine = budgetEngine ?? const BudgetEngine(),
        _insightEngine = insightEngine ?? const InsightEngine();

  /// Loads all required data for the hub.
  Future<void> loadAllData() async {
    _isLoading = true;
    notifyListeners();

    _profile = await _profileRepo.getProfile();
    if (!_profile.onboardingCompleted) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    final today = DateTime.now();
    final todayIso = MvCalendar.formatDateIso(today);
    final weekStartSat = MvCalendar.getWeekDays(today).first;
    final weekStartIso = MvCalendar.formatDateIso(weekStartSat);

    // Fetch exercises, PRs, active session
    _allExercises = await _exerciseRepo.getAllExercises();
    _prs = await _prRepo.getAllPrs();
    _activeSession = await _sessionRepo.getActiveSession();

    // Fetch or generate week slots
    _weekSlots = await _prescriptionRepo.getWeekSlots(weekStartIso);
    if (_weekSlots.isEmpty) {
      _weekSlots = await weekRegenUseCase.execute(
        profile: _profile,
        weekSaturday: weekStartSat,
      );
    }

    // Evaluate Readiness
    _readinessDecision = await readinessUseCase.execute(
      dateIso: todayIso,
      profile: _profile,
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

    // Calculate continuous active weeks (real streak)
    _continuousActiveWeeks = _calculateContinuousWeeks(weekSessions);

    _isLoading = false;
    notifyListeners();
  }

  int _calculateContinuousWeeks(List<MvSession> sessions) {
    if (sessions.isEmpty) return 0;
    // Count distinct active weeks in last 3 months
    return (sessions.length / 3).ceil().clamp(1, 52);
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
    final idx = _weekSlots.indexWhere((s) => s.id == updated.id || s.dateIso == updated.dateIso);
    if (idx != -1) {
      _weekSlots[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> saveCheckin(MvDailyCheckin checkin) async {
    await readinessUseCase.saveCheckin(checkin);
    _readinessDecision = await readinessUseCase.execute(
      dateIso: checkin.dateIso,
      profile: _profile,
    );
    notifyListeners();
  }

  Future<void> saveQuickLog(String kindCode, int durationMinutes, MvSessionFeeling? feeling, String? note) async {
    await quickLogUseCase.execute(
      kindCode: kindCode,
      durationMinutes: durationMinutes,
      feeling: feeling,
      note: note,
      dateIso: _selectedDateIso,
    );
    await loadAllData();
  }

  Future<void> regenerateWeek() async {
    final weekStartSat = MvCalendar.getWeekDays(DateTime.now()).first;
    _weekSlots = await weekRegenUseCase.execute(
      profile: _profile,
      weekSaturday: weekStartSat,
      existingSlots: _weekSlots,
    );
    notifyListeners();
  }
}
