import '../models/models.dart';

/// 7.1 ProfileEngine: Handles sports profile lifecycle and smart defaults.
class ProfileEngine {
  const ProfileEngine();

  /// Computes default Sat0 training days from number of days per week.
  List<int> computeTrainingDays(int daysPerWeek) {
    switch (daysPerWeek) {
      case 1:
        return [0]; // Sat
      case 2:
        return [0, 3]; // Sat, Tue
      case 3:
        return [0, 2, 4]; // Sat, Mon, Wed
      case 4:
        return [0, 1, 3, 4]; // Sat, Sun, Tue, Wed
      case 5:
        return [0, 1, 2, 3, 4]; // Sat..Wed
      case 6:
        return [0, 1, 2, 3, 4, 5]; // Sat..Thu
      case 7:
        return [0, 1, 2, 3, 4, 5, 6]; // All days
      default:
        return [0, 2, 4];
    }
  }

  /// Evaluates or fills empty profile parameters with smart contextual defaults.
  MvDecision<MvUserProfile> evaluateProfile(MvUserProfile profile) {
    final effectiveDays = profile.daysPerWeek.clamp(1, 7);
    final trainingDays = profile.trainingDays.isEmpty
        ? computeTrainingDays(effectiveDays)
        : profile.trainingDays;

    final updated = profile.copyWith(
      daysPerWeek: effectiveDays,
      trainingDays: trainingDays,
      availableEquipment: profile.availableEquipment.isEmpty
          ? const ['none']
          : profile.availableEquipment,
    );

    return MvDecision<MvUserProfile>(
      value: updated,
      reasonFa: 'پروفایل ورزشی با $effectiveDays روز تمرین در هفته و تجهیزات ${updated.availableEquipment.join("، ")} تنظیم شد.',
      sources: const ['profile'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }

  /// Creates a functional profile from the 20-second 3-question quick onboarding (Section 5.6).
  MvDecision<MvUserProfile> createQuickProfile({
    required int daysPerWeek,
    required String sessionDuration, // 'short' (15m), 'medium' (30m), 'long' (45m+)
    required String trainingLocation, // 'home', 'gym', 'outdoor'
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final trainingDays = computeTrainingDays(daysPerWeek);

    final profile = MvUserProfile(
      goal: 'generalFitness',
      experienceLevel: 'beginner',
      trainingLocation: trainingLocation,
      availableEquipment: trainingLocation == 'gym' ? const ['fullGym'] : const ['none'],
      daysPerWeek: daysPerWeek,
      sessionDuration: sessionDuration,
      onboardingCompleted: true,
      trainingDays: trainingDays,
      programStartDate: MvCalendar.formatDateIso(DateTime.now()),
      createdAt: now,
      updatedAt: now,
    );

    return MvDecision<MvUserProfile>(
      value: profile,
      reasonFa: 'برنامهٔ اولیه بر اساس $daysPerWeek روز در هفته، مدت $sessionDuration و محیط $trainingLocation ساخته شد.',
      sources: const ['quick_onboarding'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }
}
