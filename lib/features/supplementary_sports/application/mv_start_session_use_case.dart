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
  final MvKindRepository _kindRepo;
  final SelectionEngine _selectionEngine;

  MvStartSessionUseCase({
    MvSessionRepository? sessionRepo,
    MvExerciseRepository? exerciseRepo,
    MvKindRepository? kindRepo,
    SelectionEngine? selectionEngine,
  }) : _sessionRepo = sessionRepo ?? MvSessionRepository(),
       _exerciseRepo = exerciseRepo ?? MvExerciseRepository(),
       _kindRepo = kindRepo ?? MvKindRepository(),
       _selectionEngine = selectionEngine ?? const SelectionEngine();

  /// Deterministic player mode resolver according to S4-T4:
  /// 1. if (kind.sessionModeOverride != null) -> همان
  /// 2. else switch (kind.primaryMetric):
  ///      DISTANCE  -> kind.isOutdoor ? route : distance
  ///      ELEVATION -> route
  ///      LAPS      -> laps
  ///      DURATION  -> (kind.family == SPORT || kind.family == MARTIAL_SKILL) ? match : timed
  ///      SETS      -> اگر تجویز موجود بود guided وگرنه structured
  ///      STEPS     -> timed
  ///      NONE      -> timed
  static MvSessionMode resolveSessionMode({
    required MvMovementKind kind,
    bool hasPrescription = false,
  }) {
    if (kind.sessionModeOverride != null) {
      return kind.sessionModeOverride!;
    }
    switch (kind.primaryMetric) {
      case MovementMetric.distance:
        return kind.isOutdoor ? MvSessionMode.route : MvSessionMode.distance;
      case MovementMetric.elevation:
        return MvSessionMode.route;
      case MovementMetric.laps:
        return MvSessionMode.laps;
      case MovementMetric.duration:
        return (kind.family == MovementFamily.sport ||
                kind.family == MovementFamily.martialSkill)
            ? MvSessionMode.match
            : MvSessionMode.timed;
      case MovementMetric.sets:
        return hasPrescription ? MvSessionMode.guided : MvSessionMode.structured;
      case MovementMetric.steps:
      case MovementMetric.none:
        return MvSessionMode.timed;
    }
  }

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
        focusCodes: slot.focusCodes.isNotEmpty
            ? slot.focusCodes
            : const ['FULL_BODY'],
        physicalLimitations: profile.physicalLimitations,
        availableEquipment: profile.availableEquipment,
        neighborFriendly: profile.neighborFriendly,
      );

      final exercises = selectedDecision.value;
      final heroAnim =
          exercises.isNotEmpty && exercises.first.animationAsset != null
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
      focusCodes: slot.focusCodes.isNotEmpty
          ? slot.focusCodes
          : const ['FULL_BODY'],
      physicalLimitations: profile.physicalLimitations,
      availableEquipment: profile.availableEquipment,
      neighborFriendly: profile.neighborFriendly,
    );

    final selectedExercises = selectedDecision.value;

    // 4. Resolve session mode from kind and slot
    final kindCode = slot.kindCode ??
        (slot.focusCodes.isNotEmpty ? slot.focusCodes.first : 'BODYWEIGHT');
    final kind = await _kindRepo.getByCode(kindCode);
    final hasPrescription = selectedExercises.isNotEmpty;

    final sessionMode = kind != null
        ? resolveSessionMode(kind: kind, hasPrescription: hasPrescription)
        : (slot.slotType == MvSlotType.strength ? MvSessionMode.guided : MvSessionMode.timed);

    // 5. Create new MvSession
    final sessionId = 'sess_${now}_${slot.id}';
    final session = MvSession(
      id: sessionId,
      kindCode: kindCode,
      prescriptionId: slot.id,
      sessionMode: sessionMode,
      status: MvSessionStatus.active,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // 6. Persist session start and initial event
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

    final heroAnim =
        selectedExercises.isNotEmpty &&
            selectedExercises.first.animationAsset != null
        ? selectedExercises.first.animationAsset!
        : (selectedExercises.isNotEmpty
              ? selectedExercises.first.id
              : 'bo001_side_leg_lift');

    return MvStartSessionResult(
      session: session,
      exercises: selectedExercises,
      heroAnimationAsset: heroAnim,
    );
  }
}
