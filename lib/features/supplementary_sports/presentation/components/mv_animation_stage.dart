import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
/// Full-width Animation Stage for Workout Sessions and Hero Cards (Section 5.10 & 6.3).
class MvAnimationStage extends StatelessWidget {
  final String? animationAsset;
  final String? exerciseId;
  final double height;
  final bool isPlaying;

  const MvAnimationStage({
    super.key,
    this.animationAsset,
    this.exerciseId,
    this.height = 200,
    this.isPlaying = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;

    String? effectiveAsset = animationAsset;
    if (effectiveAsset == null || effectiveAsset.isEmpty) {
      if (exerciseId != null && exerciseId!.isNotEmpty) {
        effectiveAsset = 'assets/animations/custom/$exerciseId.json';
      } else {
        effectiveAsset = 'assets/animations/custom/hw_143.json';
      }
    }

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceSunken.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(metrics.radiusHero),
      ),
      child: Center(
        child: Lottie.asset(
          effectiveAsset,
          fit: BoxFit.contain,
          animate: isPlaying,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center_rounded, size: metrics.iconXl, color: colors.primary),
                SizedBox(height: metrics.spaceSm),
                Text(
                  'حرکت ورزشی',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
