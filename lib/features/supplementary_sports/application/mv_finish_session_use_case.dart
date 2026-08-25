import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Finishes a workout session, persists sets, updates prescription and records PRs.
class MvFinishSessionUseCase {
  final MvSessionRepository _sessionRepo;
  final MvPrescriptionRepository _prescriptionRepo;
  final MvPrRepository _prRepo;
  final ProgressionEngine _progressionEngine;

  MvFinishSessionUseCase({
    MvSessionRepository? sessionRepo,
    MvPrescriptionRepository? prescriptionRepo,
    MvPrRepository? prRepo,
    ProgressionEngine? progressionEngine,
  })  : _sessionRepo = sessionRepo ?? MvSessionRepository(),
        _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
        _prRepo = prRepo ?? MvPrRepository(),
        _progressionEngine = progressionEngine ?? const ProgressionEngine();

  /// Executes session completion and PR calculations.
  Future<List<MvPersonalRecord>> execute({
    required MvSession session,
    required List<MvSetLog> setLogs,
    required MvSessionFeeling feeling,
    String? note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Finish session and save sets atomically
    await _sessionRepo.finishSession(
      session,
      setLogs: setLogs,
      feeling: feeling,
      note: note,
    );

    // 2. Record completion event
    await _sessionRepo.recordEvent(
      MvSessionEvent(
        id: 'evt_${now}_finish',
        sessionId: session.id,
        type: 'SESSION_FINISH',
        at: now,
        dataJson: '{"setCount": ${setLogs.length}, "feeling": "${feeling.code}"}',
      ),
    );

    // 3. Check for PR breakthroughs across completed sets
    final newPrs = <MvPersonalRecord>[];
    final allExistingPrs = List<MvPersonalRecord>.from(await _prRepo.getAllPrs());

    for (final log in setLogs) {
      if (log.reps != null && log.reps! > 0) {
        final prIndex = allExistingPrs.indexWhere(
          (p) => p.exerciseId == log.exerciseId && p.prType == MvPrType.maxReps,
        );
        final existingRepsPr = prIndex != -1 ? allExistingPrs[prIndex] : null;

        final pr = _progressionEngine.evaluateNewRecord(
          setLog: log,
          currentBest: existingRepsPr,
        );

        if (pr != null) {
          await _prRepo.recordPr(pr);
          if (prIndex != -1) {
            allExistingPrs[prIndex] = pr;
          } else {
            allExistingPrs.add(pr);
          }
          // Replace or add in newPrs for this exercise
          final existingInSessionIdx = newPrs.indexWhere((p) => p.exerciseId == log.exerciseId && p.prType == pr.prType);
          if (existingInSessionIdx != -1) {
            newPrs[existingInSessionIdx] = pr;
          } else {
            newPrs.add(pr);
          }
        }
      }
    }

    // 4. Update prescription slot if linked
    if (session.prescriptionId != null) {
      await _prescriptionRepo.updateSlotStatus(
        session.prescriptionId!,
        session.status == MvSessionStatus.partial ? MvSlotStatus.partial : MvSlotStatus.done,
        workoutLogId: session.id,
      );
    }

    return newPrs;
  }
}
