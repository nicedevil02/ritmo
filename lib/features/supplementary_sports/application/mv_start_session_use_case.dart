import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Result bundle returned when starting a workout session.
class MvStartSessionResult {
  final MvSession session;
  final List<MvExercise> exercises;
  final String heroAnimationAsset;

  const MvStartSessionResult({
    required this.session,
    required this.exercises,
    required this.heroAnimationAsset,
  });
}

/// Use Case: Starts or resumes a workout session (Golden Path Phase A).
class MvStartSessionUseCase {
  final MvSessionRepository _sessionRepo;
  final MvExerciseRepository _exerciseRepo;
  final SelectionEngine _selectionEngine;

  MvStartSessionUseCase({
    MvSessionRepository? sessionRepo,
    MvExerciseRepository? exerciseRepo,
    SelectionEngine? selectionEngine,
  })  : _sessionRepo = sessionRepo ?? MvSessionRepository(),
        _exerciseRepo = exerciseRepo ?? MvExerciseRepository(),
        _selectionEngine = selectionEngine ?? const SelectionEngine();

  /// Starts a new session for the given [slot] and [profile].
  Future<MvStartSessionResult> execute({
    required MvSlot slot,
    required MvUserProfile profile,
    List<MvExercise>? preloadedPool,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Check if there is already an active session for today/slot
    final existingActive = await _sessionRepo.getActiveSession();
    if (existingActive != null) {
      final pool = preloadedPool ?? await _exerciseRepo.getAllExercises();
      final selectedDecision = _selectionEngine.selectExercises(
        pool: pool,
        focusCodes: slot.focusCodes.isNotEmpty ? slot.focusCodes : const ['FULL_BODY'],
        physicalLimitations: profile.physicalLimitations,
        availableEquipment: profile.availableEquipment,
        neighborFriendly: profile.neighborFriendly,
      );

      final exercises = selectedDecision.value;
      final heroAnim = exercises.isNotEmpty && exercises.first.animationAsset != null
          ? exercises.first.animationAsset!
          : (exercises.isNotEmpty ? exercises.first.id : 'bo001_side_leg_lift');

      return MvStartSessionResult(
        session: existingActive,
        exercises: exercises,
        heroAnimationAsset: heroAnim,
      );
    }

    // 2. Load exercise pool if not preloaded
    final pool = preloadedPool ?? await _exerciseRepo.getAllExercises();

    // 3. Select safe, constrained exercises from 268-pool
    final selectedDecision = _selectionEngine.selectExercises(
      pool: pool,
      focusCodes: slot.focusCodes.isNotEmpty ? slot.focusCodes : const ['FULL_BODY'],
      physicalLimitations: profile.physicalLimitations,
      availableEquipment: profile.availableEquipment,
      neighborFriendly: profile.neighborFriendly,
    );

    final selectedExercises = selectedDecision.value;

    // 4. Create new MvSession
    final sessionId = 'sess_${now}_${slot.id}';
    final session = MvSession(
      id: sessionId,
      kindCode: slot.kindCode ?? (slot.focusCodes.isNotEmpty ? slot.focusCodes.first : 'strength'),
      prescriptionId: slot.id,
      sessionMode: MvSessionMode.guided,
      status: MvSessionStatus.active,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // 5. Persist session start and initial event
    await _sessionRepo.startSession(session);
    await _sessionRepo.recordEvent(
      MvSessionEvent(
        id: 'evt_${now}_start',
        sessionId: sessionId,
        type: 'SESSION_START',
        at: now,
        dataJson: '{"exerciseCount": ${selectedExercises.length}}',
      ),
    );

    final heroAnim = selectedExercises.isNotEmpty && selectedExercises.first.animationAsset != null
        ? selectedExercises.first.animationAsset!
        : (selectedExercises.isNotEmpty ? selectedExercises.first.id : 'bo001_side_leg_lift');

    return MvStartSessionResult(
      session: session,
      exercises: selectedExercises,
      heroAnimationAsset: heroAnim,
    );
  }
}
