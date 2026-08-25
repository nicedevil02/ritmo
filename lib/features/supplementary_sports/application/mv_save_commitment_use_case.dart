import 'package:ritmo/features/supplementary_sports/application/mv_week_regen_use_case.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/repositories.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';

/// نتیجهٔ ذخیرهٔ تعهد/برنامه روز
class MvCommitmentSaveResult {
  final MvCommitment? commitment;
  final MvSlot savedSlot;
  final int regeneratedDaysCount;
  final bool isRecurring;
  final String userMessageFa;

  const MvCommitmentSaveResult({
    this.commitment,
    required this.savedSlot,
    this.regeneratedDaysCount = 0,
    required this.isRecurring,
    required this.userMessageFa,
  });
}

/// Use Case: ذخیرهٔ برنامهٔ روز یا تعهد ثابت هفتگی همراه با بازتولید روزهای هفته در صورت نیاز.
class MvSaveCommitmentUseCase {
  final MvCommitmentRepository _commitmentRepo;
  final MvPrescriptionRepository _prescriptionRepo;
  final MvProfileRepository _profileRepo;
  final MvWeekRegenUseCase _weekRegenUseCase;

  MvSaveCommitmentUseCase({
    MvCommitmentRepository? commitmentRepo,
    MvPrescriptionRepository? prescriptionRepo,
    MvProfileRepository? profileRepo,
    MvWeekRegenUseCase? weekRegenUseCase,
  })  : _commitmentRepo = commitmentRepo ?? MvCommitmentRepositoryImpl(),
        _prescriptionRepo = prescriptionRepo ?? MvPrescriptionRepository(),
        _profileRepo = profileRepo ?? MvProfileRepository(),
        _weekRegenUseCase =
            weekRegenUseCase ??
            MvWeekRegenUseCase(prescriptionRepo: prescriptionRepo);

  Future<MvCommitmentSaveResult> execute({
    required MvSlot slot,
    required bool repeatWeekly,
    String? venueNote,
    String? partnerNote,
  }) async {
    final slotDate = DateTime.parse(slot.dateIso);
    final sat0 = MvCalendar.dateTimeToSat0(slotDate);
    final plannedTime = slot.plannedTime ?? '20:00';

    if (repeatWeekly) {
      final defaultKind = slot.slotType == MvSlotType.strength
          ? MvKindCodes.bodyweight
          : MvKindCodes.walking;

      final commitment = MvCommitment(
        kindCode: slot.kindCode ?? defaultKind,
        titleFa: slot.headlineFa,
        dayOfWeekSat0: sat0,
        startTime: plannedTime,
        durationMinutes: slot.targetMinutes > 0 ? slot.targetMinutes : 60,
        venueNote: venueNote,
        partnerNote: partnerNote,
        recurrence: CommitmentRecurrence.weekly,
        isActive: true,
        isFlexible: false,
        startDateIso: slot.dateIso,
      );

      final savedCommitment = await _commitmentRepo.upsert(commitment);

      // ذخیرهٔ اسلات قفل‌شده برای روز انتخابی
      final lockedSlot = slot.copyWith(
        isLocked: true,
        plannedTime: plannedTime,
      );
      await _prescriptionRepo.savePrescription(lockedSlot);

      // بازتولید هوشمند بقیه روزهای هفته حول لنگر جدید
      final profile = await _profileRepo.getProfile();
      final weekSat = MvCalendar.getWeekSaturday(slotDate);
      final existingSlots = await _prescriptionRepo.getWeekSlots(
        MvCalendar.formatDateIso(weekSat),
      );

      final updatedSlotsInput = existingSlots.map((s) {
        return s.dateIso == lockedSlot.dateIso ? lockedSlot : s;
      }).toList();

      if (!updatedSlotsInput.any((s) => s.dateIso == lockedSlot.dateIso)) {
        updatedSlotsInput.add(lockedSlot);
      }

      final newSlots = await _weekRegenUseCase.execute(
        profile: profile,
        weekSaturday: weekSat,
        existingSlots: updatedSlotsInput,
      );

      final regeneratedCount = newSlots
          .where((s) => !s.isLocked && s.dateIso != lockedSlot.dateIso)
          .length;

      final msg = regeneratedCount > 0
          ? 'تعهد ورزشی با موفقیت ثبت شد و $regeneratedCount روز دیگر هفته متناسب با آن چیده شدند.'
          : 'تعهد ورزشی با موفقیت ثبت شد.';

      return MvCommitmentSaveResult(
        commitment: savedCommitment,
        savedSlot: lockedSlot,
        regeneratedDaysCount: regeneratedCount,
        isRecurring: true,
        userMessageFa: msg,
      );
    } else {
      final lockedSlot = slot.copyWith(
        isLocked: true,
        plannedTime: plannedTime,
      );
      await _prescriptionRepo.savePrescription(lockedSlot);

      return MvCommitmentSaveResult(
        commitment: null,
        savedSlot: lockedSlot,
        regeneratedDaysCount: 0,
        isRecurring: false,
        userMessageFa: 'برنامهٔ روز با موفقیت ذخیره شد.',
      );
    }
  }
}
