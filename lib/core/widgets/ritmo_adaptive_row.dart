import 'package:flutter/widgets.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// ردیفی که وقتی عرض کم می‌آید یا مقیاس متن بزرگ است، به چیدمان عمودی می‌ریزد (R-05).
/// جانشین هر Row که دو بلوک متنی یا عنصر کنار هم دارد.
class RitmoAdaptiveRow extends StatelessWidget {
  const RitmoAdaptiveRow({
    super.key,
    required this.primary,
    required this.secondary,
    this.minWidthForRow = 280.0,
    this.spacing = RitmoSpacing.sm,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.expandSecondary = false,
  });

  final Widget primary;
  final Widget secondary;
  final double minWidthForRow;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;
  final bool expandSecondary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = context.metrics;
        final effectiveMinWidth =
            minWidthForRow * m.densityFactor * (context.textScale > 1.0 ? context.textScale : 1.0);
        final canUseRow =
            constraints.maxWidth >= effectiveMinWidth && !context.isLargeTextScale;
        if (canUseRow) {
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              Expanded(child: primary),
              SizedBox(width: spacing),
              expandSecondary ? Expanded(child: secondary) : secondary,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              primary,
              SizedBox(height: spacing),
              secondary,
            ],
          );
        }
      },
    );
  }
}
