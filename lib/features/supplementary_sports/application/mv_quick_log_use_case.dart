import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Two-tap quick logging of completed activity (N-01, N-12).
class MvQuickLogUseCase {
  final MvSessionRepository _sessionRepo;
  final MvPrescriptionRepository _prescriptionRepo;

  MvQuickLogUseCase({
    MvSessionRepository? sessionRepo,
    MvPrescriptionRepository? prescriptionRepo,
  }) : _sessionRepo = sessionRepo ?? MvSessionRepository(),
       _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository();

  /// Retrieves the most recent completed activity for quick re-log preset.
  Future<MvSession?> getLastCompletedActivity() =>
      _sessionRepo.getLastCompletedSession();

  /// Logs a quick activity in 2 taps.
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
