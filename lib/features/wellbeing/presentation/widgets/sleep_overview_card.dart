import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';

/// کارت جامع وضعیت خواب در بازهٔ انتخابی
class SleepOverviewCard extends StatelessWidget {
  const SleepOverviewCard({
    super.key,
    required this.output,
    required this.target,
    required this.sleepLogCount,
  });

  final SleepEngineOutput? output;
  final SleepTarget target;
  final int sleepLogCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final out = output;
    final avgMin = out?.avgDurationMinutes ?? 0;
    final avgQuality = out?.avgQuality;
    final debtMin = out?.sleepDebtMinutes ?? 0;
    final consistency = out?.consistencyScore;

    final hasData = sleepLogCount > 0 && avgMin > 0;

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
              Row(
                children: [
                  Icon(Icons.bedtime, color: colors.sleepAccent, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'خواب این بازه',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ],
              ),
              if (hasData)
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
                    'هدف: ${RitmoNumber.faHours(target.durationMinutes / 60.0)}',
                    style: RitmoTextStyles.caption(colors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),
          if (!hasData) ...[
            Text(
              'هنوز خوابی در این بازه ثبت نشده است. با ثبت اولین خواب، میانگین و بدهی خواب محاسبه می‌شود.',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'میانگین مدت',
                    value: RitmoNumber.faHours(avgMin / 60.0),
                    icon: Icons.timer_outlined,
                    color: colors.sleepAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'کیفیت میانگین',
                    value: avgQuality != null && avgQuality > 0
                        ? '${RitmoNumber.fa(avgQuality.toStringAsFixed(1))} از ۵'
                        : '—',
                    icon: Icons.star_outline,
                    color: colors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'بدهی خواب',
                    value: debtMin.abs() > 0
                        ? '${RitmoNumber.faInt((debtMin / 60.0).round())} ساعت'
                        : 'صفر',
                    icon: Icons.account_balance_wallet_outlined,
                    color: debtMin > 60 ? colors.error : colors.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    title: 'یکنواختی خواب',
                    value: consistency != null
                        ? '${RitmoNumber.faInt(consistency.round())}٪'
                        : '—',
                    icon: Icons.sync,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: RitmoTextStyles.titleMedium(colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
