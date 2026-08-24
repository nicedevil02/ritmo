import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

/// K20 — Agenda scale view: scrollable list bucketed by time proximity.
///
/// Layout rules (from 067.md §K20):
/// - CustomScrollView with SliverPersistentHeader for sticky bucket headers.
/// - Empty buckets are NOT rendered (no header, no empty space).
/// - Fixed row height from CalendarGeometry.agendaRowHeight to prevent scroll jitter.
/// - thisWeek/nextWeek/later group items under a Jalali day sub-heading.
/// - Completed items go to the bottom of their group with lineThrough style.
/// - K23: right→left swipe = postpone (task/goalStep only); left→right swipe = done.
class JourneyAgendaView extends StatefulWidget {
  const JourneyAgendaView({
    super.key,
    required this.rangeSnapshots,
    required this.now,
    required this.onItemTap,
    required this.onAddTap,
    this.isLoading = false,
    this.onPostponeItem,
    this.onDoneItem,
    this.errorMessage,
    this.agendaLoadStatus,
    this.onRetry,
    this.olderOverdueCount = 0,
    this.daysBack = 14,
    this.onExpandOverdue,
  });

  final Map<String, DayAgendaSnapshot> rangeSnapshots;
  final DateTime now;
  final void Function(AgendaItem item) onItemTap;
  final VoidCallback onAddTap;
  final bool isLoading;
  final Future<void> Function(AgendaItem item)? onPostponeItem;
  final Future<void> Function(AgendaItem item)? onDoneItem;
  final String? errorMessage;
  final AgendaLoadStatus? agendaLoadStatus;
  final VoidCallback? onRetry;
  final int olderOverdueCount;
  final int daysBack;
  final VoidCallback? onExpandOverdue;

  @override
  State<JourneyAgendaView> createState() => _JourneyAgendaViewState();
}

