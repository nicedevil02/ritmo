import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/realm/reports/zone_report_models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// Presentation card displaying the weekly realm distribution and budget adherence (F-15).
class WeeklyRealmReportCard extends StatelessWidget {
  const WeeklyRealmReportCard({
    super.key,
    required this.report,
    this.onTapMore,
  });

  final WeeklyRealmReport report;
  final VoidCallback? onTapMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (report.items.isEmpty) {
      return const RitmoNeuEmptyCard(
        icon: Icons.pie_chart_outline,
        title: 'گزارش هفتگی قلمروها',
        subtitle: 'هنوز داده‌ای از حضور در قلمروها برای این هفته ثبت نشده است.',
      );
    }

    final totalHours = report.totalTrackedMinutes ~/ 60;
    final totalMinRemainder = report.totalTrackedMinutes % 60;

    return RitmoCard.neumorphic(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.insights,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'گزارش هفتگی قلمروها',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'مجموع $totalHours ساعت و $totalMinRemainder دقیقه حضور (${report.totalSessions} نشست)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTapMore != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: onTapMore,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Distribution bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: report.items.map((item) {
                    final percentage = report.percentageFor(item);
                    final color = _parseColor(item.colorHex);
                    return Expanded(
                      flex: (percentage * 100).toInt().clamp(1, 100),
                      child: Container(color: color),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Realm items list
            ...report.items.map((item) => _buildRealmItemRow(context, item)),
          ],
        ),
      );
  }

  Widget _buildRealmItemRow(BuildContext context, ZoneReportItem item) {
    final theme = Theme.of(context);
    final color = _parseColor(item.colorHex);
    final percentage = (report.percentageFor(item) * 100).toInt();

    final diff = item.diffMinutesFromPreviousWeek;
    final diffHours = diff != null ? (diff.abs() ~/ 60) : 0;
    final diffMin = diff != null ? (diff.abs() % 60) : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${item.hours}س و ${item.minutesRemainder}د ($percentage٪)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Comparison and Budget badges
          Row(
            children: [
              if (diff != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (diff >= 0 ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${diff >= 0 ? '+' : '-'}$diffHoursس و $diffMinد نسبت به هفته قبل',
                    style: TextStyle(
                      fontSize: 11,
                      color: diff >= 0 ? Colors.green[700] : Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (item.budget != null) ...[
                if (item.budget!.minMinutes != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (item.minBudgetProgress! >= 1.0
                              ? Colors.green
                              : Colors.blue)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'هدف ${item.budget!.minMinutes! ~/ 60}س: ${(item.minBudgetProgress! * 100).toInt()}٪',
                      style: TextStyle(
                        fontSize: 11,
                        color: item.minBudgetProgress! >= 1.0
                            ? Colors.green[700]
                            : Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                if (item.budget!.maxMinutes != null &&
                    item.isMaxBudgetExceeded) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚠️ فراتر از سقف (${item.budget!.maxMinutes! ~/ 60}س)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      var hex = colorHex.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {}
    return const Color(0xFF6366F1);
  }
}
