import 'dart:ui';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/analytics/life_balance_engine.dart';
import 'package:ritmo/core/analytics/mood_engine.dart';
import 'package:ritmo/core/analytics/reflection_engine.dart';
import 'package:ritmo/core/analytics/sleep_engine.dart';
import 'package:ritmo/core/analytics/sleep_program_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_loop.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart' hide EnergyLevel;
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/core/widgets/ritmo_progress_ring.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/energy/presentation/widgets/quick_log_sheet.dart';
import 'package:ritmo/features/reflection/models/reflection_models.dart';
import 'package:ritmo/features/sleep/logic/sleep_plan_gateway.dart';
import 'package:ritmo/features/sleep/logic/sleep_plan_insights.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/sleep/models/sleep_program.dart';
import 'package:ritmo/features/sleep/presentation/widgets/sleep_log_sheet.dart';
import 'package:ritmo/features/sleep/presentation/widgets/sleep_target_sheet.dart';
import 'package:ritmo/features/today/presentation/widgets/daily_reflection_sheet.dart';
import 'package:ritmo/features/wellbeing/data/wellbeing_daily_repository.dart';
import 'package:ritmo/features/wellbeing/logic/wellbeing_nudge_service.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/daily_rhythm_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/dynamic_energy_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/frictionless_mood_bar.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/index_trend_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/mood_analytics_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/narrative_inbox_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/sleep_overview_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_day_sheet.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_explanation_sheet.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_narrative_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_pulse_chart.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/sleep_target_card.dart';
import 'package:ritmo/features/wellbeing/presentation/widgets/wellbeing_quick_checkin_bar.dart';

enum WellbeingSection {
  today,
  sleep,
  energy;

  static const WellbeingSection trend = WellbeingSection.sleep;
  static const WellbeingSection mirror = WellbeingSection.energy;
  static const WellbeingSection journal = WellbeingSection.energy;
}

