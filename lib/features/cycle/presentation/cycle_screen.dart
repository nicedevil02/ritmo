// C-41, C-42, C-43, C-44, C-45: CycleScreen coordinator shell
// Decomposed into clean modular components, theme tokens, and < 800 lines.
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';
import 'package:ritmo/core/ux/ritmo_empty_state.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/cycle/logic/cycle_burden_engine.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_confirmation_service.dart';
import 'package:ritmo/features/cycle/logic/cycle_correlation.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/cycle_load_balancer.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';
import 'package:ritmo/features/cycle/logic/cycle_reminder_scheduler.dart';
import 'package:ritmo/features/cycle/logic/cycle_settings.dart';
import 'package:ritmo/features/cycle/logic/cycle_state_provider.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';
import 'package:ritmo/features/cycle/models/cycle_forecast_models.dart';
import 'package:ritmo/features/cycle/models/cycle_intelligence_models.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/cycle_onboarding_shell.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart';
import 'package:ritmo/features/cycle/presentation/widgets/add_edit_period_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_ai_consent_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_animated_background.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_burden_card.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_calendar_view.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_confirmation_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_correlation_section.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_fasting_debt_view.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_history_list.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_lock_gate.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_log_today_sheet.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_passcode_sheet.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_overview_tab.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_personal_forecast_card.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_prediction_detail_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_lock_gate.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_segmented_tabs.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_settings_panel.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_sos_section.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_trends_section.dart';
import 'package:shamsi_date/shamsi_date.dart';

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
  CycleConfirmationRequest? _pendingConfirmation;
  List<SymptomStat> _symptomStats = [];
  PredictionConfidence? _predictionConfidence;
  DataQualityReport? _dataQualityReport;
  List<SymptomForecast> _personalForecasts = [];
  BodyBurdenScore? _burdenScore;
  CycleAdaptiveAdvice? _adaptiveAdvice;
  Jalali _calendarMonth = Jalali.fromDateTime(CycleClock.now);
  final GlobalKey _calendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _calendarMonth = Jalali.fromDateTime(CycleClock.now);
    CycleStateNotifier.instance.addListener(_onStateNotifierChanged);
    _loadData();
  }

  @override
  void dispose() {
    CycleStateNotifier.instance.removeListener(_onStateNotifierChanged);
    super.dispose();
  }

  void _onTabChanged(int newIndex) {
    if (_activeTab == newIndex) return;
    setState(() {
      _activeTab = newIndex;
    });
  }

  void _onStateNotifierChanged() {
    if (!mounted) return;
    final state = CycleStateNotifier.instance.value;
    setState(() {
      _isLoading = state.isLoading;
      _settings = state.settings;
      _engineOutput = state.engineOutput;
      _dataQualityReport = state.dataQuality;
      _personalForecasts = state.symptomForecasts;

      if (_engineOutput != null) {
        final firstForecast = _engineOutput!.forecast.firstOrNull;
        final confLevel =
            firstForecast?.confidenceLevel ??
            (_periods.length >= 5 &&
                    !(_dataQualityReport?.hasForgottenOpenPeriod ?? false)
                ? PredictionConfidenceLevel.high
                : (_periods.length >= 3
                      ? PredictionConfidenceLevel.medium
                      : PredictionConfidenceLevel.low));
        final confScore =
            firstForecast?.confidence ??
            (_periods.length >= 5
                ? 0.90
                : (_periods.length >= 3 ? 0.65 : 0.35));

        _predictionConfidence = PredictionConfidence(
          level: confLevel,
          score: confScore,
          reasonsFa:
              (_dataQualityReport?.warningsFa != null &&
                  _dataQualityReport!.warningsFa!.isNotEmpty)
              ? _dataQualityReport!.warningsFa!
              : ['${_periods.length} چرخه ثبت‌شده و تحلیل آماری الگوها'],
        );
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final periodModels = await CyclePeriodRepository.instance.getAllPeriods(
        db,
      );
      _periods = periodModels.map((p) => p.toMap()).toList();

      _forgottenPeriod = null;
      for (final p in _periods) {
        if (p['endDate'] == null) {
          final start = CycleDateContract.parseDayKey(
            p['startDate']?.toString(),
          );
          if (start != null &&
              CycleDateContract.daysBetween(start, CycleClock.now) >=
                  CycleSettings.forgottenOpenPeriodDays) {
            _forgottenPeriod = p;
            break;
          }
        }
      }

      _dayLogs = await db.query('cycle_day_logs', orderBy: 'logDate DESC');
      _fastingDebts = await CycleConsentBridge.getFastingDebts();

      // Delegate calculation and unified adjustments to CycleStateNotifier
      await CycleStateNotifier.instance.loadState();
      final state = CycleStateNotifier.instance.value;
      _settings = state.settings;
      await PregnancySettings.reconcileFlags(_settings, db);
      _engineOutput = state.engineOutput;
      _dataQualityReport = state.dataQuality;
      _personalForecasts = state.symptomForecasts;

      if (_engineOutput != null) {
        await CycleReminderScheduler.rescheduleAll(
          dbExecutor: db,
          appSettings: _settings,
          now: CycleClock.now,
        );

        final firstForecast = _engineOutput!.forecast.firstOrNull;
        final confLevel =
            firstForecast?.confidenceLevel ??
            (_periods.length >= 5 &&
                    !(_dataQualityReport?.hasForgottenOpenPeriod ?? false)
                ? PredictionConfidenceLevel.high
                : (_periods.length >= 3
                      ? PredictionConfidenceLevel.medium
                      : PredictionConfidenceLevel.low));
        final confScore =
            firstForecast?.confidence ??
            (_periods.length >= 5
                ? 0.90
                : (_periods.length >= 3 ? 0.65 : 0.35));

        _predictionConfidence = PredictionConfidence(
          level: confLevel,
          score: confScore,
          reasonsFa:
              (_dataQualityReport?.warningsFa != null &&
                  _dataQualityReport!.warningsFa!.isNotEmpty)
              ? _dataQualityReport!.warningsFa!
              : ['${_periods.length} چرخه ثبت‌شده و تحلیل آماری الگوها'],
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

        _pendingConfirmation = await CycleConfirmationService.instance
            .evaluatePendingRequest(
              dbExecutor: db,
              engineOutput: _engineOutput!,
              settings: _settings,
              now: CycleClock.now,
            );
      } else {
        _pendingConfirmation = null;
      }

      _symptomStats = await CycleCorrelationAnalyzer.analyzeSymptomStats(db);
    } catch (e, st) {
      RitmoLog.error('CycleScreen', 'Error loading cycle data: $e', e, st);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openConfirmationSheet(CycleConfirmationRequest request) {
    CycleConfirmationSheet.show(
      context: context,
      request: request,
      onAnswered: _loadData,
    );
  }

  Color _getActivePhaseColor(BuildContext context) {
    final colors = context.colors;
    if (_engineOutput == null) return colors.primary;
    final phase = _engineOutput!.currentPhase;
    switch (phase) {
      case CyclePhase.menstrual:
        return colors.error;
      case CyclePhase.ovulation:
      case CyclePhase.follicular:
      case CyclePhase.pregnancy:
        return colors.accent;
      case CyclePhase.luteal:
        return colors.primary;
      case CyclePhase.dataStale:
        return colors.warning;
      case CyclePhase.noData:
        return colors.textSecondary;
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

  bool _isTogglingPeriod = false;

  Future<void> _togglePeriodToday() async {
    if (_isTogglingPeriod) return;
    setState(() => _isTogglingPeriod = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final open = await CyclePeriodRepository.instance.getOpenPeriod(db);
      final today = CycleDateContract.cleanDate(CycleClock.now);

      if (open != null) {
        final elapsed = open.elapsedDaysAt(today);
        if (elapsed < 2) {
          final ok = await _confirmShortPeriod(elapsed);
          if (!ok) return;
        }
        await CyclePeriodRepository.instance.endPeriod(
          db: db,
          id: open.id,
          endDate: today,
        );
      } else {
        await CyclePeriodRepository.instance.startPeriod(
          db: db,
          startDate: today,
        );
      }

      await _syncConfirmations();
      await _syncFastingDebt();
      await _loadData();
    } catch (e, st) {
      RitmoLog.error('CycleScreen', 'togglePeriodToday failed: $e', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ثبت انجام نشد. دوباره تلاش کنید.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingPeriod = false);
    }
  }

  Future<bool> _confirmShortPeriod(int days) async {
    final res = await RitmoDialog.show(
      context,
      title: 'تأیید ثبت',
      content:
          'این دوره فقط $days روز بوده است. آیا از ثبت پایان اطمینان دارید؟',
      confirmLabel: 'بله، ثبت کن',
      cancelLabel: 'انصراف',
    );
    return res ?? false;
  }

  Future<void> _syncConfirmations() async {
    final db = await DatabaseHelper.instance.database;
    await CycleConfirmationService.instance.onActualCycleStarted(
      dbExecutor: db,
      startDate: CycleClock.now,
    );
    await CycleConfirmationService.instance.pruneOldRequests(dbExecutor: db);
  }

  Future<void> _syncFastingDebt() async {
    final db = await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.addFastingDebtIfNeeded(
      db,
      CycleDateContract.toDayKey(CycleClock.now),
    );
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

  void _openAddEditPeriodSheet({
    String? existingId,
    DateTime? initialStartDate,
    DateTime? initialEndDate,
    Map<String, dynamic>? period,
  }) {
    final targetExistingId =
        existingId ?? (period != null ? period['id']?.toString() : null);
    final targetStart =
        initialStartDate ??
        (period != null
            ? CycleDateContract.parseDayKey(period['startDate']?.toString())
            : null);
    final targetEnd =
        initialEndDate ??
        (period != null
            ? CycleDateContract.parseDayKey(period['endDate']?.toString())
            : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.40,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.60, 0.94],
        expand: false,
        builder: (context, scrollController) => AddEditPeriodSheet(
          period:
              period ??
              () {
                final m = <String, dynamic>{};
                if (targetExistingId != null) m['id'] = targetExistingId;
                if (targetStart != null) {
                  m['startDate'] = CycleDateContract.toDayKey(targetStart);
                }
                if (targetEnd != null) {
                  m['endDate'] = CycleDateContract.toDayKey(targetEnd);
                }
                return m.isEmpty ? null : m;
              }(),
        onValidate: (start, end) {
          return CyclePeriodRepository.validatePeriodRange(
            existing: _periods.map((p) => CyclePeriod.fromMap(p)).toList(),
            editingId: targetExistingId,
            startDate: start,
            endDate: end,
          );
        },
        onSave: (start, end) async {
          final db = await DatabaseHelper.instance.database;
          if (targetExistingId != null && targetExistingId.isNotEmpty) {
            await CyclePeriodRepository.instance.updatePeriod(
              db: db,
              id: targetExistingId,
              startDate: start,
              endDate: end,
              clearEndDate: end == null,
            );
          } else {
            final newId = await CyclePeriodRepository.instance.startPeriod(
              db: db,
              startDate: start,
            );
            if (end != null) {
              await CyclePeriodRepository.instance.endPeriod(
                db: db,
                id: newId,
                endDate: end,
              );
            }
          }
          await _syncConfirmations();
          await _syncFastingDebt();
          await _loadData();
        },
      ),
    ),
  );
}

  Future<void> _deletePeriod(String id) async {
    final db = await DatabaseHelper.instance.database;
    await CyclePeriodRepository.instance.deletePeriod(db: db, id: id);
    await _syncConfirmations();
    await _syncFastingDebt();
    await _loadData();
  }

  Future<void> _closeForgottenPeriod(Map<String, dynamic> period) async {
    final id = period['id']?.toString();
    if (id == null || id.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final start = CycleDateContract.parseDayKey(
      period['startDate']?.toString(),
    );
    if (start == null) return;
    final pDur = CycleSettings.getPeriodDuration(_settings);
    final end = start.add(Duration(days: pDur - 1));
    await CyclePeriodRepository.instance.updatePeriod(
      db: db,
      id: id,
      startDate: start,
      endDate: end,
    );
    await _syncConfirmations();
    await _syncFastingDebt();
    await _loadData();
  }

  Future<void> _openPasscodeSheet() async {
    final hasApp = await CycleLockService.instance.hasAppLockPassword();
    final hasDedicated = await CycleLockService.instance.hasCyclePin();
    if (!mounted) return;
    final mode = (hasApp && !hasDedicated)
        ? CyclePasscodeSheetMode.chooseSource
        : hasDedicated
        ? CyclePasscodeSheetMode.change
        : CyclePasscodeSheetMode.setup;
    await CyclePasscodeSheet.show(context, mode: mode);
    await _loadData();
  }

  void _openPregnancyOnboarding() {
    PregnancyOnboardingShell.show(
      context,
      onCompleted: () {
        Navigator.of(context).pop();
        _loadData();
      },
    );
  }

Future<void> _openBaselineParameterPicker(
    String key,
    String title,
    int minVal,
    int maxVal,
    int defaultVal,
  ) async {
    final currentStr = _settings[key] ?? defaultVal.toString();
    var selectedValue = int.tryParse(currentStr) ?? defaultVal;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final colors = context.colors;
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: RitmoGlassSheet(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.border.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RitmoNeuButton(
                            padding: const EdgeInsets.all(10),
                            radius: 20,
                            onTap: () {
                              if (selectedValue > minVal) {
                                setPickerState(() => selectedValue--);
                              }
                            },
                            child: Icon(
                              CupertinoIcons.minus,
                              size: 20,
                              color: selectedValue > minVal
                                  ? colors.primary
                                  : colors.textSecondary.withValues(alpha: 0.3),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Text(
                            '${RitmoNumber.fa(selectedValue.toString())} روز',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 24),
                          RitmoNeuButton(
                            padding: const EdgeInsets.all(10),
                            radius: 20,
                            onTap: () {
                              if (selectedValue < maxVal) {
                                setPickerState(() => selectedValue++);
                              }
                            },
                            child: Icon(
                              CupertinoIcons.plus,
                              size: 20,
                              color: selectedValue < maxVal
                                  ? colors.primary
                                  : colors.textSecondary.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      RitmoPrimaryButton(
                        label: 'تأیید و ذخیره',
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final db = await DatabaseHelper.instance.database;
                          final nowMs = CycleClock.nowMillisecondsSinceEpoch;
                          final valStr = selectedValue.toString();

                          final batch = db.batch();
                          batch.insert(
                            'app_settings',
                            {'key': key, 'value': valStr, 'updatedAt': nowMs},
                            conflictAlgorithm: ConflictAlgorithm.replace,
                          );

                          if (key == 'cycle_avg_length') {
                            batch.insert(
                              'app_settings',
                              {
                                'key': 'user_cycle_length',
                                'value': valStr,
                                'updatedAt': nowMs,
                              },
                              conflictAlgorithm: ConflictAlgorithm.replace,
                            );
                            batch.insert(
                              'app_settings',
                              {
                                'key': CycleSettings.keyCycleLength,
                                'value': valStr,
                                'updatedAt': nowMs,
                              },
                              conflictAlgorithm: ConflictAlgorithm.replace,
                            );
                          } else if (key == 'cycle_avg_period') {
                            batch.insert(
                              'app_settings',
                              {
                                'key': 'user_period_length',
                                'value': valStr,
                                'updatedAt': nowMs,
                              },
                              conflictAlgorithm: ConflictAlgorithm.replace,
                            );
                            batch.insert(
                              'app_settings',
                              {
                                'key': CycleSettings.keyPeriodDuration,
                                'value': valStr,
                                'updatedAt': nowMs,
                              },
                              conflictAlgorithm: ConflictAlgorithm.replace,
                            );
                          }
                          await batch.commit(noResult: true);

                          CycleEngine().invalidate();
                          await _loadData();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.40,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.60, 0.94],
        expand: false,
        builder: (context, scrollController) => RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 12,
          ),
          child: SingleChildScrollView(
              controller: scrollController,
              child: CycleSettingsPanel(
                settings: _settings,
                onDataReloadNeeded: _loadData,
                onOpenPasscodeSheet: _openPasscodeSheet,
                onOpenPregnancyOnboarding: () {
                  Navigator.pop(ctx);
                  _openPregnancyOnboarding();
                },
                onTogglePregnancyMode: () async {
                  Navigator.pop(ctx);
                  final isActive = _settings['cycle_pregnancy_mode'] == 'true';
                  final db = await DatabaseHelper.instance.database;
                  await PregnancySettings.setPregnancyActive(!isActive, db: db);
                  await _loadData();
                },
                onEditBaselineParameter:
                    (key, title, minVal, maxVal, defVal) async {
                  await _openBaselineParameterPicker(
                    key,
                    title,
                    minVal,
                    maxVal,
                    defVal,
                  );
                },
              ),
            ),
          ),
        ),
      );
  }

  String _getPhaseTitle(CyclePhase phase) {
    return switch (phase) {
      CyclePhase.menstrual => 'فاز قاعدگی',
      CyclePhase.follicular => 'فاز فولیکولار',
      CyclePhase.ovulation => 'فاز تخمک‌گذاری',
      CyclePhase.luteal => 'فاز لوتئال',
      CyclePhase.dataStale => 'نیاز به ثبت دوره جدید',
      CyclePhase.pregnancy => 'دوران بارداری',
      CyclePhase.noData => 'ردیاب هوشمند چرخه',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CupertinoActivityIndicator(radius: 14)),
      );
    }

    final isPregnancyActive = CycleSettings.isPregnancyMode(_settings);
    final hasValidPregnancyDates = PregnancySettings.hasValidDates(_settings);

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
                  _openPregnancyOnboarding();
                },
              ),
            ),
            secondaryCtaLabel: 'در حال حاضر باردار هستم',
            onSecondaryCta: _openPregnancyOnboarding,
          ),
        ),
      );
    }

    final contentTopPadding = topPadding + (isPregnancyActive ? 104.0 : 190.0);

    if (isPregnancyActive) {
      return RitmoTabbedMorphingScaffold(
        title: 'دوران بارداری',
        background: CycleAnimatedBackground(
          phase: _engineOutput?.currentPhase ?? CyclePhase.follicular,
          isDark: isDark,
          isPregnancy: true,
        ),
        accentColor: _getActivePhaseColor(context),
        onBack: () => Navigator.pop(context),
        actions: [
          RitmoVibrancyActionButton(
            icon: CupertinoIcons.sparkles,
            iconColor: _getActivePhaseColor(context),
            isAiButton: true,
            accentColor: _getActivePhaseColor(context),
            tooltip: 'دستیار هوشمند چرخه',
            onTap: _openAiAssistant,
          ),
          const SizedBox(width: 8),
          RitmoVibrancyActionButton(
            icon: CupertinoIcons.gear_alt_fill,
            iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
            tooltip: 'تنظیمات چرخه',
            onTap: _openSettingsSheet,
          ),
        ],
        tabItems: const [
          RitmoTabItem(
            title: 'بارداری',
            icon: CupertinoIcons.heart_fill,
            value: 0,
          ),
        ],
        tabBuilders: [
          (ctx, scrollController) => hasValidPregnancyDates
              ? PregnancyLockGate(
                  settings: _settings,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, bottomPadding + 14.0),
                    child: CyclePregnancyModeView(
                      pregnancyStartDate: _settings['preg_start_date']!,
                      pregnancyDueDate: _settings['preg_due_date']!,
                      onDeactivated: () async {
                        final db = await DatabaseHelper.instance.database;
                        await PregnancySettings.setPregnancyActive(
                          false,
                          db: db,
                        );
                        await _loadData();
                      },
                      settings: _settings,
                      dayLogs: _dayLogs,
                      engineOutput: _engineOutput,
                    ),
                  ),
                )
              : Directionality(
                  textDirection: TextDirection.rtl,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: RitmoCard.neumorphic(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              size: 48,
                              color: colors.warning,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'اطلاعات بارداری ناقص است',
                              style: RitmoTextStyles.cardTitle(colors.textPrimary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'برای محاسبه دقیق سن بارداری و دسترسی به امکانات، لطفاً اطلاعات راه‌اندازی را تکمیل کنید.',
                              style: RitmoTextStyles.caption(colors.textSecondary).copyWith(height: 1.45),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            RitmoPrimaryButton(
                              icon: CupertinoIcons.pencil,
                              label: 'تکمیل راه‌اندازی بارداری',
                              onPressed: _openPregnancyOnboarding,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      );
    }

    return RitmoTabbedMorphingScaffold(
      title: 'چرخه بدن',
      subtitle: _engineOutput != null
          ? '${_getPhaseTitle(_engineOutput!.currentPhase)} • روز ${RitmoNumber.toFa(_engineOutput!.dayOfCycle)} چرخه'
          : 'ردیاب هوشمند سلامت و الگوهای هورمونی',
      background: CycleAnimatedBackground(
        phase: _engineOutput?.currentPhase ?? CyclePhase.follicular,
        isDark: isDark,
        isPregnancy: false,
      ),
      accentColor: _getActivePhaseColor(context),
      initialIndex: _activeTab,
      onTabChanged: (index) => setState(() => _activeTab = index),
      onBack: () => Navigator.pop(context),
      actions: [
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.sparkles,
          iconColor: _getActivePhaseColor(context),
          isAiButton: true,
          accentColor: _getActivePhaseColor(context),
          tooltip: 'دستیار هوشمند چرخه',
          onTap: _openAiAssistant,
        ),
        const SizedBox(width: 8),
        RitmoVibrancyActionButton(
          icon: CupertinoIcons.gear_alt_fill,
          iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
          tooltip: 'تنظیمات چرخه',
          onTap: _openSettingsSheet,
        ),
      ],
      customTabsBuilder: (context, activeIndex, onTabChanged) => CycleSegmentedTabs(
        activeTab: activeIndex,
        onTabChanged: onTabChanged,
        settings: _settings,
        activeThemeColor: _getActivePhaseColor(context),
      ),
      tabItems: const [
        RitmoTabItem(
          title: 'نمای کلی',
          icon: CupertinoIcons.sparkles,
          value: 0,
        ),
        RitmoTabItem(
          title: 'روندها',
          icon: CupertinoIcons.chart_bar_alt_fill,
          value: 1,
        ),
        RitmoTabItem(
          title: 'همبستگی',
          icon: CupertinoIcons.waveform_path,
          value: 2,
        ),
        RitmoTabItem(
          title: 'قضای روزه',
          icon: CupertinoIcons.moon_fill,
          value: 3,
        ),
      ],
      tabBuilders: [
        // Tab 0: نمای کلی
        (ctx, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              10,
              contentTopPadding,
              10,
              bottomPadding + 14.0,
            ),
            children: [
              CycleOverviewTab(
                engineOutput: _engineOutput,
                periods: _periods,
                settings: _settings,
                forgottenPeriod: _forgottenPeriod,
                symptomStats: _symptomStats,
                activePhaseColor: _getActivePhaseColor(context),
                isTogglingPeriod: _isTogglingPeriod,
                onTogglePeriodToday: _togglePeriodToday,
                onOpenDailyLog: _openLogTodaySheet,
                onCloseForgottenPeriod: _closeForgottenPeriod,
                onEditPeriod: (p) =>
                    _openAddEditPeriodSheet(period: p),
                pendingConfirmation: _pendingConfirmation,
                onOpenConfirmation: _pendingConfirmation != null
                    ? () => _openConfirmationSheet(
                        _pendingConfirmation!,
                      )
                    : null,
                onNavigateToCalendar: () {
                  if (_activeTab != 0) {
                    _onTabChanged(0);
                  }
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) {
                    final calCtx = _calendarKey.currentContext;
                    if (calCtx != null) {
                      Scrollable.ensureVisible(
                        calCtx,
                        duration:
                            const Duration(milliseconds: 650),
                        curve: Curves.easeInOutCubic,
                        alignment: 0.05,
                      );
                    }
                  });
                },
                onOpenSos: () => CycleSosSection.showSosModal(
                  context,
                  engineOutput: _engineOutput,
                  dayLogs: _dayLogs,
                  settings: _settings,
                  phase: _engineOutput?.currentPhase ??
                      CyclePhase.follicular,
                ),
                predictionConfidence: _predictionConfidence,
                dataQualityReport: _dataQualityReport,
                onOpenDataTab: () => _onTabChanged(1),
                insightCards: [
                  if (_burdenScore != null && _adaptiveAdvice != null)
                    CycleBurdenCard(
                      burden: _burdenScore!,
                      advice: _adaptiveAdvice!,
                      phase: _engineOutput?.currentPhase ??
                          CyclePhase.follicular,
                      onOpenGuide: _engineOutput != null
                          ? () => CycleSosSection.showSosModal(
                                context,
                                engineOutput: _engineOutput,
                                dayLogs: _dayLogs,
                                settings: _settings,
                                phase: _engineOutput!.currentPhase,
                              )
                          : null,
                    ),
                  if (_personalForecasts.isNotEmpty)
                    CyclePersonalForecastCard(
                      forecasts: _personalForecasts,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              CycleCalendarView(
                key: _calendarKey,
                calendarMonth: _calendarMonth,
                onMonthChanged: (m) async {
                  setState(() => _calendarMonth = m);
                  final lastDayOfMonth = Jalali(
                    m.year,
                    m.month,
                    m.monthLength,
                  ).toDateTime();
                  await CycleStateNotifier.instance
                      .ensureHorizonCovers(lastDayOfMonth);
                },
                periods: _periods,
                dayLogs: _dayLogs,
                engineOutput: _engineOutput,
                settings: _settings,
                activePhaseColor: _getActivePhaseColor(context),
                onDayTapped: (day, mark) {
                  if (mark.kind == CycleDayKind.predictedPeriod ||
                      mark.kind ==
                          CycleDayKind.predictionWindow ||
                      mark.kind == CycleDayKind.ovulation ||
                      mark.kind == CycleDayKind.fertileWindow ||
                      mark.kind == CycleDayKind.pms) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) =>
                          CyclePredictionDetailSheet(
                            selectedDate: day,
                            mark: mark,
                            engineOutput: _engineOutput,
                            symptomForecasts: _personalForecasts,
                            onRecordPeriodFromDate: (d) =>
                                _openAddEditPeriodSheet(
                                  initialStartDate: d,
                                ),
                          ),
                    );
                  } else {
                    _openLogTodaySheet(day);
                  }
                },
              ),
              const SizedBox(height: 16),
              CycleHistoryList(
                periods: _periods,
                onAddNewPeriod: () => _openAddEditPeriodSheet(),
                onEditPeriod: (p) =>
                    _openAddEditPeriodSheet(period: p),
                onDeletePeriod: _deletePeriod,
              ),
            ],
          ),
        ),

        // Tab 1: روندها
        (ctx, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              10,
              contentTopPadding,
              10,
              bottomPadding + 14.0,
            ),
            children: [
              if (_engineOutput != null)
                CycleTrendsSection(engineOutput: _engineOutput!),
            ],
          ),
        ),

        // Tab 2: همبستگی
        (ctx, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              10,
              contentTopPadding,
              10,
              bottomPadding + 14.0,
            ),
            children: const [
              CycleCorrelationSection(),
            ],
          ),
        ),

        // Tab 3: قضای روزه
        (ctx, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              10,
              contentTopPadding,
              10,
              bottomPadding + 14.0,
            ),
            children: [
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
          ),
        ),
      ],
    );
  }
}
