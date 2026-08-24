import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/logic/direct_manipulation_eligibility.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

class TimelineUntimedSection extends StatefulWidget {
  const TimelineUntimedSection({
    super.key,
    required this.untimedItems,
    this.onItemTap,
    this.onUnscheduleItem,
  });

  final List<AgendaItem> untimedItems;
  final ValueChanged<AgendaItem>? onItemTap;
  final ValueChanged<AgendaItem>? onUnscheduleItem;

  @override
  State<TimelineUntimedSection> createState() => _TimelineUntimedSectionState();
}

class _TimelineUntimedSectionState extends State<TimelineUntimedSection> {
  bool _isExpanded = false;

  void _toggleExpanded() {
    RitmoHapticsPolicy.selection();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final untimedItems = widget.untimedItems;

    return DragTarget<AgendaItem>(
      onWillAcceptWithDetails: (details) {
        return DirectManipulationEligibility.isUnschedulable(details.data);
      },
      onAcceptWithDetails: (details) {
        RitmoHapticsPolicy.success();
        widget.onUnscheduleItem?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        final hasUntimed = untimedItems.isNotEmpty;

        if (!hasUntimed && !isHovered) {
          return const SizedBox.shrink();
        }

        final canExpand = untimedItems.length > 2;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main Bordered Container
              AnimatedContainer(
                duration: RitmoMotion.state,
                curve: RitmoMotion.enter,
                margin: const EdgeInsets.only(
                  top: 9.0,
                  left: RitmoSpacing.lg,
                  right: RitmoSpacing.lg,
                  bottom: RitmoSpacing.xs,
                ),
                padding: const EdgeInsets.fromLTRB(8.0, 10.0, 8.0, 8.0),
                decoration: BoxDecoration(
                  color: isHovered
                      ? colorScheme.primaryContainer.withValues(alpha: 0.25)
                      : (isDark
                          ? theme.colorScheme.surfaceContainerHigh.withValues(
                              alpha: 0.20,
                            )
                          : theme.cardColor.withValues(alpha: 0.85)),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: isHovered
                        ? colorScheme.primary
                        : theme.dividerColor.withValues(alpha: 0.15),
                    width: isHovered ? 1.5 : 1.0,
                  ),
                ),
                child: AnimatedSize(
                  duration: RitmoMotion.state,
                  curve: RitmoMotion.enter,
                  alignment: Alignment.topRight,
                  child: _isExpanded
                      ? Wrap(
                          spacing: RitmoSpacing.sm,
                          runSpacing: RitmoSpacing.sm,
                          children: untimedItems
                              .map(
                                (item) => _buildChipItem(context, item, isDark),
                              )
                              .toList(),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: untimedItems
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(
                                      left: RitmoSpacing.sm,
                                    ),
                                    child: _buildChipItem(
                                      context,
                                      item,
                                      isDark,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ),
              ),

              // Notched Title Badge sitting directly on the top border line
              Positioned(
                top: 0,
                right: RitmoSpacing.xl + 4,
                child: GestureDetector(
                  onTap: canExpand ? _toggleExpanded : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: 1.0,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (theme.scaffoldBackgroundColor)
                          : (theme.cardColor),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isHovered
                              ? Icons.remove_circle_outline_rounded
                              : Icons.wb_sunny_outlined,
                          size: 13,
                          color: isHovered
                              ? colorScheme.primary
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isHovered
                              ? 'رها کنید برای لغو زمان‌بندی'
                              : 'بدون زمانبندی (${toPersianDigits(untimedItems.length.toString())})',
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w600,
                            color: isHovered
                                ? colorScheme.primary
                                : theme.textTheme.bodySmall?.color?.withValues(
                                    alpha: 0.75,
                                  ),
                          ),
                        ),
                        if (canExpand && !isHovered) ...[
                          const SizedBox(width: 2),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0.0,
                            duration: RitmoMotion.state,
                            curve: RitmoMotion.enter,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChipItem(BuildContext context, AgendaItem item, bool isDark) {
    final theme = Theme.of(context);
    final isDone = item.isCompleted;
    final color = domainColor(context, item.domain);
    final schedulable = DirectManipulationEligibility.isSchedulable(item);

    final chipWidget = InkWell(
      onTap: () => widget.onItemTap?.call(item),
      borderRadius: BorderRadius.circular(RitmoRadius.badge),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isDone
              ? theme.disabledColor.withValues(alpha: 0.12)
              : color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(RitmoRadius.badge),
          border: Border.all(
            color: color.withValues(alpha: isDone ? 0.2 : 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone ? theme.disabledColor : color,
              ),
            ),
            const SizedBox(width: RitmoSpacing.xs),
            if (isDone)
              Padding(
                padding: const EdgeInsets.only(left: 3.0),
                child: Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: isDone ? FontWeight.w400 : FontWeight.w600,
                color: isDone
                    ? theme.textTheme.bodySmall?.color?.withValues(alpha: 0.45)
                    : theme.textTheme.bodyLarge?.color,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );

    if (!schedulable) {
      return Opacity(
        opacity: 0.55,
        child: chipWidget,
      );
    }

    return LongPressDraggable<AgendaItem>(
      data: item,
      delay: const Duration(milliseconds: 300),
      hapticFeedbackOnStart: true,
      onDragStarted: () => RitmoHapticsPolicy.tap(),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(RitmoRadius.badge),
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.08,
          child: chipWidget,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: chipWidget,
      ),
      child: chipWidget,
    );
  }
}
