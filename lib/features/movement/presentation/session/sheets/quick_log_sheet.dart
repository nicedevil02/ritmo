import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// شیت ثبت ۵ ثانیه‌ای سریع تمرین با سه ایموجی شدت (P-11)
class QuickLogSheet extends StatelessWidget {
  const QuickLogSheet({super.key, required this.onSelectIntensity});

  final ValueChanged<String> onSelectIntensity;

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickLogSheet(
        onSelectIntensity: (intensity) => Navigator.of(ctx).pop(intensity),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildEmojiButton(
              context: context,
              emoji: '😌',
              label: 'سبک',
              intensityTag: 'light',
            ),
            _buildEmojiButton(
              context: context,
              emoji: '😊',
              label: 'خوب',
              intensityTag: 'moderate',
            ),
            _buildEmojiButton(
              context: context,
              emoji: '💪',
              label: 'سنگین',
              intensityTag: 'hard',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiButton({
    required BuildContext context,
    required String emoji,
    required String label,
    required String intensityTag,
  }) {
    final colors = context.colors;

    return InkWell(
      onTap: () => onSelectIntensity(intensityTag),
      borderRadius: BorderRadius.circular(RitmoRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: RitmoSpacing.xs),
            Text(label, style: RitmoTextStyles.body(colors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
