import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_chip.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_time_range.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

class TimelineItemCard extends StatelessWidget {
  const TimelineItemCard({
    super.key,
    required this.layoutItem,
    this.isHighlighted = false,
    this.isDraggable = false,
    this.isResizable = false,
    this.isDragging = false,
    this.isResizing = false,
    this.isGhost = false,
    this.isDimmed = false,
    this.displayTimeOverride,
    this.displayHeightOverride,
    this.onTap,
    this.onToggleComplete,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
  });

  final TimelineLayoutItem layoutItem;
  final bool isHighlighted;
  final bool isDraggable;
  final bool isResizable;
  final bool isDragging;
  final bool isResizing;
  final bool isGhost;
  final bool isDimmed;
  final String? displayTimeOverride;
  final double? displayHeightOverride;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;
  final GestureDragStartCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;
  final GestureDragEndCallback? onResizeEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = layoutItem.item;
    final isDone = item.isCompleted;

    final color = itemColor(context, item);

    final height = displayHeightOverride ?? layoutItem.height;
    final isCompact = height < 36.0;
    final isExpanded = height > 64.0;

    final cardOpacity = isDone
        ? 0.60
        : (isDimmed ? 0.30 : (isGhost ? 0.85 : 1.0));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(14);

    final startMin = layoutItem.startMinutes;
    final durMin = layoutItem.durationMinutes;

    final bgGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: isDone
          ? [
              (isDark ? colors.card : Colors.white).withValues(alpha: isDark ? 0.35 : 0.65),
              (isDark ? colors.card : Colors.white).withValues(alpha: isDark ? 0.20 : 0.45),
            ]
          : [
              color.withValues(alpha: isDark ? 0.26 : 0.16),
              (isDark ? const Color(0xFF1B2230) : Colors.white).withValues(alpha: isDark ? 0.95 : 0.98),
            ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Semantics(
        label:
            '${item.title}، ${item.timeOfDay ?? "بدون زمان"}، ${domainLabelFa(item.domain)}',
        child: Opacity(
          opacity: cardOpacity,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: SizedBox(
              height: height,
              child: AnimatedContainer(
                duration: RitmoMotion.press,
                curve: RitmoMotion.enter,
                decoration: BoxDecoration(
                  gradient: bgGradient,
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: isHighlighted
                        ? color
                        : (item.isEstimated
                              ? color.withValues(alpha: 0.45)
                              : (isDone
                                  ? (isDark ? Colors.white.withValues(alpha: 0.05) : colors.border.withValues(alpha: 0.3))
                                  : color.withValues(alpha: isDark ? 0.42 : 0.26))),
                    width: isHighlighted ? 2.0 : 0.9,
                  ),
                  boxShadow: [
                    if (isHighlighted)
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        offset: const Offset(0, 3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    else if (!isDone) ...[
                      BoxShadow(
                        color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                        offset: const Offset(0, 2.5),
                        blurRadius: 6,
                      ),
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : const Color(0xFFD0D7E2).withValues(alpha: 0.35),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    children: [
                      // Content layout by tier
                      Padding(
                        padding: EdgeInsets.only(
                          right: onToggleComplete != null ? 14.0 : 8.0,
                          left: 6.0,
                          top: isCompact ? 1.0 : (isHighlighted ? 2.0 : 3.0),
                          bottom: isCompact ? 1.0 : (isHighlighted ? 2.0 : 3.0),
                        ),
                        child: isCompact
                            ? Center(
                                child: _buildCompactTier(
                                  context,
                                  colors,
                                  color,
                                  isDone,
                                ),
                              )
                            : (isExpanded
                                  ? _buildExpandedTier(
                                      context,
                                      colors,
                                      color,
                                      isDone,
                                      startMin,
                                      durMin,
                                    )
                                  : _buildNormalTier(
                                      context,
                                      colors,
                                      color,
                                      isDone,
                                      startMin,
                                      durMin,
                                      height,
                                    )),
                      ),

                      // Single-day override indicator chip
                      if (item.hasOverride)
                        Positioned(
                          top: 2,
                          left: 2,
                          child: IgnorePointer(
                            child: Transform.scale(
                              scale: 0.8,
                              alignment: Alignment.topLeft,
                              child: const RitmoChip(
                                label: 'فقط امروز',
                                isSelected: true,
                              ),
                            ),
                          ),
                        ),

                      // Right accent bar (RTL) with touch target for completion
                      Positioned(
                        top: 0,
                        bottom: 0,
                        right: 0,
                        width: onToggleComplete != null ? 36.0 : 4.0,
                        child: GestureDetector(
                          key: ValueKey('toggle_complete_${item.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onToggleComplete != null
                              ? () {
                                  RitmoHapticsPolicy.success();
                                  onToggleComplete!();
                                }
                              : null,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 3.5,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: isDone ? colors.disabled : color,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(14),
                                  bottomRight: Radius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTier(
    BuildContext context,
    RitmoColors colors,
    Color color,
    bool isDone,
  ) {
    final item = layoutItem.item;
    return Row(
      children: [
        Icon(itemIcon(item), size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              toPersianDigits(item.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontFamily: 'Vazirmatn',
                decoration: isDone ? TextDecoration.lineThrough : null,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalTier(
    BuildContext context,
    RitmoColors colors,
    Color color,
    bool isDone,
    int startMin,
    int durMin,
    double height,
  ) {
    final item = layoutItem.item;
    final showTime = item.isTimed && height >= 50.0;
    return Row(
      children: [
        // 3D Sunken Icon Well
        RitmoNeuSurface(
          height: 22,
          width: 22,
          radius: 11,
          sunken: true,
          padding: EdgeInsets.zero,
          glowColor: color.withValues(alpha: 0.35),
          child: Center(
            child: Icon(itemIcon(item), size: 12, color: color),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  toPersianDigits(item.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.0,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Vazirmatn',
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (showTime)
                Flexible(
                  child: RitmoTimeRange(
                    startMinutes: startMin,
                    endMinutes: startMin + durMin,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'Vazirmatn',
                      color: colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedTier(
    BuildContext context,
    RitmoColors colors,
    Color color,
    bool isDone,
    int startMin,
    int durMin,
  ) {
    final item = layoutItem.item;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 3D Sunken Icon Well
        RitmoNeuSurface(
          height: 26,
          width: 26,
          radius: 13,
          sunken: true,
          padding: EdgeInsets.zero,
          glowColor: color.withValues(alpha: 0.40),
          child: Center(
            child: Icon(itemIcon(item), size: 14, color: color),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toPersianDigits(item.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.0,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Vazirmatn',
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              if (item.subtitle != null && item.subtitle!.isNotEmpty)
                Text(
                  toPersianDigits(item.subtitle ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontFamily: 'Vazirmatn',
                    color: colors.textTertiary,
                  ),
                ),
              const SizedBox(height: 2),
              if (item.isTimed)
                RitmoTimeRange(
                  startMinutes: startMin,
                  endMinutes: startMin + durMin,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontFamily: 'Vazirmatn',
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        if (onToggleComplete != null)
          GestureDetector(
            onTap: onToggleComplete,
            child: Icon(
              isDone ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              size: 18,
              color: isDone ? colors.success : colors.disabled,
            ),
          ),
      ],
    );
  }
}
