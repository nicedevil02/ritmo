import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Generates or regenerates a 7-day training week plan preserving locked slots.
class MvWeekRegenUseCase {
  final MvPrescriptionRepository _prescriptionRepo;
  final PlanEngine _planEngine;

  MvWeekRegenUseCase({
    MvPrescriptionRepository? prescriptionRepo,
    PlanEngine? planEngine,
  })  : _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
        _planEngine = planEngine ?? const PlanEngine();

  /// Executes week plan generation.
  Future<List<MvSlot>> execute({
    required MvUserProfile profile,
    required DateTime weekSaturday,
    List<MvSlot> existingSlots = const [],
  }) async {
    final locked = existingSlots.where((s) => s.isLocked).toList();

    final decision = _planEngine.generateWeekPlan(
      profile: profile,
      weekSaturday: weekSaturday,
      existingSlots: locked,
    );

    final newSlots = decision.value;
    await _prescriptionRepo.savePrescriptions(newSlots);

    return newSlots;
  }
}
