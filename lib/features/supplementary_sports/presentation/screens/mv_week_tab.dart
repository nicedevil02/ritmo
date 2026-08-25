import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';
import '../sheets/sheets.dart';

/// Tab 2: "هفته" (Section 5.2).
/// Displays 7 day cards for the week and cycle progress.
class MvWeekTab extends StatelessWidget {
  final List<MvSlot> weekSlots;
  final int cycleWeek;
  final bool isDeloadWeek;
  final ValueChanged<MvSlot> onSlotUpdated;
  final VoidCallback onRegenerateWeek;

  const MvWeekTab({
    super.key,
    required this.weekSlots,
    required this.cycleWeek,
    this.isDeloadWeek = false,
    required this.onSlotUpdated,
    required this.onRegenerateWeek,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(metrics.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Week Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'برنامهٔ هفتگی (هفتهٔ $cycleWeek)',
                    style: textTheme.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: metrics.spaceXs),
                  Text(
                    isDeloadWeek ? 'هفتهٔ سبک برای بازیابی بدنی' : 'برنامهٔ منظم تمرین و ریکاوری',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (isDeloadWeek)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: metrics.spaceSm, vertical: metrics.spaceXs),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                  child: Text(
                    'هفته سبک',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // 7 Day Slot Cards
          ...List.generate(weekSlots.length, (index) {
            final slot = weekSlots[index];
            return Padding(
              padding: EdgeInsets.only(bottom: metrics.spaceSm),
              child: MvDaySlotCard(
                slot: slot,
                onTap: () {
                  MvDayPlanSheet.show(
                    context: context,
                    slot: slot,
                    onSave: onSlotUpdated,
                  );
                },
              ),
            );
          }),
          SizedBox(height: metrics.spaceMd),

          // Smart Fill / Re-align Action
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, metrics.touchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(metrics.radiusField),
              ),
            ),
            icon: Icon(Icons.auto_fix_high_rounded, size: metrics.iconMd),
            label: const Text('تنظیم مجدد هوشمند روزهای هفته'),
            onPressed: onRegenerateWeek,
          ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }
}
