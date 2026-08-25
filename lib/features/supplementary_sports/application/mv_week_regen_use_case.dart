import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Generates or regenerates a 7-day training week plan preserving locked slots.
class MvWeekRegenUseCase {
  final MvPrescriptionRepository _prescriptionRepo;
  final MvCommitmentRepository _commitmentRepo;
  final MvKindRepository _kindRepo;
  final MvKindProfileRepository _kindProfileRepo;
  final PlanEngine _planEngine;

  MvWeekRegenUseCase({
    MvPrescriptionRepository? prescriptionRepo,
    MvCommitmentRepository? commitmentRepo,
    MvKindRepository? kindRepo,
    MvKindProfileRepository? kindProfileRepo,
    PlanEngine? planEngine,
  }) : _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
       _commitmentRepo = commitmentRepo ?? MvCommitmentRepositoryImpl(),
       _kindRepo = kindRepo ?? MvKindRepository(),
       _kindProfileRepo =
           kindProfileRepo ?? MvKindProfileRepositoryImpl(),
       _planEngine = planEngine ?? const PlanEngine();

  /// Executes week plan generation.
  Future<List<MvSlot>> execute({
    required MvUserProfile profile,
    required DateTime weekSaturday,
    List<MvSlot> existingSlots = const [],
    List<MvCommitment>? commitments,
  }) async {
    final activeCommitments = commitments ?? await _commitmentRepo.getActive();
    final allKinds = await _kindRepo.getAll();
    final kindsMap = {for (final k in allKinds) k.code: k};
    final kindProfiles = await _kindProfileRepo.getMapByCodes(
      kindsMap.keys.toList(),
    );

    final result = _planEngine.generateWeek(
      weekStartSat: weekSaturday,
      profile: profile,
      commitments: activeCommitments,
      overrides: const [],
      kinds: kindsMap,
      kindProfiles: kindProfiles,
      budget: const MvBudgetSnapshot(
        moderateEquivalentMinutes: 0,
        rawMetMinutes: 0,
        strengthDays: 0,
      ),
      load: null,
      readiness: MvReadinessTier.full,
    );

    final newSlots = result.slots;
    await _prescriptionRepo.savePrescriptions(newSlots);

    return newSlots;
  }
}
