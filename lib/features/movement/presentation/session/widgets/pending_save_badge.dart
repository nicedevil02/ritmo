import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// نشانگر وضعیت ذخیره‌سازی در صف انتظار هنگام خطای شبکه/پایگاه‌داده
class PendingSaveBadge extends StatelessWidget {
  const PendingSaveBadge({
    super.key,
    required this.pendingCount,
    required this.onRetry,
  });

  final int pendingCount;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0) return const SizedBox.shrink();

    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: RitmoSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync_problem_rounded, size: 16, color: colors.warning),
          const SizedBox(width: RitmoSpacing.xs),
          Text(
            MovementStrings.sessionPendingSave,
            style: RitmoTextStyles.caption(colors.warning).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: RitmoSpacing.sm),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                MovementStrings.commonRetry,
                style: RitmoTextStyles.caption(colors.warning).copyWith(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
