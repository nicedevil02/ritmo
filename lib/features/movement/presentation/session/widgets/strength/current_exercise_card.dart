import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_exercise.dart';

/// کارت نمایش حرکت جاری تمرین قدرتی
class CurrentExerciseCard extends StatelessWidget {
  const CurrentExerciseCard({
    super.key,
    required this.exercise,
    this.onSwapPressed,
  });

  final MovementExercise exercise;
  final VoidCallback? onSwapPressed;

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
                    if (exercise.muscleGroup != null && exercise.muscleGroup!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        exercise.muscleGroup!,
                        style: RitmoTextStyles.caption(
                          sportsColor,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              if (onSwapPressed != null)
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
        ],
      ),
    );
  }
}
