import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

const Duration _kShimmerPeriod = Duration(milliseconds: 1400);

class RitmoShimmer extends StatefulWidget {
  final Widget child;

  const RitmoShimmer({super.key, required this.child});

  @override
  State<RitmoShimmer> createState() => _RitmoShimmerState();
}

class _RitmoShimmerState extends State<RitmoShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kShimmerPeriod,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04);
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.09);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value.clamp(0.0, 1.0),
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class RitmoShimmerCard extends StatelessWidget {
  final double height;

  const RitmoShimmerCard({super.key, this.height = 140});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title placeholder
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: colors.textPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          // Body line 1
          Container(
            width: double.infinity,
            height: 10,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          // Body line 2
          Container(
            width: 100,
            height: 10,
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 30,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RitmoShimmerGrid extends StatelessWidget {
  final int count;

  const RitmoShimmerGrid({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return const RitmoShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  RitmoShimmerCard(height: 160),
                  SizedBox(height: 12),
                  RitmoShimmerCard(height: 120),
                  SizedBox(height: 12),
                  RitmoShimmerCard(height: 150),
                ],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  RitmoShimmerCard(height: 130),
                  SizedBox(height: 12),
                  RitmoShimmerCard(height: 170),
                  SizedBox(height: 12),
                  RitmoShimmerCard(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RitmoShimmerList extends StatelessWidget {
  final int count;

  const RitmoShimmerList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return RitmoShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        itemCount: count,
        separatorBuilder: (context, index) => const SizedBox(height: RitmoSpacing.md),
        itemBuilder: (context, index) => const RitmoShimmerCard(height: 100),
      ),
    );
  }
}

