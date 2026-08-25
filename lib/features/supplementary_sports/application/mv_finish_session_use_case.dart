import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Finishes a workout session, persists sets, updates prescription and records PRs.
class MvFinishSessionUseCase {
  final MvSessionRepository _sessionRepo;
  final MvPrescriptionRepository _prescriptionRepo;
  final MvPrRepository _prRepo;
  final MvRouteRepository _routeRepo;
  final ProgressionEngine _progressionEngine;

  MvFinishSessionUseCase({
    MvSessionRepository? sessionRepo,
    MvPrescriptionRepository? prescriptionRepo,
    MvPrRepository? prRepo,
    MvRouteRepository? routeRepo,
    ProgressionEngine? progressionEngine,
  }) : _sessionRepo = sessionRepo ?? MvSessionRepository(),
       _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
       _prRepo = prRepo ?? MvPrRepository(),
       _routeRepo = routeRepo ?? MvRouteRepository(),
       _progressionEngine = progressionEngine ?? const ProgressionEngine();

  /// Executes session completion and PR calculations (S4-T5).
  Future<List<MvPersonalRecord>> execute({
    required MvSession session,
    List<MvSetLog> setLogs = const [],
    MvSessionFeeling? feeling,
    int? rpe1To10,
    String? effortSource,
    double? distanceM,
    double? elevationGainM,
    int? laps,
    double? packWeightKg,
    int? routeId,
    String? note,
    double? baseMet,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Resolve effort RPE (estimated if user did not provide)
    int? resolvedRpe = rpe1To10 ?? session.rpe1To10;
    String? resolvedEffortSource = effortSource ?? session.effortSource;

    if (resolvedRpe == null && baseMet != null) {
      if (baseMet < 3.0) {
        resolvedRpe = 3;
      } else if (baseMet <= 6.0) {
        resolvedRpe = 5;
      } else {
        resolvedRpe = 7;
      }
      resolvedEffortSource = 'estimated';
    } else if (resolvedRpe != null && resolvedEffortSource == null) {
      resolvedEffortSource = 'user';
    }

    final updatedSession = session.copyWith(
      distanceM: distanceM ?? session.distanceM,
      elevationGainM: elevationGainM ?? session.elevationGainM,
      laps: laps ?? session.laps,
      packWeightKg: packWeightKg ?? session.packWeightKg,
      rpe1To10: resolvedRpe,
      effortSource: resolvedEffortSource,
      routeId: routeId ?? session.routeId,
      overallFeeling: feeling?.rirValue ?? session.overallFeeling,
      note: note ?? session.note,
    );

    // 2. Finish session and save sets atomically
    await _sessionRepo.finishSession(
      updatedSession,
      setLogs: setLogs,
      feeling: feeling,
      note: note,
    );

    // 3. Record completion event
    await _sessionRepo.recordEvent(
      MvSessionEvent(
        id: 'evt_${now}_finish',
        sessionId: session.id,
        type: 'SESSION_FINISH',
        at: now,
        dataJson:
            '{"setCount": ${setLogs.length}, "feeling": "${feeling?.code}", "rpe": $resolvedRpe, "source": "$resolvedEffortSource"}',
      ),
    );

    // 3. Check for PR breakthroughs across completed sets
    final newPrs = <MvPersonalRecord>[];
    final allExistingPrs = List<MvPersonalRecord>.from(
      await _prRepo.getAllPrs(),
    );

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
          final existingInSessionIdx = newPrs.indexWhere(
            (p) => p.exerciseId == log.exerciseId && p.prType == pr.prType,
          );
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
        session.status == MvSessionStatus.partial
            ? MvSlotStatus.partial
            : MvSlotStatus.done,
        workoutLogId: session.id,
      );
    }

    // 5. Update recurring route statistics if routeId is specified (S4-T7)
    final resolvedRouteId = routeId ?? session.routeId;
    if (resolvedRouteId != null) {
      final duration = updatedSession.elapsedMinutes > 0
          ? updatedSession.elapsedMinutes
          : 1;
      await _routeRepo.recordRouteCompletion(
        routeId: resolvedRouteId,
        durationMin: duration,
        completedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    }

    return newPrs;
  }
}
