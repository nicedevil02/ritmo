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
  });

  final Map<String, CycleDayMark> marks;
  final Map<String, String> settings;
  final Color activePhaseColor;

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

    final isFertilityVisible = settings['cycle_fertility_visible'] != 'false';

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

    if (isFertilityVisible && hasOvulation) {
      legendItems.add(
        _buildLegendItem(
          colors.accent.withValues(alpha: 0.35),
          l10n?.cycleOvulationDay ?? 'روز تخمک‌گذاری',
          colors.textPrimary,
          borderColor: colors.accent,
        ),
      );
    }

    if (isFertilityVisible && hasFertile) {
      legendItems.add(
        _buildLegendItem(
          colors.accent.withValues(alpha: 0.15),
          l10n?.cycleFertileWindow ?? 'پنجره باروری (Fertile)',
          colors.textPrimary,
        ),
      );
    }

    legendItems.add(
      _buildLegendItem(
        Colors.transparent,
        l10n?.cycleToday ?? 'امروز',
        colors.textPrimary,
        borderColor: activePhaseColor,
        borderWidth: 2,
      ),
    );

    if (hasLogs) {
      legendItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: activePhaseColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              l10n?.cycleLoggedSymptoms ?? 'علائم ثبت شده',
              style: RitmoTextStyles.caption(
                colors.textSecondary,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colors.border.withValues(alpha: 0.6), height: 28),
        Text(
          l10n?.cycleCalendarGuide ?? 'راهنمای تقویم چرخه بدنی:',
          style: RitmoTextStyles.titleMedium(
            colors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 16, runSpacing: 12, children: legendItems),
      ],
    );
  }

  Widget _buildLegendItem(
    Color bg,
    String text,
    Color textColor, {
    Color? borderColor,
    double borderWidth = 1.3,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            border: borderColor != null
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: RitmoTextStyles.caption(
            textColor,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
