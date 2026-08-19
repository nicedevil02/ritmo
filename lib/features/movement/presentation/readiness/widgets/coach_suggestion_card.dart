import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/presentation/common/reason_chip.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت پیشنهاد مربی هوشمند (CoachSuggestionCard)
/// ساختار اجباری سه‌لایه: پیشنهاد + دلیل با ReasonChip + سه اکشن (پذیرش / تغییر / رد)
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
      width: double.infinity,
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: sportsColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // لایه ۱: هدر با عنوان و ReasonChip
          Row(
            children: [
              Icon(Icons.assistant_rounded, color: sportsColor, size: 20),
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                MovementStrings.coachSuggestionTitle,
                style: RitmoTextStyles.caption(
                  sportsColor,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ReasonChip(
                reason: suggestion.reason,
                explanation: suggestion.text,
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // لایه ۲: متن پیشنهاد
          Text(
            suggestion.text,
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // لایه ۳: سه اکشن (پذیرش / تغییر / رد)
          Row(
            children: [
              // دکمهٔ پذیرش (اصلی)
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    backgroundColor: sportsColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    suggestion.primaryActionLabel,
                    style: RitmoTextStyles.caption(
                      Colors.white,
                    ).copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: RitmoSpacing.xs),

              // دکمهٔ تغییر
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: onAdjust,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(
                    suggestion.secondaryActionLabel,
                    style: RitmoTextStyles.caption(colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: RitmoSpacing.xs),

              // دکمهٔ رد کردن
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  suggestion.dismissActionLabel,
                  style: RitmoTextStyles.caption(colors.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
