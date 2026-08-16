import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// انواع حالت‌های خالی ماژول حرکت
enum MovementEmptyStateKind {
  emptyWeek,
  emptyDay,
  noHistory,
  noSearchResult,
  searchNoResult,
  noStrengthProgram,
  noProgressData,
  noLibraryResult,
}

typedef MovementEmptyKind = MovementEmptyStateKind;

/// بلوک وضعیت خالی با لحن سازنده و حداقل یک اکشن عملیاتی
class EmptyStateBlock extends StatelessWidget {
  const EmptyStateBlock({
    super.key,
    required this.kind,
    this.title = 'موردی یافت نشد',
    this.message = 'می‌توانید یک فعالیت جدید اضافه کنید.',
    this.primaryActionLabel = 'افزودن فعالیت',
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.actionLabel,
    this.onAction,
  });

  final MovementEmptyStateKind kind;
  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData _iconForKind() {
    switch (kind) {
      case MovementEmptyStateKind.emptyWeek:
        return Icons.calendar_view_week_rounded;
      case MovementEmptyStateKind.emptyDay:
        return Icons.event_available_rounded;
      case MovementEmptyStateKind.noHistory:
        return Icons.history_rounded;
      case MovementEmptyStateKind.noSearchResult:
      case MovementEmptyStateKind.searchNoResult:
        return Icons.search_off_rounded;
      case MovementEmptyStateKind.noStrengthProgram:
        return Icons.fitness_center_rounded;
      case MovementEmptyStateKind.noProgressData:
        return Icons.insights_rounded;
      case MovementEmptyStateKind.noLibraryResult:
        return Icons.menu_book_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;
    final effectiveAction = onPrimaryAction ?? onAction;
    final effectiveLabel = actionLabel ?? primaryActionLabel;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.xl,
          vertical: RitmoSpacing.xxxl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // آیکون ۴۰ پیکسل با پس‌زمینهٔ ملایم
            Container(
              width: MovementLayout.kActivityIconSize + 16,
              height: MovementLayout.kActivityIconSize + 16,
              decoration: BoxDecoration(
                color: sportsColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _iconForKind(),
                  size: MovementLayout.kActivityIconSize,
                  color: sportsColor,
                ),
              ),
            ),

            const SizedBox(height: RitmoSpacing.xl),

            // عنوان وضعیت
            Text(
              title,
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: RitmoSpacing.sm),

            // توضیح سازنده
            Text(
              message,
              style: RitmoTextStyles.body(colors.textSecondary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: RitmoSpacing.xl),

            // اکشن اصلی
            if (effectiveAction != null) ...[
              SizedBox(
                height: MovementLayout.kPrimaryButtonHeight,
                child: FilledButton(
                  onPressed: () {
                    RitmoHapticsPolicy.tap();
                    effectiveAction();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                    minimumSize: const Size(160, MovementLayout.kPrimaryButtonHeight),
                  ),
                  child: Text(
                    effectiveLabel,
                    style: RitmoTextStyles.label(colors.onPrimary),
                  ),
                ),
              ),
            ],

            // اکشن فرعی (اختیاری)
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
                    minimumSize: const Size(160, MovementLayout.kSecondaryButtonHeight),
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
