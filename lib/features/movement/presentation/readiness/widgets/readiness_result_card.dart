import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت نمایش نتیجهٔ ارزیابی آمادگی (ReadinessResultCard)
/// صرفاً وصفی، بدون نمره از ۱۰۰ یا درصد ریکاوری.
class ReadinessResultCard extends StatelessWidget {
  const ReadinessResultCard({
    super.key,
    required this.result,
    this.onSelectSuggestion,
    this.onDismiss,
  });

  final ReadinessEvaluationResult result;
  final ValueChanged<String>? onSelectSuggestion;
  final VoidCallback? onDismiss;

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
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر کارت با آیکون و دکمهٔ بستن
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(RitmoSpacing.xs),
                decoration: BoxDecoration(
                  color: sportsColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt_rounded, color: sportsColor, size: 20),
              ),
              const SizedBox(width: RitmoSpacing.sm),
              Expanded(
                child: Text(
                  MovementStrings.readinessCheckinTitle,
                  style: RitmoTextStyles.caption(
                    sportsColor,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: colors.textTertiary,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // جملهٔ وضعیت توصیفی
          Text(
            result.statusHeadline,
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.xs),

          // دلیل کوتاه
          Text(
            result.reasonSummary,
            style: RitmoTextStyles.body(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // حداکثر ۳ پیشنهاد وصفی
          ...result.suggestions.map((suggestion) {
            return Padding(
              padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
              child: InkWell(
                onTap: onSelectSuggestion != null
                    ? () => onSelectSuggestion!(suggestion)
                    : null,
                borderRadius: BorderRadius.circular(RitmoRadius.field),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.md,
                    vertical: RitmoSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_right_rounded,
                        color: sportsColor,
                        size: 20,
                      ),
                      const SizedBox(width: RitmoSpacing.xs),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: RitmoTextStyles.body(colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
