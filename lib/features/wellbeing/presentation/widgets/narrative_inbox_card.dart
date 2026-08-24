import 'package:flutter/material.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_narrative_card.dart';

/// کارت صندوق روایت‌ها: بینش‌های آمادهٔ دیگر و موارد در حال یادگیری
class NarrativeInboxCard extends StatelessWidget {
  const NarrativeInboxCard({
    super.key,
    required this.snapshot,
    required this.onAction,
  });

  final WellbeingInsightSnapshot snapshot;
  final ValueChanged<WellbeingInsightAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final readyInsights = snapshot.ready
        .where((i) => i.kind != snapshot.featured?.kind)
        .toList();
    final growingInsights = snapshot.growing;

    if (readyInsights.isEmpty && growingInsights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (readyInsights.isNotEmpty) ...[
          Text(
            'سایر بینش‌های امروز',
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.md),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: readyInsights.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: RitmoSpacing.md),
              itemBuilder: (ctx, index) {
                final insight = readyInsights[index];
                return SizedBox(
                  width: 280,
                  child: WellbeingNarrativeCard(
                    insight: insight,
                    onAction: onAction,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
        if (growingInsights.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(RitmoSpacing.lg),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'الگوهای در حال یادگیری',
                      style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: RitmoSpacing.md),
                ...growingInsights.take(3).map((g) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.timelapse, size: 14, color: colors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            g.body,
                            style: RitmoTextStyles.caption(
                              colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
