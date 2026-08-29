import 'package:flutter/material.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';

/// المان استخوانی پایه لودینگ با انیمیشن تنفس نوری نرم نئومورفیک.
class RitmoSkeleton extends StatefulWidget {
  const RitmoSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<RitmoSkeleton> createState() => _RitmoSkeletonState();
}

class _RitmoSkeletonState extends State<RitmoSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final opacity = _animation.value;
          final boneColor = isDark
              ? Colors.white.withValues(alpha: opacity * 0.09)
              : const Color(0xFFCAD4E2).withValues(alpha: opacity * 0.55);

          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              color: boneColor,
            ),
          );
        },
      ),
    );
  }
}

/// لیست اسکلت‌های نئومورفیک متصل به کارت‌های مرجع.
class RitmoSkeletonList extends StatelessWidget {
  const RitmoSkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: RitmoCardSkeleton(
            height: itemHeight,
            borderRadius: BorderRadius.circular(18),
          ),
        );
      },
    );
  }
}

/// کارت اسکلت لودینگ نئومورفیک متصل به کارت‌های مرجع ریتمو.
class RitmoSkeletonCard extends StatelessWidget {
  const RitmoSkeletonCard({
    super.key,
    this.height = 120,
    this.borderRadius,
  });

  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: RitmoCardSkeleton(
        height: height,
        borderRadius: borderRadius ?? BorderRadius.circular(22),
      ),
    );
  }
}

