import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_summary.dart';
import 'package:ritmo/features/movement/presentation/common/metric_stat.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

// ثابت میکرو-چیدمان جداکننده (اندازهٔ بصری، نه فاصله‌بندی)
const double _kDividerHeight = 36.0;

/// کارت خلاصهٔ ۳ متریکی هفته با قابلیت لمس و بازکردن پیشرفت
class WeekSummaryCard extends StatelessWidget {
  const WeekSummaryCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  final MovementWeekSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final completedPlannedStr =
        '${toPersianDigits(summary.completedCount)} از ${toPersianDigits(summary.plannedCount)}';
    final activeMinutesStr = toPersianDigits(summary.activeMinutes);
    final recoveryDaysStr = toPersianDigits(summary.recoveryDaysCount);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: colors.border,
          width: RitmoElevation.borderWidthDark,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            RitmoHapticsPolicy.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // سربرگ کارت
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: colors.primary,
                      size: 20.0,
                    ),
                    const SizedBox(width: RitmoSpacing.sm),
                    Text(
                      MovementStrings.weekSummaryTitle,
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                    const Spacer(),
                    // در RTL فلش «برو جلو» به چپ است
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18.0,
                      color: colors.textSecondary,
                    ),
                  ],
                ),

                const SizedBox(height: RitmoSpacing.md),

                // ردیف ۳ تایی MetricStat
                Row(
                  children: [
                    Expanded(
                      child: MetricStat(
                        label: MovementStrings.summaryCompletedPlanned,
                        value: completedPlannedStr,
                      ),
                    ),
                    Container(
                      width: RitmoElevation.borderWidthDark,
                      height: _kDividerHeight,
                      color: colors.border,
                    ),
                    Expanded(
                      child: MetricStat(
                        label: MovementStrings.summaryActiveMinutes,
                        value: activeMinutesStr,
                        unit: MovementStrings.unitMinute,
                      ),
                    ),
                    Container(
                      width: RitmoElevation.borderWidthDark,
                      height: _kDividerHeight,
                      color: colors.border,
                    ),
                    Expanded(
                      child: MetricStat(
                        label: MovementStrings.summaryRecoveryDays,
                        value: recoveryDaysStr,
                        unit: MovementStrings.unitDay,
                      ),
                    ),
                  ],
                ),

                if (!summary.hasAnyCompleted) ...[
                  const SizedBox(height: RitmoSpacing.sm),
                  Text(
                    MovementStrings.weekNoSessionYet,
                    style: RitmoTextStyles.caption(colors.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
