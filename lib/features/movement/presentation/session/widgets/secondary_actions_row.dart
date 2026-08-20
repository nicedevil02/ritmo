import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// ردیف اکشن‌های ثانویه جلسهٔ زنده
class SecondaryActionsRow extends StatelessWidget {
  const SecondaryActionsRow({
    super.key,
    this.leftAction,
    this.rightAction,
    this.centerAction,
  });

  final Widget? leftAction;
  final Widget? rightAction;
  final Widget? centerAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (leftAction != null)
            leftAction!
          else
            const SizedBox(width: 48, height: 48),
          if (centerAction != null) centerAction! else const SizedBox.shrink(),
          if (rightAction != null)
            rightAction!
          else
            const SizedBox(width: 48, height: 48),
        ],
      ),
    );
  }
}
