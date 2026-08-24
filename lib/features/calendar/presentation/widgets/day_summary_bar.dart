import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/relative_time_formatter.dart';

/// K24 — Day summary bar: single line above timeline with 3 numbers derived from snapshot.
/// - remainingCount ("مانده")
/// - completedCount ("انجام‌شده")
/// - free time derived from freeGaps sum ("وقت آزاد")
class DaySummaryBar extends StatelessWidget {
  const DaySummaryBar({
    super.key,
    required this.snapshot,
    required this.onTapFreeGaps,
  });

  final DayAgendaSnapshot snapshot;
  final VoidCallback onTapFreeGaps;

  int get _freeMinutes {
    int total = 0;
    for (final gap in snapshot.freeGaps) {
      total += gap.durationMinutes;
    }
    return total;
  }

  String _formatFreeTime(int totalMinutes) {
    if (totalMinutes <= 0) return '۰ دقیقه';
    return RelativeTimeFormatter.durationFa(totalMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: 3.0,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        border: Border(
          bottom: BorderSide(
            color: colors.borderSubtle,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Remaining count
          _SummaryChip(
            label: 'مانده: ${toPersianDigits(snapshot.remainingCount)}',
            color: colors.primary,
          ),

          // Completed count
          _SummaryChip(
            label: 'انجام‌شده: ${toPersianDigits(snapshot.completedCount)}',
            color: colors.success,
          ),

          // Free time (tappable)
          InkWell(
            onTap: onTapFreeGaps,
            borderRadius: BorderRadius.circular(RitmoRadius.badge),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'آزاد: ${_formatFreeTime(_freeMinutes)}',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(RitmoRadius.badge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
