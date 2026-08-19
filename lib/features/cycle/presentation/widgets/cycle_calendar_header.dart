// C-43, C-44: CycleCalendarHeader
// Header controls for Jalali cycle calendar: month navigation, confidence badge, current month and jump actions.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class CycleCalendarHeader extends StatelessWidget {
  const CycleCalendarHeader({
    super.key,
    required this.monthName,
    required this.year,
    required this.isCurrentMonth,
    required this.canJumpToNext,
    required this.isPredictionOnlyMonth,
    required this.dominantConfidence,
    required this.activePhaseColor,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onGoToCurrentMonth,
    required this.onJumpToNextPeriod,
  });

  final String monthName;
  final int year;
  final bool isCurrentMonth;
  final bool canJumpToNext;
  final bool isPredictionOnlyMonth;
  final PredictionConfidenceLevel? dominantConfidence;
  final Color activePhaseColor;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onGoToCurrentMonth;
  final VoidCallback onJumpToNextPeriod;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous Month Button (pointing right in RTL)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPreviousMonth,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withValues(alpha: 0.4)),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Icon(
                Icons.chevron_right_rounded,
                color: colors.textPrimary,
                size: 24,
              ),
            ),
          ),
        ),

        // Month & Year Center Display + Action Buttons
        Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  monthName,
                  style: RitmoTextStyles.cardTitle(
                    colors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
                const SizedBox(width: 8),
                Text(
                  PersianDigits.toFa(year.toString()),
                  style: RitmoTextStyles.body(
                    colors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                if (isPredictionOnlyMonth && dominantConfidence != null) ...[
                  const SizedBox(width: 8),
                  _buildConfidenceBadge(dominantConfidence!, colors, l10n),
                ],
              ],
            ),
            if (!isCurrentMonth || canJumpToNext) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isCurrentMonth)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onGoToCurrentMonth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: activePhaseColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: activePhaseColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_counterclockwise,
                              size: 11,
                              color: activePhaseColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n?.cycleCurrentMonth ?? 'ماه جاری',
                              style: RitmoTextStyles.badge(
                                activePhaseColor,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!isCurrentMonth && canJumpToNext)
                    const SizedBox(width: 6),
                  if (canJumpToNext)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onJumpToNextPeriod,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.calendar_today,
                              size: 11,
                              color: colors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n?.cycleJumpToNext ?? 'پرش به دوره بعد',
                              style: RitmoTextStyles.badge(
                                colors.error,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),

        // Next Month Button (pointing left in RTL)
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onNextMonth,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withValues(alpha: 0.4)),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Icon(
                Icons.chevron_left_rounded,
                color: colors.textPrimary,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidenceBadge(
    PredictionConfidenceLevel level,
    RitmoColors colors,
    AppLocalizations? l10n,
  ) {
    final String label;
    final Color badgeColor;
    switch (level) {
      case PredictionConfidenceLevel.high:
        label = l10n?.cycleConfidenceHigh ?? 'اطمینان بالا';
        badgeColor = colors.accent;
        break;
      case PredictionConfidenceLevel.medium:
        label = l10n?.cycleConfidenceMedium ?? 'اطمینان متوسط';
        badgeColor = colors.primary;
        break;
      case PredictionConfidenceLevel.low:
        label = l10n?.cycleConfidenceLow ?? 'اطمینان کم';
        badgeColor = colors.textSecondary;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: RitmoTextStyles.badge(
          badgeColor,
        ).copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
