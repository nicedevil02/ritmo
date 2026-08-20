// lib/features/supplementary_sports/presentation/ss_movement_tab_screen.dart
//
// مرکز حرکت — چهار زیرتب: «امروز»، «برنامه»، «پیشرفت»، «کتابخانه»
//
// تایم‌لاین، دیالوگ بازیابی جلسه و شیت انتخاب ورزش به فایل‌های جدا منتقل شدند.

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_session_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_budget.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_suggester.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_analytics_screen.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_log_sheet.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/planner/unified_week_planner_screen.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/open_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_session_recovery.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_week_timeline.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/weekly_budget_card.dart';
import 'package:ritmo/features/supplementary_sports/presentation/ss_exercise_library_screen.dart';

// ─── Public entry point ────────────────────────────────────────────

class SSMovementTabScreen extends StatefulWidget {
  const SSMovementTabScreen({super.key, this.onNavigateToTab});

  /// برای جابجایی بین تب‌های بیرونی برنامه (در اختیار میزبان).
  final ValueChanged<int>? onNavigateToTab;

  @override
  State<SSMovementTabScreen> createState() => _SSMovementTabScreenState();
}

class _SSMovementTabScreenState extends State<SSMovementTabScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const int _kWeekTabIndex = 1;
  static const int _kProgressTabIndex = 2;

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

  void _goToTab(int index) {
    if (!mounted) return;
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        children: [
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
                Tab(text: 'امروز'),
                Tab(text: 'برنامه'),
                Tab(text: 'پیشرفت'),
                Tab(text: 'کتابخانه'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _MovementTodayTab(
                  onOpenWeekTab: () => _goToTab(_kWeekTabIndex),
                  onOpenProgressTab: () => _goToTab(_kProgressTabIndex),
                ),
                const UnifiedWeekPlannerView(),
                const _ProgressTabWrapper(),
                // قبلاً اینجا یک حالت خالی جعلی بود؛ حالا کتابخانهٔ واقعی حرکات.
                const SSExerciseLibraryScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// تب «امروز» — بودجه + پیشنهاد + اقدام‌ها + تایم‌لاین
// ════════════════════════════════════════════════════════════════════════

class _MovementTodayTab extends StatefulWidget {
  const _MovementTodayTab({
    required this.onOpenWeekTab,
    required this.onOpenProgressTab,
  });

  final VoidCallback onOpenWeekTab;
  final VoidCallback onOpenProgressTab;

  @override
  State<_MovementTodayTab> createState() => _MovementTodayTabState();
}

class _MovementTodayTabState extends State<_MovementTodayTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isFirstLoad = true;
  MovementBudgetSnapshot? _budgetSnapshot;
  MovementSuggestion? _suggestion;

  /// تا رویداد «پیشنهاد دیده شد» با هر رفرش دوباره شلیک نشود.
  String? _lastShownSuggestionCode;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveSession();
    });
  }

  // ── داده ────────────────────────────────────────────────────

  /// قبلاً هر فراخوانی کل صفحه را با اسپینر تمام‌صفحه جایگزین می‌کرد؛
  /// بعد از هر ثبت یا پول‌تو‌رفرش، محتوا یک لحطه ناپدید می‌شد.
  Future<void> _loadData() async {
    final snapshot = await MovementBudgetService.instance.getCurrentWeekSnapshot();
    final suggestion = await MovementSuggester.suggestToday(budget: snapshot);

    if (suggestion != null && suggestion.kind.code != _lastShownSuggestionCode) {
      _lastShownSuggestionCode = suggestion.kind.code;
      RitmoEventBus().fire(RitmoEvent(
        type: 'movement_suggestion_shown',
        timestamp: DateTime.now(),
        payload: {'kindCode': suggestion.kind.code},
      ));
    }

    if (!mounted) return;
    setState(() {
      _budgetSnapshot = snapshot;
      _suggestion = suggestion;
      _isFirstLoad = false;
    });
  }

  // ── جلسهٔ ناتمام ───────────────────────────────────────────

  Future<void> _checkActiveSession() async {
    final active = await MovementSessionRepository.instance.getActiveSession();
    if (active == null || !mounted) return;
    await _handleActiveSession(active);
  }

  Future<void> _handleActiveSession(MovementSession active) async {
    final kindTitle = _budgetSnapshot?.kindsByCode[active.kindCode]?.titleFa;
    final choice = await showMovementSessionRecoveryDialog(context, kindTitle: kindTitle);
    if (!mounted || choice == null) return;

    if (choice == MovementRecoveryChoice.resume) {
      await _resumeActiveSessionScreen(active);
      return;
    }

    if (choice == MovementRecoveryChoice.finish) {
      await MovementSessionRepository.instance.finishSession(active.id);
      RitmoHaptics.success();
    } else {
      await MovementSessionRepository.instance.abandonSession(active.id);
    }
    await _loadData();
  }

  Future<void> _resumeActiveSessionScreen(MovementSession session) async {
    final kinds = await MovementRepository.instance.getKinds();
    final kind = kinds.firstWhere(
      (k) => k.code == session.kindCode,
      orElse: () => kinds.first,
    );
    if (!mounted) return;

    RitmoEventBus().fire(RitmoEvent(
      type: 'movement_session_recovered',
      timestamp: DateTime.now(),
      payload: {
        'kindCode': session.kindCode,
        'sessionMode': session.sessionMode,
      },
    ));

    unawaited(openMovementSession(context, session: session, kind: kind).then((_) {
      _loadData();
    }));
  }

  // ── اقدام‌ها ───────────────────────────────────────────────

  Future<void> _startSessionFlow({MovementKind? presetKind}) async {
    RitmoHaptics.tap();

    final active = await MovementSessionRepository.instance.getActiveSession();
    if (!mounted) return;
    if (active != null) {
      await _handleActiveSession(active);
      return;
    }

    final selected = presetKind ?? await showMovementKindPickerSheet(context);
    if (selected == null || !mounted) return;

    final mode = effectiveMode(selected);
    final session = await MovementSessionRepository.instance.startSession(
      kind: selected,
      sessionMode: mode.code,
      target: null,
    );
    if (!mounted) return;

    unawaited(openMovementSession(context, session: session, kind: selected).then((_) {
      _loadData();
    }));
  }

  void _openPlanSheet() {
    RitmoHaptics.tap();
    showMovementPlanSheet(context, onSaved: () {
      RitmoHaptics.success();
      _loadData();
    });
  }

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

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isFirstLoad) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: () => _loadData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            RitmoSpacing.lg,
            RitmoSpacing.lg,
            RitmoSpacing.lg,
            RitmoSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ۱. بودجهٔ هفتگی — لمس آن قبلاً فرم ثبت را باز می‌کرد (غیرمنتظره).
              if (_budgetSnapshot != null)
                WeeklyBudgetCard(
                  snapshot: _budgetSnapshot!,
                  onTap: widget.onOpenProgressTab,
                ),
              const SizedBox(height: RitmoSpacing.lg),

              // ۲. پیشنهاد امروز
              if (_suggestion != null) ...[
                _SuggestionCard(
                  suggestion: _suggestion!,
                  onStart: () {
                    RitmoEventBus().fire(RitmoEvent(
                      type: 'movement_suggestion_accepted',
                      timestamp: DateTime.now(),
                      payload: {'kindCode': _suggestion!.kind.code},
                    ));
                    _startSessionFlow(presetKind: _suggestion!.kind);
                  },
                  onLogInstead: () => _openLogSheet(presetKind: _suggestion!.kind),
                ),
                const SizedBox(height: RitmoSpacing.lg),
              ],

              // ۳. اقدام‌ها
              _ActionButtons(
                onStartNow: _startSessionFlow,
                onLogPast: () => _openLogSheet(),
                onPlanLater: _openPlanSheet,
                onOpenWeek: widget.onOpenWeekTab,
              ),
              const SizedBox(height: RitmoSpacing.xl),

              // ۴. تایم‌لاین فعالیت‌های هفته
              MovementWeekTimeline(
                snapshot: _budgetSnapshot,
                onChanged: _loadData,
                onRestore: (event) async {
                  await MovementRepository.instance.logEvent(event);
                  await _loadData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── کارت پیشنهاد ──────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onStart,
    required this.onLogInstead,
  });

  final MovementSuggestion suggestion;
  final VoidCallback onStart;
  final VoidCallback onLogInstead;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.hero),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(suggestion.kind.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: RitmoSpacing.sm),
              Expanded(
                child: Text(
                  'پیشنهاد امروز: ${suggestion.kind.titleFa}',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Text(
            suggestion.reasonFa,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12.5,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: RitmoSpacing.md),
          Row(
            children: [
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  onPressed: onStart,
                  child: const Text(
                    'همین را شروع کن',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RitmoSpacing.sm),
              // اگر کاربر همین را قبلاً انجام داده، نباید مجبور باشد جلسه شروع کند.
              SizedBox(
                height: 44,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
                  onPressed: onLogInstead,
                  child: const Text(
                    'انجامش دادم',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── اقدام‌های اصلی ───────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onStartNow,
    required this.onLogPast,
    required this.onPlanLater,
    required this.onOpenWeek,
  });

  final VoidCallback onStartNow;
  final VoidCallback onLogPast;
  final VoidCallback onPlanLater;
  final VoidCallback onOpenWeek;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.card),
              ),
            ),
            onPressed: onStartNow,
            icon: const Icon(CupertinoIcons.play_fill, size: 20),
            label: const Text(
              'شروع الان',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: RitmoSpacing.sm),
        // «ثبت انجام‌شده» پرکاربردترین اقدام این صفحه است ولی قبلاً یک TextButton
        // ۱۳ پیکسلی کمرنگ بود؛ حالا هم‌وزن برنامه‌ریزی است.
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  onPressed: onLogPast,
                  icon: Icon(CupertinoIcons.checkmark_circle, size: 18, color: accent),
                  label: const Text(
                    'ثبت انجام‌شده',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: RitmoSpacing.sm),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  onPressed: onPlanLater,
                  icon: Icon(CupertinoIcons.calendar_badge_plus, size: 18, color: accent),
                  label: const Text(
                    'برنامه برای بعد',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 44),
              foregroundColor: colors.textSecondary,
            ),
            onPressed: onOpenWeek,
            child: const Text(
              'دیدن برنامهٔ هفته',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// _ProgressTabWrapper — جاسازی MovementAnalyticsScreen بدون AppBar اضافه
// ════════════════════════════════════════════════════════════════════════

/// صفحهٔ تحلیل اصلی یک Scaffold/AppBar دارد که در Navigator.push درست کار می‌کند؛
/// درون TabBarView آن AppBar با تب‌بار بیرونی تداخل دارد.
/// TODO: به جای این ترفند، مانند کتابخانه یک پرچم `embedded` به آن صفحه اضافه شود.
class _ProgressTabWrapper extends StatelessWidget {
  const _ProgressTabWrapper();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: Theme.of(context).appBarTheme.copyWith(
              toolbarHeight: 0,
              elevation: 0,
            ),
      ),
      child: const MovementAnalyticsScreen(),
    );
  }
}
