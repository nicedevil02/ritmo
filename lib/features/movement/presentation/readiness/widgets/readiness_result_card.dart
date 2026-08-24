import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';

class ReadinessResultCard extends StatelessWidget {
  const ReadinessResultCard({
    super.key,
    required this.result,
  });

  final ReadinessEvaluationResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.statusHeadline,
            style: RitmoTextStyles.sectionHeadline(sportsColor),
          ),
          const SizedBox(height: RitmoSpacing.xs),
          Text(
            result.reasonSummary,
            style: RitmoTextStyles.body(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.md),
          for (final sug in result.suggestions) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18, color: sportsColor),
                  const SizedBox(width: RitmoSpacing.xs),
                  Expanded(
                    child: Text(
                      sug,
                      style: RitmoTextStyles.body(colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
