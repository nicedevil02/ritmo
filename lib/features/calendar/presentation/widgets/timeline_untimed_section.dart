import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/calendar/presentation/logic/direct_manipulation_eligibility.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

class TimelineUntimedSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DragTarget<AgendaItem>(
      onWillAcceptWithDetails: (details) {
        return DirectManipulationEligibility.isUnschedulable(details.data);
      },
      onAcceptWithDetails: (details) {
        RitmoHapticsPolicy.success();
        onUnscheduleItem?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        final hasUntimed = untimedItems.isNotEmpty;

        if (!hasUntimed && !isHovered) {
          return const SizedBox.shrink();
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AnimatedContainer(
            duration: RitmoMotion.state,
            curve: RitmoMotion.enter,
            margin: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.lg,
              vertical: RitmoSpacing.sm,
            ),
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              color: isHovered
                  ? colorScheme.primaryContainer.withValues(alpha: 0.25)
                  : (isDark
                      ? theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.22)
                      : theme.cardColor.withValues(alpha: 0.85)),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: isHovered
                    ? colorScheme.primary
                    : theme.dividerColor.withValues(alpha: 0.12),
                width: isHovered ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isHovered ? Icons.remove_circle_outline_rounded : Icons.wb_sunny_outlined,
                      size: 16,
                      color: isHovered ? colorScheme.primary : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: RitmoSpacing.sm),
                    Text(
                      isHovered
                          ? 'اینجا رها کن تا از زمان‌بندی خارج شود'
                          : 'بدون زمانبندی (${toPersianDigits(untimedItems.length.toString())})',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: isHovered
                            ? colorScheme.primary
                            : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                if (hasUntimed) ...[
                  const SizedBox(height: RitmoSpacing.sm),
                  Wrap(
                    spacing: RitmoSpacing.sm,
                    runSpacing: RitmoSpacing.sm,
                    children: untimedItems.map((item) => _buildChipItem(context, item, isDark)).toList(),
                  ),
                ],
              ],
            ),
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
      onTap: () => onItemTap?.call(item),
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
