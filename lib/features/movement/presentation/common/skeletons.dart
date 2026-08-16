import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// پایه اسکلت بارگذاری متحرک با پشتیبانی کامل از غیرفعال‌سازی انیمیشن (Reduce Motion)
class MovementSkeletonBox extends StatefulWidget {
  const MovementSkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = RitmoRadius.card,
    this.child,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final Widget? child;

  @override
  State<MovementSkeletonBox> createState() => _MovementSkeletonBoxState();
}

class _MovementSkeletonBoxState extends State<MovementSkeletonBox>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = RitmoMotion.reduceMotion(context);
    if (reduceMotion) {
      _controller?.dispose();
      _controller = null;
      _animation = null;
    } else if (_controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
      _animation = Tween<double>(begin: 0.35, end: 0.85).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reduceMotion = RitmoMotion.reduceMotion(context);

    if (reduceMotion || _animation == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: colors.border,
            width: RitmoElevation.borderWidthDark,
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _animation!,
      builder: (context, child) {
        final opacity = _animation!.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.surfaceSunken.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: colors.border,
              width: RitmoElevation.borderWidthDark,
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// اسکلت هیرو کارت مرکز حرکت
class HeroSkeleton extends StatelessWidget {
  const HeroSkeleton({
    super.key,
    this.height = MovementLayout.kHeroMinHeight,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return MovementSkeletonBox(
      width: double.infinity,
      height: height,
      borderRadius: RitmoRadius.hero,
      child: const Padding(
        padding: EdgeInsets.all(RitmoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                MovementSkeletonBox(
                  width: 36,
                  height: 36,
                  borderRadius: RitmoRadius.iconButton,
                ),
                SizedBox(width: RitmoSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MovementSkeletonBox(
                      width: 120,
                      height: 16,
                      borderRadius: RitmoRadius.badge,
                    ),
                    SizedBox(height: RitmoSpacing.xs),
                    MovementSkeletonBox(
                      width: 80,
                      height: 12,
                      borderRadius: RitmoRadius.badge,
                    ),
                  ],
                ),
              ],
            ),
            MovementSkeletonBox(
              width: 140,
              height: 36,
              borderRadius: RitmoRadius.field,
            ),
          ],
        ),
      ),
    );
  }
}

/// اسکلت کارت جلسه
class SessionCardSkeleton extends StatelessWidget {
  const SessionCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const MovementSkeletonBox(
      width: double.infinity,
      height: MovementLayout.kSessionCardMinHeight,
      borderRadius: RitmoRadius.card,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.sm,
        ),
        child: Row(
          children: [
            MovementSkeletonBox(
              width: MovementLayout.kAccentBarWidth,
              height: 48,
              borderRadius: RitmoRadius.badge,
            ),
            SizedBox(width: RitmoSpacing.sm),
            MovementSkeletonBox(
              width: MovementLayout.kActivityIconSize,
              height: MovementLayout.kActivityIconSize,
              borderRadius: RitmoRadius.iconButton,
            ),
            SizedBox(width: RitmoSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MovementSkeletonBox(
                    width: 140,
                    height: 14,
                    borderRadius: RitmoRadius.badge,
                  ),
                  SizedBox(height: RitmoSpacing.xs),
                  MovementSkeletonBox(
                    width: 90,
                    height: 10,
                    borderRadius: RitmoRadius.badge,
                  ),
                ],
              ),
            ),
            MovementSkeletonBox(
              width: 48,
              height: 28,
              borderRadius: RitmoRadius.pill,
            ),
          ],
        ),
      ),
    );
  }
}

/// اسکلت ریل هفته
class WeekRailSkeleton extends StatelessWidget {
  const WeekRailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return MovementSkeletonBox(
      width: double.infinity,
      height: MovementLayout.kWeekRailHeight,
      borderRadius: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            7,
            (index) => const MovementSkeletonBox(
              width: 48.0,
              height: 64.0,
              borderRadius: RitmoRadius.pill,
            ),
          ),
        ),
      ),
    );
  }
}

/// اسکلت کارت نمودار
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return MovementSkeletonBox(
      width: double.infinity,
      height: MovementLayout.kChartCardHeight,
      borderRadius: RitmoRadius.card,
      child: Padding(
        padding: const EdgeInsets.all(RitmoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MovementSkeletonBox(
              width: 160,
              height: 16,
              borderRadius: RitmoRadius.badge,
            ),
            const SizedBox(height: RitmoSpacing.sm),
            const MovementSkeletonBox(
              width: 90,
              height: 12,
              borderRadius: RitmoRadius.badge,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (i) => MovementSkeletonBox(
                  width: 24,
                  height: (40 + (i * 15)).toDouble(),
                  borderRadius: RitmoRadius.badge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// اسکلت ردیف لیست / ست قدرتی
class ListRowSkeleton extends StatelessWidget {
  const ListRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const MovementSkeletonBox(
      width: double.infinity,
      height: MovementLayout.kSetRowHeight,
      borderRadius: RitmoRadius.field,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: RitmoSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            MovementSkeletonBox(
              width: 32,
              height: 32,
              borderRadius: RitmoRadius.pill,
            ),
            MovementSkeletonBox(
              width: 100,
              height: 14,
              borderRadius: RitmoRadius.badge,
            ),
            MovementSkeletonBox(
              width: 80,
              height: 14,
              borderRadius: RitmoRadius.badge,
            ),
            MovementSkeletonBox(
              width: 32,
              height: 32,
              borderRadius: RitmoRadius.iconButton,
            ),
          ],
        ),
      ),
    );
  }
}

/// اسکلت عمومی کارت
class CardSkeleton extends StatelessWidget {
  const CardSkeleton({
    super.key,
    this.height = 120,
    this.width = double.infinity,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return MovementSkeletonBox(
      width: width,
      height: height,
      borderRadius: RitmoRadius.card,
    );
  }
}
