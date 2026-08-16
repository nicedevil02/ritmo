import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// پنل نمایش وضعیت تداخل زمانی با ۴ پیشنهاد قابل اقدام
class ConflictPanel extends StatelessWidget {
  const ConflictPanel({
    super.key,
    required this.conflicts,
    required this.onSuggestionPickOtherTime,
    required this.onSuggestionShorten,
    required this.onSuggestionMoveToFreeDay,
    required this.onSuggestionKeepBoth,
  });

  final List<MovementOccurrence> conflicts;
  final VoidCallback onSuggestionPickOtherTime;
  final VoidCallback onSuggestionShorten;
  final VoidCallback onSuggestionMoveToFreeDay;
  final VoidCallback onSuggestionKeepBoth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // حالت ۱: بدون تداخل (یک خطه و آرام)
    if (conflicts.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: colors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: colors.success, size: 20),
            const SizedBox(width: RitmoSpacing.sm),
            Text(
              MovementStrings.conflictNoneFound,
              style: RitmoTextStyles.body(colors.textPrimary),
            ),
          ],
        ),
      );
    }

    // حالت ۲: دارای تداخل (نمایش موارد و دکمه‌های پیشنهادی)
    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.warning, size: 22),
              const SizedBox(width: RitmoSpacing.sm),
              Text(
                MovementStrings.conflictDetectedTitle,
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // لیست موارد تداخل‌دار
          ...conflicts.map((occ) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• جلسهٔ «${occ.displayName}» در ساعت ${toPersianDigits(occ.startTime ?? 'نامشخص')}',
                style: RitmoTextStyles.caption(colors.textPrimary),
              ),
            );
          }),
          const SizedBox(height: RitmoSpacing.md),

          Text(
            'پیشنهادهای هوشمند برای رفع تداخل:',
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // ۴ دکمهٔ پیشنهاد اقدام
          Wrap(
            spacing: RitmoSpacing.sm,
            runSpacing: RitmoSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: onSuggestionPickOtherTime,
                icon: const Icon(Icons.access_time_rounded, size: 16),
                label: const Text(MovementStrings.conflictSuggestOtherTime),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, MovementLayout.kChipMinHeight),
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSuggestionShorten,
                icon: const Icon(Icons.content_cut_rounded, size: 16),
                label: const Text(MovementStrings.conflictSuggestShorten),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, MovementLayout.kChipMinHeight),
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onSuggestionMoveToFreeDay,
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text(MovementStrings.conflictSuggestMoveToFreeDay),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, MovementLayout.kChipMinHeight),
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
              ),
              TextButton(
                onPressed: onSuggestionKeepBoth,
                child: Text(
                  MovementStrings.conflictSuggestKeepBoth,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
