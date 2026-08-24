// lib/features/calendar/presentation/logic/timeline_layout_engine.dart

import 'dart:math';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';

class TimelineLayoutItem {
  const TimelineLayoutItem({
    required this.item,
    required this.top,
    required this.height,
    required this.laneIndex,
    required this.totalLanes,
    required this.startMinutes,
    required this.durationMinutes,
    required this.renderDurationMinutes,
    required this.isTruncated,
    this.isClippedAtStart = false,
    this.isClippedAtEnd = false,
    this.overflowCount = 0,
    this.overflowItems = const [],
  });

  final AgendaItem item;
  final double top;
  final double height;
  final int laneIndex;
  final int totalLanes;
  final int startMinutes;
  final int durationMinutes;
  final int renderDurationMinutes;
  final bool isTruncated;
  final bool isClippedAtStart;
  final bool isClippedAtEnd;
  final int overflowCount;
  final List<AgendaItem> overflowItems;

  double get leftFraction => totalLanes > 0 ? laneIndex / totalLanes : 0.0;
  double get widthFraction => totalLanes > 0 ? 1.0 / totalLanes : 1.0;
}

class TimelineLayoutEngine {
  const TimelineLayoutEngine({
    this.pxPerMinute = CalendarGeometry.pxPerMinute,
    this.minItemHeight = 28.0,
    this.defaultDurationMinutes = DurationBounds.defaultMinutes,
    this.rangeStartMinutes = 0,
    this.rangeEndMinutes = 1440,
    this.maxLanes,
  });

  final double pxPerMinute;
  final double minItemHeight;
  final int defaultDurationMinutes;
  final int rangeStartMinutes;
  final int rangeEndMinutes;
  final int? maxLanes;

  int get rangeDurationMinutes => rangeEndMinutes - rangeStartMinutes;
  double get totalTimelineHeight => rangeDurationMinutes * pxPerMinute;

  double _calculateSafeHeight(double rawHeight, double top) {
    final maxHeight = (totalTimelineHeight - top).clamp(
      0.0,
      totalTimelineHeight,
    );
    return maxHeight <= minItemHeight
        ? maxHeight
        : max(rawHeight, minItemHeight).clamp(minItemHeight, maxHeight);
  }

