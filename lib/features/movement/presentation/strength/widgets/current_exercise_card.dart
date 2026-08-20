import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_exercise.dart';

/// کارت نمایش حرکت جاری تمرین قدرتی با نکات فرم و دکمهٔ جایگزینی
class CurrentExerciseCard extends StatelessWidget {
  const CurrentExerciseCard({
    super.key,
    required this.exercise,
    required this.onSwapPressed,
  });

  final MovementStrengthExercise exercise;
  final VoidCallback onSwapPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // تصویر / آیکون فرم حرکت
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: sportsColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: sportsColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: RitmoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.nameFa,
                      style: RitmoTextStyles.sectionHeadline(
                        colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exercise.muscleGroup} • ${toPersianDigits(exercise.sets)} ست × ${toPersianDigits(exercise.repsDisplay)} تکرار',
                      style: RitmoTextStyles.caption(
                        sportsColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // دکمه جایگزینی حرکت
              OutlinedButton.icon(
                onPressed: onSwapPressed,
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('تعویض'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
              ),
            ],
          ),
          if (exercise.formTips.isNotEmpty) ...[
            const SizedBox(height: RitmoSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: RitmoSpacing.sm),
            ...exercise.formTips.take(3).map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: RitmoTextStyles.caption(sportsColor)),
                    Expanded(
                      child: Text(
                        tip,
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
