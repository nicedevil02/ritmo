import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_semantics.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// نمایش عمودی یک متریک با برچسب، مقدار و واحد
class MetricStat extends StatelessWidget {
  const MetricStat({
    super.key,
    required this.label,
    this.value,
    this.unit,
    this.isEstimated = false,
  });

  final String label;
  final String? value;
  final String? unit;
  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasData = value != null && value!.trim().isNotEmpty;

    final String displayValue;
    final String semanticsValue;

    if (hasData) {
      final formattedVal = toPersianDigits(value);
      final unitStr = unit != null && unit!.isNotEmpty ? ' $unit' : '';
      final estStr = isEstimated
          ? ' (${MovementStrings.summaryEstimated})'
          : '';
      displayValue = '$formattedVal$unitStr$estStr';
      semanticsValue = isEstimated
          ? '$formattedVal$unitStr تخمینی'
          : '$formattedVal$unitStr';
    } else {
      displayValue = '—';
      semanticsValue = MovementStrings.commonNotRecorded;
    }

    final semanticsText = MovementSemantics.metricLabel(
      label: label,
      value: semanticsValue,
    );

    return Semantics(
      label: semanticsText,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // برچسب متریک
          Text(
            label,
            style: RitmoTextStyles.caption(
              colors.textSecondary,
            ).copyWith(height: 1.2),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: RitmoSpacing.xs),
          // مقدار متریک
          Text(
            displayValue,
            style: RitmoTextStyles.cardTitle(
              hasData ? colors.textPrimary : colors.textTertiary,
            ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
