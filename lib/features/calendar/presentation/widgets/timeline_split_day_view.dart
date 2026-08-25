import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_geometry.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/features/calendar/presentation/logic/direct_manipulation_eligibility.dart';
import 'package:ritmo/features/calendar/presentation/logic/split_day_scroll_helper.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_column_header.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_grid.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_hour_axis.dart';

class TimelineSplitDayView extends StatefulWidget {
  const TimelineSplitDayView({
    super.key,
    required this.items,
    required this.isToday,
    this.sleepStartMinutes,
    this.sleepEndMinutes,
    this.highlightedItemId,
    this.onItemTap,
    this.onItemMove,
    this.onItemResize,
    this.onSlotTap,
    this.onScheduleUntimed,
    this.onOverflowTap,
  });

  final List<AgendaItem> items;
  final bool isToday;
  final int? sleepStartMinutes;
  final int? sleepEndMinutes;
  final String? highlightedItemId;
  final ValueChanged<AgendaItem>? onItemTap;
  final void Function(AgendaItem item, int newStartMinutes)? onItemMove;
  final void Function(AgendaItem item, int newDurationMinutes)? onItemResize;
  final ValueChanged<int>? onSlotTap; // minute of day (0..1439)
  final void Function(AgendaItem item, int startMinutes, int durationMinutes)?
  onScheduleUntimed;
  final ValueChanged<AgendaItem>? onOverflowTap;

  @override
  State<TimelineSplitDayView> createState() => TimelineSplitDayViewState();
}

class TimelineSplitDayViewState extends State<TimelineSplitDayView> {
  late final ScrollController _sharedScrollController;
  late final ScrollController _singleColumnController;

  final GlobalKey _morningGridKey = GlobalKey();
  final GlobalKey _afternoonGridKey = GlobalKey();
  final GlobalKey _singleGridKey = GlobalKey();

  String? _draggingItemId;
  int? _previewStartMinutes;
  int _previewDurationMinutes = 30;

