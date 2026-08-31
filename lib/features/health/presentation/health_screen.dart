import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/analytics/health_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/health/models/health_models.dart';
import 'package:ritmo/features/health/presentation/pages/medications_page.dart';
import 'package:ritmo/features/health/presentation/pages/monitoring_page.dart';
import 'package:ritmo/features/health/presentation/pages/records_page.dart';
import 'package:ritmo/features/health/presentation/pages/visits_page.dart';
import 'package:ritmo/features/health/presentation/widgets/adherence_card.dart';
import 'package:ritmo/features/health/presentation/widgets/doctor_visit_summary_sheet.dart';
import 'package:ritmo/features/health/presentation/widgets/health_correlation_section.dart';
import 'package:ritmo/features/health/presentation/widgets/health_trends_section.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  bool _isLoading = true;

  // Live summaries
  String _medicationsSummary = 'در حال بارگذاری...';
  String _monitoringSummary = 'در حال بارگذاری...';
  String _visitsSummary = 'در حال بارگذاری...';
  String _recordsSummary = 'در حال بارگذاری...';

  // Next upcoming dose
  String? _nextDoseName;
  String? _nextDoseTimeStr;

  // Subsystem alerts
  List<String> _criticalAlerts = [];

  HealthEngineOutput? _engineOutput;
  bool _hasAdherenceData = false;
  Timer? _countdownTimer;
  final ValueNotifier<String> _countdownNotifier = ValueNotifier<String>('در حال محاسبه زمان دوز بعدی...');
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    
    // Start live countdown timer to update every minute
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _calculateNextDoseCountdown();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _countdownNotifier.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  String _jalaliMonthName(int month) {
    const months = [
      'فروردین', 'اردیبهشت', 'خرداد',
      'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر',
      'دی', 'بهمن', 'اسفند'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  Future<void> _loadDashboardData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final startOfDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).millisecondsSinceEpoch;

      // 1. Fetch medications count & next dose
      final routines = await db.query(
        'routines',
        where: "category = 'medical' AND isArchived = 0",
      );
      final occurrences = await db.query(
        'routine_occurrences',
        where: 'date = ?',
        whereArgs: [todayStr],
      );
      final medLogs = await db.query(
        'medication_logs',
        where: 'createdAt >= ?',
        whereArgs: [startOfDay],
      );

      final scheduledIds = routines
          .where((r) => r['routineType'] != 'asNeeded')
          .map((r) => r['id']! as String)
          .toSet();

      final todayScheduledOcc = occurrences
          .where((o) => scheduledIds.contains(o['routine_id']))
          .toList();

      final totalScheduled = todayScheduledOcc.length;
      final takenScheduledIds = medLogs
          .where((l) => l['status'] == 'TAKEN')
          .map((l) => l['routineId']! as String)
          .toSet();

      final completedScheduled = todayScheduledOcc
          .where((o) => takenScheduledIds.contains(o['routine_id']))
          .length;

      // Find next upcoming scheduled medication
      String? nextMedName;
      String? nextMedTimeStr;
      
      final pendingScheduled = todayScheduledOcc
          .where((o) => o['status'] == 'pending')
          .toList();

      if (pendingScheduled.isNotEmpty) {
        pendingScheduled.sort((a, b) {
          final tA = a['scheduled_time'] as String? ?? '00:00';
          final tB = b['scheduled_time'] as String? ?? '00:00';
          return tA.compareTo(tB);
        });

        final nextOcc = pendingScheduled.first;
        final nextRoutine = routines.firstWhere((r) => r['id'] == nextOcc['routine_id']);
        nextMedName = nextRoutine['title'] as String?;
        nextMedTimeStr = nextOcc['scheduled_time'] as String?;
      }

      final medsSummary = '$completedScheduled از $totalScheduled دارو مصرف شده';

      // 2. Fetch last blood sugar & blood pressure
      final sugarLogs = await db.query('blood_sugar_logs', orderBy: 'loggedAt DESC', limit: 1);
      final bpLogs = await db.query('blood_pressure_logs', orderBy: 'loggedAt DESC', limit: 1);

      var sugarPart = '';
      if (sugarLogs.isNotEmpty) {
        sugarPart = 'قند ${sugarLogs.first['value']}';
      }

      var bpPart = '';
      if (bpLogs.isNotEmpty) {
        final sys = bpLogs.first['systolic']! as int;
        final dia = bpLogs.first['diastolic']! as int;
        
        final sysStr = (sys / 10.0).toStringAsFixed(sys % 10 == 0 ? 0 : 1);
        final diaStr = (dia / 10.0).toStringAsFixed(dia % 10 == 0 ? 0 : 1);
        bpPart = 'فشار $sysStr/$diaStr';
      }

      var monitoringSummary = 'سنجشی ثبت نشده است';
      if (sugarPart.isNotEmpty && bpPart.isNotEmpty) {
        monitoringSummary = '$sugarPart · $bpPart';
      } else if (sugarPart.isNotEmpty) {
        monitoringSummary = sugarPart;
      } else if (bpPart.isNotEmpty) {
        monitoringSummary = bpPart;
      }

      // 3. Fetch doctor visits
      final visitResults = await db.query(
        'doctor_visits', 
        where: "visitDateTime > ? AND status = 'UPCOMING'",
        whereArgs: [nowMs],
        orderBy: 'visitDateTime ASC', 
        limit: 1,
      );
      var visitsSummary = 'نوبت فعالی ثبت نشده است';
      if (visitResults.isNotEmpty) {
        final doctor = visitResults.first['doctorName'] as String? ?? 'پزشک';
        final dt = DateTime.fromMillisecondsSinceEpoch(visitResults.first['visitDateTime']! as int);
        final j = Jalali.fromDateTime(dt);
        visitsSummary = 'نوبت بعدی: ${j.day} ${_jalaliMonthName(j.month)}، $doctor';
      }

      // 4. Fetch records summary
      final docsRes = await db.query('medical_documents');
      final allergyRes = await db.query('allergies');
      final recordsSummary = '${docsRes.length} مدرک · ${allergyRes.length} آلرژی ثبت‌شده';

      // 5. Load alerts
      final settings = await db.query('app_settings');
      final settingsMap = {for (final s in settings) s['key']! as String: s['value']! as String};
      final pregnancyEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_pregnancy_enabled');
      final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
      final showPreg = isFemale && pregnancyEnabled;

      final alerts = <String>[];

      // A. Medications alerts (low stock)
      final lowStockMeds = await db.query(
        'routines',
        where: "category = 'medical' AND isArchived = 0 AND medStockCount <= medRefillThreshold AND medStockCount > 0",
      );
      for (final med in lowStockMeds) {
        alerts.add('موجودی داروی «${med['title']}» رو به اتمام است (${med['medStockCount']} عدد باقی‌مانده).');
      }

      // B. Blood sugar alerts (hypo/hyperglycemia)
      if (sugarLogs.isNotEmpty) {
        final val = sugarLogs.first['value']! as int;
        final type = sugarLogs.first['measurementType']! as String;
        final isDiabetic = settingsMap['patient_has_diabetes'] == 'true';
        
        var maxVal = isDiabetic ? 130 : 100;
        if (type == 'AFTER_MEAL' || type == 'RANDOM') maxVal = isDiabetic ? 180 : 140;

        if (val < 70) {
          alerts.add('⚠️ هشدار افت شدید قند خون (کمتر از ۷۰): مقدار $val ثبت شده است!');
        } else if (val > maxVal + 50) {
          alerts.add('⚠️ هشدار افزایش شدید قند خون: مقدار $val ثبت شده است!');
        }
      }

      // C. Blood pressure alerts (crisis)
      if (bpLogs.isNotEmpty) {
        final sys = bpLogs.first['systolic']! as int;
        final dia = bpLogs.first['diastolic']! as int;
        if (sys > 180 || dia > 120) {
          alerts.add('🚨 بحران فشار خون ($sys/$dia): نیاز به بررسی فوری پزشکی!');
        }
      }

      // D. Labor contraction alert (5-1-1)
      if (showPreg) {
        final activePreg = await db.query('pregnancy_tracker', where: 'isActive = 1', limit: 1);
        if (activePreg.isNotEmpty) {
          final trackerId = activePreg.first['id']! as String;
          final contractionRes = await db.query(
            'contraction_timer',
            where: 'pregnancyId = ?',
            whereArgs: [trackerId],
            orderBy: 'loggedAt DESC',
          );
          
          if (contractionRes.length >= 3) {
            final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
            final recent = contractionRes.where((c) => (c['loggedAt']! as int) >= oneHourAgo).toList();

            if (recent.length >= 3) {
              var matches511 = true;
              for (var i = 0; i < recent.length; i++) {
                final duration = recent[i]['durationSeconds']! as int;
                final interval = recent[i]['intervalFromPrevious']! as int;
                if (duration < 60) matches511 = false;
                if (i < recent.length - 1 && (interval > 300 || interval == 0)) matches511 = false;
              }
              if (matches511) {
                alerts.add('🤰 هشدار زایمان فعال (انقباضات ۵-۱-۱): لطفاً فوراً با اورژانس یا بخش زایمان تماس بگیرید!');
              }
            }
          }
        }
      }

      // E. Calculate Health Engine data
      final allSugars = await db.query('blood_sugar_logs', orderBy: 'loggedAt DESC');
      final sugarLogsList = allSugars.map(BloodSugarLog.fromMap).toList();

      final allBps = await db.query('blood_pressure_logs', orderBy: 'loggedAt DESC');
      final bpLogsList = allBps.map(BloodPressureLog.fromMap).toList();

      final allVitals = await db.query('vital_signs_logs', orderBy: 'loggedAt DESC');
      final vitalLogsList = allVitals.map(VitalSignLog.fromMap).toList();

      final allMedicationLogs = await db.query('medication_logs', orderBy: 'createdAt DESC');
      final medLogsList = allMedicationLogs.map(MedicationLog.fromMap).toList();

      final prnLogsRes = await db.query('prn_logs', orderBy: 'takenAt DESC');
      final energyLogsRes = await db.query('energy_logs', orderBy: 'loggedAt DESC');
      final sleepLogsRes = await db.query('bedtime_diagnostics', orderBy: 'createdAt DESC');

      final engineInput = HealthEngineInput(
        bloodSugarLogs: sugarLogsList,
        bloodPressureLogs: bpLogsList,
        vitalSignLogs: vitalLogsList,
        medicationLogs: medLogsList,
        prnLogs: prnLogsRes,
        energyLogs: energyLogsRes,
        sleepLogs: sleepLogsRes,
        hasDiabetes: settingsMap['patient_has_diabetes'] == 'true',
        hasHypertension: settingsMap['patient_has_hypertension'] == 'true',
        today: DateTime.now(),
      );

      final engineOutput = HealthEngine.calculateSync(engineInput);
      final hasAdherenceData = medLogsList.isNotEmpty;

      if (mounted) {
        setState(() {
          _medicationsSummary = medsSummary;
          _monitoringSummary = monitoringSummary;
          _visitsSummary = visitsSummary;
          _recordsSummary = recordsSummary;
          
          _nextDoseName = nextMedName;
          _nextDoseTimeStr = nextMedTimeStr;
          
          _criticalAlerts = alerts;
          _engineOutput = engineOutput;
          _hasAdherenceData = hasAdherenceData;
          _isLoading = false;
        });

        _calculateNextDoseCountdown();
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateNextDoseCountdown() {
    if (!mounted) return;
    if (_nextDoseTimeStr == null || _nextDoseName == null) {
      _countdownNotifier.value = 'برنامه دارویی فعال برای امروز تعریف نشده است 💊';
      return;
    }

    final now = DateTime.now();
    final parts = _nextDoseTimeStr!.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    
    final scheduledDateTime = DateTime(now.year, now.month, now.day, hour, minute);
    final diff = scheduledDateTime.difference(now);
    
    if (diff.isNegative) {
      final overdueMins = diff.inMinutes.abs();
      _countdownNotifier.value = 'نوبت داروی «$_nextDoseName» با تأخیر ($overdueMins دقیقه قبل)';
    } else {
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      final timeRemainingStr = hours > 0 
          ? '$hours ساعت و $minutes دقیقه مانده' 
          : '$minutes دقیقه مانده';
      _countdownNotifier.value = 'دوز بعدی: «$_nextDoseName» ($timeRemainingStr)';
    }
  }

  void _openAiAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AssistantSheet(persona: PersonaRegistry.instance.getPersona('health')!),
      ),
    );
  }

  void _openDoctorVisitSummarySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const Directionality(
        textDirection: TextDirection.rtl,
        child: DoctorVisitSummarySheet(),
      ),
    );
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    ).then((_) => _loadDashboardData());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topInset + 185.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTabbedMorphingScaffold(
        title: 'دارو و سلامت',
        subtitle: 'یادآور دارو، ثبت علائم حیاتی و پرونده پزشکی',
        statusBadge: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            'فعال',
            style: TextStyle(
              fontSize: 10.5,
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          RitmoVibrancyActionButton(
            icon: CupertinoIcons.sparkles,
            iconColor: colors.primary,
            isAiButton: true,
            accentColor: colors.primary,
            tooltip: 'دستیار هوشمند سلامت',
            onTap: _openAiAssistant,
          ),
        ],
        tabItems: const [
          RitmoTabItem<int>(
            title: 'داشبورد سلامت',
            icon: CupertinoIcons.square_grid_2x2_fill,
            value: 0,
          ),
          RitmoTabItem<int>(
            title: 'روندها و تحلیل سلامت',
            icon: CupertinoIcons.chart_bar_alt_fill,
            value: 1,
          ),
        ],
        tabBuilders: [
          (context, scrollController) => _buildDashboardTab(scrollController, contentTopPadding),
          (context, scrollController) => _buildInsightsTab(scrollController, contentTopPadding),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(ScrollController scrollController, double contentTopPadding) {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 16),
        child: _buildSkeletonLoading(),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_criticalAlerts.isNotEmpty) ...[
            SlideFadeTransition(
              delay: const Duration(milliseconds: 100),
              child: _buildAlertsBanner(),
            ),
            const SizedBox(height: 16),
          ],
          SlideFadeTransition(
            delay: const Duration(milliseconds: 150),
            child: _buildStatusHero(),
          ),
          const SizedBox(height: 16),
          SlideFadeTransition(
            delay: const Duration(milliseconds: 200),
            child: _buildGridMenu(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInsightsTab(ScrollController scrollController, double contentTopPadding) {
    final colors = context.colors;
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.only(top: contentTopPadding),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_engineOutput == null) {
      return Padding(
        padding: EdgeInsets.only(top: contentTopPadding),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.chart_bar, size: 48, color: colors.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  'داده‌ای برای تحلیل سلامت وجود ندارد.',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdherenceCard(
            stats: _engineOutput!.adherence,
            hasData: _hasAdherenceData,
          ),
          const SizedBox(height: 16),
          HealthTrendsSection(trends: _engineOutput!.trends),
          const SizedBox(height: 16),
          HealthCorrelationSection(correlations: _engineOutput!.correlations),
          const SizedBox(height: 20),
          RitmoNeuButton(
            onTap: _openDoctorVisitSummarySheet,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.doc_text_fill, color: colors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'تولید خلاصه برای پزشک',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAlertsBanner() {
    final colors = context.colors;
    return RitmoCard.neumorphic(
      backgroundColor: colors.medicalRed.withValues(alpha: 0.08),
      borderColor: colors.medicalRed.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _criticalAlerts.map((alert) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: colors.medicalRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _toPersianDigits(alert),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.medicalRed,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusHero() {
    final colors = context.colors;
    final stats = _engineOutput?.adherence;
    final rate = stats?.adherenceRate ?? 0.0;
    final streak = stats?.currentStreak ?? 0;
    final hasMeds = _nextDoseName != null;

    return RitmoCard.neumorphic(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RitmoCardHeader(
            title: 'پایبندی دارویی',
            subtitle: streak > 0
                ? '🔥 ${_toPersianDigits(streak.toString())} روز پایبندی متوالی! فوق‌العاده است.'
                : 'با ثبت به‌موقع مصرف داروها، وضعیت خود را بهبود دهید.',
            icon: CupertinoIcons.capsule_fill,
            iconColor: colors.primary,
            trailing: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: rate / 100.0,
                    strokeWidth: 5,
                    backgroundColor: colors.border.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  ),
                  Text(
                    '%${_toPersianDigits(rate.toStringAsFixed(0))}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const RitmoCardDivider(),
          RitmoCardTile(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (hasMeds ? colors.primary : colors.textSecondary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                hasMeds ? CupertinoIcons.time : CupertinoIcons.info_circle,
                color: hasMeds ? colors.primary : colors.textSecondary,
                size: 17,
              ),
            ),
            title: hasMeds ? 'نوبت بعدی دارو' : 'وضعیت نوبت بعدی',
            subtitleWidget: ValueListenableBuilder<String>(
              valueListenable: _countdownNotifier,
              builder: (context, countdownText, _) {
                return Text(
                  _toPersianDigits(countdownText),
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: hasMeds ? FontWeight.bold : FontWeight.normal,
                    color: hasMeds ? colors.textPrimary : colors.textSecondary,
                  ),
                );
              },
            ),
            trailing: Icon(
              CupertinoIcons.chevron_left,
              size: 14,
              color: colors.textSecondary.withValues(alpha: 0.4),
            ),
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (_) => const MedicationsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGridMenu() {
    final colors = context.colors;
    return RitmoAdaptiveGrid(
      minTileWidth: 140,
      spacing: 14,
      maxColumns: 2,
      children: [
        _buildHubCard(
          title: 'داروها',
          subtitle: _medicationsSummary,
          icon: CupertinoIcons.capsule_fill,
          color: colors.primary,
          onTap: () => _navigateToPage(const MedicationsPage()),
        ),
        _buildHubCard(
          title: 'پایش سلامت',
          subtitle: _monitoringSummary,
          icon: CupertinoIcons.waveform_path,
          color: colors.warning,
          onTap: () => _navigateToPage(const MonitoringPage()),
        ),
        _buildHubCard(
          title: 'نوبت‌های پزشک',
          subtitle: _visitsSummary,
          icon: CupertinoIcons.calendar_badge_plus,
          color: colors.success,
          onTap: () => _navigateToPage(const VisitsPage()),
        ),
        _buildHubCard(
          title: 'پرونده پزشکی',
          subtitle: _recordsSummary,
          icon: CupertinoIcons.folder_fill,
          color: colors.accent,
          onTap: () => _navigateToPage(const RecordsPage()),
        ),
      ],
    );
  }

  Widget _buildHubCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return RitmoCard.neumorphic(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Icon(
                CupertinoIcons.arrow_up_left,
                color: colors.textSecondary.withValues(alpha: 0.4),
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _toPersianDigits(subtitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildSkeletonLoading() {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 150,
              height: 24,
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.card.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        const SizedBox(height: 20),
        RitmoAdaptiveGrid(
          minTileWidth: 140,
          spacing: 16,
          maxColumns: 2,
          children: List.generate(4, (_) => Container(
            height: 120,
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(28),
            ),
          )),
        ),
      ],
    );
  }
}

class SlideFadeTransition extends StatelessWidget {

  const SlideFadeTransition({
    super.key,
    required this.child,
    required this.delay,
  });
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1.0 - value) * 20.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
