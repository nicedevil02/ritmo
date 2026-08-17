import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';

class WellbeingNarrativeCard extends StatelessWidget {
  const WellbeingNarrativeCard({
    super.key,
    required this.insight,
    required this.onAction,
  });

  final WellbeingInsight? insight;
  final void Function(WellbeingInsightAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final item = insight;
    if (item == null) return const SizedBox.shrink();

    final colors = context.colors;
    final growing = item.maturity == WellbeingInsightMaturity.growing;

    return Semantics(
      container: true,
      label: growing
          ? 'روایت در حال شکل‌گیری: ${item.title}'
          : 'روایت امروز: ${item.title}',
      child: Container(
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: growing
                ? colors.border
                : colors.primary.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  growing ? Icons.hourglass_empty : Icons.auto_stories_outlined,
                  size: 18,
                  color: growing ? colors.textSecondary : colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    growing ? 'در حال یادگیری' : 'روایت امروز',
                    style: RitmoTextStyles.caption(
                      growing ? colors.textSecondary : colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(item.body, style: RitmoTextStyles.body(colors.textSecondary)),
            if (growing) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 6,
                  backgroundColor: colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${RitmoNumber.faInt(item.have)} از ${RitmoNumber.faInt(item.need)} ثبت لازم',
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
            ],
            if (item.action != null && item.actionLabel != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => onAction(item.action!),
                  child: Text(
                    item.actionLabel!,
                    style: RitmoTextStyles.label(colors.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
