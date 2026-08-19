import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت روز ریکاوری در لیست برنامهٔ روز
class RecoveryDayCard extends StatelessWidget {
  const RecoveryDayCard({super.key, this.onAddLightMovement});

  final VoidCallback? onAddLightMovement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.xs,
      ),
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: colors.border,
          width: RitmoElevation.borderWidthDark,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: MovementLayout.kActivityIconSize + 12,
            height: MovementLayout.kActivityIconSize + 12,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.spa_rounded,
              color: colors.primary,
              size: MovementLayout.kActivityIconSize,
            ),
          ),
          const SizedBox(width: RitmoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MovementStrings.recoveryDayTitle,
                  style: RitmoTextStyles.label(
                    colors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: RitmoSpacing.xs),
                Text(
                  MovementStrings.recoveryDayDesc,
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ],
            ),
          ),
          if (onAddLightMovement != null) ...[
            const SizedBox(width: RitmoSpacing.sm),
            TextButton.icon(
              onPressed: () {
                RitmoHapticsPolicy.tap();
                onAddLightMovement!();
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                MovementStrings.recoveryDayAddLight,
                style: RitmoTextStyles.caption(
                  colors.primary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.sm,
                  vertical: RitmoSpacing.xs,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
