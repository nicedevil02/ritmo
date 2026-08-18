// C-41, C-42, C-43, C-44, C-45: CycleScreen coordinator shell
// Decomposed into clean modular components, theme tokens, and < 800 lines.
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';
import 'package:ritmo/core/ux/ritmo_empty_state.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/cycle/logic/cycle_burden_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_correlation.dart';
import 'package:ritmo/features/cycle/logic/cycle_data_quality_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_load_balancer.dart';
import 'package:ritmo/features/cycle/logic/cycle_personal_pattern_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_reminder_scheduler.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/logic/cycle_state_provider.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/cycle_onboarding_shell.dart';
import 'package:ritmo/features/cycle/presentation/widgets/add_edit_period_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_ai_consent_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_animated_background.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_burden_card.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_view.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_correlation_section.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_fasting_debt_view.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_history_list.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_lock_gate.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_log_today_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_overview_tab.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_personal_forecast_card.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_prediction_confidence_card.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_settings_panel.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_sos_section.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_trends_section.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

class CycleScreen extends StatelessWidget {
  const CycleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CycleLockGate(child: _CycleScreenContent());
  }
}

class _CycleScreenContent extends StatefulWidget {
  const _CycleScreenContent();

  @override
  State<_CycleScreenContent> createState() => _CycleScreenContentState();
}

class _CycleScreenContentState extends State<_CycleScreenContent> {
  bool _isLoading = true;
  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _periods = [];
  List<Map<String, dynamic>> _dayLogs = [];
  CycleEngineOutput? _engineOutput;
  int _activeTab = 0;
  List<FastingDebt> _fastingDebts = [];
  Map<String, dynamic>? _forgottenPeriod;
  List<SymptomStat> _symptomStats = [];
  PredictionConfidence? _predictionConfidence;
  DataQualityReport? _dataQualityReport;
  List<SymptomForecast> _personalForecasts = [];
  BodyBurdenScore? _burdenScore;
  CycleAdaptiveAdvice? _adaptiveAdvice;
  Jalali _calendarMonth = Jalali.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final settingsList = await db.query('app_settings');
      _settings = {
        for (final s in settingsList)
          if (s['key'] != null)
            s['key'].toString(): s['value']?.toString() ?? '',
      };

      _periods = await db.query('cycle_periods', orderBy: 'startDate DESC');

      _forgottenPeriod = null;
      for (final p in _periods) {
        if (p['endDate'] == null) {
          final start = CycleDateContract.parseDayKey(
            p['startDate']?.toString(),
          );
          if (start != null &&
              CycleDateContract.daysBetween(start, CycleClock.now) >= 12) {
            _forgottenPeriod = p;
            break;
          }
        }
      }

      _dayLogs = await db.query('cycle_day_logs', orderBy: 'logDate DESC');
      _fastingDebts = await CycleConsentBridge.getFastingDebts();

      final engine = CycleEngine();
      _engineOutput = await engine.calculate(
        CycleEngineInput(db: db, appSettings: _settings, now: CycleClock.now),
      );

      if (_engineOutput != null) {
        await CycleReminderScheduler.rescheduleAll(
          dbExecutor: db,
          appSettings: _settings,
          now: CycleClock.now,
        );

        final todayStr = CycleDateContract.toDayKey(CycleClock.now);
        _dataQualityReport = await CycleDataQualityEngine.evaluateDataQuality(
          db: db,
          periodRows: _periods,
          todayIso: todayStr,
        );

        final confLevel =
            _periods.length >= 5 && !_dataQualityReport!.hasForgottenOpenPeriod
            ? PredictionConfidenceLevel.high
            : (_periods.length >= 2
                  ? PredictionConfidenceLevel.medium
                  : PredictionConfidenceLevel.low);
        final confScore = _periods.length >= 5
            ? 0.90
            : (_periods.length >= 2 ? 0.65 : 0.35);
        _predictionConfidence = PredictionConfidence(
          level: confLevel,
          score: confScore,
          reasonsFa:
              (_dataQualityReport!.warningsFa != null &&
                  _dataQualityReport!.warningsFa!.isNotEmpty)
              ? _dataQualityReport!.warningsFa!
              : ['${_periods.length} چرخه ثبت‌شده و الگوی نسبتاً پایدار'],
        );

        _personalForecasts =
            await CyclePersonalPatternEngine.computePersonalForecasts(
              db: db,
              periodRows: _periods,
              avgCycleLength: _engineOutput!.stats.avgCycleLength,
            );

        final latestLog = _dayLogs.isNotEmpty ? _dayLogs.first : null;
        final symptomsStr = latestLog?['symptoms'] as String? ?? '';
        final loggedSymptoms = symptomsStr.isNotEmpty
            ? symptomsStr.split(',')
            : <String>[];

        _burdenScore = CycleBurdenEngine.calculateBurden(
          phase: _engineOutput!.currentPhase,
          dayOfPeriod: _engineOutput!.dayOfPeriod,
          flowIntensity: latestLog?['flowLevel'] as String?,
          loggedSymptoms: loggedSymptoms,
          energyTag: null,
          sleepHours: null,
        );

        _adaptiveAdvice = CycleLoadBalancer.generateAdvice(
          _burdenScore!,
          phase: _engineOutput!.currentPhase,
        );
      }