  @override
  void initState() {
    super.initState();
    _sharedScrollController = ScrollController();
    _singleColumnController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSmartInitialScroll();
    });
  }

  @override
  void dispose() {
    _sharedScrollController.dispose();
    _singleColumnController.dispose();
    super.dispose();
  }

  void scrollToMinutes(int minutes) {
    if (!_sharedScrollController.hasClients) {
      if (_singleColumnController.hasClients) {
        final offset =
            ((minutes - 60).clamp(0, 1440)) * CalendarGeometry.pxPerMinute;
        final maxScroll = _singleColumnController.position.maxScrollExtent;
        _singleColumnController.animateTo(
          offset.clamp(0.0, maxScroll),
          duration: RitmoMotion.effective(context, RitmoMotion.sheet),
          curve: RitmoMotion.enter,
        );
      }
      return;
    }

    final target = splitDayScrollTargetFor(minutes);
    final maxScroll = _sharedScrollController.position.maxScrollExtent;
    _sharedScrollController.animateTo(
      target.offset.clamp(0.0, maxScroll),
      duration: RitmoMotion.effective(context, RitmoMotion.sheet),
      curve: RitmoMotion.enter,
    );
  }

  void _performSmartInitialScroll() {
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;

    if (widget.isToday) {
      if (_sharedScrollController.hasClients) {
        final target = splitDayScrollTargetFor(nowMinutes);
        final maxScroll = _sharedScrollController.position.maxScrollExtent;
        _sharedScrollController.animateTo(
          target.offset.clamp(0.0, maxScroll),
          duration: RitmoMotion.effective(context, RitmoMotion.sheet),
          curve: RitmoMotion.enter,
        );
      }
      if (_singleColumnController.hasClients) {
        final offset =
            ((nowMinutes - 60).clamp(0, 1440)) * CalendarGeometry.pxPerMinute;
        final maxScroll = _singleColumnController.position.maxScrollExtent;
        _singleColumnController.animateTo(
          offset.clamp(0.0, maxScroll),
          duration: RitmoMotion.effective(context, RitmoMotion.sheet),
          curve: RitmoMotion.enter,
        );
      }
    } else {
      _scrollToFirstItemOrDefault(_sharedScrollController, 0, 1440);
      if (_singleColumnController.hasClients) {
        _scrollToFirstItemOrDefault(
          _singleColumnController,
          0,
          1440,
          isSingle: true,
        );
      }
    }
  }

  void _scrollToFirstItemOrDefault(
    ScrollController controller,
    int rangeStart,
    int rangeEnd, {
    bool isSingle = false,
  }) {
    if (!controller.hasClients) return;
    final timedItems = widget.items.where((i) => i.isTimed).toList();
    var firstMinute = rangeStart;

    for (final item in timedItems) {
      final startM = TimeOfDayMinutes.tryParse(item.timeOfDay);
      if (startM != null && startM >= rangeStart && startM < rangeEnd) {
        firstMinute = startM;
        break;
      }
    }

    final pxRate = isSingle
        ? CalendarGeometry.effectivePxPerMinute(context)
        : CalendarGeometry.effectivePxPerMinuteSplit(context);
    final offset = ((firstMinute - rangeStart - 30).clamp(0, 720)) * pxRate;
    final maxScroll = controller.position.maxScrollExtent;
    controller.animateTo(
      offset.clamp(0.0, maxScroll),
      duration: RitmoMotion.effective(context, RitmoMotion.sheet),
      curve: RitmoMotion.enter,
    );
  }

  Widget _buildColumnGrid({
    required BuildContext context,
    required SplitDayRange range,
    required HourAxisSide side,
    required GlobalKey gridKey,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pxSplit = CalendarGeometry.effectivePxPerMinuteSplit(context);

    final columnItems = widget.items.where((item) {
      if (!item.isTimed) return false;
      final startM = TimeOfDayMinutes.tryParse(item.timeOfDay);
      if (startM == null) return false;
      final durM = DurationBounds.sanitize(item.durationMinutes);
      final endM = startM + durM;
      return startM < range.endMinutes && endM > range.startMinutes;
    }).toList();

    return DragTarget<AgendaItem>(
      onWillAcceptWithDetails: (details) => true,
      onMove: (details) {
        final renderBox =
            gridKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localOffset = renderBox.globalToLocal(details.offset);
        final rawMinutes =
            ((localOffset.dy / pxSplit) +
                    range.startMinutes)
                .round();
        final dur = DurationBounds.sanitize(details.data.durationMinutes);
        final snappedStart = TimelineSnappingHelper.snapStartMinutes(
          rawMinutes,
          durationMinutes: dur,
        );

        if (_previewStartMinutes != snappedStart ||
            _draggingItemId != details.data.id) {
          setState(() {
            _draggingItemId = details.data.id;
            _previewStartMinutes = snappedStart;
            _previewDurationMinutes = dur;
          });
        }
      },
      onAcceptWithDetails: (details) {
        final renderBox =
            gridKey.currentContext?.findRenderObject() as RenderBox?;
        final localOffset = renderBox != null
            ? renderBox.globalToLocal(details.offset)
            : Offset.zero;
        final rawMinutes =
            ((localOffset.dy / pxSplit) +
                    range.startMinutes)
                .round();
        final dur = DurationBounds.sanitize(details.data.durationMinutes);
        final snappedStart = TimelineSnappingHelper.snapStartMinutes(
          rawMinutes,
          durationMinutes: dur,
        );

        setState(() {
          _draggingItemId = null;
          _previewStartMinutes = null;
        });

        if (details.data.isTimed) {
          widget.onItemMove?.call(details.data, snappedStart);
        } else {
          widget.onScheduleUntimed?.call(details.data, snappedStart, dur);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Stack(
          children: [
            TimelineGrid(
              key: gridKey,
              items: widget.items,
              isToday: widget.isToday,
              rangeStartMinutes: range.startMinutes,
              rangeEndMinutes: range.endMinutes,
              pxPerMinute: pxSplit,
              hourAxisWidth: CalendarGeometry.effectiveHourAxisWidthSplit(context),
              maxLanes: CalendarGeometry.maxLanesSplit,
              axisSide: side,
              scrollController: _sharedScrollController,
              sleepStartMinutes: widget.sleepStartMinutes,
              sleepEndMinutes: widget.sleepEndMinutes,
              highlightedItemId: widget.highlightedItemId,
              previewDraggingItemId: _draggingItemId,
              previewStartMinutes: _previewStartMinutes,
              previewDurationMinutes: _previewDurationMinutes,
              onDragStarted: (item, startM, durM) {
                setState(() {
                  _draggingItemId = item.id;
                  _previewStartMinutes = startM;
                  _previewDurationMinutes = durM;
                });
              },
              onDragCanceled: () {
                setState(() {
                  _draggingItemId = null;
                  _previewStartMinutes = null;
                });
              },
              onItemTap: widget.onItemTap,
              onItemMove: widget.onItemMove,
              onItemResize: widget.onItemResize,
              onSlotTap: widget.onSlotTap,
              onScheduleUntimed: widget.onScheduleUntimed,
              onOverflowTap: widget.onOverflowTap,
            ),
            if (columnItems.isEmpty)
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(RitmoSpacing.md),
                      child: Text(
                        'برنامه‌ای در این بازه نیست',
                        textAlign: TextAlign.center,
                        style: RitmoTextStyles.caption(
                          context.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom =
        MediaQuery.paddingOf(context).bottom +
        kBottomNavigationBarHeight +
        20.0;
    final now = DateTime.now();
    final nowMinutes = (now.hour * 60) + now.minute;

    final isMorningActive =
        widget.isToday && nowMinutes < CalendarGeometry.splitBoundaryMinutes;
    final isAfternoonActive =
        widget.isToday && nowMinutes >= CalendarGeometry.splitBoundaryMinutes;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < CalendarGeometry.splitMinScreenWidth) {
          final pxSingle = CalendarGeometry.effectivePxPerMinute(context);
          return DragTarget<AgendaItem>(
            onWillAcceptWithDetails: (details) => true,
            onMove: (details) {
              final renderBox =
                  _singleGridKey.currentContext?.findRenderObject()
                      as RenderBox?;
              if (renderBox == null) return;
              final localOffset = renderBox.globalToLocal(details.offset);
              final rawMinutes = (localOffset.dy / pxSingle)
                  .round();
              final dur = DurationBounds.sanitize(details.data.durationMinutes);
              final snappedStart = TimelineSnappingHelper.snapStartMinutes(
                rawMinutes,
                durationMinutes: dur,
              );

              if (_previewStartMinutes != snappedStart ||
                  _draggingItemId != details.data.id) {
                setState(() {
                  _draggingItemId = details.data.id;
                  _previewStartMinutes = snappedStart;
                  _previewDurationMinutes = dur;
                });
              }
            },
            onAcceptWithDetails: (details) {
              final renderBox =
                  _singleGridKey.currentContext?.findRenderObject()
                      as RenderBox?;
              final localOffset = renderBox != null
                  ? renderBox.globalToLocal(details.offset)
                  : Offset.zero;
              final rawMinutes = (localOffset.dy / pxSingle)
                  .round();
              final dur = DurationBounds.sanitize(details.data.durationMinutes);
              final snappedStart = TimelineSnappingHelper.snapStartMinutes(
                rawMinutes,
                durationMinutes: dur,
              );

              setState(() {
                _draggingItemId = null;
                _previewStartMinutes = null;
              });

              if (details.data.isTimed) {
                widget.onItemMove?.call(details.data, snappedStart);
              } else {
                widget.onScheduleUntimed?.call(details.data, snappedStart, dur);
              }
            },
            builder: (context, candidateData, rejectedData) {
              return SingleChildScrollView(
                controller: _singleColumnController,
                padding: EdgeInsets.only(bottom: paddingBottom),
                child: TimelineGrid(
                  key: _singleGridKey,
                  items: widget.items,
                  isToday: widget.isToday,
                  rangeStartMinutes: 0,
                  rangeEndMinutes: 1440,
                  pxPerMinute: pxSingle,
                  hourAxisWidth: CalendarGeometry.effectiveHourAxisWidth(context),
                  sleepStartMinutes: widget.sleepStartMinutes,
                  sleepEndMinutes: widget.sleepEndMinutes,
                  highlightedItemId: widget.highlightedItemId,
                  previewDraggingItemId: _draggingItemId,
                  previewStartMinutes: _previewStartMinutes,
                  previewDurationMinutes: _previewDurationMinutes,
                  onDragStarted: (item, startM, durM) {
                    setState(() {
                      _draggingItemId = item.id;
                      _previewStartMinutes = startM;
                      _previewDurationMinutes = durM;
                    });
                  },
                  onDragCanceled: () {
                    setState(() {
                      _draggingItemId = null;
                      _previewStartMinutes = null;
                    });
                  },
                  onItemTap: widget.onItemTap,
                  onItemMove: widget.onItemMove,
                  onItemResize: widget.onItemResize,
                  onSlotTap: widget.onSlotTap,
                  onScheduleUntimed: widget.onScheduleUntimed,
                  onOverflowTap: widget.onOverflowTap,
                ),
              );
            },
          );
        }

        final pxSplit = CalendarGeometry.effectivePxPerMinuteSplit(context);

        // Split 2-column layout (Morning on RIGHT in RTL, Afternoon on LEFT)
        // Synchronized Scrolling & Borderless Frameless UI
        return Column(
          children: [
            // Sticky Headers Row
            Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TimelineColumnHeader(
                        title: SplitDayRange.morning.titleFa,
                        icon: SplitDayRange.morning.icon,
                        rangeLabel: SplitDayRange.morning.rangeLabel,
                        isActive: isMorningActive,
                      ),
                    ),
                    const SizedBox(width: CalendarGeometry.columnGap),
                    Expanded(
                      child: TimelineColumnHeader(
                        title: SplitDayRange.afternoon.titleFa,
                        icon: SplitDayRange.afternoon.icon,
                        rangeLabel: SplitDayRange.afternoon.rangeLabel,
                        isActive: isAfternoonActive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Shared Synchronized Scrollable Grids
            Expanded(
              child: SingleChildScrollView(
                controller: _sharedScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: paddingBottom),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Morning Column (Right in RTL, side: HourAxisSide.leading -> Hour Axis on RIGHT)
                        Expanded(
                          child: _buildColumnGrid(
                            context: context,
                            range: SplitDayRange.morning,
                            side: HourAxisSide.leading,
                            gridKey: _morningGridKey,
                          ),
                        ),
                        SizedBox(
                          width: CalendarGeometry.columnGap,
                          child: Center(
                            child: Container(
                              width: 1.0,
                              height: 720 * pxSplit,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.0),
                                    Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.22),
                                    Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Afternoon Column (Left in RTL, side: HourAxisSide.leading -> Hour Axis on RIGHT)
                        Expanded(
                          child: _buildColumnGrid(
                            context: context,
                            range: SplitDayRange.afternoon,
                            side: HourAxisSide.leading,
                            gridKey: _afternoonGridKey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
