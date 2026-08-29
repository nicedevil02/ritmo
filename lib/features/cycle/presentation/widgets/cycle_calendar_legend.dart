// C-43, C-44: CycleCalendarLegend
// F-31, F-35, F-40, F-41: Dynamic, localized cycle calendar legend displaying only items present in current month view.
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class CycleCalendarLegend extends StatelessWidget {
  const CycleCalendarLegend({
    super.key,
    required this.marks,
    required this.settings,
    required this.activePhaseColor,
    this.showTitleAndDivider = true,
  });

  final Map<String, CycleDayMark> marks;
  final Map<String, String> settings;
  final Color activePhaseColor;
  final bool showTitleAndDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final hasRecorded = marks.values.any(
      (m) => m.kind == CycleDayKind.recordedPeriod,
    );
    final hasPredicted = marks.values.any(
      (m) => m.kind == CycleDayKind.predictedPeriod,
    );
    final hasWindow = marks.values.any(
      (m) => m.kind == CycleDayKind.predictionWindow,
    );
    final hasLowConfidence = marks.values.any(
      (m) =>
          m.kind == CycleDayKind.predictedPeriod &&
          m.confidenceLevel == PredictionConfidenceLevel.low,
    );
    final hasOvulation = marks.values.any(
      (m) => m.kind == CycleDayKind.ovulation,
    );
    final hasFertile = marks.values.any(
      (m) => m.kind == CycleDayKind.fertileWindow,
    );
    final hasPms = marks.values.any((m) => m.kind == CycleDayKind.pms);
    final hasLogs = marks.values.any((m) => m.hasLog);

    final legendItems = <Widget>[];

    if (hasRecorded) {
      legendItems.add(
        _buildLegendItem(
          colors.error.withValues(alpha: isDark ? 0.38 : 0.30),
          l10n?.cyclePeriodRecorded ?? 'قاعدگی (ثبت‌شده)',
          colors.textPrimary,
          borderColor: colors.error.withValues(alpha: 0.7),
        ),
      );
    }

    if (hasPredicted) {
      legendItems.add(
        _buildLegendItem(
          colors.error.withValues(alpha: 0.15),
          l10n?.cyclePeriodPredicted ?? 'دوره پیش‌بینی‌شده',
          colors.textPrimary,
          borderColor: colors.error.withValues(alpha: 0.6),
        ),
      );
    }

    if (hasWindow) {
      legendItems.add(
        _buildLegendItem(
          Colors.transparent,
          l10n?.cyclePredictionWindow ?? 'بازه احتمالی جابجایی',
          colors.textPrimary,
          borderColor: colors.error.withValues(alpha: 0.35),
        ),
      );
    }

    if (hasLowConfidence) {
      legendItems.add(
        _buildLegendItem(
          Colors.transparent,
          l10n?.cycleLowConfidence ?? 'پیش‌بینی با اطمینان کم',
          colors.textSecondary,
          borderColor: colors.textSecondary.withValues(alpha: 0.4),
        ),
      );
    }

    if (hasPms) {
      legendItems.add(
        _buildLegendItem(
          colors.primary.withValues(alpha: 0.15),
          l10n?.cyclePmsDays ?? 'روزهای پیش از عادت (PMS)',
          colors.textPrimary,
        ),
      );
    }

    if (hasOvulation) {
      legendItems.add(
        _buildLegendItem(
          colors.accent.withValues(alpha: isDark ? 0.28 : 0.20),
          l10n?.cycleOvulationDay ?? 'روز تخمک‌گذاری',
          colors.textPrimary,
          borderColor: colors.accent,
          borderWidth: 1.5,
          isCircle: true,
        ),
      );
    }

    if (hasFertile) {
      legendItems.add(
        _buildLegendItem(
          colors.accent.withValues(alpha: isDark ? 0.26 : 0.20),
          l10n?.cycleFertileWindow ?? 'پنجره باروری (Fertile)',
          colors.textPrimary,
          borderColor: colors.accent.withValues(alpha: 0.55),
        ),
      );
    }

    legendItems.add(
      _buildLegendItem(
        colors.primary,
        l10n?.cycleToday ?? 'امروز',
        colors.textPrimary,
        isCircle: true,
      ),
    );

    if (hasLogs) {
      legendItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: activePhaseColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              l10n?.cycleLoggedSymptoms ?? 'دارای ثبت علائم',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (!showTitleAndDivider) {
      return Wrap(spacing: 12, runSpacing: 10, children: legendItems);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.border.withValues(alpha: 0.6), height: 20),
        Text(
          l10n?.cycleCalendarGuide ?? 'راهنمای تقویم چرخه بدنی:',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 8, children: legendItems),
      ],
    );
  }

  Widget _buildLegendItem(
    Color bg,
    String text,
    Color textColor, {
    Color? borderColor,
    double borderWidth = 1.2,
    bool isCircle = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bg,
            border: borderColor != null
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
