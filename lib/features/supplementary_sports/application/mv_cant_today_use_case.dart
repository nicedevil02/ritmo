import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// Use Case: Handles non-judgmental "Can't today" adaptations (AC-03, F-15).
class MvCantTodayUseCase {
  final MvPrescriptionRepository _prescriptionRepo;
  final AdaptationEngine _adaptationEngine;

  MvCantTodayUseCase({
    MvPrescriptionRepository? prescriptionRepo,
    AdaptationEngine? adaptationEngine,
  }) : _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
       _adaptationEngine = adaptationEngine ?? const AdaptationEngine();

  /// Applies 10-minute minimal effective dose.
  Future<MvSlot> applyMinimalDose(MvSlot slot) async {
    final adapted = slot.copyWith(
      targetMinutes: 10,
      headlineFa: 'حداقل مؤثر ۱۰ دقیقه‌ای',
      coachNoteFa: 'جلسهٔ کوتاه و سبک برای حفظ پیوستگی عادت.',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _prescriptionRepo.savePrescription(adapted);
    return adapted;
  }

  /// Moves current slot to tomorrow.
  Future<MvSlot> moveToTomorrow(MvSlot slot) async {
    final currentDt = MvCalendar.parseDateIso(slot.dateIso);
    final tomorrowDt = currentDt.add(const Duration(days: 1));
    final tomorrowIso = MvCalendar.formatDateIso(tomorrowDt);

    final moved = slot.copyWith(
      dateIso: tomorrowIso,
      status: MvSlotStatus.planned,
      movedToDateIso: tomorrowIso,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _prescriptionRepo.savePrescription(moved);
    return moved;
  }

  /// Changes slot to gentle mobility / stretching.
  Future<MvSlot> applyGentleStretch(MvSlot slot) async {
    final adapted = slot.copyWith(
      slotType: MvSlotType.mobility,
      targetMinutes: 10,
      headlineFa: 'کشش و تنفس ملایم',
      coachNoteFa: 'ریکاوری فعال بدون فشار عضلانی.',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _prescriptionRepo.savePrescription(adapted);
    return adapted;
  }

  /// Skips slot completely with non-judgmental adaptation reasoning.
  Future<MvSlot> skipWithoutGuilt(MvSlot slot, List<MvSlot> weekSlots) async {
    final decision = _adaptationEngine.suggestCompensation(
      skippedSlot: slot,
      upcomingSlots: weekSlots.where((s) => s.id != slot.id).toList(),
    );

    final adapted = slot.copyWith(
      status: MvSlotStatus.skipped,
      coachNoteFa: decision.reasonFa,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _prescriptionRepo.savePrescription(adapted);
    return adapted;
  }
}