  List<TimelineLayoutItem> calculateLayout(List<AgendaItem> items) {
    final timed = items.where((i) => i.isTimed).toList();
    if (timed.isEmpty) return [];

    final rawEntries = <_RawEntry>[];
    for (final item in timed) {
      final startM = TimeOfDayMinutes.tryParse(item.timeOfDay);
      if (startM == null) continue;

      var durM = DurationBounds.sanitize(item.durationMinutes);
      final maxDurationForDay = (1440 - startM).clamp(1, 1440);
      durM = durM.clamp(DurationBounds.minMinutes, maxDurationForDay);
      final endM = startM + durM;

      // Filter: item must overlap range [rangeStartMinutes, rangeEndMinutes)
      if (startM >= rangeEndMinutes || endM <= rangeStartMinutes) {
        continue;
      }

      final visibleStart = max(startM, rangeStartMinutes);
      final visibleEnd = min(endM, rangeEndMinutes);
      final isClippedAtStart = startM < rangeStartMinutes;
      final isClippedAtEnd = endM > rangeEndMinutes;

      final visibleDuration = visibleEnd - visibleStart;
      final renderDurM = min(visibleDuration, DurationBounds.maxRenderMinutes);

      /// true یعنی مدت واقعی از سقف رندر بیشتر بوده و کارت کوتاه‌تر کشیده شده.
      final isTruncated = durM > renderDurM;

      rawEntries.add(
        _RawEntry(
          item: item,
          startMinutes: startM,
          durationMinutes: durM,
          renderDurationMinutes: renderDurM,
          visibleStart: visibleStart,
          visibleEnd: visibleEnd,
          isClippedAtStart: isClippedAtStart,
          isClippedAtEnd: isClippedAtEnd,
          isTruncated: isTruncated,
        ),
      );
    }

    if (rawEntries.isEmpty) return [];

    rawEntries.sort((a, b) {
      final cmp = a.visibleStart.compareTo(b.visibleStart);
      if (cmp != 0) return cmp;
      final durCmp = b.durationMinutes.compareTo(a.durationMinutes);
      if (durCmp != 0) return durCmp;
      return a.item.id.compareTo(b.item.id);
    });

    // Build connected components (clusters) on overlap graph
    /// هم‌پوشانی تراگذر نیست؛ عرض ستون باید از مؤلفهٔ همبند بیاید نه از هم‌پوشانی مستقیم.
    final clusters = <List<_RawEntry>>[];
    var current = <_RawEntry>[];
    var clusterEnd = -1;
    for (final e in rawEntries) {
      if (current.isEmpty || e.visibleStart < clusterEnd) {
        current.add(e);
        clusterEnd = max(clusterEnd, e.visibleEnd);
      } else {
        clusters.add(current);
        current = [e];
        clusterEnd = e.visibleEnd;
      }
    }
    if (current.isNotEmpty) clusters.add(current);

    final result = <TimelineLayoutItem>[];

    for (final cluster in clusters) {
      // Assign lanes inside the cluster
      final lanes = <List<_RawEntry>>[];
      for (final entry in cluster) {
        var placed = false;
        for (var i = 0; i < lanes.length; i++) {
          final lane = lanes[i];
          final hasOverlap = lane.any(
            (other) =>
                entry.visibleStart < other.visibleEnd &&
                entry.visibleEnd > other.visibleStart,
          );
          if (!hasOverlap) {
            lane.add(entry);
            entry.laneIndex = i;
            placed = true;
            break;
          }
        }
        if (!placed) {
          lanes.add([entry]);
          entry.laneIndex = lanes.length - 1;
        }
      }

      final clusterLanesCount = lanes.length;

      // Handle maxLanes capping if set
      if (maxLanes != null && clusterLanesCount > maxLanes!) {
        final totalLanes = maxLanes!;

        // Sort cluster entries by essential/priority
        final sortedCluster = List<_RawEntry>.from(cluster)
          ..sort((a, b) {
            if (a.item.isEssential != b.item.isEssential) {
              return a.item.isEssential ? -1 : 1;
            }
            if (a.item.priority != b.item.priority) {
              return b.item.priority.compareTo(a.item.priority);
            }
            final startCmp = a.visibleStart.compareTo(b.visibleStart);
            if (startCmp != 0) return startCmp;
            final durCmp = b.durationMinutes.compareTo(a.durationMinutes);
            if (durCmp != 0) return durCmp;
            return a.item.id.compareTo(b.item.id);
          });

        final primaryCount = maxLanes! - 1;
        final primaryEntries = sortedCluster.take(primaryCount).toList();
        final overflowEntries = sortedCluster.skip(primaryCount).toList();

        for (var laneIdx = 0; laneIdx < primaryEntries.length; laneIdx++) {
          final entry = primaryEntries[laneIdx];
          final top = (entry.visibleStart - rangeStartMinutes) * pxPerMinute;
          final rawHeight = entry.renderDurationMinutes * pxPerMinute;
          final height = _calculateSafeHeight(rawHeight, top);

          result.add(
            TimelineLayoutItem(
              item: entry.item,
              top: top,
              height: height,
              laneIndex: laneIdx,
              totalLanes: totalLanes,
              startMinutes: entry.startMinutes,
              durationMinutes: entry.durationMinutes,
              renderDurationMinutes: entry.renderDurationMinutes,
              isTruncated: entry.isTruncated,
              isClippedAtStart: entry.isClippedAtStart,
              isClippedAtEnd: entry.isClippedAtEnd,
            ),
          );
        }

        if (overflowEntries.isNotEmpty) {
          final overflowItemsList = overflowEntries.map((e) => e.item).toList();
          final minStart = overflowEntries
              .map((e) => e.visibleStart)
              .reduce(min);
          final maxEnd = overflowEntries.map((e) => e.visibleEnd).reduce(max);

          final top = (minStart - rangeStartMinutes) * pxPerMinute;
          final rawHeight = (maxEnd - minStart) * pxPerMinute;
          final height = _calculateSafeHeight(rawHeight, top);

          result.add(
            TimelineLayoutItem(
              item: overflowEntries.first.item,
              top: top,
              height: height,
              laneIndex: maxLanes! - 1,
              totalLanes: totalLanes,
              startMinutes: minStart,
              durationMinutes: maxEnd - minStart,
              renderDurationMinutes: maxEnd - minStart,
              isTruncated: false,
              overflowCount: overflowEntries.length,
              overflowItems: overflowItemsList,
            ),
          );
        }
      } else {
        final totalLanes = clusterLanesCount;
        for (final entry in cluster) {
          final top = (entry.visibleStart - rangeStartMinutes) * pxPerMinute;
          final rawHeight = entry.renderDurationMinutes * pxPerMinute;
          final height = _calculateSafeHeight(rawHeight, top);

          result.add(
            TimelineLayoutItem(
              item: entry.item,
              top: top,
              height: height,
              laneIndex: entry.laneIndex,
              totalLanes: totalLanes,
              startMinutes: entry.startMinutes,
              durationMinutes: entry.durationMinutes,
              renderDurationMinutes: entry.renderDurationMinutes,
              isTruncated: entry.isTruncated,
              isClippedAtStart: entry.isClippedAtStart,
              isClippedAtEnd: entry.isClippedAtEnd,
            ),
          );
        }
      }
    }

    assert(() {
      final seen = <String>{};
      for (final r in result) {
        if (r.overflowCount > 0) {
          for (final o in r.overflowItems) {
            if (!seen.add(o.id)) return false;
          }
        } else {
          if (!seen.add(r.item.id)) return false;
        }
      }
      return true;
    }(), 'یک آیتم دو بار در چیدمان ظاهر شده است');

    return result;
  }
}

class _RawEntry {
  _RawEntry({
    required this.item,
    required this.startMinutes,
    required this.durationMinutes,
    required this.renderDurationMinutes,
    required this.visibleStart,
    required this.visibleEnd,
    required this.isClippedAtStart,
    required this.isClippedAtEnd,
    required this.isTruncated,
  });

  final AgendaItem item;
  final int startMinutes;
  final int durationMinutes;
  final int renderDurationMinutes;
  final int visibleStart;
  final int visibleEnd;
  final bool isClippedAtStart;
  final bool isClippedAtEnd;
  final bool isTruncated;
  int laneIndex = 0;
}
