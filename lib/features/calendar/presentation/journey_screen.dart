import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';
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
import 'package:ritmo/features/calendar/presentation/widgets/timeline_split_day_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/timeline_untimed_section.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/registry/logic/registry_service.dart';
import 'package:ritmo/features/registry/presentation/all_plans_screen.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
import 'package:shamsi_date/shamsi_date.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, this.initialDate, this.initialItemId});

  final DateTime? initialDate;
  final String? initialItemId;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen>
    with WidgetsBindingObserver {
  late final JourneyController _controller;
  final GlobalKey<TimelineSplitDayViewState> _splitDayKey =
      GlobalKey<TimelineSplitDayViewState>();
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
    _controller.addListener(_onControllerChanged);

    final startDate = widget.initialDate ?? DateTime.now();

    if (widget.initialItemId != null) {
      _controller.selectDate(startDate, scaleToSet: JourneyScale.day);
      _controller.loadForActiveScale().then(
        (_) => _focusItemById(widget.initialItemId),
      );
    } else {
      _controller.loadDefaultScale().then((_) {
        if (_controller.snapshot == null && _controller.rangeSnapshots.isEmpty) {
          _controller.loadForActiveScale().then((_) => _autoScrollToNow());
        } else {
          _autoScrollToNow();
        }
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

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.actionErrorMessage != null) {
      final msg = _controller.actionErrorMessage!;
      _controller.clearActionError();
      RitmoToast.show(
        context,
        msg,
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.error,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      _invalidateDayMarkCache();
      final isDateChanged = !_isSameDay(_controller.selectedDate, now);

      if (isDateChanged) {
        if (_controller.activeScale == JourneyScale.day) {
          _controller.selectDate(now);
        } else if (_controller.activeScale == JourneyScale.agenda) {
          _controller.loadAgendaRange(anchorDate: now);
        } else {
          _controller.refresh();
        }
      } else {
        _controller.refresh();
      }
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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const AllPlansScreen()))
        .then((_) => _checkHealthIssues());
  }

  void _handleNavigationEvent(RitmoEvent event) {
    if (!mounted) return;
    final mode = AppModeService.instance.current;
    final calendarIndex = RitmoShellMetrics.calendarTabIndexFor(mode);
    if (event.type == 'navigate_tab' &&
        event.payload['index'] == calendarIndex) {
      final dateStr = event.payload['date'] as String?;
      final itemId = event.payload['itemId'] as String?;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (dateStr != null) {
          final targetDate = DateKey.parse(dateStr);
          if (targetDate != null) {
            _controller.selectDate(targetDate, scaleToSet: JourneyScale.day);
          } else {
            RitmoLog.error(
              'JourneyScreen',
              'Invalid date in FOCUS_ITEM event: $dateStr',
            );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = DateTime.now();
      final isToday = _isSameDay(_controller.selectedDate, now);
      if (isToday && _controller.activeScale == JourneyScale.day) {
        final nowMinutes = (now.hour * 60) + now.minute;
        if (_splitDayKey.currentState != null) {
          _scrollToMinutesValue(nowMinutes);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _splitDayKey.currentState != null) {
              _scrollToMinutesValue(nowMinutes);
            }
          });
        }
      }
    });
  }

  void _scrollToMinutesValue(int minutes) {
    _splitDayKey.currentState?.scrollToMinutes(minutes);
  }

  int? _tryParseMinutes(String? timeStr) {
    return TimeOfDayMinutes.tryParse(timeStr);
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

    ActionRouter.open(
      context,
      item: item,
      onChanged: () => _controller.refresh(),
    );
  }

  Future<void> _openSmartPanel() async {
    var snapshot = _controller.snapshot;
    if (snapshot == null) {
      final dateKey = DateKey.of(_controller.selectedDate);
      snapshot = _controller.rangeSnapshots[dateKey];
    }

    if (snapshot == null) {
      final dayAgenda = await DayAgendaService.instance.agendaForDate(
        _controller.selectedDate,
      );
      if (!mounted) return;
      snapshot = const DayAgendaSnapshotBuilder().buildSnapshot(dayAgenda);
    }

    if (!mounted) return;

    unawaited(
      JourneySmartPanel.showAsBottomSheet(
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
          final dur = min(
            gap.durationMinutes,
            item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes,
          );
          await _controller.scheduleItem(item, gap.startMinutes, dur);
        },
      ),
    );
  }

  // Open the day review sheet for the given date.
  Future<void> _openDayReview(
    DateTime date,
    DayAgendaSnapshot? existingSnapshot,
  ) async {
    final ds = DateKey.of(date);
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
    final ds = DateKey.of(date);
    final existing = await DayMarkRepository.instance.getMark(ds);
    if (!ctx.mounted) return;
    final kind = await showModalBottomSheet<DayMarkKind>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _DayMarkSheet(current: existing?.kind ?? DayMarkKind.normal),
    );
    if (kind == null || !mounted) return;
    _invalidateDayMarkCache();
    await _controller.setDayMark(kind);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _eventSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveDayAsTemplate() async {
    final j = Jalali.fromDateTime(_controller.selectedDate);
    final controller = TextEditingController(
      text: 'قالب روز ${toPersianDigits(j.day.toString())} ${j.formatter.mN}',
    );
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
      RitmoToast.show(
        context,
        'آیتم زمان‌داری برای ذخیره در این روز وجود ندارد.',
        icon: Icons.warning_amber_rounded,
      );
    }
  }

  Future<void> _applyDayTemplate() async {
    final repo = DayTemplateRepository();
    final templates = await repo.getAllTemplates();
    if (!mounted) return;

    if (templates.isEmpty) {
      RitmoToast.show(
        context,
        'هنوز قالبی ذخیره نشده است.',
        icon: Icons.info_outline,
      );
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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RitmoRadius.card),
            ),
          ),
          padding: const EdgeInsets.all(RitmoSpacing.lg),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'انتخاب قالب برای اعمال',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: RitmoSpacing.md),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: templates.length,
                    itemBuilder: (listCtx, i) {
                      final t = templates[i];
                      return ListTile(
                        leading: Icon(
                          Icons.dashboard_customize_outlined,
                          color: colors.primary,
                        ),
                        title: Text(
                          t.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${toPersianDigits(t.slots.length.toString())} بلاک زمانی',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colors.error,
                            size: 20,
                          ),
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
        content: Text(
          'آیا می‌خواهید زمان‌بندی ${toPersianDigits(selectedTemplate.slots.length.toString())} آیتم این روز مطابق این قالب تنظیم شود؟',
        ),
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
        RitmoToast.show(
          context,
          'قالب «${selectedTemplate.name}» با موفقیت اعمال شد.',
        );
      } else {
        RitmoToast.show(
          context,
          'هیچ آیتم منطبقی برای اعمال این قالب در این روز یافت نشد.',
          icon: Icons.warning_amber_rounded,
        );
      }
    }
  }

  Widget _buildQuickDayMarkButton(RitmoColors colors) {
    final mark = _controller.currentDayMark;
    IconData icon;
    Color iconColor;
    String label;

    switch (mark) {
      case DayMarkKind.rest:
        icon = Icons.spa_rounded;
        iconColor = colors.success;
        label = 'روز استراحت';
        break;
      case DayMarkKind.travel:
        icon = Icons.flight_takeoff_rounded;
        iconColor = colors.warning;
        label = 'روز سفر';
        break;
      case DayMarkKind.special:
        icon = Icons.star_rounded;
        iconColor = colors.accent;
        label = 'روز ویژه';
        break;
      case DayMarkKind.normal:
        icon = Icons.bedtime_outlined;
        iconColor = colors.textSecondary;
        label = 'روز عادی';
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<DayMarkKind>(
      tooltip: 'وضعیت روز ($label)',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222834) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFCBD3DC),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFFC7CFDA).withValues(alpha: 0.75),
              offset: const Offset(1, 1.8),
              blurRadius: 3,
            ),
            BoxShadow(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white,
              offset: const Offset(-1, -1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
      onSelected: (newKind) async {
        _invalidateDayMarkCache();
        await _controller.setDayMark(newKind);
        if (mounted) {
          final desc = newKind == DayMarkKind.rest
              ? 'روز استراحت فعال شد'
              : (newKind == DayMarkKind.travel
                    ? 'روز سفر فعال شد'
                    : 'وضعیت به روز عادی تغییر یافت');
          RitmoToast.show(
            context,
            desc,
            onUndo: () => _controller.undoLastAction(),
          );
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: DayMarkKind.normal,
          child: Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                size: 18,
                color: mark == DayMarkKind.normal
                    ? colors.primary
                    : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text('عادی (همه‌چیز فعال)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: DayMarkKind.rest,
          child: Row(
            children: [
              Icon(
                Icons.spa_rounded,
                size: 18,
                color: mark == DayMarkKind.rest
                    ? colors.success
                    : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text('استراحت (فقط ضروری)'),
            ],
          ),
        ),
        PopupMenuItem(
          value: DayMarkKind.travel,
          child: Row(
            children: [
              Icon(
                Icons.flight_takeoff_rounded,
                size: 18,
                color: mark == DayMarkKind.travel
                    ? colors.warning
                    : colors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text('سفر (فقط ضروری)'),
            ],
          ),
        ),
      ],
    );
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
        return ShamsiWeek.nameOf(jalali.weekDay);
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

        final dateKey = DateKey.of(selectedDate);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                // ─── Command Deck Header Surface (4 Controls) ───
                RitmoGlassHeader(
                  borderRadius: BorderRadius.zero,
                  border: Border(
                    bottom: BorderSide(
                      color: context.isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : colors.border.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: RitmoSpacing.md,
                    right: RitmoSpacing.md,
                    top: MediaQuery.paddingOf(context).top + 4,
                    bottom: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // [Control 1 & Navigation] Hero Date + Weekday + Period Nav Chevrons + Action Buttons
                      Row(
                        children: [
                          // Previous period chevron (pointing right in RTL towards past)
                          _NeumorphicHeaderIconButton(
                            icon: Icons.chevron_left,
                            size: 19,
                            tooltip: 'دوره قبل',
                            onPressed: () => _controller.navigatePeriod(-1),
                          ),
                          const SizedBox(width: 4),

                          // Tappable Date Title opens GoToDateDialog directly
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await GoToDateDialog.show(
                                  context,
                                  initialDate: selectedDate,
                                );
                                if (picked != null && mounted) {
                                  await _controller.selectDate(picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _getHeroDateTitle(selectedDate),
                                        style: TextStyle(
                                          fontSize: 13.0,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                          color: colors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: colors.textTertiary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Next period chevron (pointing left in RTL towards future)
                          _NeumorphicHeaderIconButton(
                            icon: Icons.chevron_right,
                            size: 19,
                            tooltip: 'دوره بعد',
                            onPressed: () => _controller.navigatePeriod(1),
                          ),
                          const SizedBox(width: 4),

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
                                      onTap: () async {
                                        await _controller.selectDate(
                                          DateTime.now(),
                                          scaleToSet: JourneyScale.day,
                                        );
                                        _autoScrollToNow();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        margin: const EdgeInsets.only(left: 4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF6366F1),
                                              Color(0xFF4F46E5),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                              offset: const Offset(0, 1.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Text(
                                          'امروز',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),

                          // Control: Undo Action Button (CAL-44)
                          if (_controller.canUndo) ...[
                            const SizedBox(width: 4),
                            _NeumorphicHeaderIconButton(
                              icon: Icons.undo_rounded,
                              size: 17,
                              tooltip:
                                  'بازگردانی (${_controller.lastUndoDescription ?? ''})',
                              onPressed: _controller.undoLastAction,
                            ),
                          ],

                          // Control: Redo Action Button (CAL-44)
                          if (_controller.canRedo) ...[
                            const SizedBox(width: 4),
                            _NeumorphicHeaderIconButton(
                              icon: Icons.redo_rounded,
                              size: 17,
                              tooltip:
                                  'انجام مجدد (${_controller.lastRedoDescription ?? ''})',
                              onPressed: _controller.redoLastAction,
                            ),
                          ],

                          const SizedBox(width: 4),

                          // Quick Day Mark Status Button (CAL-49)
                          _buildQuickDayMarkButton(colors),

                          const SizedBox(width: 4),

                          // Control 3: Search Button
                          _NeumorphicHeaderIconButton(
                            icon: Icons.search_rounded,
                            size: 18,
                            tooltip: 'جستجوی رویدادها',
                            onPressed: () {
                              final items =
                                  _controller.snapshot?.items ?? allItems;
                              showSearch(
                                context: context,
                                delegate: CalendarSearchDelegate(
                                  items: items,
                                  onItemSelected: _openItemDetails,
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 4),

                          // Management Sheet Button (Three dots ⋯)
                          _NeumorphicHeaderIconButton(
                            icon: Icons.tune_rounded,
                            size: 18,
                            tooltip: 'مدیریت و تنظیمات تقویم',
                            badgeCount: _registryHealthCount,
                            onPressed: () => CalendarManagementSheet.show(
                              context: context,
                              selectedDate: selectedDate,
                              currentScale: activeScale,
                              healthIssueCount: _registryHealthCount,
                              onSelectScale: _controller.setScale,
                              onOpenDayReview: () =>
                                  _openDayReview(selectedDate, snapshot),
                              onOpenDayMarkPicker: () =>
                                  _showDayMarkMenu(context, selectedDate),
                              onOpenAllPlans: _openAllPlans,
                              onRefresh: _controller.refresh,
                              onSaveDayTemplate: _saveDayAsTemplate,
                              onApplyDayTemplate: _applyDayTemplate,
                            ),
                          ),
                        ],
                      ),

                      // Subtitle Line: Dynamic Weekday - Occasion / Holiday banner
                      Builder(
                        builder: (ctx) {
                          final occasions =
                              OccasionsCalendarSource.occasionsForDate(
                                selectedDate,
                              );
                          final occasion =
                              (activeScale == JourneyScale.day &&
                                  occasions.isNotEmpty)
                              ? occasions.first
                              : null;
                          final subTitle = _getSubContextTitle(
                            activeScale,
                            selectedDate,
                          );
                          final fullSubTitle = occasion != null
                              ? (subTitle.isNotEmpty
                                    ? '$subTitle - ${occasion.title}${occasion.isHoliday && !occasion.title.contains('تعطیل') ? ' (تعطیل)' : ''}'
                                    : (occasion.isHoliday && !occasion.title.contains('تعطیل')
                                          ? '${occasion.title} (تعطیل)'
                                          : occasion.title))
                              : subTitle;

                          if (fullSubTitle.isEmpty)
                            return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.only(top: 1, bottom: 2),
                            child: Row(
                              children: [
                                if (occasion != null) ...[
                                  Icon(
                                    occasion.isHoliday
                                        ? Icons.celebration_outlined
                                        : Icons.info_outline_rounded,
                                    size: 11,
                                    color: occasion.isHoliday
                                        ? colors.error
                                        : colors.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    fullSubTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.0,
                                      fontWeight: FontWeight.w600,
                                      color: occasion?.isHoliday == true
                                          ? colors.error
                                          : colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Day mark badge (استراحت 🌴 / سفر ✈️ / خاص ⭐)
                      if (activeScale == JourneyScale.day)
                        FutureBuilder<DayMark?>(
                          future: _getDayMarkFuture(dateKey),
                          builder: (ctx, snap) {
                            final mark = snap.data;
                            if (mark == null || mark.kind == DayMarkKind.normal)
                              return const SizedBox.shrink();
                            final (label, icon) = switch (mark.kind) {
                              DayMarkKind.rest => (
                                'روز استراحت 🌴',
                                Icons.beach_access_outlined,
                              ),
                              DayMarkKind.travel => (
                                'روز سفر ✈️',
                                Icons.flight_outlined,
                              ),
                              DayMarkKind.special => (
                                'روز خاص ⭐',
                                Icons.star_outline,
                              ),
                              _ => ('', Icons.circle),
                            };
                            if (label.isEmpty) return const SizedBox.shrink();
                            return GestureDetector(
                              onTap: () => unawaited(
                                _showDayMarkMenu(ctx, selectedDate),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(
                                    RitmoRadius.badge,
                                  ),
                                  border: Border.all(
                                    color: colors.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 11, color: colors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 10.5,
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

                      const SizedBox(height: 4),

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
                    margin: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.md,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.md,
                      vertical: RitmoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(
                        color: colors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: colors.warning,
                        ),
                        const SizedBox(width: RitmoSpacing.sm),
                        Expanded(
                          child: Text(
                            _controller.warningMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (_controller.suggestedSlot != null) ...[
                          const SizedBox(width: RitmoSpacing.sm),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              final slot = _controller.suggestedSlot!;
                              final formattedTime = TimeOfDayMinutes.format(
                                slot.startMinutes,
                              );
                              final targetId =
                                  _controller.pendingSuggestionItemId;
                              final allItems = _controller.snapshot?.items ??
                                  _controller.rangeSnapshots.values
                                      .expand((s) => s.items)
                                      .toList();
                              if (allItems.isNotEmpty) {
                                final targetItem = allItems.firstWhere(
                                  (i) => i.id == targetId,
                                  orElse: () => allItems.firstWhere(
                                    (i) => i.isTimed,
                                    orElse: () => allItems.first,
                                  ),
                                );
                                _controller.commitItemDrag(
                                  targetItem,
                                  formattedTime,
                                );
                              }
                            },
                            child: Text(
                              'انتقال به ${toPersianDigits(TimeOfDayMinutes.format(_controller.suggestedSlot!.startMinutes))}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _controller.clearWarningMessage,
                        ),
                      ],
                    ),
                  ),

                // ─── Day Mark Banner (CAL-49: REST / TRAVEL Day Banner) ───
                if (_controller.currentDayMark == DayMarkKind.rest ||
                    _controller.currentDayMark == DayMarkKind.travel)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.md,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.md,
                      vertical: RitmoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (_controller.currentDayMark == DayMarkKind.rest
                                  ? colors.success
                                  : colors.warning)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      border: Border.all(
                        color:
                            (_controller.currentDayMark == DayMarkKind.rest
                                    ? colors.success
                                    : colors.warning)
                                .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _controller.currentDayMark == DayMarkKind.rest
                              ? Icons.spa_rounded
                              : Icons.flight_takeoff_rounded,
                          size: 18,
                          color: _controller.currentDayMark == DayMarkKind.rest
                              ? colors.success
                              : colors.warning,
                        ),
                        const SizedBox(width: RitmoSpacing.sm),
                        Expanded(
                          child: Text(
                            _controller.currentDayMark == DayMarkKind.rest
                                ? 'روز استراحت — فقط موارد ضروری فعال هستند'
                                : 'روز سفر — فقط موارد ضروری فعال هستند',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () =>
                              _controller.setDayMark(DayMarkKind.normal),
                          child: Text(
                            'تغییر به عادی',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  _controller.currentDayMark == DayMarkKind.rest
                                  ? colors.success
                                  : colors.warning,
                            ),
                          ),
                        ),
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
                        ? LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    height: constraints.maxHeight,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                          )
                        : _controller.loadErrorMessage != null
                        ? LayoutBuilder(
                            builder: (context, constraints) =>
                                SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    height: constraints.maxHeight,
                                    child: Center(
                                      key: const ValueKey('journey_error'),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'خطا: ${_controller.loadErrorMessage}',
                                            style: TextStyle(
                                              color: colors.error,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: RitmoSpacing.md,
                                          ),
                                          RitmoSecondaryButton(
                                            onPressed: _controller.refresh,
                                            label: 'تلاش دوباره',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                          )
                        : GestureDetector(
                            onHorizontalDragEnd:
                                activeScale == JourneyScale.agenda
                                ? null
                                : (details) {
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
                              key: ValueKey(
                                '${activeScale.name}_${selectedDate.year}_${selectedDate.month}_${selectedDate.day}',
                              ),
                              child: _buildScaleContent(
                                activeScale: activeScale,
                                selectedDate: selectedDate,
                                snapshot: snapshot,
                                untimedItems: untimedItems,
                                timedItems: timedItems,
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
          errorMessage: _controller.loadErrorMessage,
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
                      await _controller.commitItemResize(
                        item,
                        newDurationMinutes,
                      );
                      if (mounted) {
                        RitmoToast.show(
                          context,
                          'مدت زمان به ${toPersianDigits(newDurationMinutes.toString())} دقیقه تغییر یافت',
                          onUndo: () => _controller.undoLastAction(),
                        );
                      }
                    },
                    onSlotTap: (slotMinutes) {
                      final prefilledTime = TimeOfDay(
                        hour: slotMinutes ~/ 60,
                        minute: slotMinutes % 60,
                      );
                      UniversalPlannerSheet.show(
                        context: context,
                        prefilledTime: prefilledTime,
                        onSaved: _controller.refresh,
                      );
                    },
                    onScheduleUntimed: (item, startMinutes, durMinutes) async {
                      await _controller.scheduleItem(
                        item,
                        startMinutes,
                        durMinutes,
                      );
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
          ],
        );

      case JourneyScale.week:
        return JourneyWeekView(
          selectedDate: selectedDate,
          rangeSnapshots: _controller.rangeSnapshots,
          onSelectDate: (date) {
            _controller.selectDate(date, scaleToSet: JourneyScale.day);
          },
          onItemTap: _openItemDetails,
          onSlotTap: (date, slotMinutes) {
            final prefilledTime = TimeOfDay(
              hour: slotMinutes ~/ 60,
              minute: slotMinutes % 60,
            );
            UniversalPlannerSheet.show(
              context: context,
              prefilledTime: prefilledTime,
              onSaved: _controller.refresh,
            );
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
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(
      top: Radius.circular(RitmoRadius.sheet),
    );

    final content = SafeArea(
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
                color: colors.textSecondary.withValues(alpha: 0.2),
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
            _markTile(
              context,
              DayMarkKind.normal,
              'روز عادی',
              Icons.wb_sunny_outlined,
              colors,
            ),
            _markTile(
              context,
              DayMarkKind.rest,
              'روز استراحت 🌴',
              Icons.beach_access_outlined,
              colors,
            ),
            _markTile(
              context,
              DayMarkKind.travel,
              'روز سفر ✈️',
              Icons.flight_outlined,
              colors,
            ),
            _markTile(
              context,
              DayMarkKind.special,
              'روز خاص ⭐',
              Icons.star_outline,
              colors,
            ),
          ],
        ),
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );

    if (!isGlass) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return ClipRRect(
      borderRadius: sheetRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: sheetRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 1.0,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: sheetRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: sheetBody,
          ),
        ),
      ),
    );
  }

  Widget _markTile(
    BuildContext context,
    DayMarkKind kind,
    String label,
    IconData icon,
    RitmoColors colors,
  ) {
    final isSelected = kind == current;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colors.primary : colors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? colors.primary : colors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: colors.primary)
          : null,
      onTap: () => Navigator.of(context).pop(kind),
    );
  }
}

class _NeumorphicHeaderIconButton extends StatelessWidget {
  const _NeumorphicHeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 18.0,
    this.tooltip,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? tooltip;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;

    final btn = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222834) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFCBD3DC),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFFC7CFDA).withValues(alpha: 0.75),
            offset: const Offset(1, 1.8),
            blurRadius: 3,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.white,
            offset: const Offset(-1, -1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              size: size,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.88)
                  : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );

    if (badgeCount > 0) {
      final badgedBtn = Stack(
        clipBehavior: Clip.none,
        children: [
          btn,
          Positioned(
            top: 2,
            left: 2,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF222834) : Colors.white,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      );
      final tip = tooltip;
      if (tip != null && tip.isNotEmpty) {
        return Tooltip(message: tip, child: badgedBtn);
      }
      return badgedBtn;
    }

    final tip = tooltip;
    if (tip != null && tip.isNotEmpty) {
      return Tooltip(message: tip, child: btn);
    }
    return btn;
  }
}

