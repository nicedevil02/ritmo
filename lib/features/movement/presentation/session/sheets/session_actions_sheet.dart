import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// شیت گزینه‌های ثانویه در حین جلسهٔ زنده
class SessionActionsSheet extends StatelessWidget {
  const SessionActionsSheet({
    super.key,
    required this.onEaseUp,
    required this.onSwapMovement,
    required this.onPainReport,
    required this.onSkipStep,
    required this.onStopSession,
  });

  final VoidCallback onEaseUp;
  final VoidCallback onSwapMovement;
  final VoidCallback onPainReport;
  final VoidCallback onSkipStep;
  final VoidCallback onStopSession;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onEaseUp,
    required VoidCallback onSwapMovement,
    required VoidCallback onPainReport,
    required VoidCallback onSkipStep,
    required VoidCallback onStopSession,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SessionActionsSheet(
        onEaseUp: () {
          Navigator.of(ctx).pop();
          onEaseUp();
        },
        onSwapMovement: () {
          Navigator.of(ctx).pop();
          onSwapMovement();
        },
        onPainReport: () {
          Navigator.of(ctx).pop();
          onPainReport();
        },
        onSkipStep: () {
          Navigator.of(ctx).pop();
          onSkipStep();
        },
        onStopSession: () {
          Navigator.of(ctx).pop();
          onStopSession();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RitmoRadius.sheet),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: MovementLayout.kSheetHandleSize.width,
              height: MovementLayout.kSheetHandleSize.height,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          Text(
            MovementStrings.sessionActionsTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.md),

          _buildRow(
            icon: Icons.trending_down_rounded,
            title: MovementStrings.sessionActionEaseUp,
            color: sportsColor,
            onTap: onEaseUp,
            colors: colors,
          ),
          _buildRow(
            icon: Icons.swap_horiz_rounded,
            title: MovementStrings.sessionActionSwapMovement,
            color: colors.textPrimary,
            onTap: onSwapMovement,
            colors: colors,
          ),
          _buildRow(
            icon: Icons.healing_rounded,
            title: MovementStrings.sessionPainTitle,
            color: colors.warning,
            onTap: onPainReport,
            colors: colors,
          ),
          _buildRow(
            icon: Icons.skip_next_rounded,
            title: MovementStrings.sessionActionSkipStep,
            color: colors.textSecondary,
            onTap: onSkipStep,
            colors: colors,
          ),
          const Divider(height: 24),
          _buildRow(
            icon: Icons.stop_circle_outlined,
            title: MovementStrings.sessionActionStopSession,
            color: colors.error,
            onTap: onStopSession,
            colors: colors,
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required dynamic colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RitmoRadius.field),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: RitmoSpacing.md),
            Expanded(
              child: Text(
                title,
                style: RitmoTextStyles.body(
                  color,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              color: colors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
