import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Aggregates readiness signals and evaluates daily readiness tier.
class MvReadinessUseCase {
  final MvDailyCheckinRepository _checkinRepo;
  final ReadinessEngine _readinessEngine;

  MvReadinessUseCase({
    MvDailyCheckinRepository? checkinRepo,
    ReadinessEngine? readinessEngine,
  }) : _checkinRepo = checkinRepo ?? MvDailyCheckinRepository(),
       _readinessEngine = readinessEngine ?? const ReadinessEngine();

  /// Evaluates readiness for given [dateIso] and [profile].
  Future<MvDecision<MvReadinessTier>> execute({
    required String dateIso,
    required MvUserProfile profile,
    double? sleepHours,
    int? energyLevel1To5,
    bool? cycleConsentGranted,
  }) async {
    final checkin = await _checkinRepo.getCheckinForDate(dateIso);

    return _readinessEngine.evaluateReadiness(
      checkin: checkin,
      energyLevel: energyLevel1To5,
      sleepMinutes: sleepHours != null ? (sleepHours * 60).round() : null,
      cycleConsentGranted: cycleConsentGranted ?? profile.cycleConsentGranted,
    );
  }

  /// Saves a new daily check-in.
  Future<void> saveCheckin(MvDailyCheckin checkin) =>
      _checkinRepo.saveCheckin(checkin);
}
