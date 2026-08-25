import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Two-tap quick logging of completed activity (N-01, N-12).
class MvQuickLogUseCase {
  final MvSessionRepository _sessionRepo;
  final MvPrescriptionRepository _prescriptionRepo;
  final MvKindRepository _kindRepo;

  MvQuickLogUseCase({
    MvSessionRepository? sessionRepo,
    MvPrescriptionRepository? prescriptionRepo,
    MvKindRepository? kindRepo,
  }) : _sessionRepo = sessionRepo ?? MvSessionRepository(),
       _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
       _kindRepo = kindRepo ?? MvKindRepository();

  /// Retrieves the most recent completed activity for quick re-log preset.
  Future<MvSession?> getLastCompletedActivity() =>
      _sessionRepo.getLastCompletedSession();

  /// Returns 4 quick kind candidates from recent usage or standard fallbacks.
  Future<List<MvMovementKind>> getQuickKinds() async {
    final recent = await _kindRepo.getRecent(limit: 4);
    if (recent.length >= 4) return recent;

    const fallbackCodes = ['WALKING', 'RUNNING', 'CYCLING', 'SWIMMING'];
    final fallbackMap = await _kindRepo.getMapByCodes(fallbackCodes);
    final result = <MvMovementKind>[...recent];
    final seenCodes = recent.map((k) => k.code).toSet();

    for (final code in fallbackCodes) {
      if (result.length >= 4) break;
      if (!seenCodes.contains(code) && fallbackMap.containsKey(code)) {
        result.add(fallbackMap[code]!);
        seenCodes.add(code);
      }
    }
    return result;
  }

  /// Logs a quick activity in 2 taps and updates kind usage statistics.
  Future<MvSession> execute({
    required String kindCode,
    required int durationMinutes,
    MvSessionFeeling? feeling,
    String? note,
    String? dateIso,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final targetDateIso = dateIso ?? MvCalendar.formatDateIso(DateTime.now());

    final session = MvSession(
      id: 'quick_${now}_$kindCode',
      kindCode: kindCode,
      sessionMode: MvSessionMode.quickLog,
      status: MvSessionStatus.completed,
      startedAt: now - (durationMinutes * 60000),
      endedAt: now,
      overallFeeling: feeling?.index ?? 1,
      note: note,
      createdAt: now,
      updatedAt: now,
    );

    // Save session
    await _sessionRepo.finishSession(session);

    // Bump kind usage in movement_kinds
    await _kindRepo.bumpUsage(kindCode);

    // Update corresponding date slot if exists
    final slot = await _prescriptionRepo.getPrescriptionForDate(targetDateIso);
    if (slot != null) {
      final updatedSlot = slot.copyWith(
        status: MvSlotStatus.done,
        workoutLogId: session.id,
        updatedAt: now,
      );
      await _prescriptionRepo.savePrescription(updatedSlot);
    }

    return session;
  }
}
