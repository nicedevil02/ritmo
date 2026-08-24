import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';

class CoachSuggestionCard extends StatelessWidget {
  const CoachSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onAccept,
    required this.onAdjust,
    required this.onDismiss,
  });

  final CoachSuggestion suggestion;
  final VoidCallback onAccept;
  final VoidCallback onAdjust;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: sportsColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: sportsColor, size: 22),
              const SizedBox(width: RitmoSpacing.xs),
              Expanded(
                child: Text(
                  suggestion.reason,
                  style: RitmoTextStyles.cardTitle(sportsColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.xs),
          Text(
            suggestion.text,
            style: RitmoTextStyles.body(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.md),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: colors.onPrimary,
                  ),
                  child: Text(suggestion.primaryActionLabel),
                ),
              ),
              const SizedBox(width: RitmoSpacing.xs),
              OutlinedButton(
                onPressed: onAdjust,
                child: Text(suggestion.secondaryActionLabel),
              ),
              const SizedBox(width: RitmoSpacing.xs),
              TextButton(
                onPressed: onDismiss,
                child: Text(suggestion.dismissActionLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