class _JourneyAgendaViewState extends State<JourneyAgendaView> {
  final Set<String> _expandedSeriesKeys = <String>{};
  bool _isOverdueCollapsed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(RitmoSpacing.md),
        child: RitmoSkeletonList(itemCount: 6, itemHeight: CalendarGeometry.agendaRowHeight),
      );
    }

    final bucketed = bucketRange(widget.rangeSnapshots, now: widget.now);

    // Filter to non-empty buckets only
    final activeBuckets = AgendaBucket.values
        .where((b) => bucketed[b]?.isNotEmpty ?? false)
        .toList();

    final status = widget.agendaLoadStatus;
    final hasFailure = status != null && status.hasFailure;

    if (activeBuckets.isEmpty) {
      if (hasFailure) {
        return _AgendaFailureCard(
          failedSources: status.failedSources,
          isFatal: status.fatal,
          onRetry: widget.onRetry,
        );
      }
      return _EmptyAgendaState(onAddTap: widget.onAddTap);
    }

    final compressEnabled = SettingsService.instance.get<bool>('calendar_compress_recurring');

    // Find 2-3 closest incomplete unique items for the "Upcoming Unique Banner"
    final upcomingUniques = _findUpcomingUniqueItems(bucketed);

    // Build sliver list
    final slivers = <Widget>[];

    // 1. Upcoming Unique Banner at top (if banner has items)
    if (upcomingUniques.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: _UpcomingUniqueBanner(
          items: upcomingUniques,
          onItemTap: widget.onItemTap,
        ),
      ));
    }

    // 2. Bucket slivers
    for (final bucket in activeBuckets) {
      final items = bucketed[bucket]!;
      final isOverdueBucket = bucket == AgendaBucket.overdue;
      final isCollapsed = isOverdueBucket && _isOverdueCollapsed;

      final shouldCompress = compressEnabled &&
          (bucket == AgendaBucket.thisWeek ||
           bucket == AgendaBucket.nextWeek ||
           bucket == AgendaBucket.later);

      if (shouldCompress) {
        final daysInBucket = calculateDaysInBucket(bucket, now: widget.now, items: items);
        final entries = collapseRecurringSeries(items, daysInBucket: daysInBucket);

        final singles = entries.whereType<AgendaSingle>().map((e) => e.item).toList();
        final seriesList = entries.whereType<AgendaSeries>().toList();

        final countText = _formatUnitCountText(singles.length, seriesList.length, items.length);

        slivers.add(_BucketHeaderSliver(
          bucket: bucket,
          countText: countText,
          isOverdue: isOverdueBucket,
          isCollapsible: isOverdueBucket,
          isCollapsed: isCollapsed,
          onToggleCollapse: isOverdueBucket
              ? () => setState(() => _isOverdueCollapsed = !_isOverdueCollapsed)
              : null,
        ));

        if (!isCollapsed) {
          // Render Singles grouped by date
          if (singles.isNotEmpty) {
            final groupedSingles = groupByDate(singles);
            final sortedDates = groupedSingles.keys.toList()..sort();
            for (final dateStr in sortedDates) {
              final dayItems = _sortItems(groupedSingles[dateStr]!);
              slivers.add(_DaySubGroupHeader(dateStr: dateStr));
              slivers.add(_ItemsSliver(
                items: dayItems,
                onItemTap: widget.onItemTap,
                onPostponeItem: widget.onPostponeItem,
                onDoneItem: widget.onDoneItem,
              ));
            }
          }

          // Render Series groups
          if (seriesList.isNotEmpty) {
            slivers.add(SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    RitmoSpacing.xl, RitmoSpacing.md, RitmoSpacing.xl, 4),
                child: Text(
                  'تکرارهای ثابت (${toPersianDigits(seriesList.length)})',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ));

            for (final series in seriesList) {
              final seriesKey = series.representative.recurrenceKey;
              final isExpanded = _expandedSeriesKeys.contains(seriesKey);

              slivers.add(SliverToBoxAdapter(
                child: _RecurringGroupRow(
                  key: ValueKey('series_$seriesKey'),
                  series: series,
                  isExpanded: isExpanded,
                  onToggleExpand: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedSeriesKeys.remove(seriesKey);
                      } else {
                        _expandedSeriesKeys.add(seriesKey);
                      }
                    });
                  },
                  onItemTap: widget.onItemTap,
                  onPostponeItem: widget.onPostponeItem,
                  onDoneItem: widget.onDoneItem,
                ),
              ));
            }
          }
        }
      } else {
        // Normal uncompressed bucket rendering
        slivers.add(_BucketHeaderSliver(
          bucket: bucket,
          countText: toPersianDigits(items.length),
          isOverdue: isOverdueBucket,
          isCollapsible: isOverdueBucket,
          isCollapsed: isCollapsed,
          onToggleCollapse: isOverdueBucket
              ? () => setState(() => _isOverdueCollapsed = !_isOverdueCollapsed)
              : null,
        ));

        if (!isCollapsed) {
          final needsSubGroups = bucket == AgendaBucket.thisWeek ||
              bucket == AgendaBucket.nextWeek ||
              bucket == AgendaBucket.later;

          if (needsSubGroups) {
            final grouped = groupByDate(items);
            final sortedDates = grouped.keys.toList()..sort();
            for (final dateStr in sortedDates) {
              final dayItems = _sortItems(grouped[dateStr]!);
              slivers.add(_DaySubGroupHeader(dateStr: dateStr));
              slivers.add(_ItemsSliver(
                items: dayItems,
                onItemTap: widget.onItemTap,
                onPostponeItem: widget.onPostponeItem,
                onDoneItem: widget.onDoneItem,
              ));
            }
          } else {
            final sorted = _sortItems(items);
            slivers.add(_ItemsSliver(
              items: sorted,
              onItemTap: widget.onItemTap,
              onPostponeItem: widget.onPostponeItem,
              onDoneItem: widget.onDoneItem,
            ));
          }
        }
      }

      // Display older overdue expansion banner if historical overdue items exist outside window and not collapsed
      if (bucket == AgendaBucket.overdue && widget.olderOverdueCount > 0 && !isCollapsed) {
        slivers.add(SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: RitmoSpacing.xl, vertical: RitmoSpacing.sm),
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${toPersianDigits(widget.olderOverdueCount)} مورد قدیمی‌تر از ${toPersianDigits(widget.daysBack)} روز',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                if (widget.onExpandOverdue != null)
                  TextButton(
                    onPressed: widget.onExpandOverdue,
                    child: const Text('نمایش همه'),
                  ),
              ],
            ),
          ),
        ));
      }
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: slivers,
    );
  }

  String _formatUnitCountText(int singlesCount, int seriesCount, int totalItems) {
    if (seriesCount > 0 && singlesCount > 0) {
      return '${toPersianDigits(singlesCount)} کار یکتا + ${toPersianDigits(seriesCount)} تکرار';
    } else if (seriesCount > 0 && singlesCount == 0) {
      return '${toPersianDigits(seriesCount)} تکرار';
    } else {
      return toPersianDigits(totalItems);
    }
  }

  /// Collects up to 2-3 closest incomplete unique items from active buckets
  List<AgendaItem> _findUpcomingUniqueItems(Map<AgendaBucket, List<AgendaItem>> bucketed) {
    final futureBuckets = [
      AgendaBucket.today,
      AgendaBucket.tomorrow,
      AgendaBucket.thisWeek,
      AgendaBucket.nextWeek,
      AgendaBucket.later,
    ];

    final allFutureItems = <AgendaItem>[];
    for (final b in futureBuckets) {
      if (bucketed[b] != null) {
        allFutureItems.addAll(bucketed[b]!);
      }
    }

    final keyCounts = <String, int>{};
    for (final item in allFutureItems) {
      keyCounts[item.recurrenceKey] = (keyCounts[item.recurrenceKey] ?? 0) + 1;
    }

    final uniques = allFutureItems.where((i) {
      if (i.isCompleted) return false;
      final cnt = keyCounts[i.recurrenceKey] ?? 0;
      return cnt < 3;
    }).toList();

    uniques.sort((a, b) {
      final dateCmp = a.dateStr.compareTo(b.dateStr);
      if (dateCmp != 0) return dateCmp;
      return (a.timeOfDay ?? '').compareTo(b.timeOfDay ?? '');
    });

    return uniques.take(3).toList();
  }

  /// Sort: timed items by time, then untimed by priority descending.
  /// Done/skipped always last within their group.
  List<AgendaItem> _sortItems(List<AgendaItem> items) {
    final undone = items
        .where((i) =>
            i.completion != AgendaCompletion.done &&
            i.completion != AgendaCompletion.skipped)
        .toList();
    final done = items
        .where((i) =>
            i.completion == AgendaCompletion.done ||
            i.completion == AgendaCompletion.skipped)
        .toList();

    int compareUndone(AgendaItem a, AgendaItem b) {
      final aHasTime = a.isTimed;
      final bHasTime = b.isTimed;
      if (aHasTime && bHasTime) {
        return (a.timeOfDay ?? '').compareTo(b.timeOfDay ?? '');
      } else if (aHasTime) {
        return -1;
      } else if (bHasTime) {
        return 1;
      }
      return b.priority.compareTo(a.priority);
    }

    undone.sort(compareUndone);
    return [...undone, ...done];
  }
}