class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({
    super.key,
    this.initialSection = WellbeingSection.today,
  });

  final WellbeingSection initialSection;

  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen>
    with SingleTickerProviderStateMixin {
  bool _hasLoadedOnce = false;
  bool _loadFailed = false;
  bool _isDirty = false;
  int _loadToken = 0;
  int _selectedHorizonDays = 14;
  bool _isTabsVisible = true;
  Timer? _reloadDebounce;

  late TabController _tabController;

  WellbeingIndex? _wellbeing;
  EnergyAnalyticsOutput? _energyOutput;
  MoodEngineOutput? _moodOutput;
  SleepEngineOutput? _sleepOutput;
  ReflectionEngineOutput? _reflectionOutput;
  LifeBalanceEngineOutput? _lifeBalanceOutput;

  List<EnergyLog> _rawEnergyLogs = [];
  List<MoodLog> _rawMoodLogs = [];
  List<SleepLog> _rawSleepLogs = [];
  List<ReflectionEntry> _reflections = [];
  List<WellbeingDailyRecord> _dailyRecords = [];
  SleepTarget _sleepTarget = SleepTarget.defaultTarget();
  bool _isSleepTargetExpanded = true;
  List<WellbeingPulseDayData> _pulseDays = [];
  WellbeingInsightLoopState? _loopPrevious;
  WellbeingInsightSnapshot _insightSnapshotCache =
      const WellbeingInsightSnapshot();
  SleepProgramState? _sleepProgramState;

  StreamSubscription? _eventSub;

  MoodLog? get _latestMood =>
      _rawMoodLogs.isNotEmpty ? _rawMoodLogs.first : null;
  EnergyLog? get _latestEnergy =>
      _rawEnergyLogs.isNotEmpty ? _rawEnergyLogs.first : null;
  SleepLog? get _latestSleep =>
      _rawSleepLogs.isNotEmpty ? _rawSleepLogs.first : null;
  ReflectionEntry? get _todayReflection {
    final todayStr = RitmoDate.dayKey(DateTime.now());
    for (final r in _reflections) {
      if (r.date == todayStr) return r;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialSection.index.clamp(0, 2),
    );

    RitmoEvents.routineChanges.addListener(_requestReload);

    _eventSub = RitmoEventBus().onEvents.listen((event) {
      if (event.type == RitmoEventType.moodLogged.code ||
          event.type == RitmoEventType.sleepLogged.code ||
          event.type == RitmoEventType.reflectionSaved.code ||
          event.type == RitmoEventType.energyLogged.code) {
        _requestReload();
      }
    });

    _loadAllData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isDirty && mounted && ModalRoute.of(context)?.isCurrent == true) {
      _isDirty = false;
      _requestReload();
    }
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _loadToken++;
    RitmoEvents.routineChanges.removeListener(_requestReload);
    _eventSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _requestReload() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _isDirty = true;
      return;
    }

    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_loadAllData());
    });
  }

  Future<void> _loadAllData() async {
    final token = ++_loadToken;
    final now = DateTime.now();

    try {
      final db = await DatabaseHelper.instance.database;
      final horizonMs = RitmoDate.startOfDayMillis(
        now.subtract(Duration(days: _selectedHorizonDays)),
      );
      final horizonKey = RitmoDate.dayKey(
        now.subtract(Duration(days: _selectedHorizonDays)),
      );

      final dailyLimit = _selectedHorizonDays + 7;
      final multiLogLimit = math.max(200, _selectedHorizonDays * 8);

      final dbResults = await Future.wait([
        Future.value(ModuleGate.instance.isEnabled('module_energy_enabled')),
        Future.value(ModuleGate.instance.isEnabled('module_sleep_enabled')),
        db
            .query('app_settings', where: "key LIKE 'sleep_target_%'")
            .catchError((_) => <Map<String, dynamic>>[]),
        db
            .query(
              'energy_logs',
              where: 'loggedAt >= ?',
              whereArgs: [horizonMs],
              orderBy: 'loggedAt DESC',
              limit: multiLogLimit,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
        db
            .query(
              'mood_logs',
              where: 'loggedAt >= ?',
              whereArgs: [horizonMs],
              orderBy: 'loggedAt DESC',
              limit: multiLogLimit,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
        db
            .query(
              'bedtime_diagnostics',
              where: 'date >= ?',
              whereArgs: [horizonKey],
              orderBy: 'date DESC',
              limit: dailyLimit,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
        db
            .query(
              'daily_reflections',
              where: 'date >= ?',
              whereArgs: [horizonKey],
              orderBy: 'date DESC',
              limit: dailyLimit,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
        db
            .query(
              'daily_checkins',
              where: 'date >= ?',
              whereArgs: [horizonKey],
              orderBy: 'date DESC',
              limit: dailyLimit,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
        db
            .query('routines', where: 'isArchived = 0')
            .catchError((_) => <Map<String, dynamic>>[]),
        db
            .query(
              'routine_completions',
              where: 'completionTime >= ?',
              whereArgs: [
                now
                    .subtract(
                      Duration(days: math.max(28, _selectedHorizonDays)),
                    )
                    .millisecondsSinceEpoch,
              ],
              limit: 1000,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
        db
            .query(
              'daily_rhythm',
              where: 'date >= ?',
              whereArgs: [horizonKey],
              limit: dailyLimit,
            )
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted || token != _loadToken) return;

      final targetRows = dbResults[2] as List<Map<String, dynamic>>;
      String bedtime = '23:30';
      String wake = '07:00';
      int durationMinutes = 450;
      for (final r in targetRows) {
        final k = r['key'] as String;
        final v = r['value'] as String;
        if (k == 'sleep_target_bedtime') bedtime = v;
        if (k == 'sleep_target_wake') wake = v;
        if (k == 'sleep_target_duration_minutes')
          durationMinutes = int.tryParse(v) ?? 450;
      }
      _sleepTarget = SleepTarget(
        bedtime: bedtime,
        wake: wake,
        durationMinutes: durationMinutes,
      );

      final energyRows = dbResults[3] as List<Map<String, dynamic>>;
      final moodRows = dbResults[4] as List<Map<String, dynamic>>;
      final sleepRows = dbResults[5] as List<Map<String, dynamic>>;
      final reflectionRows = dbResults[6] as List<Map<String, dynamic>>;
      final checkinRows = dbResults[7] as List<Map<String, dynamic>>;
      final routineRows = dbResults[8] as List<Map<String, dynamic>>;
      final completionRows = dbResults[9] as List<Map<String, dynamic>>;
      final rhythmRows = dbResults[10] as List<Map<String, dynamic>>;

      _rawEnergyLogs = energyRows.map((r) => EnergyLog.fromMap(r)).toList();
      _rawMoodLogs = moodRows.map((r) => MoodLog.fromMap(r)).toList();
      _rawSleepLogs = sleepRows.map((r) => SleepLog.fromMap(r)).toList();
      _reflections = reflectionRows
          .map((r) => ReflectionEntry.fromMap(r))
          .toList();

      final energyInput = EnergyAnalyticsEngineInput(
        energyLogs: energyRows,
        routineCompletions: completionRows,
        dailyRhythm: rhythmRows,
        sleepDiagList: sleepRows,
        now: now,
      );
      final moodInput = MoodEngineInput(
        moodLogs: _rawMoodLogs,
        energyLogs: _rawEnergyLogs,
        today: now,
        horizonDays: _selectedHorizonDays,
      );
      final sleepInput = SleepEngineInput(
        sleepLogs: _rawSleepLogs,
        target: _sleepTarget,
        energyLogs: energyRows,
        moodLogs: moodRows,
        today: now,
        horizonDays: _selectedHorizonDays,
      );
      final reflectionInput = ReflectionEngineInput(
        dailyReflections: reflectionRows,
        dailyCheckins: checkinRows,
        energyLogs: energyRows,
        moodLogs: moodRows,
        today: now,
        horizonDays: _selectedHorizonDays,
        computeThemes: _reflections.length >= 7,
      );
      final balanceInput = LifeBalanceEngineInput(
        now: now,
        routines: routineRows,
        routineCompletions: completionRows,
      );

      Future<T?> evalEngine<I, T>(Type engineType, I input) async {
        try {
          return await RitmoEngineBus.instance
              .execute<I, T>(engineType, input)
              .timeout(const Duration(milliseconds: 1000));
        } catch (_) {
          return null;
        }
      }

      final engineResults = await Future.wait([
        evalEngine<EnergyAnalyticsEngineInput, EnergyAnalyticsOutput>(
          EnergyAnalyticsEngine,
          energyInput,
        ),
        evalEngine<MoodEngineInput, MoodEngineOutput>(MoodEngine, moodInput),
        evalEngine<SleepEngineInput, SleepEngineOutput>(
          SleepEngine,
          sleepInput,
        ),
        evalEngine<ReflectionEngineInput, ReflectionEngineOutput>(
          ReflectionEngine,
          reflectionInput,
        ),
        evalEngine<LifeBalanceEngineInput, LifeBalanceEngineOutput>(
          LifeBalanceEngine,
          balanceInput,
        ),
      ]);

      if (!mounted || token != _loadToken) return;

      _energyOutput = engineResults[0] as EnergyAnalyticsOutput?;
      _moodOutput = engineResults[1] as MoodEngineOutput?;
      _sleepOutput = engineResults[2] as SleepEngineOutput?;
      _reflectionOutput = engineResults[3] as ReflectionEngineOutput?;
      _lifeBalanceOutput = engineResults[4] as LifeBalanceEngineOutput?;

      final uniqueSleepDays = _rawSleepLogs.map((l) => l.date).toSet().length;
      final uniqueEnergyDays = _rawEnergyLogs
          .map(
            (e) => RitmoDate.dayKey(
              DateTime.fromMillisecondsSinceEpoch(e.loggedAt),
            ),
          )
          .toSet()
          .length;
      final uniqueMoodDays = _rawMoodLogs
          .map(
            (m) => RitmoDate.dayKey(
              DateTime.fromMillisecondsSinceEpoch(m.loggedAt),
            ),
          )
          .toSet()
          .length;
      final uniqueReflectionDays = _reflections
          .map((r) => r.date)
          .toSet()
          .length;

      _wellbeing = const WellbeingEngine().compute(
        WellbeingEngineInput(
          now: now,
          horizonDays: _selectedHorizonDays,
          sleepNights: uniqueSleepDays,
          avgSleepHours: (_sleepOutput?.avgDurationMinutes ?? 0) > 0
              ? _sleepOutput!.avgDurationMinutes / 60.0
              : null,
          targetSleepHours: _sleepTarget.durationMinutes / 60.0,
          avgSleepQuality: _sleepOutput?.avgQuality,
          sleepConsistency: _sleepOutput?.consistencyScore,
          energySamples: uniqueEnergyDays,
          avgEnergyLevel: _energyOutput?.avgLevel,
          energyIsAiDerived: _energyOutput?.isAiDerived ?? false,
          moodSamples: uniqueMoodDays,
          avgMoodScore: _moodOutput?.avgScore,
          reflectionEntries: uniqueReflectionDays,
          avgReflectionMood: _reflectionOutput?.avgMoodScore,
        ),
      );

      if (_wellbeing != null && _wellbeing!.hasValue) {
        await WellbeingDailyRepository().upsertToday(_wellbeing!, now: now);
      }
      _dailyRecords = await WellbeingDailyRepository().loadRecent(
        _selectedHorizonDays,
        now: now,
      );
      await WellbeingNudgeService.instance.scheduleDailyNudges(now: now);

      final dayKeys = RitmoDate.lastNDayKeys(now, _selectedHorizonDays);

      final energyValuesByDate = <String, List<double>>{};
      for (final e in _rawEnergyLogs) {
        final key = RitmoDate.dayKey(
          DateTime.fromMillisecondsSinceEpoch(e.loggedAt),
        );
        var val = 2.0;
        if (e.energyLevel == EnergyLevel.high) val = 3.0;
        if (e.energyLevel == EnergyLevel.low) val = 1.0;
        energyValuesByDate.putIfAbsent(key, () => []).add(val);
      }
      final energyByDate = <String, double>{
        for (final entry in energyValuesByDate.entries)
          entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
      };

      final sleepValuesByDate = <String, List<double>>{};
      for (final s in _rawSleepLogs) {
        sleepValuesByDate.putIfAbsent(s.date, () => []).add(s.durationHours);
      }
      final sleepByDate = <String, double>{
        for (final entry in sleepValuesByDate.entries)
          entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
      };

      final moodValuesByDate = <String, List<double>>{};
      for (final m in _rawMoodLogs) {
        final key = RitmoDate.dayKey(
          DateTime.fromMillisecondsSinceEpoch(m.loggedAt),
        );
        moodValuesByDate.putIfAbsent(key, () => []).add(m.valence.toDouble());
      }
      final moodByDate = <String, double>{
        for (final entry in moodValuesByDate.entries)
          entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
      };

      final reflectionDates = _reflections.map((r) => r.date).toSet();

      _pulseDays = dayKeys.map((key) {
        return WellbeingPulseDayData(
          dateStr: key,
          sleepHours: sleepByDate[key],
          energyLevel: energyByDate[key],
          moodScore: moodByDate[key],
          hasReflection: reflectionDates.contains(key),
        );
      }).toList();

      _loopPrevious = await WellbeingInsightLoop.load(db);
      final insightInput = WellbeingInsightInput(
        now: now,
        horizonDays: _selectedHorizonDays,
        index: _wellbeing,
        energy: _energyOutput,
        mood: _moodOutput,
        sleep: _sleepOutput,
        reflection: _reflectionOutput,
        balance: _lifeBalanceOutput,
        energyLogCount: _rawEnergyLogs.length,
        moodLogCount: _rawMoodLogs.length,
        sleepLogCount: _rawSleepLogs.length,
        reflectionCount: _reflections.length,
        sleepLogs: _rawSleepLogs,
        energyLogs: _rawEnergyLogs,
        moodLogs: _rawMoodLogs,
        targetSleepHours: _sleepTarget.durationMinutes / 60.0,
        loopPrevious: _loopPrevious,
      );
      _insightSnapshotCache = const WellbeingInsightArbiter().evaluate(
        insightInput,
      );
      _sleepProgramState = await SleepPlanGateway.loadState(now: now);
      _insightSnapshotCache = await SleepPlanGateway.mergeInto(
        _insightSnapshotCache,
        now: now,
        sleepLogCount: _rawSleepLogs.length,
        state: _sleepProgramState,
      );
      if (!mounted || token != _loadToken) return;
      final featured = _insightSnapshotCache.featured;
      if (featured != null) {
        final metrics = WellbeingInsightArbiter.metricByKind(insightInput);
        final metricKey = featured.kind == WellbeingInsightKind.loopOutcome
            ? (_loopPrevious?.kindName ?? featured.kind.name)
            : featured.kind.name;
        await WellbeingInsightLoop.saveIfNewDay(
          db: db,
          now: now,
          kindName: featured.kind.name,
          previous: _loopPrevious,
          metric: metrics[metricKey],
        );
      }

      if (mounted) {
        setState(() {
          _loadFailed = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e, stack) {
      debugPrint('[WellbeingScreen ERROR] $e\n$stack');
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _hasLoadedOnce = true;
        });
      }
    }
  }

  void _openAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AssistantSheet(
        persona: PersonaRegistry.instance.getPersona('wellbeing')!,
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    final w =
        _wellbeing ??
        WellbeingIndex(
          value: null,
          confidence: 0,
          contributions: const [],
          missing: const [],
          computedAtMillis: DateTime.now().millisecondsSinceEpoch,
        );
    WellbeingExplanationSheet.show(context, w);
  }

  void _setHorizonDays(int days) {
    if (_selectedHorizonDays == days) return;
    RitmoHapticsPolicy.tap();
    setState(() => _selectedHorizonDays = days);
    _loadAllData();
  }

  WellbeingInsightSnapshot get _insightSnapshot => _insightSnapshotCache;

  void _onInsightAction(WellbeingInsightAction action) {
    RitmoHapticsPolicy.tap();
    switch (action) {
      case WellbeingInsightAction.logSleep:
        RitmoSheetScaffold.present(
          context: context,
          title: 'ثبت خواب دیشب',
          builder: (ctx) =>
              SleepLogSheet(onSaved: _requestReload, target: _sleepTarget),
        );
      case WellbeingInsightAction.logEnergy:
        RitmoSheetScaffold.present(
          context: context,
          title: 'ثبت سطح انرژی',
          builder: (ctx) => QuickLogSheet(onSaved: _requestReload),
        );
      case WellbeingInsightAction.logReflection:
        _tabController.animateTo(2);
      case WellbeingInsightAction.explainIndex:
        _showExplanation(context);
      case WellbeingInsightAction.explainGoldenWindow:
        _showGoldenWindowDialog();
      case WellbeingInsightAction.openSleepTarget:
        RitmoSheetScaffold.present(
          context: context,
          title: 'تنظیم هدف خواب',
          builder: (ctx) => SleepTargetSheet(
            currentTarget: _sleepTarget,
            onSaved: _requestReload,
          ),
        );
    }
  }

  void _showGoldenWindowDialog() {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.card),
        ),
        title: Text(
          'پنجرهٔ طلایی انرژی',
          style: RitmoTextStyles.cardTitle(colors.textPrimary),
        ),
        content: Text(
          'در بازهٔ ${_energyOutput?.peakPerformanceWindow ?? "نامشخص"} معمولاً بیشترین انرژی را داری. کارهای مهم یا سخت‌تر خودت را از برنامهٔ «امروزِ من» به این بازه منتقل کن تا از این انرژی استفاده کنی.',
          style: RitmoTextStyles.body(colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('باشه', style: RitmoTextStyles.label(colors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!_hasLoadedOnce) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: RitmoSkeletonList()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 142.0;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          // Layer 1: Body Content (NotificationListener for Instant Quick-Return Header)
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical) {
                  if (notification.metrics.pixels <= 15) {
                    if (!_isTabsVisible) {
                      setState(() => _isTabsVisible = true);
                    }
                  } else if (notification is UserScrollNotification) {
                    if (notification.direction == ScrollDirection.reverse) {
                      if (_isTabsVisible) {
                        setState(() => _isTabsVisible = false);
                      }
                    } else if (notification.direction == ScrollDirection.forward) {
                      if (!_isTabsVisible) {
                        setState(() => _isTabsVisible = true);
                      }
                    }
                  }
                }
                return false;
              },
              child: RefreshIndicator(
                onRefresh: _loadAllData,
                color: colors.primary,
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _WellbeingTabKeepAlive(child: _buildTodayTab(context, contentTopPadding)),
                    _WellbeingTabKeepAlive(child: _buildSleepTab(context, contentTopPadding)),
                    _WellbeingTabKeepAlive(child: _buildEnergyTab(context, contentTopPadding)),
                  ],
                ),
              ),
            ),
          ),

          // Layer 2: Floating Capsule Header Island
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: _buildCapsuleHeader(context, isDark, colors),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapsuleHeader(
    BuildContext context,
    bool isDark,
    RitmoColors colors,
  ) {
    final capsuleBgColor = isDark
        ? const Color(0xFF1E222A).withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.90);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.50)
                : const Color(0xFFCBD5E1).withValues(alpha: 0.65),
            offset: const Offset(0, 5),
            blurRadius: 14,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.90),
            offset: const Offset(0, -1),
            blurRadius: 3,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            decoration: BoxDecoration(
              color: capsuleBgColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Back Button, Title, AI, Quick Checkin, Sleep Sheet
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      if (Navigator.canPop(context))
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                          icon: Icon(
                            CupertinoIcons.arrow_right,
                            color: isDark ? Colors.white : const Color(0xFF1D2129),
                            size: 20,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                        )
                      else
                        const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'حال و تعادل',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17.5,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1D2129),
                          ),
                        ),
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.sparkles,
                        iconColor: colors.primary,
                        isAiButton: true,
                        isDark: isDark,
                        tooltip: 'دستیار هوشمند حال و تعادل',
                        onTap: _openAssistant,
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.smiley,
                        iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                        isDark: isDark,
                        tooltip: 'ثبت حس و حال',
                        onTap: () {
                          RitmoSheetScaffold.present(
                            context: context,
                            title: 'ثبت حال روحی و انرژی',
                            builder: (_) => QuickLogSheet(onSaved: _requestReload),
                          );
                        },
                      ),
                      _buildHeaderActionButton(
                        icon: CupertinoIcons.moon_zzz_fill,
                        iconColor: const Color(0xFF8B5CF6),
                        isDark: isDark,
                        tooltip: 'ثبت و پایش خواب',
                        onTap: () {
                          RitmoSheetScaffold.present(
                            context: context,
                            title: 'ثبت گزارش خواب',
                            builder: (_) => SleepLogSheet(
                              onSaved: _requestReload,
                              target: _sleepTarget,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                ),

                // Bottom Collapsible 3-Tier Segmented Tabs
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  height: _isTabsVisible ? 54.0 : 0.0,
                  clipBehavior: Clip.hardEdge,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isTabsVisible ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                      child: Align(
                        alignment: Alignment.center,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: _buildSegmentedTabs(colors, isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabs(
    RitmoColors colors,
    bool isDark,
  ) {
    final trackBgColor = isDark ? const Color(0xFF16191E) : const Color(0xFFEFF2F6);
    final pillBgColor = isDark
        ? const Color(0xFF22262F)
        : Color.lerp(Colors.white, colors.primary, 0.12)!;
    final activeIndex = _tabController.index.clamp(0, 2);

    const tabs = [
      (title: 'امروز و تعادل', icon: CupertinoIcons.sparkles),
      (title: 'خواب و استراحت', icon: CupertinoIcons.moon_fill),
      (title: 'انرژی و خلق', icon: CupertinoIcons.bolt_fill),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const outerPadding = 4.0;
        final availableWidth = totalWidth - (outerPadding * 2);
        final tabWidth = availableWidth / 3;
        const trackHeight = 44.0;
        const pillHeight = trackHeight - (outerPadding * 2);

        return Container(
          height: trackHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: trackBgColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.90),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.70)
                    : const Color(0xFFB8C2CE).withValues(alpha: 0.55),
                offset: const Offset(2, 2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: isDark
                    ? const Color(0xFF222630)
                    : Colors.white.withValues(alpha: 0.95),
                offset: const Offset(-2, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Sliding Pill Indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                right: outerPadding + (activeIndex * tabWidth),
                top: outerPadding,
                width: tabWidth,
                height: pillHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: pillBgColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: isDark ? 0.40 : 0.28),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.60)
                            : const Color(0xFFB2BDCB).withValues(alpha: 0.65),
                        offset: const Offset(2, 2),
                        blurRadius: 4,
                      ),
                      BoxShadow(
                        color: isDark ? const Color(0xFF2E3440) : Colors.white,
                        offset: const Offset(-2, -2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),

              // Tab Buttons
              Row(
                children: List.generate(3, (index) {
                  final item = tabs[index];
                  final isSelected = activeIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _tabController.animateTo(index);
                        setState(() {});
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? colors.primary
                                : (isDark
                                    ? const Color(0xFF8A93A4)
                                    : const Color(0xFF6B7280)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.icon,
                                  size: 13,
                                  color: isSelected
                                      ? colors.primary
                                      : (isDark
                                          ? const Color(0xFF8A93A4)
                                          : const Color(0xFF6B7280)),
                                ),
                                const SizedBox(width: 4),
                                Text(item.title),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
    String? tooltip,
    bool isAiButton = false,
  }) {
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: _buildHeaderActionButtonContent(
        icon: icon,
        iconColor: iconColor,
        isDark: isDark,
        isAiButton: isAiButton,
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildHeaderActionButtonContent({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    bool isAiButton = false,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? (isAiButton
                ? iconColor.withValues(alpha: 0.18)
                : const Color(0xFF22262E))
            : (isAiButton
                ? iconColor.withValues(alpha: 0.12)
                : const Color(0xFFF3F5F8)),
        border: Border.all(
          color: isDark
              ? (isAiButton
                  ? iconColor.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.08))
              : (isAiButton
                  ? iconColor.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.90)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFFB5C0CD).withValues(alpha: 0.65),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          if (isAiButton)
            BoxShadow(
              color: iconColor.withValues(alpha: isDark ? 0.35 : 0.22),
              blurRadius: 10,
              spreadRadius: 1.0,
            ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 18,
          color: isAiButton
              ? iconColor
              : (isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280)),
        ),
      ),
    );
  }

  Widget _buildTodayTab(BuildContext context, [double topPadding = 16.0]) {
    if (_loadFailed) {
      return _buildErrorCard(context);
    }

    final snapshot = _insightSnapshot;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(10, topPadding, 10, 80),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              WellbeingQuickCheckinBar(
                latestMood: _latestMood,
                latestEnergy: _latestEnergy,
                latestSleep: _latestSleep,
                todayReflection: _todayReflection,
                onMoodEnergyTap: () {
                  RitmoSheetScaffold.present(
                    context: context,
                    title: 'ثبت حال روحی و انرژی',
                    builder: (_) => QuickLogSheet(onSaved: _requestReload),
                  );
                },
                onSleepTap: () {
                  RitmoSheetScaffold.present(
                    context: context,
                    title: 'ثبت خواب',
                    builder: (_) => SleepLogSheet(
                      onSaved: _requestReload,
                      target: _sleepTarget,
                    ),
                  );
                },
                onReflectionTap: () {
                  DailyReflectionSheet.show(
                    context: context,
                    onSaved: _requestReload,
                  );
                },
              ),
              const SizedBox(height: RitmoSpacing.lg),
              _buildIndexHeroCard(context),
              const SizedBox(height: RitmoSpacing.lg),
              WellbeingNarrativeCard(
                insight: snapshot.featured,
                onAction: _onInsightAction,
              ),
              if (snapshot.featured != null)
                const SizedBox(height: RitmoSpacing.lg),
              NarrativeInboxCard(
                snapshot: snapshot,
                onAction: _onInsightAction,
              ),
              const SizedBox(height: RitmoSpacing.lg),
              WellbeingPulseChart(
                days: _pulseDays,
                onDayTap: (day) => WellbeingDaySheet.show(
                  context: context,
                  day: day,
                  sleepTarget: _sleepTarget,
                  onLogChanged: _requestReload,
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),
              IndexTrendCard(
                records: _dailyRecords,
                horizonDays: _selectedHorizonDays,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizonFilterRow(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        height: 36,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surface.withValues(alpha: 0.6)
              : colors.border.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.border.withValues(alpha: isDark ? 0.2 : 0.12),
            width: 0.75,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [7, 14, 30, 90].map((d) {
            final isSelected = _selectedHorizonDays == d;
            return GestureDetector(
              onTap: () {
                RitmoHapticsPolicy.selection();
                _setHorizonDays(d);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? colors.card : colors.surface)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.25 : 0.06,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ]
                      : [],
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? colors.border.withValues(alpha: 0.2)
                              : colors.border.withValues(alpha: 0.12),
                          width: 0.75,
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    '${RitmoNumber.faInt(d)} روزه',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? colors.primary
                          : colors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSleepTab(BuildContext context, [double topPadding = 16.0]) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          if (notification.metrics.axis == Axis.vertical) {
            final pixels = notification.metrics.pixels;
            if (pixels > 50 && _isSleepTargetExpanded) {
              setState(() => _isSleepTargetExpanded = false);
            } else if (pixels <= 10 && !_isSleepTargetExpanded) {
              setState(() => _isSleepTargetExpanded = true);
            }
          }
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(10, topPadding, 10, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SleepTargetCard(
                  target: _sleepTarget,
                  isExpanded: _isSleepTargetExpanded,
                  onToggleExpand: () {
                    setState(
                      () => _isSleepTargetExpanded = !_isSleepTargetExpanded,
                    );
                  },
                  onEditTap: () {
                    RitmoSheetScaffold.present(
                      context: context,
                      title: 'تنظیم هدف خواب',
                      builder: (_) => SleepTargetSheet(
                        currentTarget: _sleepTarget,
                        onSaved: _requestReload,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildHorizonFilterRow(context),
                const SizedBox(height: 16),
                SleepOverviewCard(
                  output: _sleepOutput,
                  target: _sleepTarget,
                  sleepLogCount: _rawSleepLogs.length,
                ),
                const SizedBox(height: 16),
                _buildSleepProgramCard(context),
                const SizedBox(height: 16),
                _buildSleepBankCard(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyTab(BuildContext context, [double topPadding = 16.0]) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(10, topPadding, 10, 80),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              DynamicEnergyCard(
                output: _energyOutput,
                onLogTap: () {
                  RitmoSheetScaffold.present(
                    context: context,
                    title: 'ثبت انرژی',
                    builder: (_) => QuickLogSheet(onSaved: _requestReload),
                  );
                },
              ),
              const SizedBox(height: 16),
              _buildHorizonFilterRow(context),
              const SizedBox(height: 16),
              DailyRhythmCard(output: _energyOutput),
              const SizedBox(height: 16),
              MoodAnalyticsCard(output: _moodOutput),
              const SizedBox(height: 16),
              FrictionlessMoodBar(onLogChanged: _requestReload),
              const SizedBox(height: 16),
              _buildEffortDistributionCard(context),
            ]),
          ),
        ),
      ],
    );
  }

  String _formatMissingSignals(List<WellbeingMissingSignal> missing) {
    final hints = <String>[];
    for (final m in missing) {
      final remaining = m.need - m.have;
      if (remaining <= 0) continue;
      switch (m.signal) {
        case WellbeingSignal.sleep:
          hints.add('${RitmoNumber.faInt(remaining)} شب خواب');
          break;
        case WellbeingSignal.energy:
          hints.add('${RitmoNumber.faInt(remaining)} روز انرژی');
          break;
        case WellbeingSignal.mood:
          hints.add('${RitmoNumber.faInt(remaining)} روز حال');
          break;
        case WellbeingSignal.reflection:
          hints.add('${RitmoNumber.faInt(remaining)} روز بازتاب');
          break;
      }
    }
    if (hints.isEmpty) {
      return 'ثبت خواب یا دو سیگنال مشخص';
    }
    return hints.join(' یا ');
  }

  Widget _buildIndexHeroCard(BuildContext context) {
    final colors = context.colors;
    final w = _wellbeing;

    if (w == null || !w.hasValue) {
      final missingText = (w != null && w.missing.isNotEmpty)
          ? 'برای محاسبهٔ شاخص، دست‌کم به ${_formatMissingSignals(w.missing)} نیاز است.'
          : 'برای محاسبه شاخص، دست‌کم به ثبت خواب یا دو سیگنال مشخص نیاز است.';

      return Container(
        padding: const EdgeInsets.all(RitmoSpacing.xl),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          children: [
            const RitmoProgressRing(value: null),
            const SizedBox(height: RitmoSpacing.md),
            Text(
              'داده‌ها هنوز کافی نیست',
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              missingText,
              style: RitmoTextStyles.caption(colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RitmoSpacing.md),
            TextButton.icon(
              onPressed: () => _showExplanation(context),
              icon: Icon(Icons.help_outline, size: 16, color: colors.primary),
              label: Text(
                'چرا این عدد؟ (راهنمای سیگنال‌ها)',
                style: RitmoTextStyles.label(colors.primary),
              ),
            ),
          ],
        ),
      );
    }

    final lower = w.lowerBound != null
        ? RitmoNumber.faInt(w.lowerBound!)
        : '---';
    final upper = w.upperBound != null
        ? RitmoNumber.faInt(w.upperBound!)
        : '---';
    final valStr = w.value != null ? RitmoNumber.faInt(w.value!) : '---';

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          RitmoProgressRing(
            value: w.value,
            confidence: w.confidence,
            lowerBound: w.lowerBound,
            upperBound: w.upperBound,
            onTap: () => _showExplanation(context),
          ),
          const SizedBox(height: RitmoSpacing.md),
          Text(
            'امتیاز شاخص: $valStr — (دامنه $lower تا $upper)',
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          TextButton.icon(
            onPressed: () => _showExplanation(context),
            icon: Icon(Icons.info_outline, size: 16, color: colors.primary),
            label: Text(
              'چرا این عدد؟',
              style: RitmoTextStyles.label(colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEffortDistributionCard(BuildContext context) {
    final colors = context.colors;
    final score = _lifeBalanceOutput?.score;
    final distribution = _lifeBalanceOutput?.distribution ?? {};

    final domainList = [
      (
        key: 'RELIGION',
        label: 'عبادی',
        icon: CupertinoIcons.heart_circle_fill,
        color: const Color(0xff06B6D4),
      ),
      (
        key: 'HEALTH',
        label: 'ورزش و سلامت',
        icon: CupertinoIcons.flame_fill,
        color: const Color(0xff10B981),
      ),
      (
        key: 'LEARNING',
        label: 'یادگیری',
        icon: CupertinoIcons.book_fill,
        color: const Color(0xff3B82F6),
      ),
      (
        key: 'WORK',
        label: 'کار و تلاش',
        icon: CupertinoIcons.briefcase_fill,
        color: const Color(0xffF59E0B),
      ),
      (
        key: 'PERSONAL',
        label: 'شخصی',
        icon: CupertinoIcons.person_crop_circle_fill,
        color: const Color(0xff8B5CF6),
      ),
      (
        key: 'FREE',
        label: 'تفریح',
        icon: CupertinoIcons.gamecontroller_fill,
        color: const Color(0xffEC4899),
      ),
      (
        key: 'OTHER',
        label: 'سایر / متفرقه',
        icon: CupertinoIcons.circle_grid_hex_fill,
        color: colors.textSecondary,
      ),
    ];

    final skipped = _lifeBalanceOutput?.skippedRows ?? 0;

    return Container(
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      CupertinoIcons.chart_pie_fill,
                      color: colors.primary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'توزیع تلاش بین حوزه‌ها',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                ],
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'تعادل: ${RitmoNumber.faInt(score)}٪',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (score == null)
            Container(
              padding: const EdgeInsets.all(RitmoSpacing.md),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'برای محاسبهٔ تعادل زمانی، حداقل ${RitmoNumber.faInt(LifeBalanceEngine.minCompletionsForBalance)} روتین تکمیل‌شده لازم است.',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),
            )
          else ...[
            Column(
              children: domainList.map((d) {
                final percent = distribution[d.key] ?? 0.0;
                final ratio = (percent / 100.0).clamp(0.0, 1.0);
                final minutes = _lifeBalanceOutput?.domainMinutes[d.key] ?? 0;
                final timeLabel = minutes >= 60
                    ? '${RitmoNumber.faInt(minutes ~/ 60)} ساعت ${minutes % 60 > 0 ? 'و ${RitmoNumber.faInt(minutes % 60)} دقیقه' : ''}'
                    : '${RitmoNumber.faInt(minutes)} دقیقه';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(d.icon, size: 13, color: d.color),
                              const SizedBox(width: 6),
                              Text(
                                d.label,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            minutes > 0
                                ? '$timeLabel (${RitmoNumber.faInt(percent.round())}٪)'
                                : '—',
                            style: TextStyle(
                              fontSize: 11,
                              color: minutes > 0
                                  ? colors.textPrimary
                                  : colors.textSecondary.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: colors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ratio > 0 ? colors.primary : colors.border,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (skipped > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${RitmoNumber.faInt(skipped)} تکمیل روتین بدون حوزهٔ مشخص ثبت شده است.',
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSleepProgramCard(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = _sleepProgramState;
    if (state == null) return const SizedBox.shrink();

    // ۱. فاز گوش دادن (listening): زیر ۷ شب داده
    if (state.status == SleepProgramStatus.listening) {
      final nights = state.nightsLogged;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.sleepAccent.withValues(alpha: isDark ? 0.25 : 0.2),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colors.sleepAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.headphones_rounded,
                    color: colors.sleepAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مسیر خواب · در حال شنیدن ریتم شما',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${RitmoNumber.faInt(nights)} شب از ۷ شب لازم برای تنظیم الگوی خواب ثبت شده است.',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 10,
                          color: colors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 7-Night step indicator pills
            Row(
              children: List.generate(7, (i) {
                final isDone = i < nights;
                final isCurrent = i == nights;
                return Expanded(
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(left: i == 6 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: isDone
                          ? colors.sleepAccent
                          : (isCurrent
                                ? colors.sleepAccent.withValues(alpha: 0.4)
                                : colors.border.withValues(
                                    alpha: isDark ? 0.25 : 0.4,
                                  )),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'تا تکمیل این دوره هیچ ساعتی تحمیل نمی‌شود.',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10,
                      color: colors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    RitmoHapticsPolicy.tap();
                    _onInsightAction(WellbeingInsightAction.logSleep);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.sleepAccent.withValues(alpha: 0.15),
                    foregroundColor: colors.sleepAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text(
                    'ثبت خواب دیشب',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ۲. شب آزاد (freeNightTonight)
    if (state.freeNightTonight) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.sleepAccent.withValues(alpha: isDark ? 0.25 : 0.2),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colors.sleepAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.nightlife_rounded,
                color: colors.sleepAccent,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'امشب شب آزاد است 🌙',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'هیچ انتظاری از زمان خواب امشب نیست و در سنجش پایبندی شمرده نمی‌شود. استراحت کن و لذت ببر!',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10,
                      color: colors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ۳. فاز فعال یا لنگر (anchoring / active)
    final timeStr = SleepPlanInsights.hhmm(state.tonightBedtimeMin);
    final targetWakeStr = SleepPlanInsights.hhmm(state.tonightWakeMin);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.sleepAccent.withValues(alpha: isDark ? 0.3 : 0.25),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colors.sleepAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bedtime_rounded,
                  color: colors.sleepAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'پلهٔ امشب · $timeStr',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'هدف بیداری: $targetWakeStr · گام‌های ${RitmoNumber.faInt(state.stepMinutes)} دقیقه‌ای',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 10,
                        color: colors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.holdTonight
                ? 'امشب روی همین پله می‌مانیم تا بدنت تثبیت شود.'
                : 'برای رسیدن تدریجی به هدف نهایی، خوابیدن در بازهٔ ۱۵± دقیقه از این پله پیشنهاد می‌شود.',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 10.5,
              color: colors.textSecondary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (state.adherence7d != null)
                Text(
                  'پایبندی ۷ روزه: ${RitmoNumber.faPercent((state.adherence7d! * 100).round())}',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.sleepAccent,
                  ),
                )
              else
                const SizedBox.shrink(),
              FilledButton.tonalIcon(
                onPressed: () {
                  RitmoHapticsPolicy.tap();
                  _onInsightAction(WellbeingInsightAction.logSleep);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.sleepAccent.withValues(alpha: 0.15),
                  foregroundColor: colors.sleepAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.check, size: 14),
                label: const Text(
                  'ثبت خواب',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepBankCard(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = _sleepOutput?.sleepBalanceHours ?? 0.0;
    final isDeficit = balance < 0;
    final isZeroData = _rawSleepLogs.isEmpty;

    final Color statusColor = isZeroData
        ? colors.textSecondary
        : (isDeficit ? colors.cautionAccent : colors.success);

    return InkWell(
      onTap: () {
        RitmoHapticsPolicy.tap();
        RitmoSheetScaffold.present(
          context: context,
          title: 'تنظیم هدف خواب',
          builder: (ctx) => SleepTargetSheet(
            currentTarget: _sleepTarget,
            onSaved: _requestReload,
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.border.withValues(alpha: isDark ? 0.3 : 0.6),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isZeroData
                    ? Icons.bedtime_outlined
                    : (isDeficit
                          ? Icons.battery_alert_rounded
                          : Icons.battery_charging_full_rounded),
                color: statusColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isZeroData
                        ? 'ذخیرهٔ خواب: داده‌ای ثبت نشده است'
                        : (isDeficit
                              ? 'کسری خواب: ${RitmoNumber.faHours(balance.abs())}'
                              : 'ذخیرهٔ خواب: ${RitmoNumber.faHours(balance)}'),
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isZeroData ? colors.textPrimary : statusColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isZeroData
                        ? 'برای تنظیم هدف خواب و پایش ذخیره زیستی، کلیک کنید.'
                        : (isDeficit
                              ? 'یک خواب جبرانی کوتاه می‌تواند به بازیابی کمک کند.'
                              : 'خواب کافی در روزهای اخیر ذخیرهٔ خوبی ایجاد کرده است.'),
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 10,
                      color: colors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new_rounded,
              color: colors.textSecondary.withValues(alpha: 0.4),
              size: 13,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RitmoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: RitmoSpacing.md),
            Text(
              'خطا در دریافت اطلاعات',
              style: RitmoTextStyles.cardTitle(colors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'مشکلی در بارگذاری داده‌ها پیش آمد.',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
            const SizedBox(height: RitmoSpacing.lg),
            ElevatedButton(
              onPressed: _loadAllData,
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: Text(
                'تلاش دوباره',
                style: RitmoTextStyles.label(colors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WellbeingTabKeepAlive extends StatefulWidget {
  const _WellbeingTabKeepAlive({required this.child});
  final Widget child;

  @override
  State<_WellbeingTabKeepAlive> createState() => _WellbeingTabKeepAliveState();
}

class _WellbeingTabKeepAliveState extends State<_WellbeingTabKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
