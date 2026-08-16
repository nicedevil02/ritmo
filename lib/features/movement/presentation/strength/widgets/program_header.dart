import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// سربرگ مشخصات و وضعیت برنامهٔ قدرتی فعال
class ProgramHeader extends StatelessWidget {
  const ProgramHeader({
    super.key,
    required this.program,
    this.onManagePressed,
  });

  final MovementStrengthProgram program;
  final VoidCallback? onManagePressed;

  String _getStatusText(BuildContext context) {
    if (program.isPaused) return MovementStrings.strengthHubPaused;
    if (program.isDeload) return MovementStrings.strengthHubDeloadWeek;
    if (program.isFinished) return MovementStrings.strengthHubCompleted;
    return 'برنامهٔ فعال';
  }

  Color _getStatusColor(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    if (program.isPaused) return colors.warning;
    if (program.isDeload) return colors.accent;
    if (program.isFinished) return colors.textSecondary;
    return sportsColor;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = _getStatusColor(context);
    final statusText = _getStatusText(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusText,
                  style: RitmoTextStyles.caption(statusColor).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onManagePressed != null)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  tooltip: 'مدیریت برنامه',
                  onPressed: onManagePressed,
                  color: colors.textSecondary,
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Text(
            program.name ?? 'برنامهٔ قدرت در خانه',
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'هفتهٔ ${toPersianDigits(program.currentWeek)} از ${toPersianDigits(program.totalWeeks)}',
                style: RitmoTextStyles.body(colors.textSecondary),
              ),
              const SizedBox(width: RitmoSpacing.md),
              Icon(Icons.fitness_center_rounded, size: 16, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${toPersianDigits(program.daysPerWeek)} جلسه در هفته',
                style: RitmoTextStyles.body(colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            child: LinearProgressIndicator(
              value: program.progressFraction,
              minHeight: 6,
              backgroundColor: colors.surfaceSunken,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
