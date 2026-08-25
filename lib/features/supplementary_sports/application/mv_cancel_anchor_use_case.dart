import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

class MvCancelAnchorResult {
  final List<MvSlot> updatedWeekSlots;
  final int replacedMinutes;
  final String? replacedOnWeekday;
  final String feedbackFa;
  final bool suggestDeactivate;

  const MvCancelAnchorResult({
    required this.updatedWeekSlots,
    required this.replacedMinutes,
    this.replacedOnWeekday,
    required this.feedbackFa,
    this.suggestDeactivate = false,
  });
}

/// Handles "این هفته لغو شد" action on anchor slots (S2-T7).
class MvCancelAnchorUseCase {
  final MvSlotOverrideRepository _overrideRepo;
  final MvPrescriptionRepository _prescriptionRepo;

  MvCancelAnchorUseCase({
    MvSlotOverrideRepository? overrideRepo,
    MvPrescriptionRepository? prescriptionRepo,
  }) : _overrideRepo = overrideRepo ?? MvSlotOverrideRepositoryImpl(),
       _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository();

  Future<MvCancelAnchorResult> cancelAnchorThisWeek({
    required MvSlot anchorSlot,
    required List<MvSlot> currentWeekSlots,
  }) async {
    // 1. Write override record (does NOT deactivate commitment)
    final routineId = anchorSlot.kindCode ?? anchorSlot.id;
    final override = MvSlotOverride(
      id: 'mso_${DateTime.now().millisecondsSinceEpoch}',
      routineId: routineId,
      dateIso: anchorSlot.dateIso,
      action: 'CANCEL_ANCHOR',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _overrideRepo.insert(override);

    // 2. Count cancellations in the last 4 weeks (28 days)
    final anchorDt = MvCalendar.parseDateIso(anchorSlot.dateIso);
    final fourWeeksAgo = anchorDt.subtract(const Duration(days: 28));
    final fourWeeksAgoIso = MvCalendar.formatDateIso(fourWeeksAgo);
    final cancellationCount = await _overrideRepo.countCancellationsInPeriod(
      routineId,
      fourWeeksAgoIso,
      anchorSlot.dateIso,
    );
    final suggestDeactivate = cancellationCount >= 3;

    // 3. Mark the anchor slot as skipped for this week
    final cancelledSlot = anchorSlot.copyWith(
      status: MvSlotStatus.skipped,
      isLocked: false,
      headlineFa: 'لغو شده برای این هفته',
      coachNoteFa: 'لغو تعهد فقط برای این هفته. تعهد اصلی فعال می‌ماند.',
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final updatedSlots = List<MvSlot>.from(currentWeekSlots);
    final slotIdx = updatedSlots.indexWhere(
      (s) => s.dateIso == anchorSlot.dateIso,
    );
    if (slotIdx >= 0) {
      updatedSlots[slotIdx] = cancelledSlot;
    }

    // 4. Re-distribute missing minutes to upcoming days in the same week
    int replacedMinutes = 0;
    String? replacedOnWeekday;

    final missingMinutes = anchorSlot.targetMinutes;
    if (missingMinutes > 0) {
      // Find eligible upcoming slot in the week
      for (int i = 0; i < updatedSlots.length; i++) {
        final slot = updatedSlots[i];
        if (slot.dateIso.compareTo(anchorSlot.dateIso) > 0 &&
            !slot.isCompleted &&
            !slot.isLocked) {
          // If rest day, convert to a light session, or if already training, add duration
          final addDur = (missingMinutes >= 30) ? 30 : missingMinutes;
          final newDur = slot.isRest ? addDur : slot.targetMinutes + addDur;
          final dt = MvCalendar.parseDateIso(slot.dateIso);
          final sat0 = MvCalendar.dateTimeToSat0(dt);
          replacedOnWeekday = MvCalendar.persianWeekdayName(sat0);
          replacedMinutes = addDur;

          updatedSlots[i] = slot.copyWith(
            slotType: slot.isRest ? MvSlotType.strength : slot.slotType,
            targetMinutes: newDur,
            headlineFa: slot.isRest ? 'تمرین جبرانی' : slot.headlineFa,
            coachNoteFa:
                'اضافه شدن $addDur دقیقه برای جبران جلسهٔ لغو شدهٔ ${anchorSlot.headlineFa}.',
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          break;
        }
      }
    }

    // 5. Save all modified slots in prescription repository
    for (final slot in updatedSlots) {
      await _prescriptionRepo.savePrescription(slot);
    }

    // 6. Build feedback message
    final String feedbackFa;
    if (replacedMinutes > 0 && replacedOnWeekday != null) {
      feedbackFa =
          'جلسه لغو شد. ${toPersianDigits(replacedMinutes.toString())} دقیقه تمرین به روز $replacedOnWeekday اضافه شد تا بودجه هفتگی حفظ شود.';
    } else {
      feedbackFa =
          'جلسه فقط برای این هفته لغو شد. تعهد هفتگی شما فعال باقی می‌ماند.';
    }

    return MvCancelAnchorResult(
      updatedWeekSlots: updatedSlots,
      replacedMinutes: replacedMinutes,
      replacedOnWeekday: replacedOnWeekday,
      feedbackFa: feedbackFa,
      suggestDeactivate: suggestDeactivate,
    );
  }
}
