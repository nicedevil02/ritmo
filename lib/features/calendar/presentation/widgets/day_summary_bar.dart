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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141822) : const Color(0xFFEFF2F6),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFDDE3EA),
            width: 0.8,
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
            isDark: isDark,
          ),

          // Completed count
          _SummaryChip(
            label: 'انجام‌شده: ${toPersianDigits(snapshot.completedCount)}',
            color: colors.success,
            isDark: isDark,
          ),

          // Free time (tappable)
          InkWell(
            onTap: onTapFreeGaps,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2430)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFD5DCE4),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : const Color(0xFFCCD4DF).withValues(alpha: 0.5),
                    offset: const Offset(0, 1.5),
                    blurRadius: 2.5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'آزاد: ${_formatFreeTime(_freeMinutes)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
  const _SummaryChip({
    required this.label,
    required this.color,
    required this.isDark,
  });

  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.28 : 0.25),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.12 : 0.15),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
