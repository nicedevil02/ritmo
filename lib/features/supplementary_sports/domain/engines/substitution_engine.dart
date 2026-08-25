import '../models/models.dart';

/// 7.5 SubstitutionEngine: Finds valid exercise substitutes from similarity graph and safety filters.
class SubstitutionEngine {
  const SubstitutionEngine();

  /// Suggests up to 3 valid alternatives for [currentExercise] based on the user's rejection reason.
  MvDecision<List<MvExercise>> suggestSubstitutes({
    required MvExercise currentExercise,
    required String reason, // 'too_hard', 'pain', 'no_equipment', 'noise'
    required List<MvExercise> similarCandidates,
    List<MvExercise> fullPool = const [],
    bool neighborFriendly = false,
    List<String> limitations = const [],
  }) {
    // 1. Filter candidates according to the rejection reason
    final validSubstitutes = similarCandidates.where((ex) {
      if (ex.id == currentExercise.id) return false;

      // Noise filter
      if (reason == 'noise' || neighborFriendly) {
        if (ex.noisy || ex.impact > 1) return false;
      }

      // Pain / Limitation filter
      if (reason == 'pain') {
        if (ex.impact >= currentExercise.impact && ex.impact > 1) return false;
      }

      // Difficulty filter
      if (reason == 'too_hard') {
        if (ex.skillRequired > currentExercise.skillRequired) return false;
      }

      // Equipment filter
      if (reason == 'no_equipment') {
        if (ex.toolsRequired.isNotEmpty && !ex.toolsRequired.contains('none')) {
          return false;
        }
      }

      return true;
    }).toList();

    // 2. If similar candidates are insufficient, pick from same category in full pool
    if (validSubstitutes.isEmpty && fullPool.isNotEmpty) {
      final categoryFallback = fullPool.where((ex) {
        if (ex.id == currentExercise.id) return false;
        if (ex.category != currentExercise.category) return false;
        if (neighborFriendly && (ex.noisy || ex.impact > 1)) return false;
        return true;
      }).take(3).toList();

      if (categoryFallback.isNotEmpty) {
        return MvDecision<List<MvExercise>>(
          value: categoryFallback,
          reasonFa: 'حرکات جایگزین هم‌گروه با عضلات هدف انتخاب شدند.',
          sources: const ['category_fallback'],
          confidence: 0.8,
          hasEnoughData: true,
        );
      }
    }

    final reasonFa = _buildReasonFa(reason);
    return MvDecision<List<MvExercise>>(
      value: validSubstitutes.take(3).toList(),
      reasonFa: reasonFa,
      sources: const ['similarity_graph'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }

  String _buildReasonFa(String reason) {
    switch (reason) {
      case 'too_hard':
        return 'حرکات ساده‌تر با الگوی حرکتی مشابه پیشنهاد شدند.';
      case 'pain':
        return 'حرکات با فشار کمتر و کم‌ضربه پیشنهاد شدند.';
      case 'noise':
        return 'حرکات کاملاً بی‌صدا و بدون پرش جایگزین شدند.';
      case 'no_equipment':
        return 'حرکات بدون نیاز به وسیله (وزن بدن) پیشنهاد شدند.';
      default:
        return 'حرکات مشابه عضلات هدف پیشنهاد شدند.';
    }
  }
}
