import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// چیپ نمایش دلیل پیشنهاد با قابلیت ضربه و مشاهدهٔ توضیح تکمیلی
class ReasonChip extends StatelessWidget {
  const ReasonChip({
    super.key,
    required this.reason,
    this.explanation,
    this.onTap,
  });

  final String reason;
  final String? explanation;
  final VoidCallback? onTap;

  void _showExplanation(BuildContext context) {
    final text = explanation ?? reason;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ctx.colors;
        return Container(
          padding: const EdgeInsets.all(RitmoSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RitmoRadius.sheet),
            ),
            border: Border.all(
              color: colors.border,
              width: RitmoElevation.borderWidthDark,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                MovementStrings.reasonWhySuggestion,
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
              const SizedBox(height: RitmoSpacing.md),
              Text(text, style: RitmoTextStyles.body(colors.textSecondary)),
              const SizedBox(height: RitmoSpacing.xl),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
                child: Text(
                  MovementStrings.cutoverCalloutDismiss,
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sportsColor = context.modules.sports;

    return Semantics(
      button: true,
      label: 'دلیل پیشنهاد: $reason',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => _showExplanation(context),
          borderRadius: BorderRadius.circular(RitmoRadius.pill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32.0, minWidth: 48.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RitmoSpacing.sm,
                vertical: RitmoSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: sportsColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                border: Border.all(
                  color: sportsColor.withValues(alpha: 0.25),
                  width: RitmoElevation.borderWidthDark,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14.0,
                    color: sportsColor,
                  ),
                  const SizedBox(width: RitmoSpacing.xs),
                  Text(
                    reason,
                    style: RitmoTextStyles.badge(
                      sportsColor,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
