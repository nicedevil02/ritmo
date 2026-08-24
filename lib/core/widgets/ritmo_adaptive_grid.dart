import 'package:flutter/widgets.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// گریدی که شمار ستون را از عرض موجود می‌سازد و ارتفاع خانه را از محتوا (R-04).
/// جانشین مستقیم هر GridView با crossAxisCount و childAspectRatio ثابت.
class RitmoAdaptiveGrid extends StatelessWidget {
  const RitmoAdaptiveGrid({
    super.key,
    required this.children,
    this.minTileWidth,
    this.spacing = RitmoSpacing.md,
    this.runSpacing,
    this.maxColumns = 4,
  });

  final List<Widget> children;

  /// کمینه عرض هر خانه (پیش‌فرض بر اساس کلاس عرض دستگاه).
  final double? minTileWidth;

  /// فاصله افقی بین خانه‌ها.
  final double spacing;

  /// فاصله عمودی بین ردیف‌ها (پیش‌فرض برابر با spacing).
  final double? runSpacing;

  /// حداکثر تعداد ستون‌ها.
  final int maxColumns;

  static double defaultMinTileWidth(BuildContext context) {
    final baseWidth = switch (context.widthClass) {
      RitmoWidthClass.compact => RitmoBreakpoints.tileMinWidthCompact,
      RitmoWidthClass.regular => RitmoBreakpoints.tileMinWidthRegular,
      RitmoWidthClass.large => RitmoBreakpoints.tileMinWidthWide,
      RitmoWidthClass.expanded => RitmoBreakpoints.tileMinWidthWide,
    };
    final m = context.metrics;
    final textScale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.6);
    return baseWidth * m.densityFactor * (textScale > 1.0 ? textScale : 1.0);
  }

  /// سازنده کمکی برای ساختارهای SliverGrid با ابعاد پویا.
  static SliverGridDelegateWithMaxCrossAxisExtent sliverDelegate({
    required BuildContext context,
    double? maxCrossAxisExtent,
    double mainAxisExtent = 120.0,
    double crossAxisSpacing = RitmoSpacing.md,
    double mainAxisSpacing = RitmoSpacing.md,
  }) {
    final effectiveExtent = maxCrossAxisExtent ?? defaultMinTileWidth(context);
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: effectiveExtent,
      mainAxisExtent: mainAxisExtent,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale =
            MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.6);
        final baseMinWidth = minTileWidth ?? defaultMinTileWidth(context);
        final effectiveMinWidth = minTileWidth != null
            ? baseMinWidth *
                context.metrics.densityFactor *
                (textScale > 1.0 ? textScale : 1.0)
            : baseMinWidth;
        final effectiveSpacing =
            spacing == RitmoSpacing.md ? context.metrics.spaceMd : spacing;
        final effectiveRunSpacing = runSpacing ?? effectiveSpacing;
        final columns = RitmoBreakpoints.columnsFor(
          availableWidth: constraints.maxWidth,
          minTileWidth: effectiveMinWidth,
          spacing: effectiveSpacing,
          maxColumns: maxColumns,
        );
        final itemWidth =
            (constraints.maxWidth - effectiveSpacing * (columns - 1)) / columns;

        return Wrap(
          spacing: effectiveSpacing,
          runSpacing: effectiveRunSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}
