import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_icons.dart';
import 'package:ritmo/features/movement/presentation/common/status_chip.dart';

/// سربرگ صفحهٔ جزئیات جلسه با آیکون، عنوان، تاریخ جلالی، ساعت و نشان وضعیت
class OccurrenceHeader extends StatelessWidget {
  const OccurrenceHeader({super.key, required this.occurrence});

  final MovementOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          // آیکون خانواده ورزشی
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: sportsColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
            ),
            alignment: Alignment.center,
            child: Icon(
              MovementIcons.fromKey(
                occurrence.activityKind?.icon ?? 'directions_run',
              ),
              color: sportsColor,
              size: 28,
            ),
          ),
          const SizedBox(width: RitmoSpacing.md),

          // نام فعالیت و زمان جلسه
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  occurrence.displayName,
                  style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${toPersianDigits(occurrence.dateIso)} • ساعت ${toPersianDigits(occurrence.startTime ?? 'نامشخص')}',
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ],
            ),
          ),

          // نشان وضعیت
          StatusChip(status: occurrence.status),
        ],
      ),
    );
  }
}
