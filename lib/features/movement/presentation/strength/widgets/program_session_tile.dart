import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';

/// تایل نمایش هر جلسهٔ تمرینی در برنامهٔ قدرتی
class ProgramSessionTile extends StatelessWidget {
  const ProgramSessionTile({
    super.key,
    required this.day,
    required this.onTap,
    this.onStart,
    this.isCompleted = false,
  });

  final MovementStrengthDay day;
  final VoidCallback onTap;
  final VoidCallback? onStart;
  final bool isCompleted;

  String _getWeekdayName(int weekday) {
    const names = ['شنبه', '۱شنبه', '۲شنبه', '۳شنبه', '۴شنبه', '۵شنبه', 'جمعه'];
    if (weekday >= 1 && weekday <= 7) return names[weekday - 1];
    return 'روز $weekday';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: Container(
          padding: const EdgeInsets.all(RitmoSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(RitmoRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? colors.success.withValues(alpha: 0.15)
                      : sportsColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
                  color: isCompleted ? colors.success : sportsColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: RitmoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getWeekdayName(day.weekday),
                          style: RitmoTextStyles.caption(sportsColor).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          day.name,
                          style: RitmoTextStyles.cardTitle(colors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.targetMuscles.join(' • ')} (${toPersianDigits(day.exercises.length)} حرکت)',
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (onStart != null && !isCompleted)
                ElevatedButton(
                  onPressed: onStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(64, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    ),
                  ),
                  child: const Text('شروع'),
                )
              else
                Icon(Icons.chevron_left_rounded, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
