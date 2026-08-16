import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

enum PauseExitAction {
  pauseAndBack,
  finish,
  continueSession,
}

/// شیت ۳ گزینه‌ای خروج/توقف جلسهٔ زنده با ترتیب ثابت و توصیه به مکث
class PauseExitSheet extends StatelessWidget {
  const PauseExitSheet({
    super.key,
    required this.onActionSelected,
  });

  final ValueChanged<PauseExitAction> onActionSelected;

  static Future<PauseExitAction?> show(BuildContext context) {
    return showModalBottomSheet<PauseExitAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PauseExitSheet(
        onActionSelected: (act) => Navigator.of(ctx).pop(act),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
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
            MovementStrings.pauseExitTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'جلسهٔ شما در پس‌زمینه متوقف خواهد ماند و می‌توانید بعداً آن را ادامه دهید.',
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // گزینهٔ ۱: مکث و برگشت به برنامه (پیشنهادی)
          SizedBox(
            width: double.infinity,
            height: MovementLayout.kFieldMinHeight,
            child: ElevatedButton.icon(
              onPressed: () => onActionSelected(PauseExitAction.pauseAndBack),
              icon: const Icon(Icons.pause_circle_filled_rounded),
              label: const Text('${MovementStrings.pauseExitPause} (پیشنهادی)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: sportsColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // گزینهٔ ۲: پایان جلسه
          SizedBox(
            width: double.infinity,
            height: MovementLayout.kFieldMinHeight,
            child: OutlinedButton.icon(
              onPressed: () => onActionSelected(PauseExitAction.finish),
              icon: Icon(Icons.check_circle_outline_rounded, color: colors.textPrimary),
              label: Text(
                MovementStrings.pauseExitFinish,
                style: RitmoTextStyles.label(colors.textPrimary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // گزینهٔ ۳: ادامه
          SizedBox(
            width: double.infinity,
            height: MovementLayout.kFieldMinHeight,
            child: TextButton.icon(
              onPressed: () => onActionSelected(PauseExitAction.continueSession),
              icon: Icon(Icons.play_arrow_rounded, color: colors.textSecondary),
              label: Text(
                MovementStrings.pauseExitContinue,
                style: RitmoTextStyles.label(colors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }
}
