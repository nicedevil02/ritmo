import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// نشانگر وضعیت رخداد یا جلسه با رعایت کامل دسترس‌پذیری
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final MovementOccurrenceStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final (String label, IconData icon, Color color) = switch (status) {
      MovementOccurrenceStatus.planned => (
          MovementStrings.statusPlanned,
          Icons.schedule_rounded,
          colors.textSecondary,
        ),
      MovementOccurrenceStatus.inProgress => (
          MovementStrings.statusInProgress,
          Icons.play_circle_fill_rounded,
          sportsColor,
        ),
      MovementOccurrenceStatus.completed => (
          MovementStrings.statusCompleted,
          Icons.check_circle_rounded,
          colors.primary,
        ),
      MovementOccurrenceStatus.partial => (
          MovementStrings.statusPartial,
          Icons.timelapse_rounded,
          colors.warning,
        ),
      MovementOccurrenceStatus.skipped => (
          MovementStrings.statusSkipped,
          Icons.cancel_outlined,
          colors.textTertiary,
        ),
      MovementOccurrenceStatus.moved => (
          MovementStrings.statusMoved,
          Icons.swap_horiz_rounded,
          sportsColor,
        ),
      MovementOccurrenceStatus.late => (
          MovementStrings.statusLate,
          Icons.history_toggle_off_rounded,
          colors.warning,
        ),
      MovementOccurrenceStatus.restDay => (
          'استراحت',
          Icons.nightlight_round,
          colors.textSecondary,
        ),
    };

    return Semantics(
      label: 'وضعیت: $label',
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? RitmoSpacing.xs : RitmoSpacing.sm,
          vertical: RitmoSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RitmoRadius.badge),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: RitmoElevation.borderWidthDark,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.0,
              color: color,
            ),
            if (!compact) ...[
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                label,
                style: RitmoTextStyles.badge(color).copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
