import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

class JourneySummarySection extends StatelessWidget {
  const JourneySummarySection({
    super.key,
    required this.snapshot,
    this.onSelectActivity,
  });

  final DayAgendaSnapshot snapshot;
  final ValueChanged<AgendaItem>? onSelectActivity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: RitmoSpacing.sm),
              Text(
                'خلاصه روز (${toPersianDigits(snapshot.dateStr)})',
                style: const TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),

          // 3 Metric Tiles Row
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'تکمیل‌شده',
                  value: toPersianDigits('${snapshot.completedCount}'),
                  icon: Icons.task_alt_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: RitmoSpacing.sm),
              Expanded(
                child: _MetricCard(
                  label: 'باقی‌مانده',
                  value: toPersianDigits('${snapshot.remainingCount}'),
                  icon: Icons.pending_actions_rounded,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: RitmoSpacing.sm),
              Expanded(
                child: _MetricCard(
                  label: 'زمان آزاد',
                  value: toPersianDigits('${snapshot.freeGaps.length}'),
                  icon: Icons.event_available_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // Spotlight rows for Current / Next activity
          if (snapshot.currentActivity != null) ...[
            _SpotlightActivityCard(
              label: 'فعالیت جاری',
              item: snapshot.currentActivity!,
              accentColor: theme.colorScheme.primary,
              isCurrent: true,
              onTap: () => onSelectActivity?.call(snapshot.currentActivity!),
            ),
            const SizedBox(height: RitmoSpacing.sm),
          ],
          if (snapshot.nextActivity != null) ...[
            _SpotlightActivityCard(
              label: 'فعالیت بعدی',
              item: snapshot.nextActivity!,
              accentColor: theme.colorScheme.tertiary,
              isCurrent: false,
              onTap: () => onSelectActivity?.call(snapshot.nextActivity!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(RitmoRadius.badge),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: RitmoSpacing.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.0,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightActivityCard extends StatelessWidget {
  const _SpotlightActivityCard({
    required this.label,
    required this.item,
    required this.accentColor,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final AgendaItem item;
  final Color accentColor;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RitmoRadius.card),
      child: Container(
        padding: const EdgeInsets.all(RitmoSpacing.md),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor,
              ),
            ),
            const SizedBox(width: RitmoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}
