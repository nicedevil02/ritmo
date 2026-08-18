import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';

/// کارت نمایش ریتم ۲۴ ساعتهٔ روز (پنجرهٔ طلایی، پنجرهٔ افت و پربارترین روز)
class DailyRhythmCard extends StatelessWidget {
  const DailyRhythmCard({
    super.key,
    required this.output,
  });

  final EnergyAnalyticsOutput? output;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final out = output;
    final golden = out?.peakPerformanceWindow;
    final fatigued = out?.mostFatiguedWindow;
    final weekday = out?.mostProductiveWeekday;

    final hasData = (golden != null && golden.isNotEmpty) ||
        (fatigued != null && fatigued.isNotEmpty);

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
                  Icon(Icons.schedule, color: colors.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'ریتم شبانه‌روزی انرژی',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ],
              ),
              if (weekday != null && weekday.isNotEmpty)
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
                    'پربارترین: ${_weekdayName(weekday)}',
                    style: RitmoTextStyles.caption(colors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),
          if (!hasData) ...[
            Text(
              'برای کشف پنجره‌های طلایی و افت انرژی، به ثبت‌های منظم انرژی در ساعات مختلف روز نیاز است.',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
          ] else ...[
            // 24-hour visual bar
            _buildTimelineBar(context, golden, fatigued),
            const SizedBox(height: RitmoSpacing.md),
            Row(
              children: [
                if (golden != null && golden.isNotEmpty) ...[
                  Expanded(
                    child: _buildWindowBlock(
                      context,
                      title: 'پنجرهٔ طلایی (اوج تمرکز)',
                      window: golden,
                      color: colors.success,
                      icon: Icons.wb_sunny_outlined,
                    ),
                  ),
                ],
                if (golden != null &&
                    golden.isNotEmpty &&
                    fatigued != null &&
                    fatigued.isNotEmpty)
                  const SizedBox(width: RitmoSpacing.md),
                if (fatigued != null && fatigued.isNotEmpty) ...[
                  Expanded(
                    child: _buildWindowBlock(
                      context,
                      title: 'پنجرهٔ افت (نیاز به استراحت)',
                      window: fatigued,
                      color: colors.cautionAccent,
                      icon: Icons.battery_charging_full_outlined,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineBar(
    BuildContext context,
    String? golden,
    String? fatigued,
  ) {
    final colors = context.colors;

    final goldenRange = _parseWindowRange(golden);
    final fatiguedRange = _parseWindowRange(fatigued);

    return Column(
      children: [
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  // Base 24h background
                  Container(
                    width: w,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Golden window highlight
                  if (goldenRange != null)
                    Positioned(
                      left: w * (goldenRange.$1 / 24.0),
                      width: w * ((goldenRange.$2 - goldenRange.$1).abs() / 24.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors.success.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  // Fatigued window highlight
                  if (fatiguedRange != null)
                    Positioned(
                      left: w * (fatiguedRange.$1 / 24.0),
                      width:
                          w * ((fatiguedRange.$2 - fatiguedRange.$1).abs() / 24.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors.cautionAccent.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('۰۰:۰۰', style: RitmoTextStyles.caption(colors.textSecondary)),
            Text('۰۶:۰۰', style: RitmoTextStyles.caption(colors.textSecondary)),
            Text('۱۲:۰۰', style: RitmoTextStyles.caption(colors.textSecondary)),
            Text('۱۸:۰۰', style: RitmoTextStyles.caption(colors.textSecondary)),
            Text('۲۴:۰۰', style: RitmoTextStyles.caption(colors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildWindowBlock(
    BuildContext context, {
    required String title,
    required String window,
    required Color color,
    required IconData icon,
  }) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            RitmoNumber.fa(window),
            style: RitmoTextStyles.cardTitle(color),
          ),
        ],
      ),
    );
  }

  (double, double)? _parseWindowRange(String? window) {
    if (window == null || !window.contains('-')) return null;
    final parts = window.split('-');
    if (parts.length != 2) return null;
    final start = _parseHour(parts[0].trim());
    final end = _parseHour(parts[1].trim());
    if (start == null || end == null) return null;
    return (start, end);
  }

  double? _parseHour(String timeStr) {
    if (timeStr.contains(':')) {
      final sub = timeStr.split(':');
      final h = double.tryParse(sub[0]);
      final m = double.tryParse(sub[1]) ?? 0;
      if (h == null) return null;
      return h + (m / 60.0);
    }
    return double.tryParse(timeStr);
  }

  String _weekdayName(String weekday) {
    switch (weekday.toLowerCase()) {
      case 'saturday':
        return 'شنبه';
      case 'sunday':
        return 'یک‌شنبه';
      case 'monday':
        return 'دوشنبه';
      case 'tuesday':
        return 'سه‌شنبه';
      case 'wednesday':
        return 'چهارشنبه';
      case 'thursday':
        return 'پنج‌شنبه';
      case 'friday':
        return 'جمعه';
      default:
        return weekday;
    }
  }
}
