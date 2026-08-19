import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// بلوک یا بنر نمایش خطا با پیام انسانی، ثبت لاگ فنی و دکمهٔ تلاش دوباره
class ErrorBlock extends StatelessWidget {
  const ErrorBlock({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.isBannerMode = false,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool isBannerMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (isBannerMode) {
      // حالت بنر بالای دادهٔ کش‌شده
      return Container(
        margin: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.lg,
          vertical: RitmoSpacing.xs,
        ),
        padding: const EdgeInsets.all(RitmoSpacing.md),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: colors.error.withValues(alpha: 0.35),
            width: RitmoElevation.borderWidthDark,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.error, size: 20.0),
            const SizedBox(width: RitmoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: RitmoTextStyles.label(colors.error)),
                  Text(
                    message,
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RitmoSpacing.sm),
            TextButton(
              onPressed: () {
                RitmoHapticsPolicy.tap();
                onRetry();
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
                minimumSize: const Size(48, 48),
              ),
              child: Text(
                MovementStrings.commonRetry,
                style: RitmoTextStyles.label(colors.error),
              ),
            ),
          ],
        ),
      );
    }

    // حالت تمام صفحه وقتی داده‌ای وجود ندارد
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.xl,
          vertical: RitmoSpacing.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: MovementLayout.kActivityIconSize + 16,
              height: MovementLayout.kActivityIconSize + 16,
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  size: MovementLayout.kActivityIconSize,
                  color: colors.error,
                ),
              ),
            ),

            const SizedBox(height: RitmoSpacing.xl),

            Text(
              title,
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: RitmoSpacing.sm),

            Text(
              message,
              style: RitmoTextStyles.body(colors.textSecondary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: RitmoSpacing.xl),

            SizedBox(
              height: MovementLayout.kPrimaryButtonHeight,
              child: FilledButton(
                onPressed: () {
                  RitmoHapticsPolicy.tap();
                  onRetry();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                  minimumSize: const Size(
                    160,
                    MovementLayout.kPrimaryButtonHeight,
                  ),
                ),
                child: Text(
                  MovementStrings.commonRetry,
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
              ),
            ),

            if (secondaryActionLabel != null && onSecondaryAction != null) ...[
              const SizedBox(height: RitmoSpacing.sm),
              SizedBox(
                height: MovementLayout.kSecondaryButtonHeight,
                child: OutlinedButton(
                  onPressed: () {
                    RitmoHapticsPolicy.tap();
                    onSecondaryAction!();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(
                      color: colors.border,
                      width: RitmoElevation.borderWidthDark,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                    minimumSize: const Size(
                      160,
                      MovementLayout.kSecondaryButtonHeight,
                    ),
                  ),
                  child: Text(
                    secondaryActionLabel!,
                    style: RitmoTextStyles.label(colors.textPrimary),
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