// ────────────────────────────────────────────────────────────
// Bucket Header Sliver (sticky)
// ────────────────────────────────────────────────────────────

class _BucketHeaderSliver extends StatelessWidget {
  const _BucketHeaderSliver({
    required this.bucket,
    required this.countText,
    required this.isOverdue,
    this.isCollapsible = false,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final AgendaBucket bucket;
  final String countText;
  final bool isOverdue;
  final bool isCollapsible;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _StickyHeaderDelegate(
        bucket: bucket,
        countText: countText,
        isOverdue: isOverdue,
        isCollapsible: isCollapsible,
        isCollapsed: isCollapsed,
        onToggleCollapse: onToggleCollapse,
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyHeaderDelegate({
    required this.bucket,
    required this.countText,
    required this.isOverdue,
    this.isCollapsible = false,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final AgendaBucket bucket;
  final String countText;
  final bool isOverdue;
  final bool isCollapsible;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  @override
  double get minExtent => CalendarGeometry.agendaBucketHeaderHeight;
  @override
  double get maxExtent => CalendarGeometry.agendaBucketHeaderHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final labelColor = isOverdue
        ? context.colors.warning
        : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: InkWell(
        onTap: isCollapsible ? onToggleCollapse : null,
        child: Container(
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.xl,
            vertical: RitmoSpacing.xs,
          ),
          child: Row(
            children: [
              Text(
                bucketLabelFa(bucket),
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: (isOverdue ? context.colors.warning : theme.colorScheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                ),
                child: Text(
                  countText,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: isOverdue ? context.colors.warning : theme.colorScheme.primary,
                  ),
                ),
              ),
              if (isCollapsible) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isOverdue ? context.colors.warning : theme.colorScheme.primary)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(RitmoRadius.chip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCollapsed ? 'نمایش' : 'جمع‌کردن',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: isOverdue ? context.colors.warning : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isCollapsed
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        size: 16,
                        color: isOverdue ? context.colors.warning : theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) =>
      oldDelegate.bucket != bucket ||
      oldDelegate.countText != countText ||
      oldDelegate.isOverdue != isOverdue ||
      oldDelegate.isCollapsible != isCollapsible ||
      oldDelegate.isCollapsed != isCollapsed;
}

// ────────────────────────────────────────────────────────────
// Upcoming Unique Banner
// ────────────────────────────────────────────────────────────

class _UpcomingUniqueBanner extends StatelessWidget {
  const _UpcomingUniqueBanner({
    required this.items,
    required this.onItemTap,
  });

  final List<AgendaItem> items;
  final void Function(AgendaItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        RitmoSpacing.xl,
        RitmoSpacing.md,
        RitmoSpacing.xl,
        RitmoSpacing.sm,
      ),
      padding: const EdgeInsets.all(RitmoSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_added_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'پیش‌رو (کارهای یکتا)',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: items.map((item) {
              final iconColor = domainIconColor(context, item.domain);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: InkWell(
                  onTap: () => onItemTap(item),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: iconColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(RitmoRadius.badge),
                          ),
                          child: Text(
                            daySubGroupLabel(item.dateStr),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Recurring Group Row
// ────────────────────────────────────────────────────────────

class _RecurringGroupRow extends StatelessWidget {
  const _RecurringGroupRow({
    super.key,
    required this.series,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onItemTap,
    this.onPostponeItem,
    this.onDoneItem,
  });

  final AgendaSeries series;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final void Function(AgendaItem) onItemTap;
  final Future<void> Function(AgendaItem)? onPostponeItem;
  final Future<void> Function(AgendaItem)? onDoneItem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rep = series.representative;
    final color = domainColor(context, rep.domain);
    final iconColor = domainIconColor(context, rep.domain);
    final icon = domainIcon(rep.domain);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.xl,
        vertical: 3,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          side: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RitmoSpacing.md,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Domain Icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: iconColor),
                    ),
                    const SizedBox(width: RitmoSpacing.sm),

                    // Title + Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rep.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                          if (series.completedCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${toPersianDigits(series.completedCount)} از ${toPersianDigits(series.totalCount)} انجام شد',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Time label if timed
                    if (rep.isTimed && rep.timeOfDay != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          toPersianDigits(rep.timeOfDay ?? ''),
                          style: TextStyle(
                            fontSize: 12.0,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
                          ),
                        ),
                      ),

                    // Recurrence Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(RitmoRadius.badge),
                      ),
                      child: Text(
                        series.recurrenceLabel,
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Expand / Collapse Chevron
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded Child Instances List
            if (isExpanded) ...[
              Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.3)),
              Column(
                children: series.instances.map((inst) {
                  final onPostpone = onPostponeItem;
                  final onDone = onDoneItem;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: Text(
                          daySubGroupLabel(inst.dateStr),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      _AgendaRow(
                        item: inst,
                        onTap: () => onItemTap(inst),
                        onPostpone: onPostpone != null ? () => onPostpone(inst) : null,
                        onDone: onDone != null ? () => onDone(inst) : null,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// ────────────────────────────────────────────────────────────
// Day Sub-Group Header (non-sticky)
// ────────────────────────────────────────────────────────────

class _DaySubGroupHeader extends StatelessWidget {
  const _DaySubGroupHeader({required this.dateStr});
  final String dateStr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            RitmoSpacing.xl, RitmoSpacing.sm, RitmoSpacing.xl, 2),
        child: Text(
          daySubGroupLabel(dateStr),
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Items Sliver — K23 swipe gestures embedded
// ────────────────────────────────────────────────────────────

class _ItemsSliver extends StatelessWidget {
  const _ItemsSliver({
    required this.items,
    required this.onItemTap,
    this.onPostponeItem,
    this.onDoneItem,
  });

  final List<AgendaItem> items;
  final void Function(AgendaItem) onItemTap;
  final Future<void> Function(AgendaItem)? onPostponeItem;
  final Future<void> Function(AgendaItem)? onDoneItem;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _AgendaRow(
          item: items[i],
          onTap: () => onItemTap(items[i]),
          onPostpone: onPostponeItem != null ? () => onPostponeItem!(items[i]) : null,
          onDone: onDoneItem != null ? () => onDoneItem!(items[i]) : null,
        ),
        childCount: items.length,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Single Agenda Row — K23 Dismissible swipe
// ────────────────────────────────────────────────────────────

class _AgendaRow extends StatefulWidget {
  const _AgendaRow({
    required this.item,
    required this.onTap,
    this.onPostpone,
    this.onDone,
  });

  final AgendaItem item;
  final VoidCallback onTap;
  final Future<void> Function()? onPostpone;
  final Future<void> Function()? onDone;

  @override
  State<_AgendaRow> createState() => _AgendaRowState();
}

class _AgendaRowState extends State<_AgendaRow> {
  /// K23: Only task and goalStep support right→left postpone.
  bool get _canPostpone =>
      widget.item.domain == AgendaDomain.task ||
      widget.item.domain == AgendaDomain.goalStep;

  bool get _isDone =>
      widget.item.completion == AgendaCompletion.done ||
      widget.item.completion == AgendaCompletion.skipped;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final item = widget.item;
    final color = domainColor(context, item.domain);
    final iconColor = domainIconColor(context, item.domain);
    final icon = domainIcon(item.domain);
    final isDone = _isDone;

    final Widget row = SizedBox(
      height: CalendarGeometry.agendaRowHeight,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.xl,
            vertical: RitmoSpacing.xs,
          ),
          child: Row(
            children: [
              // Domain icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDone ? 0.06 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 16,
                    color: iconColor.withValues(alpha: isDone ? 0.4 : 1.0)),
              ),
              const SizedBox(width: RitmoSpacing.sm),

              // Title + subtitle
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: isDone
                            ? theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.35)
                            : theme.textTheme.bodyMedium?.color,
                        decoration:
                            isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty)
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: isDone ? 0.25 : 0.5),
                        ),
                      ),
                  ],
                ),
              ),

              // Time label if timed
              if (item.isTimed && item.timeOfDay != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    toPersianDigits(item.timeOfDay ?? ''),
                    style: TextStyle(
                      fontSize: 12.0,
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: isDone ? 0.25 : 0.55),
                    ),
                  ),
                ),

              // Importance star — task domain only
              if (item.domain == AgendaDomain.task &&
                  item.meta['isImportant'] == 1)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.star_rounded,
                      size: 16,
                      color: theme.colorScheme.primary.withValues(
                          alpha: isDone ? 0.25 : 0.75)),
                ),
            ],
          ),
        ),
      ),
    );

    // K23 — wrap in Dismissible for swipe gestures
    return Dismissible(
      key: ValueKey(item.id),
      direction: _canPostpone ? DismissDirection.horizontal : DismissDirection.startToEnd,
      // Left→right: mark done (all domains)
      background: _SwipeBackground(
        color: colors.success,
        icon: Icons.check_rounded,
        alignment: AlignmentDirectional.centerStart,
        label: 'انجام شد',
      ),
      // Right→left: postpone (task/goalStep only); disabled when !_canPostpone
      secondaryBackground: _SwipeBackground(
        color: _canPostpone ? colors.accent : Colors.transparent,
        icon: _canPostpone ? Icons.schedule_rounded : null,
        alignment: AlignmentDirectional.centerEnd,
        label: _canPostpone ? 'فردا' : '',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Done swipe
          RitmoHapticsPolicy.tap();
          if (widget.onDone != null) await widget.onDone!();
          return false; // parent refreshes via event; don't remove from list directly
        } else {
          // Postpone swipe
          if (!_canPostpone) {
            // Snap back — routines cannot be postponed
            return false;
          }
          RitmoHapticsPolicy.tap();
          if (widget.onPostpone != null) await widget.onPostpone!();
          return false;
        }
      },
      child: row,
    );
  }
}

