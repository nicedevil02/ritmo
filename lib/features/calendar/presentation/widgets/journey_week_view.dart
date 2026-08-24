import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';
import 'package:shamsi_date/shamsi_date.dart';

class JourneyWeekView extends StatefulWidget {
  const JourneyWeekView({
    super.key,
    required this.selectedDate,
    required this.rangeSnapshots,
    required this.onSelectDate,
    this.onItemTap,
    this.onSlotTap,
    this.onMoveItemToDate,
  });

  final DateTime selectedDate;
  final Map<String, DayAgendaSnapshot> rangeSnapshots;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<AgendaItem>? onItemTap;
  final void Function(DateTime date, int slotMinutes)? onSlotTap;
  final void Function(AgendaItem item, DateTime targetDate)? onMoveItemToDate;

  static const double pxPerMinute = 1.05; // 1440 * 1.05 = 1512.0 px total vertical scrollable height
  static const double hourAxisWidth = 44.0;
  static const List<String> weekDayShortFa = ['ش', '۱ش', '۲ش', '۳ش', '۴ش', '۵ش', 'ج'];

  @override
  State<JourneyWeekView> createState() => _JourneyWeekViewState();
}

class _JourneyWeekViewState extends State<JourneyWeekView> {
  late final ScrollController _scrollController;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _startMinuteTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollToNow();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startMinuteTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  void _autoScrollToNow() {
    if (!_scrollController.hasClients) return;
    final nowMinutes = (_now.hour * 60) + _now.minute;
    final targetOffset = (nowMinutes * JourneyWeekView.pxPerMinute - 130).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final sat = ShamsiWeek.saturdayOf(widget.selectedDate);
    final weekDays = List.generate(7, (i) => sat.add(Duration(days: i)));

    final nowMinutes = (_now.hour * 60) + _now.minute;
    final nowTop = nowMinutes * JourneyWeekView.pxPerMinute;

    int weekTotal = 0;
    int weekCompleted = 0;
    bool hasAnyUntimedItems = false;

    for (final day in weekDays) {
      final k = DateKey.of(day);
      final snap = widget.rangeSnapshots[k];
      if (snap != null) {
        weekTotal += snap.completedCount + snap.remainingCount;
        weekCompleted += snap.completedCount;
        if (snap.items.any((i) => !i.isTimed)) {
          hasAnyUntimedItems = true;
        }
      }
    }
    final weekRatio = weekTotal > 0 ? (weekCompleted / weekTotal).clamp(0.0, 1.0) : 0.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.xs,
          vertical: RitmoSpacing.xs,
        ),
        child: Column(
          children: [
            // ─── ۱. نوار پیشرفت هفتگی (Weekly Progress Bar) ───
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RitmoSpacing.sm,
                vertical: RitmoSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: weekCompleted == weekTotal && weekTotal > 0
                        ? colors.success
                        : colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'پیشرفت هفته: ${toPersianDigits(weekCompleted)} از ${toPersianDigits(weekTotal)} وظیفه',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: weekRatio,
                        minHeight: 6,
                        backgroundColor: colors.border.withValues(alpha: 0.35),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          weekCompleted == weekTotal && weekTotal > 0
                              ? colors.success
                              : colors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${toPersianDigits((weekRatio * 100).toInt().toString())}٪',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ─── ۲. هدر ثابت ۷ روزه (Pinned Week Header) ───
            Row(
              children: [
                // فاصله اندازه ستون ساعت
                const SizedBox(width: JourneyWeekView.hourAxisWidth),
                // ۷ ستون روزهای هفته
                Expanded(
                  child: Row(
                    children: List.generate(7, (index) {
                      final day = weekDays[index];
                      final isToday = _isSameDay(day, _now);
                      final isSelected = _isSameDay(day, widget.selectedDate);
                      final isFriday = index == 6;

                      final jalaliDay = Jalali.fromDateTime(day);
                      final dayNumStr = toPersianDigits(jalaliDay.day.toString());

                      final k = DateKey.of(day);
                      final snap = widget.rangeSnapshots[k];
                      final dayCompleted = snap?.completedCount ?? 0;
                      final dayTotal = (snap?.completedCount ?? 0) + (snap?.remainingCount ?? 0);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => widget.onSelectDate(day),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.primary
                                  : (isToday
                                      ? colors.primaryContainer.withValues(alpha: 0.35)
                                      : colors.surface),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? colors.primary
                                    : (isToday ? colors.primary : colors.border.withValues(alpha: 0.6)),
                                width: (isToday || isSelected) ? 1.5 : 0.8,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: colors.primary.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  JourneyWeekView.weekDayShortFa[index],
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? colors.onPrimary
                                        : (isFriday ? colors.error : colors.textSecondary),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dayNumStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? colors.onPrimary
                                        : (isFriday ? colors.error : colors.textPrimary),
                                  ),
                                ),
                                if (dayTotal > 0) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? colors.onPrimary
                                          : (dayCompleted == dayTotal ? colors.success : colors.primary),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),

            // ─── ۳. بخش وظایف بدون ساعت (Untimed / All-Day Tray) ───
            if (hasAnyUntimedItems) ...[
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: JourneyWeekView.hourAxisWidth,
                      child: Center(
                        child: Text(
                          'همه‌روزه',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(7, (index) {
                          final day = weekDays[index];
                          final k = DateKey.of(day);
                          final snap = widget.rangeSnapshots[k];
                          final untimedItems = (snap?.items ?? []).where((i) => !i.isTimed).toList();

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.5),
                              child: Column(
                                children: [
                                  for (final item in untimedItems.take(2))
                                    GestureDetector(
                                      onTap: () => widget.onItemTap?.call(item),
                                      child: Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(bottom: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: domainColor(context, item.domain).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: domainColor(context, item.domain).withValues(alpha: 0.5),
                                            width: 0.7,
                                          ),
                                        ),
                                        child: Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            color: item.isCompleted ? colors.textTertiary : colors.textPrimary,
                                            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (untimedItems.length > 2)
                                    Text(
                                      '+${toPersianDigits((untimedItems.length - 2).toString())}',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 4),

            // ─── ۴. گرید اسکرول‌شونده ۲۴ ساعته (24-Hour Vertical Time Grid) ───
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.border.withValues(alpha: 0.6)),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  child: SizedBox(
                    height: 1440 * JourneyWeekView.pxPerMinute,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── محور ساعت ۲۴ ساعته در سمت راست ──
                        _buildHourAxis(context, colors),

                        // ── ۷ ستون زمانی روزهای هفته ──
                        Expanded(
                          child: Stack(
                            children: [
                              // خطوط راهنمای افقی ساعات شبانه‌روز
                              _buildHorizontalGridLines(colors),

                              // ستون‌های روزانه و کارت‌های رویداد
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(7, (index) {
                                  final day = weekDays[index];
                                  final isToday = _isSameDay(day, _now);
                                  final isSelected = _isSameDay(day, widget.selectedDate);
                                  final dateKey = DateKey.of(day);
                                  final snapshot = widget.rangeSnapshots[dateKey];
                                  final timedItems = (snapshot?.items ?? []).where((i) => i.isTimed).toList();

                                  return Expanded(
                                    child: _buildDayColumn(
                                      context: context,
                                      day: day,
                                      isToday: isToday,
                                      isSelected: isSelected,
                                      timedItems: timedItems,
                                      nowTop: nowTop,
                                      colors: colors,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ساخت محور ساعت (Time Axis Column) ──
  Widget _buildHourAxis(BuildContext context, RitmoColors colors) {
    return Container(
      width: JourneyWeekView.hourAxisWidth,
      decoration: BoxDecoration(
        color: colors.surfaceSubtle.withValues(alpha: 0.4),
        border: Border(
          left: BorderSide(color: colors.border.withValues(alpha: 0.4), width: 0.8),
        ),
      ),
      child: Stack(
        children: [
          for (int h = 0; h < 24; h++)
            Positioned(
              top: (h * 60) * JourneyWeekView.pxPerMinute - 7,
              left: 0,
              right: 4,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  toPersianDigits('${h.toString().padLeft(2, '0')}:00'),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── رسم خطوط افقی شبکه‌ای (Hour & Half-Hour Grid Lines) ──
  Widget _buildHorizontalGridLines(RitmoColors colors) {
    return Stack(
      children: [
        for (int h = 0; h < 24; h++) ...[
          // خط هر ۱ ساعت کامل
          Positioned(
            top: (h * 60) * JourneyWeekView.pxPerMinute,
            left: 0,
            right: 0,
            child: Container(
              height: 0.8,
              color: colors.divider.withValues(alpha: 0.35),
            ),
          ),
          // خط نیم‌ساعت
          Positioned(
            top: ((h * 60) + 30) * JourneyWeekView.pxPerMinute,
            left: 0,
            right: 0,
            child: Container(
              height: 0.5,
              color: colors.divider.withValues(alpha: 0.15),
            ),
          ),
        ],
      ],
    );
  }

  // ── ساخت ستون هر روز و کارت‌های زمان‌بندی‌شده ──
  Widget _buildDayColumn({
    required BuildContext context,
    required DateTime day,
    required bool isToday,
    required bool isSelected,
    required List<AgendaItem> timedItems,
    required double nowTop,
    required RitmoColors colors,
  }) {
    // محاسبه چیدمان با موتور هوشمند جهت رفع تداخل برنامه‌ها
    const layoutEngine = TimelineLayoutEngine(
      pxPerMinute: JourneyWeekView.pxPerMinute,
      minItemHeight: 22.0,
      rangeStartMinutes: 0,
      rangeEndMinutes: 1440,
    );
    final layoutItems = layoutEngine.calculateLayout(timedItems);

    return DragTarget<AgendaItem>(
      onWillAcceptWithDetails: (details) => DateKey.of(day) != details.data.dateStr,
      onAcceptWithDetails: (details) {
        widget.onMoveItemToDate?.call(details.data, day);
      },
      builder: (ctx, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: isHovered
                ? colors.primary.withValues(alpha: 0.18)
                : (isSelected ? colors.primaryContainer.withValues(alpha: 0.08) : null),
            border: Border(
              left: BorderSide(
                color: isHovered ? colors.primary : colors.divider.withValues(alpha: 0.25),
                width: isHovered ? 1.5 : 0.6,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final colWidth = constraints.maxWidth;

              return Stack(
                children: [
                  // لایه تشخیص لمس اسلات خالی جهت افزودن برنامه جدید
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapUp: (details) {
                        final localY = details.localPosition.dy;
                        final minuteOfDay = (localY / JourneyWeekView.pxPerMinute).round().clamp(0, 1439);
                        final roundedMinute = (minuteOfDay ~/ 15) * 15;
                        widget.onSlotTap?.call(day, roundedMinute);
                      },
                    ),
                  ),

                  // کارت‌های رویدادهای این ستون با موتور چیدمان
                  for (final layoutItem in layoutItems)
                    _buildEventCard(
                      context: context,
                      layoutItem: layoutItem,
                      colWidth: colWidth,
                      colors: colors,
                    ),

                  // خط نشانگر زمان جاری (Live Now Line)
                  if (isToday)
                    Positioned(
                      top: nowTop,
                      left: 0,
                      right: 0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerRight,
                        children: [
                          Container(
                            height: 2.0,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.accent.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            right: -3,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.accent,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accent.withValues(alpha: 0.8),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ── ساخت کارت مدرن هر رویداد (Rich Event Card) ──
  Widget _buildEventCard({
    required BuildContext context,
    required TimelineLayoutItem layoutItem,
    required double colWidth,
    required RitmoColors colors,
  }) {
    final item = layoutItem.item;
    final color = domainColor(context, item.domain);

    final left = layoutItem.leftFraction * colWidth;
    final width = max(layoutItem.widthFraction * colWidth - 2.0, 18.0);
    final isCompact = layoutItem.height < 32.0;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: item.isCompleted
            ? colors.disabled.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: item.isCompleted
              ? colors.borderSubtle
              : color.withValues(alpha: 0.6),
          width: 0.9,
        ),
      ),
      child: Stack(
        children: [
          // نوار رنگی کناری (Accent Bar)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 3.0,
            child: Container(
              decoration: BoxDecoration(
                color: item.isCompleted ? colors.disabled : color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
              ),
            ),
          ),
          // محتوای متنی کارت
          Padding(
            padding: EdgeInsets.only(
              right: 5.0,
              left: 2.0,
              top: isCompact ? 1.0 : 2.5,
              bottom: isCompact ? 1.0 : 2.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (item.isCompleted) ...[
                      Icon(
                        Icons.check_circle_rounded,
                        size: 9,
                        color: colors.success,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: isCompact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isCompact ? 9.0 : 10.0,
                          fontWeight: FontWeight.w700,
                          color: item.isCompleted
                              ? colors.textTertiary
                              : colors.textPrimary,
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isCompact && item.timeOfDay != null && item.timeOfDay!.isNotEmpty) ...[
                  const SizedBox(height: 1.5),
                  Text(
                    toPersianDigits(item.timeOfDay ?? ''),
                    style: TextStyle(
                      fontSize: 8.0,
                      fontWeight: FontWeight.w600,
                      color: item.isCompleted ? colors.textTertiary : color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Positioned(
      top: layoutItem.top,
      right: left,
      width: width,
      height: layoutItem.height,
      child: LongPressDraggable<AgendaItem>(
        data: item,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              item.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: cardContent),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => widget.onItemTap?.call(item),
            child: cardContent,
          ),
        ),
      ),
    );
  }
}
