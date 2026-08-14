import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/agenda/action_feedback.dart';
import 'package:ritmo/core/domain/agenda/action_router.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_snapshot_builder.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/calendar/data/day_mark_repository.dart';
import 'package:ritmo/features/calendar/data/occasions_calendar_source.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/logic/direct_manipulation_eligibility.dart';
import 'package:ritmo/features/calendar/presentation/models/now_pill_view_model.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_date_formatter.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';
import 'package:ritmo/features/calendar/presentation/widgets/calendar_search_delegate.dart';
import 'package:ritmo/features/calendar/utils/calendar_defaults.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
import 'package:ritmo/features/calendar/presentation/widgets/day_summary_bar.dart';
import 'package:ritmo/features/calendar/presentation/widgets/empty_day_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/go_to_date_dialog.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_agenda_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_month_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_scale_switcher.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_smart_panel.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_week_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_year_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/now_pill.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_split_day_view.dart';
import 'package:ritmo/features/calendar/widgets/day_review_sheet.dart';
import 'package:ritmo/features/registry/logic/registry_service.dart';
import 'package:ritmo/features/registry/presentation/all_plans_screen.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_untimed_section.dart';
import 'package:shamsi_date/shamsi_date.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({
    super.key,
    this.initialDate,
    this.initialItemId,
  });

  final DateTime? initialDate;
  final String? initialItemId;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  late final JourneyController _controller;
  final GlobalKey<TimelineSplitDayViewState> _splitDayKey = GlobalKey<TimelineSplitDayViewState>();
  StreamSubscription<RitmoEvent>? _eventSubscription;

  JourneyScale _prevScale = JourneyScale.day;
  DateTime _prevDate = DateTime.now();
  int _registryHealthCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = JourneyController();

    final startDate = widget.initialDate ?? DateTime.now();
    _prevDate = startDate;

    if (widget.initialItemId != null) {
      // K22 EXCEPTION: navigating to a specific item forces day scale.
      // This comment is intentional — do not remove without reading 067.md §K22.
      _controller.selectDate(startDate, scaleToSet: JourneyScale.day);
      _controller.loadForActiveScale().then((_) => _focusItemById(widget.initialItemId));
    } else {
      // K22: Load user-preferred scale from settings; fall back to agenda.
      _controller.loadDefaultScale().then((_) {
        _controller.loadForActiveScale().then((_) => _autoScrollToNow());
      });
    }

    _checkHealthIssues();
    _eventSubscription = RitmoEventBus().onEvents.listen((event) {
      _handleNavigationEvent(event);
      _checkHealthIssues();
    });
  }

  Future<void> _checkHealthIssues() async {
    final count = await RegistryService().healthIssueCount({});
    if (mounted) {
      setState(() {
        _registryHealthCount = count;
      });
    }
  }

  void _openAllPlans() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const AllPlansScreen()),
    ).then((_) => _checkHealthIssues());
  }

  void _handleNavigationEvent(RitmoEvent event) {
    if (!mounted) return;
    if (event.type == 'navigate_tab' && event.payload['index'] == 4) {
      final dateStr = event.payload['date'] as String?;
      final itemId = event.payload['itemId'] as String?;

      if (dateStr != null) {
        try {
          final targetDate = DateTime.parse(dateStr);
          _controller.selectDate(targetDate, scaleToSet: JourneyScale.day);
        } catch (_) {}
      }

      if (itemId != null) {
        _focusItemById(itemId);
      } else {
        _autoScrollToNow();
      }
    }
  }

  void _focusItemById(String? itemId) {
    if (itemId == null || !mounted) return;
    _controller.highlightItem(itemId);

    final snapshot = _controller.snapshot;
    if (snapshot != null) {
      for (final item in snapshot.items) {
        if (item.id == itemId && item.isTimed) {
          _scrollToTimeString(item.timeOfDay);
          break;
        }
      }
    }
  }

  void _autoScrollToNow() {
    if (!mounted) return;
    final now = DateTime.now();
    final isToday = _isSameDay(_controller.selectedDate, now);
    if (isToday && _controller.activeScale == JourneyScale.day) {
      final nowMinutes = (now.hour * 60) + now.minute;
      _scrollToMinutesValue(nowMinutes);
    }
  }

  void _scrollToMinutesValue(int minutes) {
    _splitDayKey.currentState?.scrollToMinutes(minutes);
  }

  int? _tryParseMinutes(String? timeStr) {
    if (timeStr == null) return null;

    final value = timeStr.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;

    final h = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    if (h == null || m == null) return null;
    if (h < 0 || h >= 24 || m < 0 || m >= 60) return null;

    return (h * 60) + m;
  }

  void _scrollToTimeString(String? timeStr) {
    final minutes = _tryParseMinutes(timeStr);
    if (minutes == null) return;
    _scrollToMinutesValue(minutes);
  }

  void _openItemDetails(AgendaItem item) {
    _controller.highlightItem(item.id);
    if (item.isTimed) {
      _scrollToTimeString(item.timeOfDay);
    }

    ActionRouter.open(context, item: item, onChanged: () => _controller.refresh());
  }

  Future<void> _openSmartPanel() async {
    var snapshot = _controller.snapshot;
    if (snapshot == null) {
      final dateKey = '${_controller.selectedDate.year}-${_controller.selectedDate.month.toString().padLeft(2, '0')}-${_controller.selectedDate.day.toString().padLeft(2, '0')}';
      snapshot = _controller.rangeSnapshots[dateKey];
    }

    if (snapshot == null) {
      final dayAgenda = await DayAgendaService.instance.agendaForDate(_controller.selectedDate);
      if (!mounted) return;
      snapshot = const DayAgendaSnapshotBuilder().buildSnapshot(dayAgenda);
    }

    if (!mounted) return;

    unawaited(JourneySmartPanel.showAsBottomSheet(
      context,
      snapshot: snapshot,
      onSelectActivity: _openItemDetails,
      onSelectFreeGap: (gap) {
        if (_controller.activeScale != JourneyScale.day) {
          _controller.setScale(JourneyScale.day);
        }
        _scrollToTimeString(gap.startTimeStr);
      },
    ));
  }

  // K32 — Open the day review sheet for the given date.
  Future<void> _openDayReview(DateTime date, DayAgendaSnapshot? existingSnapshot) async {
    final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    DayAgendaSnapshot? snap = existingSnapshot;
    if (snap == null) {
      final dayAgenda = await DayAgendaService.instance.agendaForDate(date);
      if (!mounted) return;
      snap = const DayAgendaSnapshotBuilder().buildSnapshot(dayAgenda);
    }
    if (!mounted) return;
    DayReviewSheet.show(
      context,
      dateStr: ds,
      snapshot: snap,
      onReviewed: _controller.refresh,
    );
  }

  // K44 — Show bottom sheet to pick day mark (REST / TRAVEL / SPECIAL / NORMAL).
  Future<void> _showDayMarkMenu(BuildContext ctx, DateTime date) async {
    final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final existing = await DayMarkRepository.instance.getMark(ds);
    if (!ctx.mounted) return;
    final kind = await showModalBottomSheet<DayMarkKind>(
      context: ctx,
      builder: (_) => _DayMarkSheet(current: existing?.kind ?? DayMarkKind.normal),
    );
    if (kind == null || !mounted) return;
    await DayMarkRepository.instance.setMark(ds, kind);
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getHeroDateTitle(DateTime date) {
    return CalendarDateFormatter.formatSelectedDateTitle(
      date,
      relativeTo: DateTime.now(),
      includeYear: true,
    );
  }

  String _getSubContextTitle(JourneyScale scale, DateTime date) {
    switch (scale) {
      case JourneyScale.agenda:
        return 'نمای برنامه';
      case JourneyScale.day:
        final jalali = Jalali.fromDateTime(date);
        return 'روز ${jalali.formatter.wN}';
      case JourneyScale.week:
        final sat = date.subtract(Duration(days: (date.weekday == 6 ? 0 : (date.weekday == 7 ? 1 : date.weekday + 1))));
        final fri = sat.add(const Duration(days: 6));
        final satJalali = Jalali.fromDateTime(sat);
        final friJalali = Jalali.fromDateTime(fri);
        return 'هفته ${toPersianDigits(satJalali.day.toString())} ${satJalali.formatter.mN} – ${toPersianDigits(friJalali.day.toString())} ${friJalali.formatter.mN}';
      case JourneyScale.month:
        final jalali = Jalali.fromDateTime(date);
        return '${jalali.formatter.mN} ${toPersianDigits(jalali.year.toString())}';
      case JourneyScale.year:
        final jalali = Jalali.fromDateTime(date);
        return 'سال ${toPersianDigits(jalali.year.toString())}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final activeScale = _controller.activeScale;
        final selectedDate = _controller.selectedDate;
        final snapshot = _controller.snapshot;
        final isToday = _isSameDay(selectedDate, DateTime.now());

        final allItems = snapshot?.items ?? const <AgendaItem>[];
        final untimedItems = allItems.where((i) => !i.isTimed).toList();
        final timedItems = allItems.where((i) => i.isTimed).toList();

        final pillViewModel = NowPillViewModel.fromSnapshot(
          snapshot,
          now: DateTime.now(),
          isToday: isToday,
          selectedDate: selectedDate,
        );

        final isScaleChanged = activeScale != _prevScale;
        final isDateBackward = selectedDate.isBefore(_prevDate);
        _prevScale = activeScale;
        _prevDate = selectedDate;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                // Layer 1 Command Deck Header Surface
                Container(
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.85)
                      : theme.colorScheme.surface.withValues(alpha: 0.95),
                  padding: EdgeInsets.only(
                    left: CalendarTokens.spacingXl,
                    right: CalendarTokens.spacingXl,
                    top: MediaQuery.paddingOf(context).top + CalendarTokens.spacingS,
                    bottom: CalendarTokens.spacingM,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [1] Date Hero Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _getHeroDateTitle(selectedDate),
                              style: TextStyle(
                                fontSize: CalendarTokens.textHero,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                fontFamily: 'Vazirmatn',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isToday)
                            Semantics(
                              label: 'پرش به امروز',
                              button: true,
                              child: GestureDetector(
                                onTap: () {
                                  _controller.selectDate(DateTime.now(), scaleToSet: JourneyScale.day);
                                  _autoScrollToNow();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(CalendarTokens.radiusPill),
                                  ),
                                  child: Text(
                                    'امروز',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                      fontFamily: 'Vazirmatn',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      // K40 — Occasion banner (day scale only, first occasion title)
                      if (activeScale == JourneyScale.day)
                        Builder(builder: (ctx) {
                          final occasions = OccasionsCalendarSource.occasionsForDate(selectedDate);
                          if (occasions.isEmpty) return const SizedBox.shrink();
                          final first = occasions.first;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  first.isHoliday ? Icons.celebration_outlined : Icons.info_outline_rounded,
                                  size: 13,
                                  color: first.isHoliday
                                      ? Theme.of(ctx).colorScheme.error
                                      : Theme.of(ctx).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    first.isHoliday ? '${first.title} - تعطیل' : first.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Vazirmatn',
                                      color: first.isHoliday
                                          ? Theme.of(ctx).colorScheme.error
                                          : Theme.of(ctx).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      // K45 — Day mark badge (روز استراحت 🌴 / روز سفر ✈️ / روز خاص ⭐)
                      if (activeScale == JourneyScale.day)
                        FutureBuilder<DayMark?>(
                          future: DayMarkRepository.instance.getMark(
                            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          ),
                          builder: (ctx, snap) {
                            final mark = snap.data;
                            if (mark == null || mark.kind == DayMarkKind.normal) return const SizedBox.shrink();
                            final (label, icon) = switch (mark.kind) {
                              DayMarkKind.rest   => ('روز استراحت 🌴', Icons.beach_access_outlined),
                              DayMarkKind.travel => ('روز سفر ✈️',     Icons.flight_outlined),
                              DayMarkKind.special => ('روز خاص ⭐',    Icons.star_outline),
                              _                   => ('',               Icons.circle),
                            };
                            if (label.isEmpty) return const SizedBox.shrink();
                            return GestureDetector(
                              onTap: () => unawaited(_showDayMarkMenu(ctx, selectedDate)),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(CalendarTokens.radiusPill),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 13, color: Theme.of(ctx).colorScheme.onSecondaryContainer),
                                    const SizedBox(width: 5),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'Vazirmatn',
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(ctx).colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: CalendarTokens.spacingS),

                      // [2] Navigation & Context Action Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 38,
                                height: 38,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.chevron_right, size: 22),
                                  onPressed: () => _controller.navigatePeriod(-1),
                                  tooltip: 'دوره قبل',
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  _getSubContextTitle(activeScale, selectedDate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.55),
                                    fontFamily: 'Vazirmatn',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 38,
                                height: 38,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.chevron_left, size: 22),
                                  onPressed: () => _controller.navigatePeriod(1),
                                  tooltip: 'دوره بعد',
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // K32 — Day Review button
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.rate_review_outlined, size: 20),
                                  tooltip: 'مرور روز',
                                  onPressed: () => unawaited(_openDayReview(selectedDate, snapshot)),
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.space_dashboard_outlined, size: 20),
                                  tooltip: 'خلاصه روز',
                                  onPressed: () {
                                    unawaited(_openSmartPanel());
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.calendar_month_outlined, size: 20),
                                  tooltip: 'برو به تاریخ',
                                  onPressed: () async {
                                    final picked = await GoToDateDialog.show(context, initialDate: selectedDate);
                                    if (picked != null && mounted) {
                                      _controller.selectDate(picked);
                                    }
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.search_rounded, size: 20),
                                  tooltip: 'جستجوی رویدادها',
                                  onPressed: () {
                                    final items = _controller.snapshot?.items ?? allItems;
                                    showSearch(
                                      context: context,
                                      delegate: CalendarSearchDelegate(
                                        items: items,
                                        onItemSelected: _openItemDetails,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.list_alt_rounded, size: 20),
                                      tooltip: 'همه برنامه‌ها',
                                      onPressed: _openAllPlans,
                                    ),
                                    if (_registryHealthCount > 0)
                                      Positioned(
                                        top: 7,
                                        left: 7,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF43F5E),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.refresh, size: 20),
                                  tooltip: 'بازخوانی',
                                  onPressed: _controller.refresh,
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                                  tooltip: 'تنظیمات نمای تقویم',
                                  onSelected: (value) async {
                                    if (value == 'toggle_compression') {
                                      final current = SettingsService.instance.get<bool>('calendar_compress_recurring');
                                      await SettingsService.instance.set('calendar_compress_recurring', !current);
                                      unawaited(_controller.refresh());
                                    }
                                  },
                                  itemBuilder: (ctx) {
                                    final isCompressed = SettingsService.instance.get<bool>('calendar_compress_recurring');
                                    return [
                                      CheckedPopupMenuItem<String>(
                                        value: 'toggle_compression',
                                        checked: isCompressed,
                                        child: const Text(
                                          'فشرده‌سازی تکرارها',
                                          style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                                        ),
                                      ),
                                    ];
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: CalendarTokens.spacingM),

                      // Scale Switcher Segmented Control
                      JourneyScaleSwitcher(
                        activeScale: activeScale,
                        onScaleChanged: _controller.setScale,
                      ),
                    ],
                  ),
                ),

                // Content View with PageTransitionSwitcher
                Expanded(
                  child: PageTransitionSwitcher(
                    duration: CalendarTokens.durationEmphasis,
                    reverse: isDateBackward,
                    transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
                      if (isScaleChanged) {
                        return SharedAxisTransition(
                          animation: primaryAnimation,
                          secondaryAnimation: secondaryAnimation,
                          transitionType: SharedAxisTransitionType.scaled,
                          child: child,
                        );
                      } else {
                        return SharedAxisTransition(
                          animation: primaryAnimation,
                          secondaryAnimation: secondaryAnimation,
                          transitionType: SharedAxisTransitionType.horizontal,
                          child: child,
                        );
                      }
                    },
                    child: _controller.isLoading
                        ? const Center(key: ValueKey('journey_loading'), child: CircularProgressIndicator())
                        : _controller.errorMessage != null
                            ? Center(
                                key: const ValueKey('journey_error'),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('خطا: ${_controller.errorMessage}'),
                                    const SizedBox(height: CalendarTokens.spacingM),
                                    ElevatedButton(
                                      onPressed: _controller.refresh,
                                      child: const Text('بازخوانی'),
                                    ),
                                  ],
                                ),
                              )
                            : KeyedSubtree(
                                key: ValueKey('${activeScale.name}_${selectedDate.year}_${selectedDate.month}_${selectedDate.day}'),
                                child: _buildScaleContent(
                                  activeScale: activeScale,
                                  selectedDate: selectedDate,
                                  snapshot: snapshot,
                                  untimedItems: untimedItems,
                                  timedItems: timedItems,
                                  pillViewModel: pillViewModel,
                                  isToday: isToday,
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScaleContent({
    required JourneyScale activeScale,
    required DateTime selectedDate,
    required DayAgendaSnapshot? snapshot,
    required List<AgendaItem> untimedItems,
    required List<AgendaItem> timedItems,
    required NowPillViewModel pillViewModel,
    required bool isToday,
  }) {
    switch (activeScale) {
      case JourneyScale.agenda:
        return JourneyAgendaView(
          rangeSnapshots: _controller.rangeSnapshots,
          now: DateTime.now(),
          onItemTap: _openItemDetails,
          onAddTap: () => UniversalPlannerSheet.show(
            context: context,
            onSaved: _controller.refresh,
          ),
        );
      case JourneyScale.day:
        return (snapshot == null || snapshot.items.isEmpty)
            ? EmptyDayView(
                date: selectedDate,
                onRefreshRequested: _controller.refresh,
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      // K24 — Day Summary Bar
                      DaySummaryBar(
                        snapshot: snapshot,
                        onTapFreeGaps: _openSmartPanel,
                      ),
                      TimelineUntimedSection(
                        untimedItems: untimedItems,
                        onItemTap: _openItemDetails,
                        onUnscheduleItem: (item) async {
                          await _controller.unscheduleItem(item);
                          if (mounted) {
                            RitmoToast.show(
                              context,
                              'رویداد از زمان‌بندی خارج شد',
                              onUndo: () => _controller.undoLastAction(),
                            );
                          }
                        },
                      ),
                      Expanded(
                        child: TimelineSplitDayView(
                          key: _splitDayKey,
                          items: snapshot.items,
                          isToday: isToday,
                          sleepStartMinutes: snapshot.sleepWindow?.startMinutes,
                          sleepEndMinutes: snapshot.sleepWindow?.endMinutes,
                          highlightedItemId: _controller.highlightedItemId,
                          onItemTap: _openItemDetails,
                          onItemMove: (item, newStartMinutes) async {
                            final dur = item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes;
                            await _controller.scheduleItem(item, newStartMinutes, dur);
                            if (mounted) {
                              final timeStr = TimelineSnappingHelper.minutesToTimeString(newStartMinutes);
                              RitmoToast.show(
                                context,
                                'زمان رویداد به ${toPersianDigits(timeStr)} تغییر یافت',
                                onUndo: () => _controller.undoLastAction(),
                              );
                            }
                          },
                          onItemResize: (item, newDurationMinutes) async {
                            await _controller.commitItemResize(item, newDurationMinutes);
                            if (mounted) {
                              RitmoToast.show(
                                context,
                                'مدت زمان به ${toPersianDigits(newDurationMinutes.toString())} دقیقه تغییر یافت',
                                onUndo: () => _controller.undoLastAction(),
                              );
                            }
                          },
                          onSlotTap: (slotMinutes) {
                            final prefilledTime = TimeOfDay(hour: slotMinutes ~/ 60, minute: slotMinutes % 60);
                            UniversalPlannerSheet.show(
                              context: context,
                              prefilledTime: prefilledTime,
                              onSaved: _controller.refresh,
                            );
                          },
                          onScheduleUntimed: (item, startMinutes, durMinutes) async {
                            await _controller.scheduleItem(item, startMinutes, durMinutes);
                            if (mounted) {
                              final timeStr = TimelineSnappingHelper.minutesToTimeString(startMinutes);
                              RitmoToast.show(
                                context,
                                'رویداد در ساعت ${toPersianDigits(timeStr)} زمان‌بندی شد',
                                onUndo: () => _controller.undoLastAction(),
                              );
                            }
                          },
                          onOverflowTap: _openItemDetails,
                        ),
                      ),
                    ],
                  ),
                  if (pillViewModel.isVisible)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: NowPill(
                          viewModel: pillViewModel,
                          onTapPill: _openSmartPanel,
                          onTapJumpNow: _autoScrollToNow,
                          onTapComplete: pillViewModel.targetItem != null
                              ? () async {
                                  final item = pillViewModel.targetItem!;
                                  await _controller.completeItem(item);
                                  if (mounted) {
                                    ActionFeedback.success(
                                      context,
                                      message: 'رویداد با موفقیت ثبت شد',
                                      dateStr: item.dateStr,
                                    );
                                  }
                                }
                              : null,
                        ),
                      ),
                    ),
                ],
              );
      case JourneyScale.week:
        return JourneyWeekView(
          selectedDate: selectedDate,
          rangeSnapshots: _controller.rangeSnapshots,
          onSelectDate: (date) {
            _controller.selectDate(date, scaleToSet: JourneyScale.day);
          },
        );
      case JourneyScale.month:
        return JourneyMonthView(
          selectedDate: selectedDate,
          rangeSnapshots: _controller.rangeSnapshots,
          onSelectDate: (date) {
            _controller.selectDate(date, scaleToSet: JourneyScale.day);
          },
          onLongPressDayCell: (date) => unawaited(_showDayMarkMenu(context, date)),
        );
      case JourneyScale.year:
        return JourneyYearView(
          selectedDate: selectedDate,
          rangeSnapshots: _controller.rangeSnapshots,
          onSelectMonth: (date) {
            _controller.selectDate(date, scaleToSet: JourneyScale.month);
          },
        );
    }
  }
}

// K44 — Day Mark picker bottom sheet
class _DayMarkSheet extends StatelessWidget {
  const _DayMarkSheet({required this.current});
  final DayMarkKind current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('وضعیت روز', style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'Vazirmatn')),
            const SizedBox(height: 12),
            _markTile(context, DayMarkKind.normal, 'روز عادی', Icons.wb_sunny_outlined),
            _markTile(context, DayMarkKind.rest, 'روز استراحت 🌴', Icons.beach_access_outlined),
            _markTile(context, DayMarkKind.travel, 'روز سفر ✈️', Icons.flight_outlined),
            _markTile(context, DayMarkKind.special, 'روز خاص ⭐', Icons.star_outline),
          ],
        ),
      ),
    );
  }

  Widget _markTile(BuildContext context, DayMarkKind kind, String label, IconData icon) {
    final isSelected = kind == current;
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : null),
      title: Text(label, style: const TextStyle(fontFamily: 'Vazirmatn')),
      trailing: isSelected ? Icon(Icons.check_rounded, color: theme.colorScheme.primary) : null,
      onTap: () => Navigator.of(context).pop(kind),
    );
  }
}
