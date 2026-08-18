import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/analysis/agenda_gap_calculator.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/logic/direct_manipulation_eligibility.dart';

class JourneyFreeGapsSection extends StatelessWidget {
  const JourneyFreeGapsSection({
    super.key,
    required this.snapshot,
    this.onSelectFreeGap,
    this.onDropItemOnGap,
  });

  final DayAgendaSnapshot snapshot;
  final ValueChanged<TimeGap>? onSelectFreeGap;
  final void Function(AgendaItem item, TimeGap gap)? onDropItemOnGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final gaps = snapshot.freeGaps;

    if (gaps.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.xxl),
        alignment: Alignment.center,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.disabledColor.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 26,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: RitmoSpacing.md),
            const Text(
              'روز پرباری داری! 💪',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.0,
              ),
            ),
            const SizedBox(height: RitmoSpacing.xs),
            Text(
              'زمان آزاد قابل توجهی در این روز باقی نمانده است.',
              style: TextStyle(
                fontSize: 12.0,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.60),
              ),
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: RitmoSpacing.sm),
              Text(
                'بلاک‌های زمان آزاد (${toPersianDigits(gaps.length.toString())})',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),
          for (final gap in gaps)
            DragTarget<AgendaItem>(
              onWillAcceptWithDetails: (details) {
                return DirectManipulationEligibility.isSchedulable(details.data);
              },
              onAcceptWithDetails: (details) {
                RitmoHapticsPolicy.success();
                onDropItemOnGap?.call(details.data, gap);
              },
              builder: (context, candidateData, rejectedData) {
                final isHovered = candidateData.isNotEmpty;
                return InkWell(
                  onTap: () => onSelectFreeGap?.call(gap),
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                  child: AnimatedContainer(
                    duration: RitmoMotion.state,
                    margin: const EdgeInsets.only(bottom: RitmoSpacing.sm),
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                          : theme.colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.06),
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(
                        color: isHovered
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withValues(alpha: 0.20),
                        width: isHovered ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isHovered ? Icons.add_circle_outline_rounded : Icons.access_time_filled_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: RitmoSpacing.sm),
                            Text(
                              isHovered
                                  ? 'رها کن برای شروع از ${toPersianDigits(gap.startTimeStr)}'
                                  : toPersianDigits('از ${gap.startTimeStr} تا ${gap.endTimeStr}'),
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: isHovered ? theme.colorScheme.primary : null,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isHovered ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                              ),
                              child: Text(
                                toPersianDigits('${gap.durationMinutes} دقیقه'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isHovered ? theme.colorScheme.onPrimary : theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: RitmoSpacing.xs),
                            Icon(
                              Icons.chevron_left_rounded,
                              size: 18,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
