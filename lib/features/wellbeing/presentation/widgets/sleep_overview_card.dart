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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final out = output;
    final avgMin = out?.avgDurationMinutes ?? 0;
    final avgQuality = out?.avgQuality;
    final debtMin = out?.sleepDebtMinutes ?? 0;
    final consistency = out?.consistencyScore;

    final hasData = sleepLogCount > 0 && avgMin > 0;

    if (!hasData) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.border.withValues(alpha: isDark ? 0.3 : 0.6),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.sleepAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bedtime_rounded,
                color: colors.sleepAccent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خواب این بازه',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'هنوز خوابی در این بازه ثبت نشده است.',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10,
                      color: colors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.border.withValues(alpha: isDark ? 0.3 : 0.6),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bedtime_rounded,
                    color: colors.sleepAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'خواب این بازه',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'هدف: ${RitmoNumber.faHours(target.durationMinutes / 60.0)}',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 10,
                    color: colors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
