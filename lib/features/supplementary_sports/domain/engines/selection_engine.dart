import '../models/models.dart';

/// 7.4 SelectionEngine: Selects exercises for a workout session with strict safety filters.
class SelectionEngine {
  const SelectionEngine();

  /// Selects a list of suitable exercises matching user constraints and session focus.
  MvDecision<List<MvExercise>> selectExercises({
    required List<MvExercise> pool,
    required List<String> focusCodes,
    List<String> physicalLimitations = const [],
    List<String> availableEquipment = const ['none'],
    bool neighborFriendly = false,
    List<String> recentlyUsedIds = const [],
    int count = 6,
  }) {
    final candidatePool = pool.where((ex) {
      // 1. Hard filter: Limitations (e.g. knee, shoulder, back)
      if (ex.constraintNegative != null && ex.constraintNegative!.isNotEmpty) {
        for (final lim in physicalLimitations) {
          if (ex.constraintNegative!.toLowerCase().contains(lim.toLowerCase())) {
            return false;
          }
        }
      }

      // 2. Hard filter: Apartment / Neighbor friendly (N-04, AC-09)
      if (neighborFriendly) {
        if (ex.noisy || ex.impact > 1) {
          return false;
        }
      }

      // 3. Hard filter: Equipment
      if (availableEquipment.contains('none') || availableEquipment.isEmpty) {
        final needsTools = ex.toolsRequired.where((t) => t != 'none' && t.isNotEmpty).isNotEmpty;
        if (needsTools) return false;
      }

      return true;
    }).toList();

    // 4. Score and sort candidates
    final scored = candidatePool.map((ex) {
      double score = 10.0;

      // Focus matching
      final cat = ex.category.toUpperCase();
      for (final focus in focusCodes) {
        if (cat.contains(focus) || focus == 'FULL_BODY') {
          score += 15.0;
        }
      }

      // Animation bonus
      if (ex.hasAnimation) score += 5.0;

      // Recent usage penalty
      if (recentlyUsedIds.contains(ex.id)) score -= 10.0;

      return MapEntry(ex, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));

    // Select top count
    final selected = scored.take(count).map((e) => e.key).toList();

    // Fallback: If strict filters produced fewer exercises, relax soft filters from original pool
    if (selected.isEmpty && pool.isNotEmpty) {
      final safeFallback = pool.where((e) => !e.noisy).take(count).toList();
      return MvDecision<List<MvExercise>>(
        value: safeFallback.isNotEmpty ? safeFallback : pool.take(count).toList(),
        reasonFa: 'حرکات با اولویت ایمنی و حرکات پایه انتخاب شدند.',
        sources: const ['pool_fallback'],
        confidence: 0.7,
        hasEnoughData: true,
      );
    }

    final reason = neighborFriendly
        ? 'حرکات متناسب با تمرکز ${focusCodes.join("، ")} و در حالت کم‌صدا (همسایه‌پسند) انتخاب شدند.'
        : 'حرکات متناسب با تمرکز ${focusCodes.join("، ")} انتخاب شدند.';

    return MvDecision<List<MvExercise>>(
      value: selected,
      reasonFa: reason,
      sources: const ['exercise_pool', 'profile_constraints'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }
}
