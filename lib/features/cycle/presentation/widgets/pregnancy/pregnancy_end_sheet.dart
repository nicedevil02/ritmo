import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_animated_background.dart';

class PregnancyEndSheet extends StatelessWidget {
  const PregnancyEndSheet({
    super.key,
    required this.onBirth,
    required this.onLoss,
    required this.onMistake,
  });

  final VoidCallback onBirth;
  final VoidCallback onLoss;
  final VoidCallback onMistake;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onBirth,
    required VoidCallback onLoss,
    required VoidCallback onMistake,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return RitmoSheetGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: PregnancyEndSheet(
              onBirth: () {
                Navigator.of(sheetCtx).pop();
                onBirth();
              },
              onLoss: () {
                Navigator.of(sheetCtx).pop();
                onLoss();
              },
              onMistake: () {
                Navigator.of(sheetCtx).pop();
                onMistake();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'پایان دوره بارداری',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Path 1: Birth
        InkWell(
          onTap: onBirth,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.heart_fill, color: colors.success, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تولد نوزاد 🎉',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'داده‌های بارداری نگه داشته می‌شوند و حالت بارداری بسته می‌شود.',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Path 2: Loss
        InkWell(
          onTap: onLoss,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.heart, color: colors.textSecondary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'پایان زودهنگام یا از دست رفتن 🤍',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'حالت بارداری بسته می‌شود. می‌توانی انتخاب کنی داده‌ها بمانند یا پاک شوند.',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Path 3: Mistake / Simple exit
        InkWell(
          onTap: onMistake,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.arrow_counterclockwise, color: colors.textSecondary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ثبت اشتباهی یا خروج ساده 🔄',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'همهٔ داده‌های بارداری پاک می‌شوند و چرخه برمی‌گردد.',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
