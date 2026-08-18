import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/wellbeing/data/wellbeing_daily_repository.dart';

/// کارت نمایش روند تاریخی شاخص حال و تعادل
class IndexTrendCard extends StatelessWidget {
  const IndexTrendCard({
    super.key,
    required this.records,
    required this.horizonDays,
  });

  final List<WellbeingDailyRecord> records;
  final int horizonDays;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final validRecords = records.where((r) => r.indexValue != null).toList();

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'روند شاخص حال و تعادل',
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
              if (validRecords.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${RitmoNumber.faInt(validRecords.length)} روز ثبت‌شده',
                    style: RitmoTextStyles.caption(colors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),
          if (validRecords.length < 3) ...[
            Text(
              'برای محاسبه و نمایش روند شاخص، حداقل به ۳ روز ثبت نیاز است (ثبت‌شده: ${RitmoNumber.faInt(validRecords.length)} روز).',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
          ] else ...[
            _buildMetricsRow(context, validRecords),
            const SizedBox(height: RitmoSpacing.lg),
            _buildTrendBars(context, validRecords),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsRow(
    BuildContext context,
    List<WellbeingDailyRecord> validRecords,
  ) {
    final colors = context.colors;
    final latest = validRecords.last.indexValue ?? 50.0;
    final avg =
        validRecords.map((r) => r.indexValue!).reduce((a, b) => a + b) /
        validRecords.length;

    // Calculate weekly delta
    String? deltaText;
    bool? isPositive;
    if (validRecords.length >= 6) {
      final mid = validRecords.length ~/ 2;
      final firstHalf = validRecords.sublist(0, mid);
      final secondHalf = validRecords.sublist(mid);
      final avg1 = firstHalf.map((r) => r.indexValue!).reduce((a, b) => a + b) /
          firstHalf.length;
      final avg2 =
          secondHalf.map((r) => r.indexValue!).reduce((a, b) => a + b) /
          secondHalf.length;
      final delta = avg2 - avg1;
      isPositive = delta >= 0;
      final sign = isPositive ? '+' : '';
      deltaText = '$sign${RitmoNumber.fa(delta.toStringAsFixed(1))}٪';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('آخرین شاخص', style: RitmoTextStyles.caption(colors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              '${RitmoNumber.faInt(latest.round())} از ۱۰۰',
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('میانگین بازه', style: RitmoTextStyles.caption(colors.textSecondary)),
            const SizedBox(height: 2),
            Text(
              '${RitmoNumber.faInt(avg.round())}٪',
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
            ),
          ],
        ),
        if (deltaText != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تغییرات', style: RitmoTextStyles.caption(colors.textSecondary)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPositive ?? true)
                      ? colors.success.withValues(alpha: 0.15)
                      : colors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  deltaText,
                  style: RitmoTextStyles.caption(
                    (isPositive ?? true) ? colors.success : colors.error,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTrendBars(
    BuildContext context,
    List<WellbeingDailyRecord> validRecords,
  ) {
    final colors = context.colors;

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: validRecords.map((r) {
          final val = (r.indexValue ?? 50.0).clamp(0.0, 100.0);
          final factor = math.max(0.1, val / 100.0);
          final conf = r.confidence.clamp(0.0, 1.0);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: factor,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(
                            alpha: 0.4 + (conf * 0.6),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
