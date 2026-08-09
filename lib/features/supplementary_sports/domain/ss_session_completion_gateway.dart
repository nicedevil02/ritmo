import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_prescription_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/session_prescription.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';

class SsSessionCompletionGateway {
  /// Completes a prescription session, updates its status to DONE,
  /// and bridges it to the `workout_logs` table via `MovementRepository.logEvent`
  /// so that all trend charts, MET budget, and heatmaps correctly reflect this session.
  static Future<String?> completeSession({
    required String dateIso,
    required int actualMinutes,
    required int actualRpe, // 3 to 9
    String? location,
    String? customNote,
  }) async {
    final repo = SsPrescriptionRepository.instance;
    final prescription = await repo.getPrescriptionForDate(dateIso);
    if (prescription == null) return null;

    final logId = RitmoIdFactory.uuid();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // 1. Mark prescription as DONE and link it
    final updatedPrescription = prescription.copyWith(
      status: PrescriptionStatus.done,
      workoutLogId: logId,
      targetRpe: actualRpe, // Store the actual RPE they felt
      updatedAt: nowMs,
    );
    await repo.savePrescriptionsBulk([updatedPrescription]);

    // 2. Map RPE to MovementIntensity
    MovementIntensity intensity = MovementIntensity.moderate;
    if (actualRpe <= 5) {
      intensity = MovementIntensity.light;
    } else if (actualRpe >= 8) {
      intensity = MovementIntensity.vigorous;
    }

    // 3. Map SlotType to an appropriate MovementKind code
    // Fallback defaults based on seed data
    String kindCode = 'GYM'; 
    switch (prescription.slotType) {
      case SlotType.strength:
        kindCode = 'GYM';
        break;
      case SlotType.cardio:
        kindCode = 'RUNNING'; 
        break;
      case SlotType.mobility:
        kindCode = 'YOGA';
        break;
      case SlotType.activeRest:
        kindCode = 'WALKING';
        break;
      case SlotType.rest:
        // Do not log a workout for pure rest days
        return logId;
    }

    // 4. Create the centralized MovementEvent
    final event = MovementEvent(
      id: logId,
      kindCode: kindCode,
      durationMinutes: actualMinutes,
      intensity: intensity,
      loggedAt: nowMs,
      sourceModule: 'ss_prescription',
      notes: customNote ?? prescription.headlineFa,
    );

    // 5. Log it to `workout_logs` so it shows up in heatmap and MET budget
    await MovementRepository.instance.logEvent(event);

    return logId;
  }
}
