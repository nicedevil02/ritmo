// lib/features/supplementary_sports/presentation/ss_movement_tab_screen.dart
//
// فاز ۱ — بازطراحی ناوبری بخش حرکت
// چهار زیرتب: «امروز»، «ورزش‌ها»، «برنامه»، «پیشرفت»
// سه دکمهٔ اصلی: شروع الان، برنامه‌ریزی، ثبت گذشته

import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_suggester.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_analytics_screen.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_log_sheet.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/weekly_budget_card.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart';
import 'package:ritmo/features/supplementary_sports/supplementary_sports_theme.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_session_repository.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_tokens.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/movement_session_screen.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_kind_selector.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_campaign.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_campaign_repository.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';

// ─── Public entry point ──────────────────────────────────────────────────────

class SSMovementTabScreen extends StatefulWidget {
  const SSMovementTabScreen({super.key, this.onNavigateToTab});
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<SSMovementTabScreen> createState() => _SSMovementTabScreenState();
}

class _SSMovementTabScreenState extends State<SSMovementTabScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
          // ── زیرتب‌های داخل «حرکت» ──────────────────────────────────────
          Material(
            color: colors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: accent,
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: accent,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'فعالیت امروز'),
                Tab(text: 'بانک حرکات'),
                Tab(text: 'بودجه و اهداف'),
                Tab(text: 'آنالیز حرکت'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // تب ۰: امروز
                _MovementTodayTab(onNavigateToTab: widget.onNavigateToTab),
                // تب ۱: ورزش‌ها
                const _MovementExercisesTab(),
                // تب ۲: برنامه
                const _MovementPlanTab(),
                // تب ۳: پیشرفت — جاسازی مستقیم بدون AppBar اضافی
                const _ProgressTabWrapper(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// تب «امروز» — بودجه + پیشنهاد + سه دکمه + تایم‌لاین
// ═══════════════════════════════════════════════════════════════════════════════

class _MovementTodayTab extends StatefulWidget {
  const _MovementTodayTab({this.onNavigateToTab});
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<_MovementTodayTab> createState() => _MovementTodayTabState();
}

class _MovementTodayTabState extends State<_MovementTodayTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  MovementBudgetSnapshot? _budgetSnapshot;
  MovementSuggestion? _suggestion;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveSession();
    });
  }

  Future<void> _checkActiveSession() async {
    final active = await MovementSessionRepository.instance.getActiveSession();
    if (active != null && mounted) {
      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(
              'جلسهٔ زندهٔ ناتمام',
              style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'یک جلسهٔ ورزشی ناتمام پیدا شد. می‌خواهی چه کار کنی؟',
              style: TextStyle(fontFamily: 'Vazirmatn'),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await MovementSessionRepository.instance.abandonSession(active.id);
                  await _loadData();
                },
                child: const Text('حذف جلسه', style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.red)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await MovementSessionRepository.instance.finishSession(active.id);
                  await _loadData();
                },
                child: const Text('پایان و ذخیره', style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.amber)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CalendarTokens.emerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _resumeActiveSessionScreen(active);
                },
                child: const Text(
                  'ادامهٔ جلسه',
                  style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ));
    }
  }

  Future<void> _resumeActiveSessionScreen(MovementSession session) async {
    final kinds = await MovementRepository.instance.getKinds();
    final kind = kinds.firstWhere((k) => k.code == session.kindCode, orElse: () => kinds.first);
    if (!mounted) return;

    RitmoEventBus().fire(RitmoEvent(
      type: 'movement_session_recovered',
      timestamp: DateTime.now(),
      payload: {
        'kindCode': session.kindCode,
        'sessionMode': session.sessionMode,
      },
    ));

    unawaited(Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MovementSessionScreen(session: session, kind: kind),
    )).then((_) {
      _loadData();
    }));
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    final snapshot = await MovementBudgetService.instance.getCurrentWeekSnapshot();
    final suggestion = await MovementSuggester.suggestToday(budget: snapshot);
    if (suggestion != null) {
      RitmoEventBus().fire(RitmoEvent(
        type: 'movement_suggestion_shown',
        timestamp: DateTime.now(),
        payload: {
          'kindCode': suggestion.kind.code,
        },
      ));
    }
    if (mounted) {
      setState(() {
        _budgetSnapshot = snapshot;
        _suggestion = suggestion;
        _isLoading = false;
      });
    }
  }

  // ── اکشن‌ها ──────────────────────────────────────────────────────────────

  /// دکمهٔ اول: «شروع الان» — تا فاز ۳ همان فرم ثبت را باز می‌کند.
  Future<void> _startSessionFlow({MovementKind? presetKind}) async {
    RitmoHaptics.tap();
    final active = await MovementSessionRepository.instance.getActiveSession();
    if (active != null) {
      unawaited(_checkActiveSession());
      return;
    }
    final selected = presetKind ?? await _pickKind();
    if (selected == null) return;

    final mode = effectiveMode(selected);
    final session = await MovementSessionRepository.instance.startSession(
      kind: selected,
      sessionMode: mode.code,
      target: null,
    );

    if (!mounted) return;
    unawaited(Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MovementSessionScreen(session: session, kind: selected),
    )).then((_) {
      _loadData();
    }));
  }

  Future<MovementKind?> _pickKind() async {
    MovementKind? selected;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'شروع جلسه جدید: انتخاب ورزش',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: MovementKindSelector(
                  selectedKind: null,
                  onKindSelected: (kind) {
                    selected = kind;
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  /// دکمهٔ دوم: «برای بعد برنامه‌ریزی کن» — تا فاز ۲ همان فرم ثبت باز می‌کند.
  void _openPlanSheet() {
    RitmoHaptics.tap();
    showMovementPlanSheet(context, onSaved: () {
      RitmoHaptics.success();
      _loadData();
    });
  }

  /// دکمهٔ سوم: «ثبت فعالیت انجام‌شده» — فرم پایه با تاریخ.
  void _openLogSheet({MovementKind? presetKind}) {
    RitmoHaptics.tap();
    showMovementLogSheet(
      context,
      presetKind: presetKind,
      onLogged: () {
        RitmoHaptics.success();
        _loadData();
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = SupplementarySportsTheme.of(context);

    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ۱. کارت بودجهٔ هفتگی
              if (_budgetSnapshot != null)
                WeeklyBudgetCard(
                  snapshot: _budgetSnapshot!,
                  onTap: () => _openLogSheet(),
                ),
              const SizedBox(height: 16),

              // ۲. کارت پیشنهاد امروز
              if (_suggestion != null) ...[
                _SuggestionCard(
                  suggestion: _suggestion!,
                  theme: theme,
                  onStart: () {
                    RitmoEventBus().fire(RitmoEvent(
                      type: 'movement_suggestion_accepted',
                      timestamp: DateTime.now(),
                      payload: {
                        'kindCode': _suggestion!.kind.code,
                      },
                    ));
                    _startSessionFlow(presetKind: _suggestion!.kind);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ۳. سه دکمهٔ اصلی
              _ThreeActionButtons(
                onStartNow: _startSessionFlow,
                onPlanLater: _openPlanSheet,
                onLogPast: () => _openLogSheet(),
                theme: theme,
              ),
              const SizedBox(height: 28),

              // ۴. تایم‌لاین فعالیت‌های هفته
              _WeekTimeline(
                snapshot: _budgetSnapshot,
                theme: theme,
                onDeleted: _loadData,
                onUndo: (event) async {
                  await MovementRepository.instance.logEvent(event);
                  unawaited(_loadData());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── کارت پیشنهاد ────────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.theme,
    required this.onStart,
  });

  final MovementSuggestion suggestion;
  final SupplementarySportsTheme theme;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.emeraldPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(suggestion.kind.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'پیشنهاد امروز: ${suggestion.kind.titleFa}',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: theme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.reasonFa,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12,
              color: theme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.emeraldPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onStart,
              child: const Text(
                'شروع پیشنهاد امروز',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── سه دکمهٔ اصلی ───────────────────────────────────────────────────────────

class _ThreeActionButtons extends StatelessWidget {
  const _ThreeActionButtons({
    required this.onStartNow,
    required this.onPlanLater,
    required this.onLogPast,
    required this.theme,
  });

  final VoidCallback onStartNow;
  final VoidCallback onPlanLater;
  final VoidCallback onLogPast;
  final SupplementarySportsTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // دکمهٔ اول — شروع الان (ElevatedButton، ارتفاع ۵۲)
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.emeraldPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onStartNow,
            icon: const Icon(CupertinoIcons.play_fill, color: Colors.white),
            label: const Text(
              'شروع الان',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // دکمهٔ دوم — برنامه‌ریزی برای بعد (OutlinedButton)
        SizedBox(
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.emeraldPrimary.withValues(alpha: 0.7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onPlanLater,
            icon: Icon(
              CupertinoIcons.calendar_badge_plus,
              color: theme.emeraldPrimary,
              size: 18,
            ),
            label: Text(
              'برای بعد برنامه‌ریزی کن',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: theme.emeraldPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // دکمهٔ سوم — ثبت گذشته (TextButton کمرنگ)
        TextButton(
          onPressed: onLogPast,
          child: Text(
            'ثبت فعالیت انجام‌شده',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 13,
              color: theme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── تایم‌لاین فعالیت‌های هفته ───────────────────────────────────────────────

typedef _OnUndo = Future<void> Function(dynamic event);

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.snapshot,
    required this.theme,
    required this.onDeleted,
    required this.onUndo,
  });

  final MovementBudgetSnapshot? snapshot;
  final SupplementarySportsTheme theme;
  final VoidCallback onDeleted;
  final _OnUndo onUndo;

  @override
  Widget build(BuildContext context) {
    final events = snapshot?.events ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تایم‌لاین فعالیت‌های این هفته',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: theme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'در این هفته هنوز فعالیتی ثبت نشده است.',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  color: theme.textSecondary,
                ),
              ),
            ),
          )
        else
          Column(
            children: events.map((e) {
              final duration = e.durationMinutes.toPersianDigits();
              final met = e.metMinutes.round().toPersianDigits();
              return Dismissible(
                key: Key(e.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text(
                            'حذف فعالیت',
                            style: TextStyle(fontFamily: 'Vazirmatn'),
                          ),
                          content: const Text(
                            'این فعالیت برای همیشه حذف می‌شود. مطمئنی؟',
                            style: TextStyle(fontFamily: 'Vazirmatn'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text(
                                'انصراف',
                                style: TextStyle(fontFamily: 'Vazirmatn'),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text(
                                'حذف',
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ) ??
                      false;
                },
                onDismissed: (_) async {
                  // Capture messenger before async gap.
                  final messenger = ScaffoldMessenger.of(context);
                  final deleted = e;
                  try {
                    await MovementRepository.instance.deleteEvent(e.id);
                  } on StateError {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'این رکورد متعلق به جلسهٔ بدنسازی است و از اینجا حذف نمی‌شود.',
                          style: TextStyle(fontFamily: 'Vazirmatn'),
                        ),
                      ),
                    );
                    onDeleted();
                    return;
                  }
                  onDeleted();
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text(
                        'فعالیت حذف شد',
                        style: TextStyle(fontFamily: 'Vazirmatn'),
                      ),
                      action: SnackBarAction(
                        label: 'بازگردانی',
                        onPressed: () => unawaited(onUndo(deleted)),
                      ),
                    ),
                  );
                },
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  color: Colors.red.withValues(alpha: 0.8),
                  child: const Icon(CupertinoIcons.trash, color: Colors.white),
                ),
                child: Card(
                  color: theme.surfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    title: Text(
                      snapshot?.kindsByCode[e.kindCode] == null
                          ? e.kindCode
                          : '${snapshot!.kindsByCode[e.kindCode]!.emoji} ${snapshot!.kindsByCode[e.kindCode]!.titleFa}',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '$duration دقیقه · $met MET-min',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        color: theme.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// تب «ورزش‌ها» — انتخاب نوع حرکت و شروع
// ═══════════════════════════════════════════════════════════════════════════════

class _MovementExercisesTab extends StatelessWidget {
  const _MovementExercisesTab();

  @override
  Widget build(BuildContext context) {
    final theme = SupplementarySportsTheme.of(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.sportscourt,
                size: 64,
                color: theme.emeraldPrimary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 20),
              Text(
                'ورزش مورد نظرت را انتخاب کن',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'از میان ده‌ها نوع حرکت، یکی را انتخاب و مستقیم شروع کن.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  color: theme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.emeraldPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                  ),
                  onPressed: () {
                    RitmoHaptics.tap();
                    showMovementLogSheet(context);
                  },
                  icon: const Icon(
                    CupertinoIcons.play_fill,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'انتخاب و شروع',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// تب «برنامه» — فهرست روتین‌های fitness از جدول routines
// ═══════════════════════════════════════════════════════════════════════════════

class _MovementPlanTab extends StatefulWidget {
  const _MovementPlanTab();

  @override
  State<_MovementPlanTab> createState() => _MovementPlanTabState();
}

class _MovementPlanTabState extends State<_MovementPlanTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  List<Map<String, dynamic>> _routines = [];
  MovementCampaign? _activeCampaign;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      
      // Load active campaign
      final campaign = await MovementCampaignRepository.instance.getActiveCampaign();
      if (campaign != null) {
        await MovementCampaignRepository.instance.checkAndUpdateCampaignWeek(campaign.id);
      }
      final updatedCampaign = await MovementCampaignRepository.instance.getActiveCampaign();

      final rows = await db.rawQuery('''
        SELECT r.*, s.timeOfDay, s.daysOfWeek, s.recurrenceRule
        FROM routines r
        LEFT JOIN routine_schedules s ON r.id = s.routineId
        WHERE r.category = 'fitness' AND r.isArchived = 0
        ORDER BY r.title ASC
      ''');
      if (mounted) {
        setState(() {
          _routines = List.unmodifiable(rows);
          _activeCampaign = updatedCampaign;
        });
      }
    } catch (e) {
      debugPrint('[MovementPlanTab] loadRoutines failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCampaignSection() {
    if (_activeCampaign == null) {
      return Card(
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
        margin: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Text('🏔', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Text(
                    'کارزار صعود: دماوند در ۶ هفته',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'برنامه هفتگی صعود، پله‌نوردی و ریکاوری برای آماده‌سازی تدریجی صعود به قله دماوند.',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  color: Color(0xFFCBD5E1),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CalendarTokens.emerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  RitmoHaptics.success();
                  await MovementCampaignRepository.instance.createCampaign(
                    goalCode: 'DAMAVAND_6W',
                    titleFa: 'دماوند در ۶ هفته',
                    startDate: DateTime.now(),
                    weeks: 6,
                  );
                  await _loadRoutines();
                },
                child: const Text(
                  'شروع کارزار صعود 🚀',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Active Campaign Card
    final progress = jsonDecode(_activeCampaign!.progressJson ?? '{}') as Map;
    final currentWeek = progress['currentWeek'] as int? ?? 1;
    final totalWeeks = _activeCampaign!.weeks;
    final double percent = currentWeek / totalWeeks;

    return Card(
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
      ),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      _activeCampaign!.titleFa,
                      style: const TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent, size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => Directionality(
                        textDirection: TextDirection.rtl,
                        child: AlertDialog(
                          title: const Text('لغو کارزار', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
                          content: const Text('آیا مطمئن هستید که می‌خواهید کارزار صعود و تمام برنامه‌های آن را لغو کنید؟', style: TextStyle(fontFamily: 'Vazirmatn')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('خیر', style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.grey)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('بله، لغو شود', style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (confirm == true) {
                      RitmoHaptics.confirm();
                      await MovementCampaignRepository.instance.cancelCampaign(_activeCampaign!.id);
                      await _loadRoutines();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'هفتهٔ $currentWeek از $totalWeeks',
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(percent * 100).round()}% پیشرفت',
                  style: const TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDays(String? daysStr) {
    if (daysStr == null || daysStr.isEmpty) return '';
    final days = daysStr.split(',').map((s) => int.parse(s.trim())).toList();
    if (days.length == 7) return 'هر روز';

    const dayNames = {
      6: 'شنبه',
      7: 'یکشنبه',
      1: 'دوشنبه',
      2: 'سه‌شنبه',
      3: 'چهارشنبه',
      4: 'پنج‌شنبه',
      5: 'جمعه',
    };

    return days.map((d) => dayNames[d] ?? '').where((s) => s.isNotEmpty).join('، ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = SupplementarySportsTheme.of(context);

    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _loadRoutines,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'برنامه‌های حرکتی',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        // دکمهٔ «برنامهٔ جدید»
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: theme.emeraldPrimary.withValues(alpha: 0.7),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onPressed: () {
                            RitmoHaptics.tap();
                            showMovementPlanSheet(context, onSaved: _loadRoutines);
                          },
                          icon: Icon(
                            CupertinoIcons.add,
                            size: 16,
                            color: theme.emeraldPrimary,
                          ),
                          label: Text(
                            'برنامهٔ جدید',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 13,
                              color: theme.emeraldPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCampaignSection(),
                  ],
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 12)),
            if (_routines.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 52,
                          color: theme.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'هنوز برنامه‌ای ثبت نشده',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'با دکمهٔ «برنامهٔ جدید» اولین روتین حرکتی‌ات را بساز.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 13,
                            color: theme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final routine = _routines[index];
                      final title =
                          routine['title']?.toString() ?? 'برنامهٔ بی‌نام';
                      final formattedDays = _formatDays(routine['daysOfWeek']?.toString());
                      final formattedTime = (routine['timeOfDay']?.toString() ?? '07:00').toPersianDigits();
                      final subtitleText = '$formattedDays · ساعت $formattedTime';
                      final desc = routine['description']?.toString();

                      return Card(
                        color: theme.surfaceVariant,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: theme.cardBorder),
                        ),
                        child: ListTile(
                          onTap: () {
                            RitmoHaptics.tap();
                            showMovementPlanSheet(
                              context,
                              routineToEdit: routine,
                              onSaved: _loadRoutines,
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.emeraldPrimary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.flame_fill,
                              size: 18,
                              color: theme.emeraldPrimary,
                            ),
                          ),
                          title: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                subtitleText,
                                style: TextStyle(
                                  fontFamily: 'Vazirmatn',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.emeraldPrimary,
                                ),
                              ),
                              if (desc != null && desc.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Vazirmatn',
                                    fontSize: 11,
                                    color: theme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Icon(
                            CupertinoIcons.chevron_left,
                            size: 14,
                            color: theme.textSecondary,
                          ),
                        ),
                      );
                    },
                    childCount: _routines.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// _ProgressTabWrapper — جاسازی MovementAnalyticsScreen بدون AppBar اضافه
// ═══════════════════════════════════════════════════════════════════════════════

/// صفحهٔ تحلیل اصلی یک Scaffold/AppBar دارد که در Navigator.push درست کار می‌کند.
/// وقتی درون TabBarView جاسازی می‌شود، AppBar آن با AppBar بیرونی تداخل ایجاد می‌کند.
/// این wrapper از [MediaQuery.removePadding] و [AppBar] با ارتفاع صفر برای سرکوب AppBar استفاده می‌کند.
class _ProgressTabWrapper extends StatelessWidget {
  const _ProgressTabWrapper();

  @override
  Widget build(BuildContext context) {
    // MovementAnalyticsScreen را از طریق یک Navigator مستقل جاسازی می‌کنیم
    // تا Scaffold آن به طور مستقل کار کند ولی AppBar آن مرئی نباشد.
    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: Theme.of(context).appBarTheme.copyWith(
          // ارتفاع را صفر می‌کنیم تا AppBar داخلی فضا نگیرد
          toolbarHeight: 0,
          elevation: 0,
        ),
      ),
      child: const MovementAnalyticsScreen(),
    );
  }
}
