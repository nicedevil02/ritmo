import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';
import 'package:ritmo/core/domain/agenda/action_feedback.dart';
import 'package:ritmo/core/domain/agenda/action_router.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_snapshot_builder.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/features/calendar/data/day_mark_repository.dart';
import 'package:ritmo/features/calendar/data/day_template_repository.dart';
import 'package:ritmo/features/calendar/data/occasions_calendar_source.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/models/now_pill_view_model.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_date_formatter.dart';
import 'package:ritmo/features/calendar/presentation/widgets/calendar_management_sheet.dart';
import 'package:ritmo/features/calendar/presentation/widgets/calendar_search_delegate.dart';
import 'package:ritmo/features/calendar/presentation/widgets/day_review_sheet.dart';
import 'package:ritmo/features/calendar/presentation/widgets/day_summary_bar.dart';
import 'package:ritmo/features/calendar/presentation/widgets/agenda_degraded_banner.dart';
import 'package:ritmo/features/calendar/presentation/widgets/go_to_date_dialog.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_agenda_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_month_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_scale_switcher.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_smart_panel.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_week_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_year_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/now_pill.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_split_day_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_untimed_section.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/registry/logic/registry_service.dart';
import 'package:ritmo/features/registry/presentation/all_plans_screen.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
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

class _JourneyScreenState extends State<JourneyScreen> with WidgetsBindingObserver {
  late final JourneyController _controller;
  final GlobalKey<TimelineSplitDayViewState> _splitDayKey = GlobalKey<TimelineSplitDayViewState>();
  StreamSubscription<RitmoEvent>? _eventSubscription;

  int _registryHealthCount = 0;

  // Cached DayMark future per date
  String? _cachedDayMarkDateStr;
  Future<DayMark?>? _cachedDayMarkFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = JourneyController();

    final startDate = widget.initialDate ?? DateTime.now();

    if (widget.initialItemId != null) {
      _controller.selectDate(startDate, scaleToSet: JourneyScale.day);
      _controller.loadForActiveScale().then((_) => _focusItemById(widget.initialItemId));
    } else {
      _controller.loadDefaultScale().then((_) {
        _controller.loadForActiveScale().then((_) => _autoScrollToNow());
      });
    }

