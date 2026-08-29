import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/relative_time_formatter.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

/// K24 — Day summary bar: tactile Neumorphic status bar above timeline with 3 key metrics.
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
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Remaining count
          _SummaryChip(
            icon: CupertinoIcons.hourglass,
            label: 'مانده: ${toPersianDigits(snapshot.remainingCount)}',
            color: colors.primary,
            isDark: isDark,
          ),

          // Completed count
          _SummaryChip(
            icon: CupertinoIcons.checkmark_seal_fill,
            label: 'انجام‌شده: ${toPersianDigits(snapshot.completedCount)}',
            color: colors.success,
            isDark: isDark,
          ),

          // Free time (tappable)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                RitmoHaptics.selection();
                onTapFreeGaps();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E2430)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFD5DCE4),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : const Color(0xFFCCD4DF).withValues(alpha: 0.45),
                      offset: const Offset(0, 1.5),
                      blurRadius: 3.5,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.clock_fill,
                      size: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'آزاد: ${toPersianDigits(_formatFreeTime(_freeMinutes))}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Vazirmatn',
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
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
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.14 : 0.10),
            offset: const Offset(0, 1.5),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              fontFamily: 'Vazirmatn',
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