// ────────────────────────────────────────────────────────────
// Swipe Background
// ────────────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    this.icon,
    required this.alignment,
    required this.label,
  });

  final Color color;
  final IconData? icon;
  final AlignmentGeometry alignment;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox.shrink();
    return Container(
      color: color.withValues(alpha: 0.15),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.xl),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Empty Agenda State — K20 rule + K25 rule (3 action buttons)
// ────────────────────────────────────────────────────────────

class _EmptyAgendaState extends StatelessWidget {
  const _EmptyAgendaState({required this.onAddTap});
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'برنامه‌ای در بازه پیش‌رو ثبت نشده.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.0,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            _ActionButton(
              label: 'افزودن برنامه',
              icon: Icons.add_rounded,
              onTap: onAddTap,
              isPrimary: true,
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'رفتن به نمای روز',
              icon: Icons.today_rounded,
              onTap: () {}, // Caller handles via onItemTap flow
            ),
            const SizedBox(height: 10),
            _ActionButton(
              label: 'نمای ماه',
              icon: Icons.calendar_month_rounded,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isPrimary
              ? theme.colorScheme.primary
              : theme.textTheme.bodyMedium?.color,
          side: BorderSide(
            color: isPrimary
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : theme.dividerColor,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RitmoRadius.card),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Agenda Failure Card — T4 (shown instead of silent empty state)
// ────────────────────────────────────────────────────────────

class _AgendaFailureCard extends StatelessWidget {
  const _AgendaFailureCard({
    required this.failedSources,
    required this.isFatal,
    this.onRetry,
  });

  final List<String> failedSources;
  final bool isFatal;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'بارگذاری برنامه‌ها ناقص بود',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'بخشی از داده‌ها بارگذاری نشد. دوباره تلاش کن.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.0,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
              ),
            ),
            if (kDebugMode && failedSources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(RitmoRadius.card),
                ),
                child: Text(
                  'منابع خراب: ${failedSources.join(', ')}',
                  style: TextStyle(
                    fontSize: 11.0,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (onRetry != null)
              _ActionButton(
                label: 'تلاش مجدد',
                icon: Icons.refresh_rounded,
                onTap: onRetry!,
                isPrimary: true,
              ),
          ],
        ),
      ),
    );
  }
}