    _checkHealthIssues();
    _eventSubscription = RitmoEventBus().onEvents.listen((event) {
      _handleNavigationEvent(event);
      if (event.type == 'health_updated' ||
          event.type == 'medicine_logged' ||
          event.type == 'cycle_data_changed' ||
          event.type == 'registry_updated') {
        _checkHealthIssues();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refresh();
      _autoScrollToNow();
    }
  }

  Future<DayMark?> _getDayMarkFuture(String dateStr) {
    if (_cachedDayMarkDateStr == dateStr && _cachedDayMarkFuture != null) {
      return _cachedDayMarkFuture!;
    }
    _cachedDayMarkDateStr = dateStr;
    _cachedDayMarkFuture = DayMarkRepository.instance.getMark(dateStr);
    return _cachedDayMarkFuture!;
  }

  void _invalidateDayMarkCache() {
    _cachedDayMarkDateStr = null;
    _cachedDayMarkFuture = null;
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
    final mode = AppModeService.instance.current;
    final calendarIndex = RitmoShellMetrics.calendarTabIndexFor(mode);
    if (event.type == 'navigate_tab' && event.payload['index'] == calendarIndex) {
      final dateStr = event.payload['date'] as String?;
      final itemId = event.payload['itemId'] as String?;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (dateStr != null) {
          final targetDate = DateKey.parse(dateStr);
          if (targetDate != null) {
            _controller.selectDate(targetDate, scaleToSet: JourneyScale.day);
          } else {
            RitmoLog.error('JourneyScreen', 'Invalid date in FOCUS_ITEM event: $dateStr');
          }
        }

        if (itemId != null) {
          _focusItemById(itemId);
        } else {
          _autoScrollToNow();
        }
      });
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
      onDropItemOnGap: (item, gap) async {
        final dur = min(gap.durationMinutes, item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes);
        await _controller.scheduleItem(item, gap.startMinutes, dur);
      },
    ));
  }

  // Open the day review sheet for the given date.
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

  // Show bottom sheet to pick day mark (REST / TRAVEL / SPECIAL / NORMAL).
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
    _invalidateDayMarkCache();
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveDayAsTemplate() async {
    final controller = TextEditingController(text: 'قالب روز ${_controller.selectedDate.day}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ذخیره به‌عنوان قالب روز'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'نام قالب',
            hintText: 'مثلاً: روز مطالعه، روز کاری فشرده',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;
    final saved = await _controller.saveCurrentDayAsTemplate(name.trim());
    if (!mounted) return;
    if (saved != null) {
      RitmoToast.show(context, 'قالب «${saved.name}» با موفقیت ذخیره شد.');
    } else {
      RitmoToast.show(context, 'آیتم زمان‌داری برای ذخیره در این روز وجود ندارد.', icon: Icons.warning_amber_rounded);
    }
  }

  Future<void> _applyDayTemplate() async {
    final repo = DayTemplateRepository();
    final templates = await repo.getAllTemplates();
    if (!mounted) return;

    if (templates.isEmpty) {
      RitmoToast.show(context, 'هنوز قالبی ذخیره نشده است.', icon: Icons.info_outline);
      return;
    }

    final selectedTemplate = await showModalBottomSheet<DayTemplate>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = ctx.colors;
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.card)),
          ),
          padding: const EdgeInsets.all(RitmoSpacing.lg),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('انتخاب قالب برای اعمال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                const SizedBox(height: RitmoSpacing.md),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    itemBuilder: (listCtx, i) {
                      final t = templates[i];
                      return ListTile(
                        leading: Icon(Icons.dashboard_customize_outlined, color: colors.primary),
                        title: Text(t.name, style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                        subtitle: Text('${toPersianDigits(t.slots.length.toString())} بلاک زمانی', style: TextStyle(color: colors.textSecondary)),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: colors.error, size: 20),
                          onPressed: () async {
                            await repo.deleteTemplate(t.id);
                            if (listCtx.mounted) {
                              Navigator.of(listCtx).pop();
                            }
                            unawaited(_applyDayTemplate());
                          },
                        ),
                        onTap: () => Navigator.of(listCtx).pop(t),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedTemplate == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('اعمال قالب «${selectedTemplate.name}»'),
        content: Text('آیا می‌خواهید زمان‌بندی ${toPersianDigits(selectedTemplate.slots.length.toString())} آیتم این روز مطابق این قالب تنظیم شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('اعمال قالب'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _controller.applyTemplate(selectedTemplate);
      if (!mounted) return;
      if (success) {
        RitmoToast.show(context, 'قالب «${selectedTemplate.name}» با موفقیت اعمال شد.');
      } else {
        RitmoToast.show(context, 'هیچ آیتم منطبقی برای اعمال این قالب در این روز یافت نشد.', icon: Icons.warning_amber_rounded);
      }
    }
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
        final sat = ShamsiWeek.saturdayOf(date);
        final fri = DateKey.addDays(sat, 6);
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
    final colors = context.colors;

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

        final dateKey = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                // ─── Command Deck Header Surface (4 Controls) ───
                Container(
                  color: colors.surfaceElevated,
                  padding: EdgeInsets.only(
                    left: RitmoSpacing.lg,
                    right: RitmoSpacing.lg,
                    top: MediaQuery.paddingOf(context).top + RitmoSpacing.xs,
                    bottom: RitmoSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [Control 1 & Control 4] Tappable Date Hero Title + Today Chip + Period Navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Tappable Date Title opens GoToDateDialog directly
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await GoToDateDialog.show(context, initialDate: selectedDate);
                                if (picked != null && mounted) {
                                  _controller.selectDate(picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(RitmoRadius.card),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _getHeroDateTitle(selectedDate),
                                        style: TextStyle(
                                          fontSize: 22.0,
                                          fontWeight: FontWeight.bold,
                                          color: colors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color: colors.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Control 4: Animated Today Chip (visible only when !isToday)
                          AnimatedOpacity(
                            opacity: isToday ? 0.0 : 1.0,
                            duration: RitmoMotion.state,
                            child: isToday
                                ? const SizedBox.shrink()
                                : Semantics(
                                    label: 'پرش به امروز',
                                    button: true,
                                    child: GestureDetector(
                                      onTap: () {
                                        _controller.selectDate(DateTime.now(), scaleToSet: JourneyScale.day);
                                        _autoScrollToNow();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(
                                          color: colors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(RitmoRadius.pill),
                                          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          'امروز',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),

                          // Control: Undo Action Button (CAL-44)
                          if (_controller.canUndo)
                            IconButton(
                              icon: const Icon(Icons.undo_rounded, size: 20),
                              tooltip: 'بازگردانی (${_controller.lastUndoDescription ?? ''})',
                              color: colors.textPrimary,
                              onPressed: _controller.undoLastAction,
                            ),

                          // Control: Redo Action Button (CAL-44)
                          if (_controller.canRedo)
                            IconButton(
                              icon: const Icon(Icons.redo_rounded, size: 20),
                              tooltip: 'انجام مجدد (${_controller.lastRedoDescription ?? ''})',
                              color: colors.textPrimary,
                              onPressed: _controller.redoLastAction,
                            ),

                          // Control 3: Search Button
                          IconButton(
                            icon: const Icon(Icons.search_rounded, size: 22),
                            tooltip: 'جستجوی رویدادها',
                            color: colors.textPrimary,
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

                          // Management Sheet Button (Three dots ⋯)
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.tune_rounded, size: 22),
                                tooltip: 'مدیریت و تنظیمات تقویم',
                                color: colors.textPrimary,
                                onPressed: () => CalendarManagementSheet.show(
                                  context: context,
                                  selectedDate: selectedDate,
                                  currentScale: activeScale,
                                  healthIssueCount: _registryHealthCount,
                                  onSelectScale: _controller.setScale,
                                  onOpenDayReview: () => _openDayReview(selectedDate, snapshot),
                                  onOpenDayMarkPicker: () => _showDayMarkMenu(context, selectedDate),
                                  onOpenAllPlans: _openAllPlans,
                                  onRefresh: _controller.refresh,
                                  onSaveDayTemplate: _saveDayAsTemplate,
                                  onApplyDayTemplate: _applyDayTemplate,
                                ),
                              ),
                              if (_registryHealthCount > 0)
                                Positioned(
                                  top: 8,
                                  left: 8,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: colors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Occasion / Holiday banner (day scale)
                      if (activeScale == JourneyScale.day)
                        Builder(builder: (ctx) {
                          final occasions = OccasionsCalendarSource.occasionsForDate(selectedDate);
                          if (occasions.isEmpty) return const SizedBox.shrink();
                          final first = occasions.first;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  first.isHoliday ? Icons.celebration_outlined : Icons.info_outline_rounded,
                                  size: 13,
                                  color: first.isHoliday ? colors.error : colors.textTertiary,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    first.isHoliday ? '${first.title} - تعطیل' : first.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: first.isHoliday ? colors.error : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      // Day mark badge (استراحت 🌴 / سفر ✈️ / خاص ⭐)
                      if (activeScale == JourneyScale.day)
                        FutureBuilder<DayMark?>(
                          future: _getDayMarkFuture(dateKey),
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
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(RitmoRadius.badge),
                                  border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 13, color: colors.primary),
                                    const SizedBox(width: 5),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      // Navigation arrows row + Sub-context subtitle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
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
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.chevron_left, size: 22),
                                  onPressed: () => _controller.navigatePeriod(1),
                                  tooltip: 'دوره بعد',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: RitmoSpacing.xs),

                      // Shared degraded warning banner
                      AgendaDegradedBanner(
                        degradedDomains: _controller.activeDegradedSources,
                        onRetry: _controller.refresh,
                      ),

                      // [Control 2] Scale Switcher Segmented Control
                      JourneyScaleSwitcher(
                        activeScale: activeScale,
                        onScaleChanged: _controller.setScale,
                      ),
                    ],
                  ),
                ),

                // ─── Non-blocking Overlap Warning & Smart Gap Suggestion Banner (CAL-43) ───
                if (_controller.warningMessage != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md, vertical: RitmoSpacing.sm),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: colors.warning),
                        const SizedBox(width: RitmoSpacing.sm),
                        Expanded(
                          child: Text(
                            _controller.warningMessage!,
                            style: TextStyle(fontSize: 12, color: colors.textPrimary),
                          ),
                        ),
                        if (_controller.suggestedSlot != null) ...[
                          const SizedBox(width: RitmoSpacing.sm),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              final slot = _controller.suggestedSlot!;
                              final formattedTime = TimeOfDayMinutes.format(slot.startMinutes);
                              final targetItem = _controller.snapshot?.items.firstWhere(
                                (i) => i.isTimed,
                                orElse: () => _controller.snapshot!.items.first,
                              );
                              if (targetItem != null) {
                                _controller.commitItemDrag(targetItem, formattedTime);
                              }
                            },
                            child: Text(
                              'انتقال به ${toPersianDigits(TimeOfDayMinutes.format(_controller.suggestedSlot!.startMinutes))}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // ─── Main Content Viewport with Pull-to-Refresh & Swipe Gestures ───
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _invalidateDayMarkCache();
                      await _controller.refresh();
                    },
                    child: _controller.isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: colors.primary,
                            ),
                          )
                        : _controller.errorMessage != null
                            ? Center(
                                key: const ValueKey('journey_error'),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('خطا: ${_controller.errorMessage}', style: TextStyle(color: colors.error)),
                                    const SizedBox(height: RitmoSpacing.md),
                                    RitmoSecondaryButton(
                                      onPressed: _controller.refresh,
                                      label: 'تلاش دوباره',
                                    ),
                                  ],
                                ),
                              )
                            : GestureDetector(
                                onHorizontalDragEnd: (details) {
                                  if (details.primaryVelocity == null) return;
                                  // RTL awareness: swipe left = next (period 1), swipe right = prev (period -1)
                                  if (details.primaryVelocity! < -150) {
                                    _controller.navigatePeriod(1);
                                  } else if (details.primaryVelocity! > 150) {
                                    _controller.navigatePeriod(-1);
                                  }
                                },
                                behavior: HitTestBehavior.translucent,
                                child: KeyedSubtree(
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
    final colors = context.colors;

    switch (activeScale) {
      case JourneyScale.agenda:
        return JourneyAgendaView(
          rangeSnapshots: _controller.rangeSnapshots,
          now: DateTime.now(),
          onItemTap: _openItemDetails,
          onDoneItem: (item) async {
            await _controller.completeItem(item);
          },
          onPostponeItem: (item) async {
            await _controller.postponeItem(item, days: 1);
          },
          onAddTap: () => UniversalPlannerSheet.show(
            context: context,
            onSaved: _controller.refresh,
          ),
          errorMessage: _controller.errorMessage,
          agendaLoadStatus: _controller.agendaLoadStatus,
          onRetry: _controller.loadForActiveScale,
          olderOverdueCount: _controller.olderOverdueCount,
          daysBack: JourneyController.agendaWindowDaysBack,
          onExpandOverdue: _controller.expandAgendaOverdue,
        );

      case JourneyScale.day:
        final hasItems = snapshot != null && snapshot.items.isNotEmpty;
        return Stack(
          children: [
            Column(
              children: [
                if (hasItems) ...[
                  // Day Summary Bar
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
                ] else ...[
                  // Empty day banner card inside timeline header
                  Container(
                    margin: const EdgeInsets.all(RitmoSpacing.md),
                    padding: const EdgeInsets.all(RitmoSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'برای این روز برنامه‌ای ثبت نشده',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'با لمس طولانی روی ساعت دلخواه، برنامه اضافه کنید',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        RitmoPrimaryButton(
                          label: 'افزودن',
                          icon: Icons.add_rounded,
                          fullWidth: false,
                          onPressed: () => UniversalPlannerSheet.show(
                            context: context,
                            onSaved: _controller.refresh,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Timeline Split Day View (Always Rendered)
                Expanded(
                  child: TimelineSplitDayView(
                    key: _splitDayKey,
                    items: snapshot?.items ?? const [],
                    isToday: isToday,
                    sleepStartMinutes: snapshot?.sleepWindow?.startMinutes,
                    sleepEndMinutes: snapshot?.sleepWindow?.endMinutes,
                    highlightedItemId: _controller.highlightedItemId,
                    onItemTap: _openItemDetails,
                    onItemMove: (item, newStartMinutes) async {
                      final timeStr = TimeOfDayMinutes.format(newStartMinutes);
                      await _controller.commitItemDrag(
                        item,
                        timeStr,
                        scope: CalendarEditScope.thisDayOnly,
                      );
                      if (mounted) {
                        RitmoToast.show(
                          context,
                          'فقط برای امروز جابه‌جا شد',
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
                        final timeStr = TimeOfDayMinutes.format(startMinutes);
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

            // NowPill positioned above bottom nav bar (Section 4.7)
            if (pillViewModel.isVisible)
              Positioned(
                bottom: RitmoShellMetrics.navBarHeight + RitmoShellMetrics.navBarBottomGap + 8,
                left: RitmoSpacing.lg,
                right: RitmoSpacing.lg,
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
          onMoveItemToDate: _controller.moveItemToDate,
        );

      case JourneyScale.month:
        return JourneyMonthView(
          selectedDate: selectedDate,
          rangeSnapshots: _controller.rangeSnapshots,
          onSelectDate: (date) {
            _controller.selectDate(date, scaleToSet: JourneyScale.day);
          },
          onLongPressDayCell: (date) {
            UniversalPlannerSheet.show(
              context: context,
              onSaved: _controller.refresh,
            );
          },
          onMoveItemToDate: _controller.moveItemToDate,
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

// Day Mark picker bottom sheet
class _DayMarkSheet extends StatelessWidget {
  const _DayMarkSheet({required this.current});
  final DayMarkKind current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: RitmoSpacing.md),
              decoration: BoxDecoration(
                color: colors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'وضعیت روز',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: RitmoSpacing.sm),
            _markTile(context, DayMarkKind.normal, 'روز عادی', Icons.wb_sunny_outlined, colors),
            _markTile(context, DayMarkKind.rest, 'روز استراحت 🌴', Icons.beach_access_outlined, colors),
            _markTile(context, DayMarkKind.travel, 'روز سفر ✈️', Icons.flight_outlined, colors),
            _markTile(context, DayMarkKind.special, 'روز خاص ⭐', Icons.star_outline, colors),
          ],
        ),
      ),
    );
  }

  Widget _markTile(BuildContext context, DayMarkKind kind, String label, IconData icon, RitmoColors colors) {
    final isSelected = kind == current;
    return ListTile(
      leading: Icon(icon, color: isSelected ? colors.primary : colors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? colors.primary : colors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_rounded, color: colors.primary) : null,
      onTap: () => Navigator.of(context).pop(kind),
    );
  }
}
