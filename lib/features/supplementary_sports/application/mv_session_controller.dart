import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Application Controller for Workout Session lifecycle events, pause/resume, and exercise substitutions.
class MvSessionController {
  final MvSessionRepository _sessionRepo;
  final MvExerciseRepository _exerciseRepo;

  MvSessionController({
    MvSessionRepository? sessionRepo,
    MvExerciseRepository? exerciseRepo,
  })  : _sessionRepo = sessionRepo ?? MvSessionRepository(),
        _exerciseRepo = exerciseRepo ?? MvExerciseRepository();

  Future<void> recordEvent({
    required String sessionId,
    required String type,
    String? dataJson,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _sessionRepo.recordEvent(
      MvSessionEvent(
        id: 'evt_${now}_$type',
        sessionId: sessionId,
        type: type,
        at: now,
        dataJson: dataJson,
      ),
    );
  }

  Future<void> savePartialExit({
    required MvSession session,
    required List<MvSetLog> setLogs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final partialSession = session.copyWith(
      status: setLogs.isNotEmpty ? MvSessionStatus.partial : MvSessionStatus.active,
      endedAt: now,
      updatedAt: now,
    );
    await _sessionRepo.finishSession(partialSession, setLogs: setLogs);
  }

  Future<void> finishSession({
    required MvSession session,
    required List<MvSetLog> setLogs,
    required MvSessionFeeling feeling,
    String? note,
  }) async {
    await _sessionRepo.finishSession(
      session,
      setLogs: setLogs,
      feeling: feeling,
      note: note,
    );
  }

  Future<List<MvExercise>> getSimilarCandidates(String exerciseId, {List<MvExercise> fallbackPool = const []}) async {
    final similar = await _exerciseRepo.getSimilarExercises(exerciseId);
    if (similar.isNotEmpty) return similar;

    // Fallback: pick matching category from fallbackPool
    final target = await _exerciseRepo.getExerciseById(exerciseId);
    final cat = target?.category ?? 'CHEST';
    return fallbackPool.where((e) => e.id != exerciseId && e.category == cat).take(5).toList();
  }
}
