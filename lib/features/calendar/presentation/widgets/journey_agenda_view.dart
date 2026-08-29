import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/calendar/presentation/logic/agenda_bucketing.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

/// K20 — Agenda scale view: scrollable list bucketed by time proximity.
///
/// ارتقایافته به سیستم کارت‌های مرجع نئومورفیک ریتمو:
/// - کارت‌های مجتمع برای هر روز (Grouped Day Cards)
/// - آیکون‌های فرورفتهٔ سه‌بعدی نئومورفیک با رنگ‌های دامنه‌ای (Sunken Wells)
/// - دکمهٔ تیک و ثبت سریع تعاملی (Quick Complete) با فیدبک لمسی
/// - تفکیک دیداری کارهای انجام‌شده
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
      return Padding(
        padding: const EdgeInsets.all(RitmoSpacing.md),
        child: RitmoSkeletonList(
          itemCount: 6,
          itemHeight: CalendarGeometry.effectiveAgendaRowHeight(context),
        ),
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

    final compressEnabled = SettingsService.instance.get<bool>(
      'calendar_compress_recurring',
    );

    // Find 2-3 closest incomplete unique items for the "Upcoming Unique Banner"
    final upcomingUniques = _findUpcomingUniqueItems(bucketed);

    // Build sliver list
    final slivers = <Widget>[];

    // 1. Upcoming Unique Banner at top (if banner has items)
    if (upcomingUniques.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: _UpcomingUniqueBanner(
            items: upcomingUniques,
            onItemTap: widget.onItemTap,
          ),
        ),
      );
    }

    // 2. Bucket slivers
    for (final bucket in activeBuckets) {
      final items = bucketed[bucket]!;
      final isOverdueBucket = bucket == AgendaBucket.overdue;
      final isCollapsed = isOverdueBucket && _isOverdueCollapsed;

      final shouldCompress =
          compressEnabled &&
          (bucket == AgendaBucket.thisWeek ||
              bucket == AgendaBucket.nextWeek ||
              bucket == AgendaBucket.later);

      if (shouldCompress) {
        final daysInBucket = calculateDaysInBucket(
          bucket,
          now: widget.now,
          items: items,
        );
        final entries = collapseRecurringSeries(
          items,
          daysInBucket: daysInBucket,
        );

        final singles = entries
            .whereType<AgendaSingle>()
            .map((e) => e.item)
            .toList();
        final seriesList = entries.whereType<AgendaSeries>().toList();

        final countText = _formatUnitCountText(
          singles.length,
          seriesList.length,
          items.length,
        );

        slivers.add(
          _BucketHeaderSliver(
            bucket: bucket,
            countText: countText,
            isOverdue: isOverdueBucket,
            isCollapsible: isOverdueBucket,
            isCollapsed: isCollapsed,
            onToggleCollapse: isOverdueBucket
                ? () =>
                      setState(() => _isOverdueCollapsed = !_isOverdueCollapsed)
                : null,
          ),
        );

        if (!isCollapsed) {
          // Render Singles grouped by date
          if (singles.isNotEmpty) {
            final groupedSingles = groupByDate(singles);
            final sortedDates = groupedSingles.keys.toList()..sort();
            for (final dateStr in sortedDates) {
              final dayItems = _sortItems(groupedSingles[dateStr]!);
              slivers.add(
                _ItemsSliver(
                  title: daySubGroupLabel(dateStr),
                  items: dayItems,
                  onItemTap: widget.onItemTap,
                  onPostponeItem: widget.onPostponeItem,
                  onDoneItem: widget.onDoneItem,
                ),
              );
            }
          }

          // Render Series groups
          if (seriesList.isNotEmpty) {
            slivers.add(
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RitmoSpacing.xl,
                    RitmoSpacing.md,
                    RitmoSpacing.xl,
                    4,
                  ),
                  child: Text(
                    'تکرارهای ثابت (${toPersianDigits(seriesList.length)})',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            );

            for (final series in seriesList) {
              final seriesKey = series.representative.recurrenceKey;
              final isExpanded = _expandedSeriesKeys.contains(seriesKey);

              slivers.add(
                SliverToBoxAdapter(
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
                ),
              );
            }
          }
        }
      } else {
        // Normal uncompressed bucket rendering
        final needsSubGroups =
            bucket == AgendaBucket.thisWeek ||
            bucket == AgendaBucket.nextWeek ||
            bucket == AgendaBucket.later;

        if (needsSubGroups) {
          slivers.add(
            _BucketHeaderSliver(
              bucket: bucket,
              countText: toPersianDigits(items.length),
              isOverdue: isOverdueBucket,
              isCollapsible: isOverdueBucket,
              isCollapsed: isCollapsed,
              onToggleCollapse: isOverdueBucket
                  ? () =>
                        setState(() => _isOverdueCollapsed = !_isOverdueCollapsed)
                  : null,
            ),
          );

          if (!isCollapsed) {
            final grouped = groupByDate(items);
            final sortedDates = grouped.keys.toList()..sort();
            for (final dateStr in sortedDates) {
              final dayItems = _sortItems(grouped[dateStr]!);
              slivers.add(
                _ItemsSliver(
                  title: daySubGroupLabel(dateStr),
                  items: dayItems,
                  onItemTap: widget.onItemTap,
                  onPostponeItem: widget.onPostponeItem,
                  onDoneItem: widget.onDoneItem,
                ),
              );
            }
          }
        } else {
          final sorted = _sortItems(items);
          slivers.add(
            _ItemsSliver(
              title: bucketLabelFa(bucket),
              isOverdue: isOverdueBucket,
              items: sorted,
              onItemTap: widget.onItemTap,
              onPostponeItem: widget.onPostponeItem,
              onDoneItem: widget.onDoneItem,
            ),
          );
        }
      }

      // Display older overdue expansion banner if historical overdue items exist outside window and not collapsed
      if (bucket == AgendaBucket.overdue &&
          widget.olderOverdueCount > 0 &&
          !isCollapsed) {
        slivers.add(
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(
                horizontal: RitmoSpacing.xl,
                vertical: RitmoSpacing.sm,
              ),
              padding: const EdgeInsets.all(RitmoSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(RitmoRadius.card),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.2),
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
          ),
        );
      }
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: slivers,
    );
  }

  String _formatUnitCountText(
    int singlesCount,
    int seriesCount,
    int totalItems,
  ) {
    if (seriesCount > 0 && singlesCount > 0) {
      return '${toPersianDigits(singlesCount)} کار یکتا + ${toPersianDigits(seriesCount)} تکرار';
    } else if (seriesCount > 0 && singlesCount == 0) {
      return '${toPersianDigits(seriesCount)} تکرار';
    } else {
      return toPersianDigits(totalItems);
    }
  }

  /// Collects up to 2-3 closest incomplete unique items from active buckets
  List<AgendaItem> _findUpcomingUniqueItems(
    Map<AgendaBucket, List<AgendaItem>> bucketed,
  ) {
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
      if (i.domain == AgendaDomain.cycle) return false;
      if (i.kind == AgendaItemKind.reminder) return false;
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
        .where(
          (i) =>
              i.completion != AgendaCompletion.done &&
              i.completion != AgendaCompletion.skipped,
        )
        .toList();
    final done = items
        .where(
          (i) =>
              i.completion == AgendaCompletion.done ||
              i.completion == AgendaCompletion.skipped,
        )
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
        headerHeight: CalendarGeometry.effectiveAgendaBucketHeaderHeight(context),
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StickyHeaderDelegate({
    required this.bucket,
    required this.countText,
    required this.isOverdue,
    required this.headerHeight,
    this.isCollapsible = false,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  final AgendaBucket bucket;
  final String countText;
  final bool isOverdue;
  final double headerHeight;
  final bool isCollapsible;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  @override
  double get minExtent => headerHeight;
  @override
  double get maxExtent => headerHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = context.colors;
    final labelColor = isOverdue ? colors.warning : colors.textPrimary;
    final accentColor = isOverdue ? colors.warning : colors.primary;

    return Material(
      color: colors.background,
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
                style: RitmoTextStyles.caption(
                  labelColor,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                ),
                child: Text(
                  countText,
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
              if (isCollapsible) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
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
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isCollapsed
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        size: 16,
                        color: accentColor,
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
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => true;
}

// ────────────────────────────────────────────────────────────
// Upcoming Unique Banner
// ────────────────────────────────────────────────────────────

class _UpcomingUniqueBanner extends StatelessWidget {
  const _UpcomingUniqueBanner({required this.items, required this.onItemTap});

  final List<AgendaItem> items;
  final void Function(AgendaItem) onItemTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const bannerAccent = Color(0xFFF59E0B);
    final radius = BorderRadius.circular(20);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RitmoSpacing.md,
        RitmoSpacing.sm,
        RitmoSpacing.md,
        RitmoSpacing.xs,
      ),
      child: RitmoCard.neumorphic(
        borderRadius: radius,
        backgroundColor: Color.lerp(
          isDark ? colors.card : Colors.white,
          bannerAccent,
          isDark ? 0.18 : 0.09,
        ),
        borderColor: bannerAccent.withValues(alpha: isDark ? 0.38 : 0.25),
        borderWidth: 1.2,
        customShadows: [
          ...RitmoNeu.raisedShadows(isDark, blur: 12, distance: 4),
          BoxShadow(
            color: bannerAccent.withValues(alpha: isDark ? 0.20 : 0.12),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
        ],
        padding: EdgeInsets.zero,
        enableSpring: false,
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  bannerAccent.withValues(alpha: isDark ? 0.25 : 0.14),
                  (isDark ? colors.card : Colors.white)
                      .withValues(alpha: isDark ? 0.45 : 0.85),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      RitmoNeuSurface(
                        height: 32,
                        width: 32,
                        radius: 16,
                        sunken: true,
                        padding: EdgeInsets.zero,
                        glowColor: bannerAccent.withValues(alpha: 0.45),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.bookmark_fill,
                            size: 15,
                            color: bannerAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'پیش‌رو (کارهای یکتا)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Vazirmatn',
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const RitmoCardDivider(margin: EdgeInsets.symmetric(vertical: 4)),
                  Column(
                    children: items.map((item) {
                      final iconColor = itemColor(context, item);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: InkWell(
                          onTap: () => onItemTap(item),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 3,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: iconColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: iconColor.withValues(alpha: 0.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    toPersianDigits(item.title),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Vazirmatn',
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(
                                      RitmoRadius.badge,
                                    ),
                                    border: Border.all(
                                      color: colors.border.withValues(alpha: 0.4),
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    toPersianDigits(daySubGroupLabel(item.dateStr)),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Vazirmatn',
                                      color: colors.textSecondary,
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
            ),
          ),
        ),
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
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rep = series.representative;
    final color = itemColor(context, rep);
    final icon = itemIcon(rep);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: 3,
      ),
      child: RitmoCard.neumorphic(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enableSpring: false,
        child: Column(
          children: [
            InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    // Domain Sunken Icon
                    RitmoNeuSurface(
                      height: 36,
                      width: 36,
                      radius: 18,
                      sunken: true,
                      padding: EdgeInsets.zero,
                      glowColor: color.withValues(alpha: 0.4),
                      child: Center(
                        child: Icon(icon, size: 17, color: color),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title + Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            toPersianDigits(rep.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Vazirmatn',
                              color: colors.textPrimary,
                            ),
                          ),
                          if (series.completedCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${toPersianDigits(series.completedCount)} از ${toPersianDigits(series.totalCount)} انجام شد',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'Vazirmatn',
                                  color: colors.success,
                                  fontWeight: FontWeight.w600,
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
                            fontSize: 11.5,
                            fontFamily: 'Vazirmatn',
                            color: colors.textSecondary,
                          ),
                        ),
                      ),

                    // Recurrence Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(RitmoRadius.badge),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.25),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        series.recurrenceLabel,
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Vazirmatn',
                          color: colors.primary,
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
                      color: colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded Child Instances List
            if (isExpanded) ...[
              const RitmoCardDivider(margin: EdgeInsets.symmetric(vertical: 6)),
              Column(
                children: series.instances.map((inst) {
                  final onPostpone = onPostponeItem;
                  final onDone = onDoneItem;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                        child: Text(
                          toPersianDigits(daySubGroupLabel(inst.dateStr)),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Vazirmatn',
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      _AgendaRow(
                        item: inst,
                        onTap: () => onItemTap(inst),
                        onPostpone: onPostpone != null
                            ? () => onPostpone(inst)
                            : null,
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
// Day Group Card (Grouped Day Cards)
// ────────────────────────────────────────────────────────────

class _DayGroupCard extends StatelessWidget {
  const _DayGroupCard({
    required this.title,
    this.isOverdue = false,
    required this.items,
    required this.onItemTap,
    this.onPostponeItem,
    this.onDoneItem,
  });

  final String title;
  final bool isOverdue;
  final List<AgendaItem> items;
  final void Function(AgendaItem item) onItemTap;
  final Future<void> Function(AgendaItem item)? onPostponeItem;
  final Future<void> Function(AgendaItem item)? onDoneItem;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = items.length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.md,
        vertical: 4,
      ),
      child: RitmoCard.neumorphic(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enableSpring: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // هدر روز نئومورفیک با شمارنده
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Vazirmatn',
                    color: isOverdue ? colors.error : colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isOverdue ? colors.error : colors.primary)
                        .withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isOverdue ? colors.error : colors.primary)
                          .withValues(alpha: isDark ? 0.35 : 0.22),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    toPersianDigits('$count'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Vazirmatn',
                      color: isOverdue ? colors.error : colors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const RitmoCardDivider(margin: EdgeInsets.symmetric(vertical: 4)),
            // لیست ردیف‌های کارهای روز
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (ctx, i) =>
                  const RitmoCardDivider(margin: EdgeInsets.symmetric(vertical: 2)),
              itemBuilder: (ctx, i) {
                final item = items[i];
                return _AgendaRow(
                  item: item,
                  onTap: () => onItemTap(item),
                  onPostpone: onPostponeItem != null
                      ? () => onPostponeItem!(item)
                      : null,
                  onDone: onDoneItem != null ? () => onDoneItem!(item) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Items Sliver
// ────────────────────────────────────────────────────────────

class _ItemsSliver extends StatelessWidget {
  const _ItemsSliver({
    required this.title,
    this.isOverdue = false,
    required this.items,
    required this.onItemTap,
    this.onPostponeItem,
    this.onDoneItem,
  });

  final String title;
  final bool isOverdue;
  final List<AgendaItem> items;
  final void Function(AgendaItem) onItemTap;
  final Future<void> Function(AgendaItem)? onPostponeItem;
  final Future<void> Function(AgendaItem)? onDoneItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: _DayGroupCard(
        title: title,
        isOverdue: isOverdue,
        items: items,
        onItemTap: onItemTap,
        onPostponeItem: onPostponeItem,
        onDoneItem: onDoneItem,
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Single Agenda Row — 3D Sunken Well + Quick Complete
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

  /// Items that can be marked done/completed via swipe / quick-tap:
  bool get _canComplete =>
      widget.item.kind != AgendaItemKind.event &&
      (widget.item.domain != AgendaDomain.cycle ||
          widget.item.kind == AgendaItemKind.reminder);

  bool get _isDone =>
      widget.item.completion == AgendaCompletion.done ||
      widget.item.completion == AgendaCompletion.skipped;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;
    final color = itemColor(context, item);
    final icon = itemIcon(item);
    final isDone = _isDone;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget row = SizedBox(
      height: 48,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // شیار فرورفته مقعر سه‌بعدی نئومورفیک با رنگ و هاله نوری اختصاصی دامنه
              RitmoNeuSurface(
                height: 36,
                width: 36,
                radius: 18,
                sunken: true,
                padding: EdgeInsets.zero,
                glowColor: color.withValues(alpha: isDone ? 0.15 : 0.40),
                child: Center(
                  child: Icon(
                    icon,
                    size: 17,
                    color: isDone ? color.withValues(alpha: 0.4) : color,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // عنوان + زیرعنوان
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      toPersianDigits(item.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isDone ? FontWeight.w500 : FontWeight.w700,
                        fontFamily: 'Vazirmatn',
                        color: isDone
                            ? colors.textTertiary
                            : colors.textPrimary,
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
                  ],
                ),
              ),

              // پیل زمان در صورت زمان‌دار بودن
              if (item.isTimed && item.timeOfDay != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: isDark ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    toPersianDigits(item.timeOfDay ?? ''),
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Vazirmatn',
                      color: isDone
                          ? colors.textTertiary
                          : colors.textSecondary,
                    ),
                  ),
                ),

              // ستاره اهمیت برای تسک‌ها
              if (item.domain == AgendaDomain.task &&
                  item.meta['isImportant'] == 1)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: colors.primary.withValues(
                      alpha: isDone ? 0.25 : 0.85,
                    ),
                  ),
                ),

              // دکمه تعاملی تیک و ثبت سریع (Quick Complete)
              if (_canComplete) ...[
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      RitmoHaptics.confirm();
                      if (widget.onDone != null) widget.onDone!();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isDone
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.circle,
                        size: 21,
                        color: isDone
                            ? colors.success
                            : colors.textSecondary.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!_canComplete && !_canPostpone) {
      return row;
    }

    // K23 — Dismissible swipe gestures
    return Dismissible(
      key: ValueKey(item.id),
      direction: _canPostpone && _canComplete
          ? DismissDirection.horizontal
          : (_canPostpone
              ? DismissDirection.endToStart
              : DismissDirection.startToEnd),
      background: _SwipeBackground(
        color: colors.success,
        icon: Icons.check_rounded,
        alignment: AlignmentDirectional.centerStart,
        label: 'انجام شد',
      ),
      secondaryBackground: _SwipeBackground(
        color: _canPostpone ? colors.accent : Colors.transparent,
        icon: _canPostpone ? Icons.schedule_rounded : null,
        alignment: AlignmentDirectional.centerEnd,
        label: _canPostpone ? 'فردا' : '',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          RitmoHapticsPolicy.tap();
          if (widget.onDone != null) await widget.onDone!();
          return false;
        } else {
          if (!_canPostpone) return false;
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
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.5,
                ),
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
        label: Text(label, style: const TextStyle(fontSize: 14)),
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
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.55,
                ),
              ),
            ),
            if (kDebugMode && failedSources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.25,
                  ),
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
