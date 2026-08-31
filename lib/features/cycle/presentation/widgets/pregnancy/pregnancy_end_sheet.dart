import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

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
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: RitmoBreakpoints.sheetMaxHeight(sheetCtx, factor: 0.94),
            ),
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            children: [
              RitmoNeuButton(
                padding: const EdgeInsets.all(8),
                radius: 10,
                onTap: () => Navigator.pop(context),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 16,
                  color: colors.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  'پایان دوره بارداری',
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 34),
            ],
          ),
          const SizedBox(height: 16),

          // Path 1: Birth
          RitmoCard.neumorphic(
            onTap: onBirth,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.heart_fill,
                    color: colors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تولد نوزاد 🎉',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'داده‌های بارداری نگه داشته می‌شوند و حالت بارداری بسته می‌شود.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Path 2: Loss
          RitmoCard.neumorphic(
            onTap: onLoss,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.heart,
                    color: colors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'پایان زودهنگام یا از دست رفتن 🤍',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'حالت بارداری بسته می‌شود. می‌توانی انتخاب کنی داده‌ها بمانند یا پاک شوند.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Path 3: Mistake / Simple exit
          RitmoCard.neumorphic(
            onTap: onMistake,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.arrow_counterclockwise,
                    color: colors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ثبت اشتباهی یا خروج ساده 🔄',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'همهٔ داده‌های بارداری پاک می‌شوند و چرخه برمی‌گردد.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
