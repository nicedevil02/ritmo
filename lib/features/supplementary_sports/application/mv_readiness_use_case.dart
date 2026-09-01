import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_cross_module_engine.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Aggregates readiness signals and evaluates daily readiness tier.
/// Integrates with RitmoCrossModuleEngine for sleep debt, fasting, and cycle adaptations.
class MvReadinessUseCase {
  final MvDailyCheckinRepository _checkinRepo;
  final ReadinessEngine _readinessEngine;

  MvReadinessUseCase({
    MvDailyCheckinRepository? checkinRepo,
    ReadinessEngine? readinessEngine,
  })  : _checkinRepo = checkinRepo ?? MvDailyCheckinRepository(),
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
    final dt = DateTime.tryParse(dateIso);
    final crossModuleSnapshot =
        await RitmoCrossModuleEngine.instance.getSnapshot(date: dt);

    final effectiveSleepMinutes = sleepHours != null
        ? (sleepHours * 60).round()
        : crossModuleSnapshot.sleepMinutesLastNight;

    final effectiveEnergy = energyLevel1To5 ?? crossModuleSnapshot.energyLevel;
    final effectiveCycleConsent =
        cycleConsentGranted ?? profile.cycleConsentGranted;
    final isMenstrual = crossModuleSnapshot.isMenstrualPhase;

    final decision = _readinessEngine.evaluateReadiness(
      checkin: checkin,
      energyLevel: effectiveEnergy,
      sleepMinutes: effectiveSleepMinutes,
      isMenstrualPhase: isMenstrual,
      cycleConsentGranted: effectiveCycleConsent,
    );

    // If sleep debt or cycle adaptation occurred, record transparent decision log (Constitution Law 2 & 19)
    if (crossModuleSnapshot.isSleepDebtHigh ||
        (isMenstrual && effectiveCycleConsent)) {
      await _logAdaptationDecision(dateIso, decision, crossModuleSnapshot);
    }

    return decision;
  }

  /// Records readiness adaptation decision into ss_decision_log.
  Future<void> _logAdaptationDecision(
    String dateIso,
    MvDecision<MvReadinessTier> decision,
    RitmoCrossModuleSnapshot snapshot,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = RitmoIdFactory.uuid();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final reason = snapshot.isSleepDebtHigh
          ? MvReasonKeys.readinessLow
          : MvReasonKeys.readinessLow;

      await db.insert('ss_decision_log', {
        'id': id,
        'userId': 'default',
        'sessionId': dateIso,
        'exerciseId': null,
        'decisionType': 'ADAPT_READINESS',
        'rejectionReason': reason,
        'createdAt': nowMs,
      });
    } catch (_) {}
  }

  /// Saves a new daily check-in.
  Future<void> saveCheckin(MvDailyCheckin checkin) =>
      _checkinRepo.saveCheckin(checkin);
}
