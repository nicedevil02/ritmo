import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// بلوک جشن رکورد شخصی (PR) با انیمیشن ملایم و قابل خاموشی در حالت Reduce Motion
class SummaryPrBlock extends StatelessWidget {
  const SummaryPrBlock({
    super.key,
    required this.prTitle,
    required this.prValue,
  });

  final String prTitle;
  final String prValue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: sportsColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: sportsColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sportsColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: RitmoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MovementStrings.summaryPrCelebration,
                  style: RitmoTextStyles.cardTitle(sportsColor).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$prTitle: $prValue',
                  style: RitmoTextStyles.body(colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
