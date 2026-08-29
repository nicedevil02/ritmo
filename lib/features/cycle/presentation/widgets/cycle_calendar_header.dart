// C-43, C-44: CycleCalendarHeader
// Header controls for Jalali cycle calendar: month navigation, confidence badge, current month and jump actions.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous Month Button (pointing right in RTL)
        Semantics(
          label: 'ماه قبل',
          button: true,
          child: RitmoNeuSurface(
            radius: 14,
            width: 38,
            height: 38,
            padding: EdgeInsets.zero,
            onTap: () {
              RitmoHapticsPolicy.selection();
              onPreviousMonth();
            },
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: colors.textPrimary,
                  size: 16,
                ),
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
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  PersianDigits.toFa(year.toString()),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
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
                    RitmoNeuSurface(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      tint: activePhaseColor.withValues(alpha: isDark ? 0.15 : 0.08),
                      onTap: () {
                        RitmoHapticsPolicy.tap();
                        onGoToCurrentMonth();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.calendar_today,
                            size: 11,
                            color: activePhaseColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n?.cycleCurrentMonth ?? 'امروز',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: activePhaseColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isCurrentMonth && canJumpToNext)
                    const SizedBox(width: 6),
                  if (canJumpToNext)
                    RitmoNeuSurface(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      tint: colors.error.withValues(alpha: isDark ? 0.15 : 0.08),
                      onTap: () {
                        RitmoHapticsPolicy.tap();
                        onJumpToNextPeriod();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_right_circle,
                            size: 11,
                            color: colors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n?.cycleJumpToNext ?? 'پرش به دوره بعد',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),

        // Next Month Button (pointing left in RTL)
        Semantics(
          label: 'ماه بعد',
          button: true,
          child: RitmoNeuSurface(
            radius: 14,
            width: 38,
            height: 38,
            padding: EdgeInsets.zero,
            onTap: () {
              RitmoHapticsPolicy.selection();
              onNextMonth();
            },
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(
                  CupertinoIcons.chevron_left,
                  color: colors.textPrimary,
                  size: 16,
                ),
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
