import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/ai/ai_briefing_service.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/ai/ai_shared_rules.dart';
import 'package:ritmo/core/ai/daily_digest_builder.dart';
import 'package:ritmo/core/analytics/data_maturity_engine.dart';
import 'package:ritmo/core/analytics/energy_analytics_engine.dart';
import 'package:ritmo/core/analytics/insight_generation_engine.dart';
import 'package:ritmo/core/analytics/life_balance_engine.dart';
import 'package:ritmo/core/analytics/milestone_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/engine_enums.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/services/ad_service.dart';
import 'package:ritmo/core/services/central_inbox_service.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/utils/ritmo_date.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/premium_gate.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';
import 'package:ritmo/features/today/presentation/widgets/ai_deep_analysis_dialog.dart';
import 'package:ritmo/features/today/presentation/widgets/insights_time_window_ruler.dart';
import 'package:ritmo/features/today/presentation/widgets/life_pulse_sparkline_chart.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/ux/ritmo_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  int _loadGeneration = 0;
  AiBriefing? _briefing;
  bool _isDeepAnalyzing = false;
  String? _deepAnalysisResult;

  // Selected time window ruler state (ط۵)
  InsightsTimeWindow _selectedWindow = InsightsTimeWindow.last7Days;
  bool _isTabsVisible = true;

  // Gate & Metrics
  int _daysOfData = 0;
  int _completionCount = 0;
  int _lifePulseAverage = 0;
  int _pulseDiffPercentage = 0;
  bool _pulseDiffUp = true;

  int _pulseMonthlyChange = 0;
  bool _pulseMonthlyUp = true;
  List<Map<String, dynamic>> _pulseHistoryList = [];

  // Life Balance
  int _lifeBalanceScore = 0;
  Map<String, double> _categoryDistribution = {};

  // Energy
  String? _peakPerformanceWindow;
  String? _mostProductiveWeekday;
  String? _mostFatiguedWindow;

  // Milestones & Insights
  List<Milestone> _milestones = [];
  List<InsightResult> _insights = [];

  // Streaks
  int _currentStreak = 0;
  int _longestStreak = 0;

  // Private Data Excluded Check
  bool _isCycleModuleEnabled = false;
  bool _isFemale = false;

  final Map<String, Color> _domainColors = {
    'RELIGION': const Color(0xffFBBF24), // amber
    'HEALTH': const Color(0xffEF4444),   // red
    'LEARNING': const Color(0xff3B82F6), // blue
    'WORK': const Color(0xff8B5CF6),     // purple
    'PERSONAL': const Color(0xffEC4899), // pink
    'FREE': const Color(0xff10B981),     // green
  };

  final Map<String, String> _domainNamesFarsi = {
    'RELIGION': 'عبادی و معنوی',
    'HEALTH': 'ورزش و سلامتی',
    'LEARNING': 'آموزش و یادگیری',
    'WORK': 'کار و پروژه‌ها',
    'PERSONAL': 'شخصی و خانوادگی',
    'FREE': 'تفریح و استراحت',
  };

  @override
  void initState() {
    super.initState();
    // POP v1.1 — defer heavy analytics load until after first frame
    // so the Insights scaffold renders immediately (no jank on tab switch).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAnalytics(showLoading: true);
    });
  }

  @override
  void dispose() {
    AdService.instance.showInterstitialAd();
    super.dispose();
  }

  // IN-05: Safe percent change helper to prevent division by zero / NaN / Infinity crash
  (int percent, bool isUp) _safePercentChange(double current, double previous) {
    if (previous <= 0.0 || !previous.isFinite || !current.isFinite) {
      return (0, true);
    }
    final diff = current - previous;
    final percent = ((diff.abs() / previous) * 100).round().clamp(0, 999);
    return (percent, diff >= 0);
  }

  Future<void> _loadAnalytics({bool showLoading = false, bool isRefresh = false}) async {
    final generation = ++_loadGeneration;

    if (mounted) {
      setState(() {
        if (isRefresh) {
          _isRefreshing = true;
        } else if (showLoading) {
          _isLoading = true;
        }
        _error = null;
        // IN-15: Explicit reset so stale data is not rendered
        _insights = [];
        _milestones = [];
        _categoryDistribution = {};
        _lifeBalanceScore = 0; // IN-16: 0 means uncalculated, not 100
        _peakPerformanceWindow = null;
        _mostProductiveWeekday = null;
        _mostFatiguedWindow = null;
        _pulseDiffPercentage = 0;
        _pulseMonthlyChange = 0;
      });
    }

    try {
      final loadedAt = DateTime.now();
      final db = await DatabaseHelper.instance.database;

      // 1. Fetch raw data from DB using windowed queries for memory safety (ط۳, IN-02, IN-23)
      final windowDays = _selectedWindow.days;
      final windowStart = loadedAt.subtract(Duration(days: windowDays));
      final windowStartMs = windowStart.millisecondsSinceEpoch;
      final windowStartDay = RitmoDate.dayKey(windowStart);

      final completionsRaw = await db.query(
        'routine_completions',
        where: 'completionTime >= ?',
        whereArgs: [windowStartMs],
      );
      final completions = completionsRaw.map(Map<String, dynamic>.from).toList();

      final energyRaw = await db.query(
        'energy_logs',
        where: 'loggedAt >= ?',
        whereArgs: [windowStartMs],
      );
      final energy = energyRaw.map(Map<String, dynamic>.from).toList();

      final rhythmsRaw = await db.query(
        'daily_rhythm',
        where: 'date >= ?',
        whereArgs: [windowStartDay],
        orderBy: 'date DESC',
      );
      final rhythms = rhythmsRaw.map(Map<String, dynamic>.from).toList();

      final routinesRaw = await db.query('routines');
      final routines = routinesRaw.map(Map<String, dynamic>.from).toList();

      final coursesRaw = await db.query('courses');
      final courses = coursesRaw.map(Map<String, dynamic>.from).toList();

      final courseSessionsRaw = await db.query('course_sessions');
      final courseSessions = courseSessionsRaw.map(Map<String, dynamic>.from).toList();

      final konkurSubjectsRaw = await db.query(
        'konkur_subjects',
        where: "isArchived = 0 AND (origin = 'KONKUR_PRESET' OR origin = 'KONKUR_CUSTOM' OR origin = 'KONKUR' OR isPreset = 1)",
      );
      final konkurSubjects = konkurSubjectsRaw.map(Map<String, dynamic>.from).toList();

      final settings = await db.query('app_settings');
      final settingsMap = {for (final s in settings) s['key']! as String: s['value']! as String};
      final unlockedDB = await DatabaseHelper.instance.getUnlockedMilestones();
      final unlockedMap = {for (final m in unlockedDB) m['id'] as String: m['unlockedAt'] as int};

      _isCycleModuleEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_cycle_enabled');
      _isFemale = CyclePrivacyGuard.isVisible(settingsMap);
      _currentStreak = int.tryParse(settingsMap['current_streak'] ?? '0') ?? 0;
      _longestStreak = int.tryParse(settingsMap['longest_streak'] ?? '0') ?? 0;

      _completionCount = completions.length;

      // 2. Calculate active days from unique logged dates (B-15 fix)
      final completionDates = completions.map((c) => c['completionDate'] as String?).whereType<String>().toSet();
      final rhythmDates = rhythms.map((r) => r['date'] as String?).whereType<String>().toSet();
      final allActiveDates = {...completionDates, ...rhythmDates};
      _daysOfData = math.min(allActiveDates.length, windowDays);
      if (_daysOfData < 1 && completions.isNotEmpty) _daysOfData = 1;

      // 3. Load Pulse History
      _pulseHistoryList = rhythms.map((r) => {
        'date': r['date'] as String? ?? '',
        'rhythmScore': (r['rhythmScore'] as num? ?? 0).toInt(),
      }).toList();
      _pulseHistoryList.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

      // Calculate averages
      final sevenDaysAgo = loadedAt.subtract(const Duration(days: 7));
      final fourteenDaysAgo = loadedAt.subtract(const Duration(days: 14));
      final thirtyDaysAgo = loadedAt.subtract(const Duration(days: 30));
      final sixtyDaysAgo = loadedAt.subtract(const Duration(days: 60));

      final recentRhythms = rhythms.where((r) {
        final date = DateTime.tryParse(r['date'] as String? ?? '');
        return date != null && date.isAfter(sevenDaysAgo);
      }).toList();

      final prevRhythms = rhythms.where((r) {
        final date = DateTime.tryParse(r['date'] as String? ?? '');
        return date != null && date.isAfter(fourteenDaysAgo) && date.isBefore(sevenDaysAgo);
      }).toList();

      double recentAvg = 0;
      if (recentRhythms.isNotEmpty) {
        recentAvg = recentRhythms.map((r) => (r['rhythmScore'] as num? ?? 0).toDouble()).reduce((a, b) => a + b) / recentRhythms.length;
      }
      _lifePulseAverage = recentAvg.round();

      double prevAvg = 0;
      if (prevRhythms.isNotEmpty) {
        prevAvg = prevRhythms.map((r) => (r['rhythmScore'] as num? ?? 0).toDouble()).reduce((a, b) => a + b) / prevRhythms.length;
      }

      final (weekPct, weekUp) = _safePercentChange(recentAvg, prevAvg);
      _pulseDiffPercentage = weekPct;
      _pulseDiffUp = weekUp;

      // Calculate monthly average difference if data >= 60 days
      if (_daysOfData >= 60) {
        final thisMonthRhythms = rhythms.where((r) {
          final date = DateTime.tryParse(r['date'] as String? ?? '');
          return date != null && date.isAfter(thirtyDaysAgo);
        }).toList();

        final lastMonthRhythms = rhythms.where((r) {
          final date = DateTime.tryParse(r['date'] as String? ?? '');
          return date != null && date.isAfter(sixtyDaysAgo) && date.isBefore(thirtyDaysAgo);
        }).toList();

        if (thisMonthRhythms.isNotEmpty && lastMonthRhythms.isNotEmpty) {
          final thisAvg = thisMonthRhythms.map((r) => (r['rhythmScore'] as num? ?? 0).toDouble()).reduce((a, b) => a + b) / thisMonthRhythms.length;
          final lastAvg = lastMonthRhythms.map((r) => (r['rhythmScore'] as num? ?? 0).toDouble()).reduce((a, b) => a + b) / lastMonthRhythms.length;
          final (monthPct, monthUp) = _safePercentChange(thisAvg, lastAvg);
          _pulseMonthlyChange = monthPct;
          _pulseMonthlyUp = monthUp;
        }
      }

      if (DataMaturityEngine.hasEnoughDataForWeeklyTrend(_daysOfData)) {
        final bus = RitmoEngineBus.instance;

        // Run Energy Analytics via Engine Bus
        final energyOut = await bus.execute<EnergyAnalyticsEngineInput, EnergyAnalyticsOutput>(
          EnergyAnalyticsEngine,
          EnergyAnalyticsEngineInput(
            energyLogs: energy,
            routineCompletions: completions,
            dailyRhythm: rhythms,
            now: loadedAt,
          ),
        );
        _peakPerformanceWindow = energyOut.peakPerformanceWindow;
        _mostProductiveWeekday = energyOut.mostProductiveWeekday;
        _mostFatiguedWindow = energyOut.mostFatiguedWindow;

        // Run Life Balance via Engine Bus
        final balanceOut = await bus.execute<LifeBalanceEngineInput, LifeBalanceEngineOutput>(
          LifeBalanceEngine,
          LifeBalanceEngineInput(
            now: loadedAt,
            routines: routines,
            routineCompletions: completions,
          ),
        );
        _lifeBalanceScore = balanceOut.score ?? 0;
        _categoryDistribution = balanceOut.distribution;

        // Run Milestones via Engine Bus (side-effect free evaluation)
        _milestones = await bus.execute<MilestoneEngineInput, List<Milestone>>(
          MilestoneEngine,
          MilestoneEngineInput(
            currentStreak: _currentStreak,
            longestStreak: _longestStreak,
            routineCompletions: completions,
            routines: routines,
            courses: courses,
            courseSessions: courseSessions,
            konkurSubjects: konkurSubjects,
            unlockedMilestonesMap: unlockedMap,
          ),
        );

        // Run Insights Engine via Engine Bus
        _insights = await bus.execute<InsightGenerationEngineInput, List<InsightResult>>(
          InsightGenerationEngine,
          InsightGenerationEngineInput(
            now: loadedAt,
            windowDays: _selectedWindow.days,
            routineCompletions: completions,
            routines: routines,
            peakPerformanceWindow: _peakPerformanceWindow,
            mostProductiveWeekday: _mostProductiveWeekday,
            mostFatiguedWindow: _mostFatiguedWindow,
            daysOfData: _daysOfData,
            dailyRhythm: rhythms,
            isMenstruating: _isFemale && _isCycleModuleEnabled,
          ),
        );
        unawaited(_pushInsightsToInbox(_insights));
      }
    } catch (e, st) {
      RitmoLogger.error('[Insights] analytics load failed: $e', error: e, stack: st);
      if (generation == _loadGeneration && mounted) {
        setState(() {
          _error = 'محاسبهٔ بینش‌ها با خطا مواجه شد.';
        });
      }
    } finally {
      if (generation == _loadGeneration && mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }

    if (generation != _loadGeneration) return;

    // Load AI Briefing & Deep Analysis cache (RITF-098)
    try {
      final b = await AiBriefingService.instance.getCached();
      var cachedDeepAnalysis = await SecureKeyStore.getKey('ai_deep_analysis_result_v1');
      if (cachedDeepAnalysis == null) {
        final prefs = await SharedPreferences.getInstance();
        final legacyDeep = prefs.getString('ai_deep_analysis_result_v1');
        if (legacyDeep != null && legacyDeep.isNotEmpty) {
          cachedDeepAnalysis = legacyDeep;
          await SecureKeyStore.setKey('ai_deep_analysis_result_v1', legacyDeep);
          await prefs.remove('ai_deep_analysis_result_v1');
        }
      }
      if (generation == _loadGeneration && mounted) {
        setState(() {
          _briefing = b;
          _deepAnalysisResult = cachedDeepAnalysis;
        });
      }
    } catch (e, st) {
      RitmoLogger.warning('Error loading briefing cache in Insights: $e', error: e, stack: st);
    }
  }

  Future<void> _pushInsightsToInbox(List<InsightResult> insights) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    for (final insight in insights) {
      final typeName = insight.type.name.toLowerCase();
      if (typeName.contains('cycle') || typeName.contains('hormone') || typeName.contains('period')) {
        continue;
      }

      var title = '';
      var message = '';

      switch (insight.type) {
        case InsightType.learningGrowth:
          title = l10n.learningGrowthInsightTitle;
          message = l10n.learningGrowthInsightMessage(insight.params['percent'] as int? ?? 0);
        case InsightType.healthDecline:
          title = l10n.healthDeclineInsightTitle;
          message = l10n.healthDeclineInsightMessage(insight.params['percent'] as int? ?? 0);
        case InsightType.morningLead:
          title = l10n.morningLeadInsightTitle;
          message = l10n.morningLeadInsightMessage;
        case InsightType.fatigueWarning:
          title = l10n.fatigueWarningInsightTitle;
          message = l10n.fatigueWarningInsightMessage(insight.params['window'] as String? ?? '');
        case InsightType.productiveWeekday:
          title = l10n.productiveWeekdayInsightTitle;
          message = l10n.productiveWeekdayInsightMessage(insight.params['weekday'] as String? ?? '');
        case InsightType.gatheringData:
          title = l10n.gatheringDataInsightTitle;
          message = l10n.gatheringDataInsightMessage;
        default:
          title = insight.params['title'] as String? ?? 'تحلیل جدید';
          message = insight.params['message'] as String? ?? 'تحلیل رفتار جدیدی برای شما آماده شده است.';
      }

      if (title.isNotEmpty && message.isNotEmpty) {
        await CentralInboxService.push(
          category: InboxCategory.INSIGHT,
          sourceSystem: 'insight_engine',
          entityId: '${insight.type.name}_${insight.sourceMetric}',
          eventType: 'insight',
          title: title,
          body: message,
          linkModule: 'insights',
          linkAction: 'open_list',
          dateBucket: todayStr,
        );
      }
    }
  }

  Future<void> _runDeepAnalysis() async {
    final hasConsent = await AIDeepAnalysisDialog.checkConsent(context);
    if (!hasConsent) return;

    RitmoHaptics.tap();
    setState(() {
      _isDeepAnalyzing = true;
      _deepAnalysisResult = null;
    });

    try {
      final digest = await DailyDigestBuilder.buildFull();
      const systemPrompt = """
You are Ritmo's Deep Behavioral Analyst. Your job is to analyze the user's metrics in-depth.

RULES:
${AnalyticsPromptRules.core}

OUTPUT STRUCTURE:
Your output must be structured in Farsi markdown with exactly the following headings:
### نقاط قوت
### روندها و استمرار
### همبستگی‌های رفتاری
### پیشنهاد هفته

CONSTRAINTS:
1. Under each heading, output AT MOST 3 sentences.
2. Refer directly to actual numbers, routine names, or specific categories from the user's digest (do not make up titles or numbers).
3. The total word count must be around 250 words or less. Keep it concise, high-impact, and warm yet strictly analytical.
""";

      final userPrompt = """
Here is the user's complete behavioral digest:
Legend:
- sleep: [durationMinutes: کل مدت خواب به دقیقه | sleepEfficiency: درصد کیفیت خواب | deepSleepMinutes: مدت خواب عمیق | remSleepMinutes: مدت خواب رِم | sleepDebt: بدهی خواب به دقیقه]
- habits: [stabilityScore: امتیاز ثبات از ۰ تا ۱۰۰ | adaptabilityScore: امتیاز انطباق‌پذیری از ۰ تا ۱۰۰ | consistencyScore: امتیاز استمرار رفتاری]
- completion30d: درصد موفقیت تکمیل روتین‌ها در ۳۰ روز اخیر

Digest Data:
${jsonEncode(digest.json)}
""";
      
      final result = await AIGateway.instance.sendRawCompletion(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );

      final finalResult = result.isNotEmpty ? result : 'خطا در برقراری ارتباط با سرور تحلیل هوش مصنوعی.';

      if (result.isNotEmpty) {
        await SecureKeyStore.setKey('ai_deep_analysis_result_v1', result);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('ai_deep_analysis_result_v1');
      }

      if (mounted) {
        setState(() {
          _deepAnalysisResult = finalResult;
        });
      }
    } catch (e, st) {
      RitmoLogger.warning('[DEEP_ANALYSIS] failed: $e', error: e, stack: st);
      if (mounted) {
        setState(() {
          _deepAnalysisResult = 'خطا در پردازش اطلاعات رفتاری شما.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeepAnalyzing = false;
        });
      }
    }
  }

  Widget _buildAIBriefingSection(RitmoColors colors, bool isDarkMode) {
    final m = context.metrics;
    if (_briefing == null && !_isDeepAnalyzing && _deepAnalysisResult == null) {
      return RitmoTheme.glassCardLight(
        child: Padding(
          padding: EdgeInsets.all(m.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تحلیل هوشمند ریتمو 🧠',
                style: RitmoTextStyles.titleMedium(
                  colors.textPrimary,
                ).copyWith(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: m.spaceSm),
              Text(
                'هنوز هیچ تحلیلی ثبت نشده است. دکمه زیر را برای اجرای اولین تحلیل عمیق الگوهای رفتاری خود فشار دهید.',
                style: RitmoTextStyles.caption(
                  colors.textSecondary,
                ).copyWith(height: 1.6),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: m.spaceLg),
              ElevatedButton.icon(
                onPressed: _runDeepAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff06B6D4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(m.radiusField)),
                  padding: EdgeInsets.symmetric(vertical: m.spaceMd),
                ),
                icon: const Icon(CupertinoIcons.sparkles, size: 16, color: Colors.white),
                label: Text(
                  'تحلیل عمیق با هوش مصنوعی',
                  style: RitmoTextStyles.label(Colors.white).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: EdgeInsets.all(m.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تحلیل هوشمند ریتمو 🧠',
                  style: RitmoTextStyles.titleMedium(
                    colors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                if (!_isDeepAnalyzing)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _runDeepAnalysis, minimumSize: const Size(0, 0),
                    child: Icon(
                      CupertinoIcons.refresh,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                  ),
              ],
            ),
            SizedBox(height: m.spaceMd),

            if (_briefing != null) ...[
              Text(
                _briefing!.headline,
                style: RitmoTextStyles.label(
                  Colors.cyanAccent,
                ).copyWith(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: m.spaceSm),
              Text(
                _briefing!.summary,
                style: RitmoTextStyles.caption(
                  colors.textSecondary,
                ).copyWith(height: 1.6),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: m.spaceMd),
            ],

            if (_isDeepAnalyzing) ...[
              SizedBox(height: m.spaceLg),
               Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: Color(0xff06B6D4)),
                    SizedBox(height: m.spaceMd),
                    Text(
                      'در حال تحلیل عمیق الگوهای رفتاری شما... لطفاً صبور باشید 🧐',
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: m.spaceLg),
            ] else if (_deepAnalysisResult != null) ...[
              Divider(color: colors.border, height: 16),
              Text(
                'گزارش تحلیل عمیق:',
                style: RitmoTextStyles.caption(
                  Colors.cyanAccent,
                ).copyWith(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: m.spaceSm),
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black.withValues(alpha: 0.2) : colors.textSecondary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(m.radiusField),
                ),
                padding: EdgeInsets.all(m.spaceMd),
                child: SingleChildScrollView(
                  child: Text(
                    _deepAnalysisResult!,
                    style: RitmoTextStyles.caption(
                      colors.textSecondary,
                    ).copyWith(height: 1.6),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ),
              SizedBox(height: m.spaceMd),
            ] else ...[
              ElevatedButton.icon(
                onPressed: _runDeepAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff06B6D4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(m.radiusCard)),
                  padding: EdgeInsets.symmetric(vertical: m.spaceSm),
                ),
                icon: Icon(CupertinoIcons.sparkles, size: m.iconSm, color: Colors.white),
                label: const Text(
                  'تحلیل عمیق با هوش مصنوعی',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 142.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        onPopInvokedWithResult: (didPop, result) {
          AdService.instance.showInterstitialAd(context);
        },
        child: Scaffold(
          backgroundColor: colors.background,
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification) {
                if (notification.direction == ScrollDirection.reverse && _isTabsVisible) {
                  setState(() => _isTabsVisible = false);
                } else if (notification.direction == ScrollDirection.forward && !_isTabsVisible) {
                  setState(() => _isTabsVisible = true);
                }
              } else if (notification is ScrollUpdateNotification) {
                if (notification.metrics.pixels <= 15 && !_isTabsVisible) {
                  setState(() => _isTabsVisible = true);
                }
              }
              return false;
            },
            child: Stack(
              children: [
                // Layer 1: Body Content
                Positioned.fill(
                  child: _isLoading
                      ? Padding(
                          padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 16),
                          child: Center(
                            child: CircularProgressIndicator(color: colors.primary),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadAnalytics(isRefresh: true),
                          color: colors.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 120),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isRefreshing)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: LinearProgressIndicator(
                                      minHeight: 2,
                                      backgroundColor: Colors.transparent,
                                      color: colors.primary,
                                    ),
                                  ),
                                if (_error != null)
                                  _buildErrorView(colors, isDarkMode)
                                else ...[
                                  // AI Briefing section
                                  PremiumGate(
                                    feature: PremiumFeature.unlimitedAi,
                                    child: _buildAIBriefingSection(colors, isDarkMode),
                                  ),
                                  const SizedBox(height: 16),

                                  // Maturity Gate Dispatcher
                                  if (!DataMaturityEngine.hasEnoughDataForWeeklyTrend(_daysOfData))
                                    _buildEarlyStageView(colors, isDarkMode)
                                  else
                                    PremiumGate(
                                      feature: PremiumFeature.advancedInsights,
                                      child: _buildAdvancedView(colors, isDarkMode),
                                    ),
                                  const SizedBox(height: 16),
                                  AdService.instance.getBannerAd(),
                                ],
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
                      child: _buildCapsuleHeader(context, isDarkMode, colors),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                // Top Row (52 height)
                SizedBox(
                  height: 52,
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
                          'بینش‌ها و الگوها',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17.5,
                            letterSpacing: -0.4,
                            color: isDark ? Colors.white : const Color(0xFF1D2129),
                          ),
                        ),
                      ),
                      Builder(
                        builder: (btnCtx) => _buildHeaderActionButton(
                          icon: CupertinoIcons.share,
                          iconColor: colors.primary,
                          isDark: isDark,
                          tooltip: 'اشتراک‌گذاری گزارش',
                          onTap: () => _simulateShare(btnCtx, colors),
                        ),
                      ),
                      const SizedBox(width: 2),
                    ],
                  ),
                ),

                // Bottom Collapsible Time Window Ruler
                ClipRect(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    height: _isTabsVisible ? 54.0 : 0.0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isTabsVisible ? 1.0 : 0.0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
                        child: Align(
                          alignment: Alignment.center,
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: _buildTimeWindowSegmentedRuler(colors, isDark),
                          ),
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

  Widget _buildTimeWindowSegmentedRuler(RitmoColors colors, bool isDark) {
    final trackBgColor = isDark ? const Color(0xFF16191E) : const Color(0xFFEFF2F6);
    final pillBgColor = isDark
        ? const Color(0xFF22262F)
        : Color.lerp(Colors.white, colors.primary, 0.12)!;
    final activeIndex = InsightsTimeWindow.values.indexOf(_selectedWindow).clamp(0, 3);

    const tabs = InsightsTimeWindow.values;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const outerPadding = 4.0;
        final availableWidth = totalWidth - (outerPadding * 2);
        final tabWidth = availableWidth / tabs.length;
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
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: outerPadding),
                  child: Row(
                    children: tabs.map((window) {
                      final isSelected = window == _selectedWindow;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!isSelected) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedWindow = window;
                              });
                              _loadAnalytics(showLoading: false);
                            }
                          },
                          child: Center(
                            child: Text(
                              window.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF1D2129))
                                    : (isDark ? const Color(0xFF8E95A2) : const Color(0xFF6B7280)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
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

  // Gate Check Badge
  Widget _buildMaturityBadge() {
    var label = 'عدم بلوغ داده 🔴';
    Color color = Colors.redAccent;
    if (DataMaturityEngine.hasEnoughDataForMonthlyComparison(_daysOfData)) {
      label = 'داده‌های کامل 🟢';
      color = const Color(0xff34D399);
    } else if (DataMaturityEngine.hasEnoughDataForWeeklyTrend(_daysOfData)) {
      label = 'داده‌های اولیه 🟡';
      color = const Color(0xffF5B95B);
    }

    final m = context.metrics;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: m.spaceSm, vertical: m.spaceXs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(m.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: RitmoTextStyles.badge(color).copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  // ERROR VIEW (IN-06)
  Widget _buildErrorView(RitmoColors colors, bool isDarkMode) {
    final m = context.metrics;
    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: EdgeInsets.all(m.spaceXl),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              size: 48 * m.densityFactor,
              color: colors.medicalRed,
            ),
            SizedBox(height: m.spaceMd),
            Text(
              'خطا در بارگذاری اطلاعات',
              style: RitmoTextStyles.cardTitle(colors.textPrimary).copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: m.spaceSm),
            Text(
              _error ?? 'محاسبهٔ بینش‌ها با خطا مواجه شد.',
              textAlign: TextAlign.center,
              style: RitmoTextStyles.caption(colors.textSecondary).copyWith(height: 1.5),
            ),
            SizedBox(height: m.spaceLg),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(CupertinoIcons.refresh, size: 18),
              label: const Text('تلاش مجدد'),
              onPressed: () => _loadAnalytics(showLoading: true),
            ),
          ],
        ),
      ),
    );
  }

  // EARLY STAGE MODE VIEW
  Widget _buildEarlyStageView(RitmoColors colors, bool isDarkMode) {
    final m = context.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Maturity Banner
        RitmoTheme.glassCardLight(
          child: Padding(
            padding: EdgeInsets.all(m.spaceXl),
            child: Column(
              children: [
                Icon(
                  CupertinoIcons.square_stack_3d_down_right_fill,
                  size: 52 * m.densityFactor,
                  color: const Color(0xff5B8AF5),
                ),
                SizedBox(height: m.spaceLg),
                Text(
                  'هنوز در حال شناخت شما هستیم',
                  style: RitmoTextStyles.cardTitle(
                    colors.textPrimary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: m.spaceSm),
                Text(
                  'با ادامه استفاده از ریتمو و تکمیل روتین‌های روزانه، بینش‌های هوشمند، آنالیز تعادل ابعاد زندگی و تحلیل‌های پیشرفته ریتم انرژی شما ظاهر خواهند شد.',
                  textAlign: TextAlign.center,
                  style: RitmoTextStyles.caption(
                    colors.textSecondary,
                  ).copyWith(height: 1.6),
                ),
                SizedBox(height: m.spaceLg),
                _buildMaturityBadge(),
              ],
            ),
          ),
        ),
        SizedBox(height: m.spaceXl),

        // Section Title
        _buildSectionTitle(colors, 'وضعیت فعلی ریتم زندگی'),
        SizedBox(height: m.spaceMd),

        // 3 metrics allowed in Early Stage
        Row(
          children: [
            Expanded(
              child: _buildEarlyMetricCard(
                colors,
                'نبض فعلی زندگی',
                toPersianDigits('$_lifePulseAverage٪'),
                colors.success,
              ),
            ),
            SizedBox(width: m.spaceMd),
            Expanded(
              child: _buildEarlyMetricCard(
                colors,
                'روزهای استفاده',
                toPersianDigits('$_daysOfData روز'),
                colors.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: m.spaceMd),
        _buildEarlyMetricCard(
          colors,
          'کل روتین‌های تکمیل شده',
          toPersianDigits('$_completionCount روتین'),
          colors.primary,
        ),
      ],
    );
  }

  Widget _buildEarlyMetricCard(RitmoColors colors, String title, String val, Color color) {
    final m = context.metrics;
    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: EdgeInsets.all(m.spaceXl),
        child: Column(
          children: [
            Text(
              title,
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
            SizedBox(height: m.spaceSm),
            Text(
              val,
              style: RitmoTextStyles.sectionHeadline(color).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ADVANCED ANALYTICS MODE VIEW
  Widget _buildAdvancedView(RitmoColors colors, bool isDarkMode) {
    final m = context.metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMaturityBadge(),
        SizedBox(height: m.spaceLg),

        // SECTION 1: Life Pulse Hero
        _buildLifePulseHero(colors),
        SizedBox(height: m.spaceXl),

        // SECTION 2: Life Balance
        _buildSectionTitle(colors, 'تعادل ابعاد زندگی ⚖️'),
        SizedBox(height: m.spaceMd),
        _buildLifeBalanceCard(colors, isDarkMode),
        SizedBox(height: m.spaceXl),

        // SECTION 3: Streaks & Momentum
        _buildSectionTitle(colors, 'تداوم و انرژی رفتاری 🔥'),
        SizedBox(height: m.spaceMd),
        _buildStreaksCard(colors),
        SizedBox(height: m.spaceXl),

        // SECTION 4: Trend Analysis
        _buildSectionTitle(colors, 'تحلیل پویای روندهای پیشرفت 📈'),
        SizedBox(height: m.spaceMd),
        _buildTrendAnalysisGrid(colors),
        SizedBox(height: m.spaceXl),

        // SECTION 5: Energy Insights
        _buildSectionTitle(colors, 'بینش‌های ریتم شبانه‌روزی و انرژی ⚡'),
        SizedBox(height: m.spaceMd),
        _buildEnergyInsights(colors),
        SizedBox(height: m.spaceXl),

        // SECTION 6: Intelligence Insights
        if (_insights.isNotEmpty) ...[
          _buildSectionTitle(colors, 'بینش‌های هوشمند رفتاری 💡'),
          SizedBox(height: m.spaceMd),
          _buildIntelligenceInsightsList(colors, isDarkMode),
          SizedBox(height: m.spaceXl),
        ],

        // SECTION 7: Milestones
        if (_milestones.isNotEmpty) ...[
          _buildSectionTitle(colors, 'دستاوردهای آزاد شده و مایل‌استون‌ها 🎖️'),
          SizedBox(height: m.spaceMd),
          _buildMilestonesTimeline(colors),
          SizedBox(height: m.spaceXl),
        ],

        // SECTION 8: Comparative Analysis
        _buildSectionTitle(colors, 'تحلیل‌های مقایسه‌ای زمان‌محور 📊'),
        SizedBox(height: m.spaceMd),
        _buildComparativeAnalysis(colors),
        SizedBox(height: m.spaceXl),

        // SECTION 9: Reflection Summary
        _buildSectionTitle(colors, 'خلاصه انعکاس رفتاری (تصویر زندگی شما) 🌿'),
        SizedBox(height: m.spaceMd),
        _buildReflectionSummary(colors),
      ],
    );
  }

  Widget _buildSectionTitle(RitmoColors colors, String title) {
    return Text(
      title,
      style: RitmoTextStyles.body(
        colors.textPrimary,
      ).copyWith(fontWeight: FontWeight.bold),
    );
  }

  // SECTION 1: Life Pulse Hero
  Widget _buildLifePulseHero(RitmoColors colors) {
    final m = context.metrics;
    return RitmoTheme.glassCardLight(
      child: InkWell(
        onTap: () => _showPulseHistorySheet(colors),
        borderRadius: BorderRadius.circular(m.radiusHero),
        child: Padding(
          padding: EdgeInsets.all(m.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'نبض زندگی جاری (میانگین ۷ روزه)',
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                  Icon(CupertinoIcons.chevron_left, size: m.iconSm, color: colors.textSecondary.withValues(alpha: 0.5)),
                ],
              ),
              SizedBox(height: m.spaceSm),
              Text(
                toPersianDigits('$_lifePulseAverage٪'),
                style: RitmoTextStyles.heroNumber(colors.success),
              ),
              SizedBox(height: m.spaceMd),
              // Trend indicator
              Row(
                children: [
                  _buildPulseTrendIndicator(
                    label: 'نسبت به هفته قبل',
                    value: _pulseDiffPercentage,
                    isUp: _pulseDiffUp,
                    colors: colors,
                  ),
                  if (_daysOfData >= 60) ...[
                    SizedBox(width: m.spaceLg),
                    _buildPulseTrendIndicator(
                      label: 'نسبت به ماه قبل',
                      value: _pulseMonthlyChange,
                      isUp: _pulseMonthlyUp,
                      colors: colors,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              LifePulseSparklineChart(pulseHistory: _pulseHistoryList),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulseTrendIndicator({
    required String label,
    required int value,
    required bool isUp,
    required RitmoColors colors,
  }) {
    if (value == 0) {
      return Text(
        'پایدار $label',
        style: RitmoTextStyles.badge(colors.textSecondary),
      );
    }
    final trendColor = isUp ? colors.success : colors.medicalRed;
    return Row(
      children: [
        Icon(isUp ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down_right, color: trendColor, size: 12),
        const SizedBox(width: 3),
        Text(
          '$value٪ $label',
          style: RitmoTextStyles.badge(trendColor).copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // PULSE DETAILED HISTORY BOTTOM SHEET
  void _showPulseHistorySheet(RitmoColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            snap: true,
            builder: (context, scrollController) {
              return RitmoTheme.glassCardLight(
                borderRadius: 28,
                child: Column(
                  children: [
                    // Pull indicator
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تایم‌لاین نبض زندگی',
                            style: RitmoTextStyles.titleMedium(
                              colors.textPrimary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'ثبت‌شده: ${_pulseHistoryList.length} روز',
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: colors.border),
                    Expanded(
                      child: _pulseHistoryList.isEmpty
                          ? Center(
                              child: Text(
                                'هنوز هیچ نبض روزانه‌ای ثبت نشده است.',
                                style: RitmoTextStyles.caption(colors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _pulseHistoryList.length,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              itemBuilder: (context, index) {
                                final item = _pulseHistoryList[index];
                                final score = item['rhythmScore'] as int;
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item['date'] as String,
                                        style: RitmoTextStyles.caption(Colors.white70).copyWith(fontFamily: 'monospace'),
                                      ),
                                      Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.white10,
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: FractionallySizedBox(
                                                widthFactor: (score / 100).clamp(0.0, 1.0),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: score >= 80 ? colors.success : (score >= 50 ? colors.primary : colors.medicalRed),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            '$score٪',
                                            style: RitmoTextStyles.label(
                                              score >= 80 ? colors.success : (score >= 50 ? colors.primary : colors.medicalRed),
                                            ).copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // SECTION 2: Life Balance
  Widget _buildLifeBalanceCard(RitmoColors colors, bool isDarkMode) {
    // Generate active categories (real activity percentage > 0)
    final activeEntries = _categoryDistribution.entries.where((e) => e.value > 0).toList();

    if (activeEntries.isEmpty) {
      return RitmoTheme.glassCardLight(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'هنوز در این ابعاد روتینی تکمیل نشده است تا تعادل محاسبه شود. برای دیدن تعادل ابعاد زندگی، روتین‌های روزانه خود را تکمیل کنید.',
                textAlign: TextAlign.center,
                style: RitmoTextStyles.caption(colors.textSecondary).copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // Radial Pie/Donut custom painter
                RepaintBoundary(
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: DonutChartPainter(
                        distribution: _categoryDistribution,
                        colors: _domainColors,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شاخص تعادل کل زندگی',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_lifeBalanceScore٪',
                        style: RitmoTextStyles.pageTitle(colors.primary).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            // Show only dynamic categories with real completions
            ...activeEntries.map((e) {
              final domain = e.key;
              final percent = e.value;
              final name = _domainNamesFarsi[domain] ?? domain;
              final color = _domainColors[domain] ?? colors.primary;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                            const SizedBox(width: 8),
                            Text(name, style: RitmoTextStyles.caption(colors.textPrimary)),
                          ],
                        ),
                        Text('${percent.toStringAsFixed(0)}٪', style: RitmoTextStyles.caption(colors.textSecondary).copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 6,
                        color: Colors.white.withValues(alpha: 0.04),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: (percent / 100).clamp(0.0, 1.0),
                            child: Container(color: color),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // SECTION 3: Streaks & Momentum
  Widget _buildStreaksCard(RitmoColors colors) {
    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.flame_fill, color: Colors.orangeAccent, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تداوم فعلی', style: RitmoTextStyles.badge(colors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(toPersianDigits('$_currentStreak روز متوالی'), style: RitmoTextStyles.body(colors.textPrimary).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: colors.border.withValues(alpha: 0.3)),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.sparkles, color: Colors.amber, size: 26),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('طولانی‌ترین تداوم', style: RitmoTextStyles.badge(colors.textSecondary)),
                          const SizedBox(height: 4),
                          Text(toPersianDigits('$_longestStreak روز متوالی'), style: RitmoTextStyles.body(colors.textPrimary).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: colors.border.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(CupertinoIcons.waveform_path_ecg, color: colors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _pulseDiffUp
                        ? 'شتاب انرژی رفتاری شما در ۷ روز اخیر با افزایش ${toPersianDigits('$_pulseDiffPercentage٪')} همراه بوده است.'
                        : 'شتاب انرژی رفتاری شما در ۷ روز اخیر با تغییر ${toPersianDigits('$_pulseDiffPercentage٪')} نیازمند پایش است.',
                    style: RitmoTextStyles.badge(colors.textSecondary).copyWith(height: 1.5),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // SECTION 4: Trend Analysis
  Widget _buildTrendAnalysisGrid(RitmoColors colors) {
    final activeEntries = _categoryDistribution.entries.where((e) => e.value > 0).toList();

    if (activeEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          'هنوز دسته‌بندی در روتین‌ها برای تحلیل روند وجود ندارد.',
          style: RitmoTextStyles.caption(colors.textSecondary),
        ),
      );
    }

    return RitmoAdaptiveGrid(
      minTileWidth: 140,
      spacing: 12,
      maxColumns: 2,
      children: activeEntries.map((e) {
        final domain = e.key;
        final name = _domainNamesFarsi[domain] ?? domain;
        final color = _domainColors[domain] ?? colors.primary;

        return RitmoTheme.glassCardLight(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RitmoTextStyles.caption(colors.textPrimary).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      toPersianDigits('${e.value.toStringAsFixed(0)}٪'),
                      style: RitmoTextStyles.titleMedium(colors.textPrimary).copyWith(fontWeight: FontWeight.w900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'فعال',
                        style: RitmoTextStyles.badge(color).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // SECTION 5: Energy Insights
  Widget _buildEnergyInsights(RitmoColors colors) {
    final cards = <Widget>[];

    if (_peakPerformanceWindow != null) {
      cards.add(
        _buildEnergyCard(
          colors: colors,
          title: 'اوج عملکرد ذهنی و فیزیکی ☀️',
          value: _peakPerformanceWindow!,
          color: colors.success,
        ),
      );
    }
    if (_mostProductiveWeekday != null) {
      cards.add(
        _buildEnergyCard(
          colors: colors,
          title: 'پربازده‌ترین روز هفته 🌟',
          value: _mostProductiveWeekday!,
          color: colors.primary,
        ),
      );
    }
    if (_mostFatiguedWindow != null) {
      cards.add(
        _buildEnergyCard(
          colors: colors,
          title: 'بازه زمانی حساس خستگی ⚡',
          value: _mostFatiguedWindow!,
          color: Colors.orangeAccent,
        ),
      );
    }

    if (cards.isEmpty) {
      return RitmoTheme.glassCardLight(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'داده‌های ثبت انرژی کافی نیست.',
              style: RitmoTextStyles.caption(colors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Column(
      children: cards.map((c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: c,
      )).toList(),
    );
  }

  Widget _buildEnergyCard({
    required RitmoColors colors,
    required String title,
    required String value,
    required Color color,
  }) {
    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: RitmoTextStyles.caption(colors.textSecondary)),
            Text(value, style: RitmoTextStyles.label(color).copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // SECTION 6: Intelligence Insights
  Widget _buildIntelligenceInsightsList(RitmoColors colors, bool isDarkMode) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _insights.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final insight = _insights[index];
        var typeColor = colors.primary;
        var icon = CupertinoIcons.info_circle_fill;
        var title = '';
        var message = '';

        switch (insight.type) {
          case InsightType.learningGrowth:
            typeColor = colors.success;
            icon = CupertinoIcons.checkmark_circle_fill;
            title = l10n.learningGrowthInsightTitle;
            message = l10n.learningGrowthInsightMessage(insight.params['percent'] as int? ?? 0);
          case InsightType.healthDecline:
            typeColor = insight.severity == 'INFO' ? colors.primary : colors.medicalRed;
            icon = CupertinoIcons.exclamationmark_triangle_fill;
            title = l10n.healthDeclineInsightTitle;
            message = l10n.healthDeclineInsightMessage(insight.params['percent'] as int? ?? 0);
          case InsightType.morningLead:
            typeColor = colors.primary;
            icon = CupertinoIcons.info_circle_fill;
            title = l10n.morningLeadInsightTitle;
            message = l10n.morningLeadInsightMessage;
          case InsightType.fatigueWarning:
            typeColor = colors.medicalRed;
            icon = CupertinoIcons.exclamationmark_triangle_fill;
            title = l10n.fatigueWarningInsightTitle;
            message = l10n.fatigueWarningInsightMessage(insight.params['window'] as String? ?? '');
          case InsightType.productiveWeekday:
            typeColor = colors.success;
            icon = CupertinoIcons.checkmark_circle_fill;
            title = l10n.productiveWeekdayInsightTitle;
            message = l10n.productiveWeekdayInsightMessage(insight.params['weekday'] as String? ?? '');
          case InsightType.sleepEnergyCorrelation:
            typeColor = insight.severity == 'POSITIVE' ? colors.success : colors.primary;
            icon = CupertinoIcons.bed_double_fill;
            title = 'همبستگی خواب و انرژی 🌙⚡';
            final coef = insight.params['coef'] as int? ?? 0;
            message = coef > 0
                ? toPersianDigits('کیفیت خواب شما همبستگی مثبت $coef٪ با سطوح انرژی در طول روز نشان می‌دهد.')
                : toPersianDigits('کمبود خواب همبستگی منفی $coef٪ با پایداری انرژی شما داشته است.');
          case InsightType.sleepMoodCorrelation:
            typeColor = colors.primary;
            icon = CupertinoIcons.smiley_fill;
            title = 'همبستگی خواب و خلق 🌙😊';
            final coef = insight.params['coef'] as int? ?? 0;
            message = toPersianDigits('استمرار خواب خوب همبستگی $coef٪ با بهبودی خلق روزانه شما دارد.');
          case InsightType.energyCompletionLink:
            typeColor = colors.success;
            icon = CupertinoIcons.bolt_horizontal_fill;
            title = 'ارتباط انرژی و تکمیل روتین‌ها ⚡🎯';
            final coef = insight.params['coef'] as int? ?? 0;
            message = toPersianDigits('در روزهایی که شارژ انرژی بالاتر بوده، نرخ تکمیل روتین‌ها $coef٪ افزایش یافته است.');
          case InsightType.consistencyScore:
            typeColor = colors.success;
            icon = CupertinoIcons.graph_square_fill;
            title = 'شاخص ثبات رفتاری 📈';
            final score = insight.params['score'] as int? ?? 0;
            message = toPersianDigits('ثبات عملکرد شما در ۱۴ روز گذشته نمره عالی $score٪ را ثبت کرده است.');
          case InsightType.bestDomainOfWeek:
            typeColor = colors.primary;
            icon = CupertinoIcons.star_fill;
            title = 'برترین دامنه هفته 🌟';
            message = 'عملکرد شما در این دامنه بالاترین پایداری را نشان می‌دهد.';
          case InsightType.streakHighlight:
            typeColor = colors.success;
            icon = CupertinoIcons.flame_fill;
            title = 'دستاورد تداوم 🔥';
            message = toPersianDigits('تداوم فعلی شما به $_currentStreak روز رسید!');
          case InsightType.goalProgress:
            typeColor = colors.primary;
            icon = CupertinoIcons.flag_fill;
            title = 'پیشرفت اهداف 🎯';
            message = 'مسیر اهداف شما با موفقیت در حال طی شدن است.';
          case InsightType.worshipConsistency:
            typeColor = colors.primary;
            icon = CupertinoIcons.sparkles;
            title = 'پایداری عبادی 🌿';
            message = 'پایداری روتین‌های معنوی شما با موفقیت ثبت شد.';
          case InsightType.gatheringData:
          case InsightType.noisyDataSuppressed:
            typeColor = colors.textSecondary;
            icon = CupertinoIcons.time;
            title = l10n.gatheringDataInsightTitle;
            message = l10n.gatheringDataInsightMessage;
        }

        return RitmoTheme.glassCardLight(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, color: typeColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: RitmoTextStyles.label(
                          colors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(CupertinoIcons.doc_text_search, size: 18, color: colors.textSecondary.withValues(alpha: 0.5)),
                      tooltip: 'شناسنامه و ردیابی شاخص',
                      onPressed: () => _showTraceabilityDialog(insight, colors),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: RitmoTextStyles.caption(
                    colors.textSecondary,
                  ).copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Traceability dialog
  void _showTraceabilityDialog(InsightResult insight, RitmoColors colors) {
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);
    
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xff1C1F2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(CupertinoIcons.doc_text_search, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text('شناسنامه و ردیابی شاخص', style: RitmoTextStyles.body(Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTraceItem('شاخص اندازه‌گیری', insight.sourceMetric, colors),
                const SizedBox(height: 12),
                _buildTraceItem('بازه محاسباتی داده', insight.calculationWindow, colors),
                const SizedBox(height: 12),
                _buildTraceItem('زمان آخرین محاسبه', dateStr, colors),
                const SizedBox(height: 12),
                _buildTraceItem('جدول دیتابیس مبدا', _getDBTableName(insight.sourceMetric), colors),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('بستن', style: TextStyle(color: Color(0xff5B8AF5), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTraceItem(String label, String value, RitmoColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RitmoTextStyles.badge(colors.textSecondary)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Text(
            value,
            style: RitmoTextStyles.caption(Colors.white).copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  String _getDBTableName(String sourceMetric) {
    if (sourceMetric.contains('completion')) return 'routine_completions';
    if (sourceMetric.contains('energy')) return 'energy_logs';
    if (sourceMetric.contains('weekday')) return 'routine_completions, daily_rhythm';
    if (sourceMetric.contains('fatigue')) return 'energy_logs, routine_completions';
    return 'daily_rhythm';
  }

  // SECTION 7: Milestones
  Widget _buildMilestonesTimeline(RitmoColors colors) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: math.min(_milestones.length, 5), // Only show top 5 milestones
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final milestone = _milestones[index];
        return RitmoTheme.glassCardLight(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: milestone.isUnlocked ? colors.success.withValues(alpha: 0.1) : colors.textSecondary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    milestone.isUnlocked ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.lock_fill,
                    color: milestone.isUnlocked ? colors.success : colors.textSecondary.withValues(alpha: 0.5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(milestone.title, style: RitmoTextStyles.caption(Colors.white).copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(milestone.description, style: RitmoTextStyles.badge(colors.textSecondary)),
                      if (!milestone.isUnlocked) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            height: 6,
                            color: Colors.white.withValues(alpha: 0.04),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FractionallySizedBox(
                                widthFactor: milestone.progress.clamp(0.0, 1.0),
                                child: Container(color: colors.primary),
                              ),
                            ),
                          ),
                        )
                      ],
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // SECTION 8: Comparative Analysis
  Widget _buildComparativeAnalysis(RitmoColors colors) {
    final weeklyChangeStr = _pulseDiffPercentage > 0
        ? (_pulseDiffUp
            ? toPersianDigits('+$_pulseDiffPercentage٪ تغییر مثبت')
            : toPersianDigits('-$_pulseDiffPercentage٪ افت'))
        : 'پایدار';

    final monthlyChangeStr = _pulseMonthlyChange > 0
        ? (_pulseMonthlyUp
            ? toPersianDigits('+$_pulseMonthlyChange٪ تغییر مثبت')
            : toPersianDigits('-$_pulseMonthlyChange٪ افت'))
        : 'پایدار';

    return Column(
      children: [
        _buildComparisonItem(
          colors: colors,
          title: 'مقایسه هفتگی (۷ روز اخیر vs هفته قبل)',
          requiredDays: 14,
          value: toPersianDigits('میانگین جاری: $_lifePulseAverage٪'),
          changeStr: weeklyChangeStr,
          isBetter: _pulseDiffUp,
        ),
        const SizedBox(height: 10),
        _buildComparisonItem(
          colors: colors,
          title: 'مقایسه ماهانه (۳۰ روز اخیر vs ماه قبل)',
          requiredDays: 60,
          value: _daysOfData >= 60 ? toPersianDigits('میانگین ماهانه: $_lifePulseAverage٪') : '',
          changeStr: _daysOfData >= 60 ? monthlyChangeStr : '',
          isBetter: _pulseMonthlyUp,
        ),
        const SizedBox(height: 10),
        _buildComparisonItem(
          colors: colors,
          title: 'مقایسه فصلی (۹۰ روز اخیر vs فصل قبل)',
          requiredDays: 120,
          value: '',
          changeStr: '',
          isBetter: true,
        ),
        const SizedBox(height: 10),
        _buildComparisonItem(
          colors: colors,
          title: 'مقایسه سالانه (امسال vs سال گذشته)',
          requiredDays: 365,
          value: '',
          changeStr: '',
          isBetter: true,
        ),
      ],
    );
  }

  Widget _buildComparisonItem({
    required RitmoColors colors,
    required String title,
    required int requiredDays,
    required String value,
    required String changeStr,
    required bool isBetter,
  }) {
    final hasEnough = _daysOfData >= requiredDays;
    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: RitmoTextStyles.caption(colors.textPrimary).copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (hasEnough) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(value, style: RitmoTextStyles.caption(colors.textSecondary)),
                  Text(changeStr, style: RitmoTextStyles.caption(isBetter ? colors.success : colors.medicalRed).copyWith(fontWeight: FontWeight.bold)),
                ],
              )
            ] else ...[
              Text(
                toPersianDigits('هنوز داده کافی برای این تحلیل وجود ندارد (نیاز به حداقل $requiredDays روز داده فعالیتی)'),
                style: RitmoTextStyles.badge(colors.textSecondary.withValues(alpha: 0.6)),
              )
            ]
          ],
        ),
      ),
    );
  }

  // SECTION 9: Reflection Summary
  Widget _buildReflectionSummary(RitmoColors colors) {
    // Generate reflection objectively based on dynamic data
    var summary = 'در این بازه، فعالیت‌های منظم شما در ابعاد زندگی ریتم پایداری را تجربه کرده است.';
    
    final activeEntries = _categoryDistribution.entries.where((e) => e.value > 0).toList();
    if (activeEntries.isNotEmpty) {
      activeEntries.sort((a, b) => b.value.compareTo(a.value));
      final topDomain = activeEntries.first.key;
      final topDomainName = _domainNamesFarsi[topDomain] ?? topDomain;
      summary = 'در این ماه بیشترین رشد شما در حوزه «$topDomainName» بوده است و شاخص تعادل کل شما روی مقدار $_lifeBalanceScore٪ قرار دارد.';
    }

    return RitmoTheme.glassCardLight(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(CupertinoIcons.quote_bubble_fill, color: Color(0xff5B8AF5), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                summary,
                style: RitmoTextStyles.caption(
                  colors.textSecondary,
                ).copyWith(height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }





  // System Share Action with Dedicated Persian Sheet & Fast Clipboard Option
  void _simulateShare(BuildContext buttonContext, RitmoColors colors) {
    final text = 'گزارش بینش‌های رفتاری ریتمو 🌿\n'
        'نبض زندگی: ${toPersianDigits('$_lifePulseAverage٪')}\n'
        'تداوم فعلی: ${toPersianDigits('$_currentStreak روز')}\n'
        'شاخص تعادل ابعاد: ${toPersianDigits('$_lifeBalanceScore٪')}';

    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(24));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final content = Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(CupertinoIcons.share, color: Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'اشتراک‌گذاری گزارش بینش‌ها',
                    style: RitmoTextStyles.titleMedium(colors.textPrimary).copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(CupertinoIcons.doc_on_clipboard, color: Color(0xFF10B981)),
                title: Text('کپی متن گزارش در حافظه (کپی سریع)', style: RitmoTextStyles.label(colors.textPrimary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(ClipboardData(text: text));
                  if (mounted) {
                    RitmoSnackbar.success(context, 'متن گزارش در حافظه دستگاه (Clipboard) کپی شد 📋');
                  }
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.paperplane, color: Color(0xFF3B82F6)),
                title: Text('ارسال به پیام‌رسان‌ها (اشتراک سیستم)', style: RitmoTextStyles.label(colors.textPrimary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  final origin = (box != null && box.hasSize) ? (box.localToGlobal(Offset.zero) & box.size) : null;
                  try {
                    // ignore: deprecated_member_use
                    await Share.share(text, sharePositionOrigin: origin).timeout(const Duration(seconds: 3));
                  } catch (_) {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (mounted) {
                      RitmoSnackbar.success(context, 'متن گزارش در حافظه دستگاه کپی شد 📋');
                    }
                  }
                },
              ),
            ],
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
      },
    );
  }
}

// Donut Chart CustomPainter with Rounded Caps
class DonutChartPainter extends CustomPainter {

  DonutChartPainter({required this.distribution, required this.colors});
  final Map<String, double> distribution;
  final Map<String, Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: Offset(radius, radius), radius: radius - 10);
    const strokeWidth = 10.0;

    // Track Background
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(Offset(radius, radius), radius - 10, trackPaint);

    var startAngle = -math.pi / 2;
    final activeEntries = distribution.entries.where((e) => e.value > 0).toList();

    if (activeEntries.isEmpty) return;

    for (final entry in activeEntries) {
      final percentage = entry.value;
      final sweepAngle = (percentage / 100.0) * 2 * math.pi;
      final color = colors[entry.key] ?? Colors.grey;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Draw active segment with slight padding
      canvas.drawArc(rect, startAngle + 0.04, sweepAngle - 0.08, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) => true;
}
