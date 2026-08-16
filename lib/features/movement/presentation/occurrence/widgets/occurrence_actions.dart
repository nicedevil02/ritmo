import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// فهرست کامل اکشن‌های قابل انجام روی یک Occurrence در صفحهٔ جزئیات
class OccurrenceActions extends StatelessWidget {
  const OccurrenceActions({
    super.key,
    required this.occurrence,
    required this.onStartSession,
    required this.onQuickComplete,
    required this.onMoveSession,
    required this.onPlanB,
    required this.onSkipSession,
    required this.onEditPlan,
    required this.onDeleteSession,
  });

  final MovementOccurrence occurrence;
  final VoidCallback onStartSession;
  final VoidCallback onQuickComplete;
  final VoidCallback onMoveSession;
  final VoidCallback onPlanB;
  final VoidCallback onSkipSession;
  final VoidCallback onEditPlan;
  final VoidCallback onDeleteSession;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;
    final isDone = occurrence.isCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDone) ...[
          // دکمهٔ اصلی: شروع جلسه
          SizedBox(
            width: double.infinity,
            height: MovementLayout.kFieldMinHeight,
            child: ElevatedButton.icon(
              onPressed: onStartSession,
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              label: Text(
                MovementStrings.menuStart,
                style: RitmoTextStyles.label(Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: sportsColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // ثبت دستی / سریع
          _buildActionTile(
            context,
            icon: Icons.check_circle_outline_rounded,
            title: MovementStrings.menuManualLog,
            colors: colors,
            onTap: onQuickComplete,
          ),

          // جابه‌جایی جلسه
          _buildActionTile(
            context,
            icon: Icons.calendar_month_rounded,
            title: MovementStrings.menuMove,
            colors: colors,
            onTap: onMoveSession,
          ),

          // نسخهٔ کوتاه (Plan B)
          _buildActionTile(
            context,
            icon: Icons.timer_outlined,
            title: MovementStrings.menuShortVersion,
            colors: colors,
            onTap: onPlanB,
          ),

          // رد کردن جلسه
          _buildActionTile(
            context,
            icon: Icons.do_not_disturb_on_outlined,
            title: MovementStrings.menuSkip,
            colors: colors,
            onTap: onSkipSession,
          ),

          // ویرایش برنامه
          _buildActionTile(
            context,
            icon: Icons.edit_calendar_outlined,
            title: MovementStrings.menuEditPlan,
            colors: colors,
            onTap: onEditPlan,
          ),
        ],

        // حذف جلسه
        _buildActionTile(
          context,
          icon: Icons.delete_outline_rounded,
          title: MovementStrings.menuDelete,
          colors: colors,
          iconColor: colors.error,
          titleColor: colors.error,
          onTap: onDeleteSession,
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required dynamic colors,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.lg,
              vertical: RitmoSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? colors.textSecondary, size: 22),
                const SizedBox(width: RitmoSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: RitmoTextStyles.body(titleColor ?? colors.textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colors.textSecondary.withValues(alpha: 0.4),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