      _symptomStats = await CycleCorrelationAnalyzer.analyzeSymptomStats(db);
    } catch (e, st) {
      RitmoLog.error('CycleScreen', 'Error loading cycle data: $e', e, st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getActivePhaseColor(BuildContext context) {
    final colors = context.colors;
    if (_engineOutput == null) return colors.primary;
    final phase = _engineOutput!.currentPhase;
    switch (phase) {
      case CyclePhase.menstrual:
        return colors.error;
      case CyclePhase.ovulation:
        return colors.accent;
      case CyclePhase.luteal:
        return colors.primary;
      case CyclePhase.follicular:
      default:
        return colors.accent;
    }
  }

  void _openAiAssistant() {
    showCycleAiConsentSheet(
      context,
      engineOutput: _engineOutput,
      dayLogs: _dayLogs,
      settings: _settings,
      onConsentGranted: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AssistantSheet(
            persona: PersonaRegistry.instance.getPersona('cycle')!,
          ),
        );
      },
    );
  }

  Future<void> _togglePeriodToday() async {
    if (_engineOutput == null) return;
    final db = await DatabaseHelper.instance.database;
    final todayStr = CycleDateContract.toDayKey(CycleClock.now);
    final nowMs = CycleClock.nowMillisecondsSinceEpoch;

    final hasActivePeriod = _periods.any((p) {
      final start = CycleDateContract.parseDayKey(p['startDate']?.toString());
      return p['endDate'] == null &&
          start != null &&
          CycleDateContract.daysBetween(start, CycleClock.now) < 12;
    });

    if (!hasActivePeriod) {
      if (_forgottenPeriod != null) {
        if (mounted) {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('خطا در ثبت دوره جدید'),
                content: const Text(
                  'شما یک دورهٔ باز قدیمی (فراموش‌شده) دارید. لطفاً ابتدا تکلیف آن را مشخص کنید.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('متوجه شدم'),
                  ),
                ],
              ),
            ),
          );
        }
        return;
      }

      await db.insert('cycle_periods', {
        'id': 'period_$nowMs',
        'startDate': todayStr,
        'endDate': null,
        'flowIntensity': 'MEDIUM',
        'isPredicted': 0,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      });

      if (_settings['cycle_consent_worship'] == 'true') {
        await DatabaseHelper.instance.addFastingDebtIfNeeded(db, todayStr);
      }
    } else {
      final active = _periods.firstWhere((p) {
        final start = CycleDateContract.parseDayKey(p['startDate']?.toString());
        return p['endDate'] == null &&
            start != null &&
            CycleDateContract.daysBetween(start, CycleClock.now) < 12;
      });
      await db.update(
        'cycle_periods',
        {'endDate': todayStr, 'updatedAt': nowMs},
        where: 'id = ?',
        whereArgs: [active['id']],
      );
    }

    RitmoEventBus().fire(
      RitmoEvent(
        type: hasActivePeriod ? 'CycleEnded' : 'CycleStarted',
        payload: {'date': todayStr},
      ),
    );
    await _loadData();
  }

  void _openLogTodaySheet([DateTime? targetDate]) {
    final effectiveDate = targetDate ?? CycleClock.now;
    final dateStr = CycleDateContract.toDayKey(effectiveDate);
    final dayLog = _dayLogs.cast<Map<String, dynamic>?>().firstWhere(
      (l) => l?['logDate'] == dateStr || l?['dateIso'] == dateStr,
      orElse: () => null,
    );

    CycleLogTodaySheet.show(
      context: context,
      todayStr: dateStr,
      todayLog: dayLog,
      activePhaseColor: _getActivePhaseColor(context),
      onSaved: _loadData,
    );
  }

  void _openAddEditPeriodSheet([Map<String, dynamic>? period]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditPeriodSheet(
        period: period,
        onValidate: (start, end) {
          if (end != null && end.isBefore(start)) {
            return 'تاریخ پایان نمی‌تواند قبل از تاریخ شروع باشد.';
          }
          return null;
        },
        onSave: (start, end) async {
          final db = await DatabaseHelper.instance.database;
          final startStr = CycleDateContract.toDayKey(start);
          final endStr = end != null ? CycleDateContract.toDayKey(end) : null;
          final nowMs = CycleClock.nowMillisecondsSinceEpoch;

          if (period != null) {
            await db.update(
              'cycle_periods',
              {'startDate': startStr, 'endDate': endStr, 'updatedAt': nowMs},
              where: 'id = ?',
              whereArgs: [period['id']],
            );
          } else {
            await db.insert('cycle_periods', {
              'id': 'period_$nowMs',
              'startDate': startStr,
              'endDate': endStr,
              'flowIntensity': 'MEDIUM',
              'isPredicted': 0,
              'createdAt': nowMs,
              'updatedAt': nowMs,
            });
          }
          await _loadData();
        },
      ),
    );
  }

  Future<void> _deletePeriod(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('cycle_periods', where: 'id = ?', whereArgs: [id]);
    await _loadData();
  }

  Future<void> _closeForgottenPeriod(Map<String, dynamic> period) async {
    final db = await DatabaseHelper.instance.database;
    final start = CycleDateContract.parseDayKey(
      period['startDate']?.toString(),
    );
    if (start == null) return;
    final pDur = CycleSettings.getPeriodDuration(_settings);
    final end = start.add(Duration(days: pDur - 1));
    final endStr = CycleDateContract.toDayKey(end);

    await db.update(
      'cycle_periods',
      {'endDate': endStr, 'updatedAt': CycleClock.nowMillisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [period['id']],
    );
    await _loadData();
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RitmoSheetGlassCard(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: CycleSettingsPanel(
              settings: _settings,
              onDataReloadNeeded: _loadData,
              onOpenPasscodeSheet: () {},
              onTogglePregnancyMode: () async {
                Navigator.pop(ctx);
                final isActive = _settings['cycle_pregnancy_mode'] == 'true';
                final db = await DatabaseHelper.instance.database;
                await db.insert('app_settings', {
                  'key': 'cycle_pregnancy_mode',
                  'value': (!isActive).toString(),
                  'updatedAt': CycleClock.nowMillisecondsSinceEpoch,
                }, conflictAlgorithm: ConflictAlgorithm.replace);
                await _loadData();
              },
              onEditBaselineParameter: (key, title, min, max, defVal) async {
                // Implementation for parameter edit
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    final isPregnancyActive = _settings['cycle_pregnancy_mode'] == 'true';

    if (_periods.isEmpty && !isPregnancyActive) {
      return Scaffold(
        body: SafeArea(
          child: RitmoEmptyState(
            title: 'ردیاب هوشمند چرخه بدن',
            description:
                'اطلاعات دوره‌های قاعدگی، پیش‌بینی‌ها، الگوها و خودمراقبتی هوشمند در این بخش مدیریت می‌شوند.',
            icon: CupertinoIcons.heart_circle_fill,
            ctaLabel: 'راه‌اندازی چرخه',
            onCta: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => CycleOnboardingShell(
                onCompleted: () {
                  Navigator.pop(ctx);
                  _loadData();
                },
                onNavigateToPregnancy: () {
                  Navigator.pop(ctx);
                  _loadData();
                },
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CycleAnimatedBackground(
              phase: _engineOutput?.currentPhase ?? CyclePhase.follicular,
              isDark: isDark,
              isPregnancy: isPregnancyActive,
            ),
          ),
          SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (ctx, innerBoxIsScrolled) => [
                SliverAppBar(
                  floating: true,
                  pinned: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    isPregnancyActive ? 'بارداری' : 'چرخه بدن',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colors.textPrimary,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.sparkles,
                        color: colors.primary,
                        size: 20,
                      ),
                      onPressed: _openAiAssistant,
                    ),
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.gear_alt,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                      onPressed: _openSettingsSheet,
                    ),
                  ],
                ),
              ],
              body: isPregnancyActive
                  ? CyclePregnancyModeView(
                      pregnancyStartDate:
                          _settings['preg_start_date'] ??
                          CycleClock.now.toIso8601String(),
                      pregnancyDueDate:
                          _settings['preg_due_date'] ??
                          CycleClock.now
                              .add(const Duration(days: 280))
                              .toIso8601String(),
                      onDeactivated: () async {
                        final db = await DatabaseHelper.instance.database;
                        await db.insert(
                          'app_settings',
                          {'key': 'cycle_pregnancy_mode', 'value': 'false'},
                          conflictAlgorithm: ConflictAlgorithm.replace,
                        );
                        await _loadData();
                      },
                      settings: _settings,
                      dayLogs: _dayLogs,
                      engineOutput: _engineOutput,
                    )
                  : Directionality(
                      textDirection: TextDirection.rtl,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        children: [
                          _buildSegmentedTabs(colors),
                          const SizedBox(height: 16),
                          if (_activeTab == 0) ...[
                            if (_predictionConfidence != null &&
                                _dataQualityReport != null)
                              CyclePredictionConfidenceCard(
                                confidence: _predictionConfidence!,
                                dataQuality: _dataQualityReport!,
                              ),
                            const SizedBox(height: 16),
                            if (_burdenScore != null && _adaptiveAdvice != null)
                              CycleBurdenCard(
                                burden: _burdenScore!,
                                advice: _adaptiveAdvice!,
                              ),
                            const SizedBox(height: 16),
                            if (_personalForecasts.isNotEmpty)
                              CyclePersonalForecastCard(
                                forecasts: _personalForecasts,
                              ),
                            const SizedBox(height: 16),
                            if (_engineOutput != null)
                              CycleSosSection(
                                engineOutput: _engineOutput,
                                dayLogs: _dayLogs,
                                settings: _settings,
                                phase: _engineOutput!.currentPhase,
                              ),
                            const SizedBox(height: 16),
                            CycleOverviewTab(
                              engineOutput: _engineOutput,
                              periods: _periods,
                              settings: _settings,
                              forgottenPeriod: _forgottenPeriod,
                              symptomStats: _symptomStats,
                              activePhaseColor: _getActivePhaseColor(context),
                              onTogglePeriodToday: _togglePeriodToday,
                              onOpenDailyLog: _openLogTodaySheet,
                              onCloseForgottenPeriod: _closeForgottenPeriod,
                              onEditPeriod: _openAddEditPeriodSheet,
                            ),
                            const SizedBox(height: 16),
                            CycleCalendarView(
                              calendarMonth: _calendarMonth,
                              onMonthChanged: (m) async {
                                setState(() => _calendarMonth = m);
                                final lastDayOfMonth = Jalali(m.year, m.month, m.monthLength).toDateTime();
                                await CycleStateNotifier.instance.ensureHorizonCovers(lastDayOfMonth);
                              },
                              periods: _periods,
                              dayLogs: _dayLogs,
                              engineOutput: _engineOutput,
                              settings: _settings,
                              activePhaseColor: _getActivePhaseColor(context),
                              onDayTapped: _openLogTodaySheet,
                            ),
                            const SizedBox(height: 16),
                            CycleHistoryList(
                              periods: _periods,
                              onAddNewPeriod: () => _openAddEditPeriodSheet(),
                              onEditPeriod: _openAddEditPeriodSheet,
                              onDeletePeriod: _deletePeriod,
                            ),
                          ] else if (_activeTab == 1) ...[
                            if (_engineOutput != null)
                              CycleTrendsSection(engineOutput: _engineOutput!),
                          ] else if (_activeTab == 2) ...[
                            const CycleCorrelationSection(),
                          ] else if (_activeTab == 3) ...[
                            CycleFastingDebtView(
                              fastingDebts: _fastingDebts,
                              settings: _settings,
                              onToggleSync: (enabled) async {
                                final db =
                                    await DatabaseHelper.instance.database;
                                await db.insert(
                                  'app_settings',
                                  {
                                    'key': 'cycle_send_fasting_debt_to_worship',
                                    'value': enabled.toString(),
                                    'updatedAt':
                                        CycleClock.nowMillisecondsSinceEpoch,
                                  },
                                  conflictAlgorithm: ConflictAlgorithm.replace,
                                );
                                await _loadData();
                              },
                              onReloadData: _loadData,
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs(RitmoColors colors) {
    final showWorship = ModuleGate.instance.isEnabledFrom(
      _settings,
      'module_religion_enabled',
    );
    final activeThemeColor = _getActivePhaseColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildTabButton(int index, String label, IconData icon) {
      final isActive = _activeTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _activeTab = index);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? activeThemeColor.withValues(alpha: 0.12)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.black.withValues(alpha: 0.02)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? activeThemeColor
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : colors.border),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isActive
                      ? activeThemeColor
                      : (isDark ? Colors.white54 : colors.textSecondary),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? activeThemeColor
                        : (isDark ? Colors.white70 : colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTabButton(0, 'داشبورد', CupertinoIcons.today),
        buildTabButton(1, 'روندها', CupertinoIcons.chart_bar_alt_fill),
        buildTabButton(2, 'همبستگی‌ها', CupertinoIcons.sparkles),
        if (showWorship)
          buildTabButton(3, 'روزه قضا', CupertinoIcons.bookmark_fill),
      ],
    );
  }
}
