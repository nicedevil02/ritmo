import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کارت ورودی بخش تمرین قدرتی در مرکز حرکت با ۴ وریانت
class StrengthEntryCard extends StatelessWidget {
  const StrengthEntryCard({
    super.key,
    this.program,
    required this.onBuildProgram,
    required this.onViewProgram,
    required this.onResumeSession,
    required this.onStartNextCycle,
  });

  final MovementStrengthProgram? program;
  final VoidCallback onBuildProgram;
  final VoidCallback onViewProgram;
  final VoidCallback onResumeSession;
  final VoidCallback onStartNextCycle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final isInactive = program == null || program!.isInactive;
    final isActive = program != null && program!.isActive;
    final isDeload = program != null && program!.isDeload;
    final isFinished = program != null && program!.isFinished;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.sm,
      ),
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: colors.border,
          width: RitmoElevation.borderWidthDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // سربرگ کارت
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: sportsColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: sportsColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: RitmoSpacing.sm),
              Expanded(
                child: Text(
                  MovementStrings.strengthTitle,
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                ),
              ),
              if (isDeload)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.sm,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    MovementStrings.strengthDeload,
                    style: RitmoTextStyles.badge(colors.warning),
                  ),
                ),
            ],
          ),

          const SizedBox(height: RitmoSpacing.md),

          // محتوا بر اساس حالت
          if (isInactive) ...[
            Text(
              MovementStrings.strengthCardDesc,
              style: RitmoTextStyles.body(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.md),
            _buildBenefit(Icons.home_rounded, MovementStrings.strengthBenefit1, colors),
            _buildBenefit(Icons.trending_up_rounded, MovementStrings.strengthBenefit2, colors),
            _buildBenefit(Icons.shield_outlined, MovementStrings.strengthBenefit3, colors),
            const SizedBox(height: RitmoSpacing.lg),
            SizedBox(
              height: MovementLayout.kPrimaryButtonHeight,
              child: FilledButton(
                onPressed: () {
                  RitmoHapticsPolicy.selection();
                  onBuildProgram();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: sportsColor,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
                child: Text(
                  MovementStrings.strengthBuildProgram,
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
              ),
            ),
          ] else if (isActive || isDeload) ...[
            if (isDeload) ...[
              Text(
                MovementStrings.strengthDeloadDesc,
                style: RitmoTextStyles.caption(colors.warning),
              ),
              const SizedBox(height: RitmoSpacing.sm),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  MovementStrings.strengthWeekProgress(
                    program!.currentWeek ?? 1,
                    program!.totalWeeks ?? 8,
                  ),
                  style: RitmoTextStyles.label(colors.textPrimary),
                ),
                Text(
                  toPersianDigits('${(program!.progressFraction * 100).round()}%'),
                  style: RitmoTextStyles.caption(colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: RitmoSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
              child: LinearProgressIndicator(
                value: program!.progressFraction,
                backgroundColor: colors.surfaceSunken,
                valueColor: AlwaysStoppedAnimation<Color>(sportsColor),
                minHeight: 6.0,
              ),
            ),
            const SizedBox(height: RitmoSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      RitmoHapticsPolicy.selection();
                      onResumeSession();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: sportsColor,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                    child: Text(
                      MovementStrings.strengthResumeSession,
                      style: RitmoTextStyles.label(colors.onPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: RitmoSpacing.sm),
                OutlinedButton(
                  onPressed: () {
                    RitmoHapticsPolicy.tap();
                    onViewProgram();
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
                  ),
                  child: Text(
                    MovementStrings.strengthViewProgram,
                    style: RitmoTextStyles.label(colors.textPrimary),
                  ),
                ),
              ],
            ),
          ] else if (isFinished) ...[
            Text(
              'دورهٔ تمرینی با موفقیت به پایان رسید. اکنون می‌توانید دورهٔ بعدی را با حجم و شدت جدید آغاز کنید.',
              style: RitmoTextStyles.body(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.lg),
            SizedBox(
              height: MovementLayout.kPrimaryButtonHeight,
              child: FilledButton(
                onPressed: () {
                  RitmoHapticsPolicy.selection();
                  onStartNextCycle();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: sportsColor,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
                child: Text(
                  MovementStrings.strengthStartNextCycle,
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text, RitmoColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16.0, color: colors.primary),
          const SizedBox(width: RitmoSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: RitmoTextStyles.caption(colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
