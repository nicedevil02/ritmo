import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';
import 'package:ritmo/core/ai/ai_briefing_service.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/completion/snooze_policy.dart';
import 'package:ritmo/core/domain/engines/engine_enums.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/domain/engines/ritmo_intelligence_engine.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/daily_behavior.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/platform/notification_platform.dart';
import 'package:ritmo/core/security/app_lock_service.dart';
import 'package:ritmo/core/services/ad_service.dart';
import 'package:ritmo/core/services/central_inbox_service.dart';
import 'package:ritmo/core/services/ritmo_timer_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/features/assistant/logic/mid_day_replan_service.dart';
import 'package:ritmo/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart';
import 'package:ritmo/features/courses/presentation/courses_screen.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/goals/presentation/goals_screen.dart';
import 'package:ritmo/features/health/presentation/health_screen.dart';
import 'package:ritmo/features/inbox/presentation/inbox_screen.dart';
import 'package:ritmo/features/sleep/presentation/widgets/sleep_tonight_shortcut.dart';
import 'package:ritmo/features/study/study_module_entry.dart';
import 'package:ritmo/features/settings/presentation/settings_screen.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';
import 'package:ritmo/features/routines/presentation/widgets/routine_snooze_bottom_sheet.dart';
import 'package:ritmo/features/routines/shared/routine_actions.dart';
import 'package:ritmo/features/routines/shared/widgets/routine_details_sheet.dart';
import 'package:ritmo/features/routines/shared/widgets/routine_niyyah_sheet.dart';
import 'package:ritmo/features/supplementary_sports/supplementary_sports.dart';
import 'package:ritmo/features/today/presentation/active_timer_overlay.dart';
import 'package:ritmo/features/today/presentation/dashboard_controller.dart';
import 'package:ritmo/features/today/presentation/insights_screen.dart';
import 'package:ritmo/features/today/presentation/home_focus_ranker.dart';
import 'package:ritmo/features/notes/presentation/widgets/today_experience_card.dart';
import 'package:ritmo/features/today/presentation/widgets/daily_reflection_sheet.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/ai_day_planner_launcher.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/assistant_card.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/dashboard_header.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/features/search/presentation/global_search_screen.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/energy/presentation/widgets/quick_log_sheet.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/dashboard_module_summary.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/home_focus_hero.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/home_notice_cards.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/home_pulse_strip.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/home_quick_actions.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/module_summary_grid.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/next_action_hero.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/today_path_progress_banner.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_dashboard_card.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/energy_dashboard_card.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/morning_checkin_pill_banner.dart';
import 'package:ritmo/features/today/presentation/widgets/morning_checkin_sheet.dart';
import 'package:ritmo/features/wellbeing/presentation/wellbeing_screen.dart';
import 'package:ritmo/features/worship/presentation/worship_screen.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class NowDashboardScreen extends StatefulWidget {
  const NowDashboardScreen({
    super.key,
    required this.onLogout,
    required this.themeRepository,
    required this.localeRepository,
    this.onNavigateToTab,
  });
  final VoidCallback onLogout;
  final ThemeRepository themeRepository;
  final LocaleRepository localeRepository;
  final Function(int)? onNavigateToTab;

  @override
  State<NowDashboardScreen> createState() => _NowDashboardScreenState();
}

class _NowDashboardScreenState extends State<NowDashboardScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isFirstLoad = true;
  AiBriefing? _briefing;
  bool _isBriefingLoading = false;
  int _unreadInboxCount = 0;
  StreamSubscription? _inboxSubscription;
  StreamSubscription? _agendaSubscription;

  // Timeline list representation
  List<Map<String, dynamic>> _timelineItems = [];

  // G-2/G-4: منبع واحد Agenda (همهٔ دامنهها) + شمار واقعی دوزهای باقیماندهٔ دارو
  List<AgendaItem> _agendaItems = [];
  int _pendingMedDoses = 0;

  // P1-1: اسنپشات «مسیر امروز»
  DayAgendaSnapshot? _todaySnapshot;

  // G-4: توکن نسل برای باطلکردن نتایج کهنه و جلوگیری از race بین دو بارگذاری
  int _loadGeneration = 0;
  DateTime? _lastLoadAt;
  bool _avatarFileExists = false;

  // Specialized Dashboard state variables
  Map<String, String> _settingsMap = {};

  DailyBehavior? _dailyBehavior;
  Map<String, dynamic>? _activeZone;
  ActiveRealmState _realmState = const FreeRealmState();
  List<RealmData> _allRealms = const [];
  List<RealmScheduleData> _allSchedules = const [];
  String? _activeZoneName;
  String? _activeZoneIcon;
  String? _activeZoneTimeRange;
  String? _activeZoneColorHex;
  int _activeZoneRoutinesCount = 0;
  RitmoEngineOutput? _engineOutput;
  bool _needCheckin = true;
  bool _hasReflection = false;
  bool _reflectionDismissed = false;
  bool _showReplanBanner = false;

  // Dynamic Energy State fields
  // G-3: null = هیچ لاگ انرژی ثبت نشده؛ مقدار ساختگی ۶۵ حذف شد.
  double? _currentEnergyPercent;
  String _currentEnergyLabel = 'متوسط';
  String _currentEnergyDesc = 'مناسب برای مطالعه، پروژه‌ها و روتین‌ها';
  List<String> _currentEnergyExplanation = [];
  int _rhythmScore = 0;
  bool _rhythmScoreHasData = false;
  List<Map<String, dynamic>> _completionsToday = [];
  List<DashboardModuleSummary> _moduleSummaries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardData();
    _checkActiveTimerOnStart();
    _checkLaunchIntent();
    RitmoEvents.routineChanges.addListener(_onRoutineChanges);
    _updateUnreadCount();
    _inboxSubscription = RitmoEventBus().onEvents
        .where((e) => e.type == 'inbox_updated')
        .listen((_) {
          _updateUnreadCount();
        });
    // P1-1: وقتی از کارت «مسیر امروز» یا تقویم آیتمی تیک میخورد، خانه تازه شود.
    _agendaSubscription = RitmoEventBus().onEvents
        .where((e) => e.type == 'AgendaItemToggled')
        .listen((_) {
          _loadDashboardData();
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inboxSubscription?.cancel();
    _agendaSubscription?.cancel();
    RitmoEvents.routineChanges.removeListener(_onRoutineChanges);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLaunchIntent();
      // G-4: اگر کمتر از ۳۰ ثانیه از آخرین بارگذاری موفق گذشته، دوباره لود نکن؛
      // این کار از سینک/اسکن تکراری در هر سوییچ اپ جلوگیری میکند.
      final last = _lastLoadAt;
      if (last == null ||
          DateTime.now().difference(last) > const Duration(seconds: 30)) {
        _loadDashboardData();
      }
    }
  }

  Future<void> _checkLaunchIntent() async {
    final launchInfo = await sl<NotificationPlatform>().getLaunchIntent();
    // Quick Add notification action tapped
    if (launchInfo != null && launchInfo['action'] == 'OPEN_QUICK_ADD') {
      if (mounted) {
        unawaited(
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              barrierDismissible: true,
              pageBuilder: (context, _, _) =>
                  UniversalPlannerSheet(onSaved: _loadDashboardData),
            ),
          ),
        );
      }
      return;
    }
    // Home-screen widget row tapped -> open that module's screen directly.
    if (launchInfo != null && launchInfo['action'] == 'OPEN_MODULE') {
      final moduleId = launchInfo['moduleId'] as String?;
      if (moduleId != null && moduleId.isNotEmpty && mounted) {
        _openModuleScreen(moduleId);
      }
      return;
    }
    if (launchInfo != null &&
        (launchInfo['action'] == 'START_TIMER' ||
            launchInfo['action'] == 'OPEN_ROUTINE')) {
      final reminderId = launchInfo['reminderId'] as String?;
      if (reminderId != null) {
        final db = await DatabaseHelper.instance.database;
        final List<Map<String, dynamic>> reminders = await db.query(
          'pending_reminders',
          where: 'id = ?',
          whereArgs: [reminderId],
        );
        String? routineId;
        if (reminders.isNotEmpty) {
          routineId = reminders.first['routineId'] as String?;
        } else {
          routineId = reminderId;
        }

        if (routineId != null) {
          final List<Map<String, dynamic>> routines = await db.query(
            'routines',
            where: 'id = ?',
            whereArgs: [routineId],
          );
          if (routines.isNotEmpty) {
            // G-9: هیدراسیون دستی ۳۰ خطی حذف شد — همان مسیر Routine.fromMap
            // که _resumeActiveTimer استفاده میکند، منبع واحد تبدیل ردیف است.
            final routine = Routine.fromMap(routines.first);
            if (routine.isPrivate) {
              final authenticated = await AppLockService.instance
                  .authenticateWithDevice(
                    reason: 'تأیید هویت برای اجرای رویداد محرمانه',
                    biometricOnly: false,
                  );
              if (!authenticated) return;
            }
            if (mounted) {
              _startTimerFlow(routine, 'FULL');
            }
          }
        }
      }
      return;
    }
  }

  Future<void> _updateUnreadCount() async {
    final count = await CentralInboxService.unreadCount();
    if (mounted) {
      setState(() {
        _unreadInboxCount = count;
      });
    }
  }

  bool _dashboardLoadInFlight = false;
  DateTime _lastDashboardLoad = DateTime.fromMillisecondsSinceEpoch(0);

  void _onRoutineChanges() {
    if (_dashboardLoadInFlight) return;
    if (DateTime.now().difference(_lastDashboardLoad) <
        const Duration(seconds: 2)) {
      return;
    }
    _loadDashboardData();
  }

  Future<void> _checkActiveTimerOnStart() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = await DatabaseHelper.instance.database;
      final activeTimers = await db.query('active_timers', limit: 1);
      if (activeTimers.isNotEmpty) {
        final timerData = activeTimers.first;
        final routineId = timerData['routineId']! as String;
        final plannedMinutes = timerData['plannedDurationMinutes']! as int;

        final routineMapList = await db.query(
          'routines',
          where: 'id = ?',
          whereArgs: [routineId],
        );
        if (routineMapList.isNotEmpty) {
          final routine = Routine.fromMap(routineMapList.first);

          var mode = 'FULL';
          if (plannedMinutes == routine.lightDurationMinutes) {
            mode = 'LIGHT';
          } else if (plannedMinutes == routine.minimalDurationMinutes) {
            mode = 'MINIMAL';
          }

          if (mounted) {
            _startTimerFlow(routine, mode);
          }
        }
      }
    });
  }

  Future<void> _refreshBriefing() async {
    if (!mounted) return;
    setState(() {
      _isBriefingLoading = true;
    });
    try {
      final b = await AiBriefingService.instance.getOrRefresh(force: true);
      if (mounted) {
        setState(() {
          _briefing = b;
        });
      }
    } catch (e) {
      debugPrint('[BRIEFING] Manual refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBriefingLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData({bool showLoading = false}) async {
    if (!mounted) return;
    if (_dashboardLoadInFlight) return;
    _dashboardLoadInFlight = true;
    _lastDashboardLoad = DateTime.now();
    try {
      // G-4: نسل جدید — هر نتیجهٔ کهنهای که بعداً برگردد دور ریخته میشود.
      final generation = ++_loadGeneration;
      bool isStale() => !mounted || generation != _loadGeneration;

      if (showLoading || _isFirstLoad) {
        setState(() {
          _isLoading = true;
        });
      }

      final controller = DashboardController();

      // P0: critical path (settings -> routines -> RIE -> timeline)
      await controller.loadP0();

      if (isStale()) return;
      setState(() {
        _isFirstLoad = false;
        _isLoading = false;
        _timelineItems = controller.timelineItems;
        _completionsToday = controller.completionsToday;
        _rhythmScore = controller.rhythmScore;
        _rhythmScoreHasData = controller.rhythmScoreHasData;
        _settingsMap = controller.settingsMap;
        _activeZone = controller.activeZone;
        _realmState = controller.realmState;
        _allRealms = controller.allRealms;
        _allSchedules = controller.allSchedules;
        _activeZoneName = controller.activeZoneName;
        _activeZoneIcon = controller.activeZoneIcon;
        _activeZoneTimeRange = controller.activeZoneTimeRange;
        _activeZoneColorHex = controller.activeZoneColorHex;
        _activeZoneRoutinesCount = controller.activeZoneRoutinesCount;
        _engineOutput = controller.engineOutput;
        _needCheckin = controller.needCheckin;
        _hasReflection = controller.hasReflection;
        _reflectionDismissed = controller.reflectionDismissed;
        // G-2: دوزهای واقعی باقیماندهٔ دارو (از P0 کنترلر)
        _pendingMedDoses = controller.pendingMedicationDoseCount;
        _lastLoadAt = DateTime.now();
      });

      // P1: deferred — runs after first frame is painted
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (isStale()) return;
        await controller.loadP1();
        if (isStale()) return;

        final showReplan = await MidDayReplanService.instance
            .shouldSuggestReplan();

        // G-4: وجود فایل آواتار بهصورت async و خارج از build چک میشود (نه existsSync)
        var avatarExistsResult = false;
        final avatarPath = controller.settingsMap['user_avatar_path'];
        if (avatarPath != null && avatarPath.isNotEmpty) {
          if (avatarPath.startsWith('http://') ||
              avatarPath.startsWith('https://') ||
              avatarPath.startsWith('blob:') ||
              avatarPath.startsWith('data:')) {
            avatarExistsResult = true;
          } else {
            try {
              avatarExistsResult = await File(avatarPath).exists();
            } catch (_) {
              avatarExistsResult = false;
            }
          }
        }

        if (isStale()) return;
        setState(() {
          _briefing = controller.briefing;
          _isBriefingLoading = controller.isBriefingLoading;
          _dailyBehavior = controller.dailyBehavior;
          _currentEnergyPercent = controller.currentEnergyPercent;
          _currentEnergyLabel = controller.currentEnergyLabel;
          _currentEnergyDesc = controller.currentEnergyDesc;
          _currentEnergyExplanation = controller.currentEnergyExplanation;
          _rhythmScore = controller.rhythmScore;
          _rhythmScoreHasData = controller.rhythmScoreHasData;
          _completionsToday = controller.completionsToday;
          _moduleSummaries = controller.moduleSummaries;
          _showReplanBanner = showReplan;
          _avatarFileExists = avatarExistsResult;
          // G-2: منبع واحد Agenda برای کارت اقدام بعدی
          _agendaItems = controller.agenda;
          // P1-1: اسنپشات «مسیر امروز»
          _todaySnapshot = controller.todaySnapshot;
        });

        if (isStale()) return;
        await _pushCriticalAlerts();
        if (isStale()) return;
        await _pushCheckinsAndReflections();
      });
    } finally {
      _dashboardLoadInFlight = false;
    }
  }

  void _openModuleScreen(String moduleId) {
    Widget? screen;
    switch (moduleId) {
      case 'wellbeing':
      case 'energy':
        screen = const WellbeingScreen();
        break;
      case 'sleep':
        screen = const WellbeingScreen(initialSection: WellbeingSection.sleep);
        break;
      case 'sports':
        _openSupplementarySports();
        return;
      case 'medicine':
        screen = const HealthScreen();
      case 'worship':
        screen = const WorshipScreen();
      case 'cycle':
        screen = const CycleScreen();
      case 'goals':
        screen = const GoalsScreen();
      case 'courses':
        screen = const CoursesScreen(); // can() always returns true
      case 'study':
      case 'konkur':
        StudyModuleEntry.open(context).then((_) => _loadDashboardData());
        return;
    }
    if (screen == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    ).then((_) => _loadDashboardData());
  }

  Future<void> _openSupplementarySports() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final profiles = await db.query(
        'ss_user_profile',
        where: 'onboardingCompleted = 1',
        limit: 1,
      );
      final hasCompletedOnboarding = profiles.isNotEmpty;

      if (mounted) {
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => hasCompletedOnboarding
                  ? const MvHubScreen()
                  : MvOnboardingScreen(onComplete: (_) async => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MvHubScreen()))),
            ),
          ).then((_) => _loadDashboardData()),
        );
      }
    } catch (e) {
      debugPrint('Error opening supplementary sports: $e');
      if (mounted) {
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MvHubScreen()),
          ).then((_) => _loadDashboardData()),
        );
      }
    }
  }

  Future<void> _completeTask(
    Routine routine,
    String resultType, [
    int? customDuration,
  ]) async {
    final todayStr = RitmoDate.now().value;

    if (resultType == 'SKIPPED') {
      await RitmoExecutionKernel.instance.execute(
        SkipOccurrenceCommand(routineId: routine.id, dateStr: todayStr),
      );
    } else {
      final duration = DurationBounds.resolveForCompletion(
        targetMinutes: routine.targetDurationMinutes,
        lightMinutes: routine.lightDurationMinutes,
        minimalMinutes: routine.minimalDurationMinutes,
        resultType: resultType,
        customDuration: customDuration,
        currentTargetMinutes: routine.currentTargetMinutes,
      );

      await RitmoExecutionKernel.instance.execute(
        CompleteOccurrenceCommand(
          routineId: routine.id,
          dateStr: todayStr,
          resultType: resultType,
          durationMinutes: duration,
        ),
      );
    }

    if (mounted) {
      var msg = 'روتین "${routine.title}" انجام شد! 🌟';
      if (resultType == 'LIGHT')
        msg = 'روتین "${routine.title}" به صورت سبک انجام شد! ⚡';
      if (resultType == 'MINIMAL')
        msg = 'روتین "${routine.title}" به صورت حداقلی انجام شد! 🌿';
      if (resultType == 'SKIPPED') msg = 'روتین "${routine.title}" رد شد. ✕';
      if (resultType == 'CANNOT_NOW' || resultType == 'SNOOZED') {
        msg = 'روتین "${routine.title}" به تعویق افتاد. ⏳';
      }

      final colors = context.colors;
      final isWarning =
          (resultType == 'CANNOT_NOW' ||
          resultType == 'SNOOZED' ||
          resultType == 'SKIPPED');
      RitmoToast.show(
        context,
        msg,
        icon: isWarning
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline,
        iconColor: isWarning ? colors.warning : colors.success,
      );
    }

    unawaited(_loadDashboardData());
  }

  /// ورود پلکانی سکشن‌ها — با احترام به Reduced Motion
  Widget _enter(int slot, Widget child) {
    if (RitmoMotion.reduceMotion(context)) return child;
    return child
        .animate(delay: Duration(milliseconds: 45 * slot))
        .fadeIn(duration: RitmoMotion.normal, curve: RitmoMotion.standard)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: RitmoMotion.normal,
          curve: RitmoMotion.standard,
        );
  }

  /// پیشرفت واقعی مسیر امروز — اول از اسنپشات Agenda، در نبود آن از تایملاین.
  ({double ratio, int done, int remaining, int total}) _todayProgress() {
    final snapshot = _todaySnapshot;
    if (snapshot != null) {
      final total = snapshot.completedCount + snapshot.remainingCount;
      if (total > 0) {
        return (
          ratio: snapshot.completedCount / total,
          done: snapshot.completedCount,
          remaining: snapshot.remainingCount,
          total: total,
        );
      }
    }
    final total = _timelineItems.length;
    final done = _timelineItems.where((i) => i['isCompleted'] == true).length;
    return (
      ratio: total == 0 ? 0.0 : done / total,
      done: done,
      remaining: total - done,
      total: total,
    );
  }

  /// مجموع دقایق تمرکز کارهای انجام‌شدهٔ امروز
  int get _focusMinutesToday {
    var total = 0;
    if (_agendaItems.isNotEmpty) {
      for (final item in _agendaItems) {
        if (item.completion == AgendaCompletion.done) {
          total += (item.durationMinutes ?? 15);
        }
      }
    } else if (_completionsToday.isNotEmpty) {
      for (final c in _completionsToday) {
        final dur = (c['durationMinutes'] as int?) ??
            (c['actual_duration_minutes'] as int?) ??
            15;
        total += dur;
      }
    }
    return total;
  }

  /// فرمت‌بندی زمان تمرکز (مثلاً: ۱ ساعت و ۲۰ دقیقه)
  static String _formatFocusTime(int totalMinutes) {
    if (totalMinutes <= 0) {
      return '۰ دقیقه';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '$minutes دقیقه';
    }
    if (minutes == 0) {
      return '$hours ساعت';
    }
    return '$hours ساعت و $minutes دقیقه';
  }

  /// میان‌برهای صفحهٔ خانه.
  ///
  /// ردیف عمداً ثابت است: هر میان‌بر همیشه سر جای خودش می‌ماند تا حافظهٔ عضلانی
  /// کاربر حفظ شود. فوریت با هایلایت اعلام می‌شود، نه با پنهان‌کردن همسایه‌ها —
  /// چون نوار افقی اسکرول می‌شود و تعداد میان‌برها هیچوقت محدودیت فضایی نداشته.
  ///
  /// تنها استثنای قاعدهٔ «یک مقصد، یک ورودی» دستیار است که تب اختصاصی در داک
  /// پایین دارد و کارت بریفینگش هم پایین صفحه هست.
  List<HomeQuickAction> _quickActions(RitmoColors colors, bool isDarkMode) {
    return [
      HomeQuickAction(
        label: 'افزودن برنامه',
        icon: CupertinoIcons.add_circled_solid,
        color: colors.primary,
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              barrierDismissible: true,
              pageBuilder: (context, _, _) =>
                  UniversalPlannerSheet(onSaved: _loadDashboardData),
            ),
          );
        },
      ),
      HomeQuickAction(
        label: 'ارزیابی انرژی',
        icon: CupertinoIcons.sunrise_fill,
        color: colors.accent,
        highlighted: _needCheckin,
        onTap: _showMorningCheckinSheet,
      ),
      HomeQuickAction(
        label: 'بازچینی روز',
        icon: CupertinoIcons.arrow_2_squarepath,
        color: colors.goldAccent,
        highlighted: _showReplanBanner,
        onTap: _runReplanFlow,
      ),
      HomeQuickAction(
        label: 'برنامه‌ریز هوشمند',
        icon: CupertinoIcons.sparkles,
        color: colors.reflectionAccent,
        onTap: () =>
            AiDayPlannerLauncher.open(context, onSaved: _loadDashboardData),
      ),
      HomeQuickAction(
        label: 'تقویم امروز',
        icon: CupertinoIcons.calendar,
        color: colors.primary,
        onTap: () => widget.onNavigateToTab?.call(4),
      ),
      HomeQuickAction(
        label: 'بازتاب روز',
        icon: CupertinoIcons.moon_stars_fill,
        color: colors.sleepAccent,
        onTap: _openReflectionSheet,
      ),
    ];
  }

  /// آواتار با هالهٔ گرادیان انرژی در هدر کپسولی شیشه‌ای
  Widget _buildAvatarLeading(
    RitmoColors colors,
    bool hasAvatarFile,
    String? avatarPath,
    String userName,
  ) {
    return Semantics(
      button: true,
      label: 'پروفایل و تنظیمات',
      child: GestureDetector(
        onTap: () {
          RitmoHaptics.tap();
          _showMoreSheet();
        },
        child: Container(
          height: 38,
          width: 38,
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors.energyGradient),
            boxShadow: [
              BoxShadow(
                color: colors.energyGradient.first.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.bg,
              image: hasAvatarFile && avatarPath != null
                  ? DecorationImage(
                      image: ResizeImage(
                        FileImage(File(avatarPath)),
                        width: 120,
                        height: 120,
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasAvatarFile
                ? null
                : Center(
                    child: Text(
                      userName.isNotEmpty ? userName[0] : '؟',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// نشان زنگوله اعلان‌ها با شمارش پیام‌های خوانده‌نشده
  Widget? _buildBellBadge(RitmoColors colors, bool isDark) {
    if (_unreadInboxCount <= 0) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        border: Border.all(
          color: isDark ? const Color(0xFF1E222A) : Colors.white,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          _unreadInboxCount > 9
              ? '۹+'
              : toPersianDigits(_unreadInboxCount.toString()),
          style: TextStyle(
            color: colors.onPrimary,
            fontSize: 9.0,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  /// اسکلت لودینگ نئومورفیک یکپارچه با چیدمان دقیق کارت‌های مرجع داشبورد (Zero Layout Shift)
  Widget _buildLoadingSkeleton() {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(10, 16, 10, 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // هدر: آواتار + دو خط متن + خوشهٔ اکشن
              Row(
                children: [
                  RitmoSkeleton(width: 44, height: 44, borderRadius: 22),
                  SizedBox(width: RitmoSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RitmoSkeleton(width: 120, height: 14, borderRadius: 6),
                      SizedBox(height: 6),
                      RitmoSkeleton(width: 80, height: 10, borderRadius: 5),
                    ],
                  ),
                  Spacer(),
                  RitmoSkeleton(width: 88, height: 40, borderRadius: 20),
                ],
              ),
              SizedBox(height: 16),

              // ۱. بنر مسیر امروز
              RitmoCardSkeleton(
                height: 72,
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
              SizedBox(height: 16),

              // ۲. تمرکز اکنون (هیرو فوکوس)
              RitmoCardSkeleton(
                height: 190,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              SizedBox(height: 16),

              // ۳. کارت قلمرو فعلی
              RitmoCardSkeleton(
                height: 130,
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
              SizedBox(height: 16),

              // ۴. نبض امروز
              RitmoCardSkeleton(
                height: 105,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              SizedBox(height: 16),

              // ۵. کارت انرژی فعلی
              RitmoCardSkeleton(
                height: 160,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              SizedBox(height: 16),

              // ۶. نوار میان‌برهای سریع (۴ کارت مربعی نئومورفیک)
              Row(
                children: [
                  Expanded(
                    child: RitmoCardSkeleton(
                      height: 92,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                  SizedBox(width: RitmoSpacing.sm),
                  Expanded(
                    child: RitmoCardSkeleton(
                      height: 92,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                  SizedBox(width: RitmoSpacing.sm),
                  Expanded(
                    child: RitmoCardSkeleton(
                      height: 92,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                  SizedBox(width: RitmoSpacing.sm),
                  Expanded(
                    child: RitmoCardSkeleton(
                      height: 92,
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // ۷. کارت تجربهٔ امروز
              RitmoCardSkeleton(
                height: 100,
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
              SizedBox(height: 16),

              // ۸. سیستم‌های فعال
              RitmoCardSkeleton(
                height: 220,
                borderRadius: BorderRadius.all(Radius.circular(22)),
              ),
              SizedBox(height: 16),

              // ۹. دستیار هوشمند
              RitmoCardSkeleton(
                height: 150,
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;

    final alerts = _engineOutput?.criticalAlerts ?? const <String>[];
    final progress = _todayProgress();

    // یکبار محاسبه میشود و بقیهٔ صفحه از آن تبعیت میکند: هرچه هیرو گفته باشد،
    // جای دیگری دوباره تکرار نمیشود.
    final heroData = _buildNextActionHeroData();

    final locale = Localizations.localeOf(context);
    final isFa = locale.languageCode == 'fa';
    final l10n = AppLocalizations.of(context);

    // تاریخ
    final String dateStr;
    if (isFa) {
      final jalali = Jalali.now();
      dateStr =
          '${ShamsiWeek.nameOf(jalali.weekDay)} ${toPersianDigits(jalali.day.toString())} ${jalali.formatter.mN}';
    } else {
      final now = DateTime.now();
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      dateStr =
          '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
    }

    final tg = DashboardHeader.timeGreeting(DateTime.now());
    final userName = _settingsMap['user_name'] ?? 'کاربر';
    final greetingLine = isFa
        ? '${tg.greeting}، $userName ${tg.emoji}'
        : (l10n != null ? '${l10n.welcomeUser(userName)} ${tg.emoji}' : 'Welcome, $userName ${tg.emoji}');
    final avatarPath = _settingsMap['user_avatar_path'];
    final hasAvatarFile =
        _avatarFileExists && avatarPath != null && avatarPath.isNotEmpty;

    return Directionality(
      textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
      child: RitmoSingleMorphingScaffold(
        title: greetingLine,
        subtitle: dateStr,
        leading: _buildAvatarLeading(
          colors,
          hasAvatarFile,
          avatarPath,
          userName,
        ),
        actions: [
          RitmoVibrancyActionButton(
            icon: CupertinoIcons.search,
            tooltip: 'جستجو',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalSearchScreen(),
                ),
              ).then((_) => _loadDashboardData());
            },
          ),
          const SizedBox(width: 6),
          RitmoVibrancyActionButton(
            icon: CupertinoIcons.bell,
            tooltip: 'صندوق ورودی',
            badge: _buildBellBadge(colors, isDarkMode),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InboxScreen(),
                ),
              ).then((_) => _updateUnreadCount());
            },
          ),
        ],
        bodyBuilder: (context, scrollController, topPadding) {
          return CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  10,
                  topPadding,
                  10,
                  140,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ۰. هشدارهای بحرانی — بالاتر از همه چیز
                    if (alerts.isNotEmpty) ...[
                      _enter(0, CriticalAlertsCard(alerts: alerts)),
                      const SizedBox(height: 16),
                    ],

                    // ۰.۲ بنر کپسولی هوشمند ارزیابی انرژی صبحگاهی
                    if (_needCheckin &&
                        heroData.type != HeroPriorityType.morningCheckIn) ...[
                      _enter(
                        0,
                        MorningCheckinPillBanner(
                          onTap: _showMorningCheckinSheet,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ۰.۵ میانبر شبانه — فقط در پنجرهٔ پیش‌خواب دیده می‌شود
                    SleepTonightShortcut(
                      padding: const EdgeInsets.only(bottom: 16),
                      onOpen: () => _openModuleScreen('sleep'),
                    ),

                    // ۱. بنر اختصاصی و پریمیوم مسیر امروز — تفکیک‌شده و در بالای پنجره هیرو (با قابلیت گسترش کشویی)
                    _enter(
                      1,
                      TodayPathProgressBanner(
                        progress: progress.total > 0 ? progress.ratio : 0.0,
                        doneCount: progress.done,
                        totalCount: progress.total,
                        remainingCount: progress.remaining,
                        snapshot: _todaySnapshot,
                        onOpenAgendaItem: _openAgendaItem,
                        onTap: () => widget.onNavigateToTab?.call(
                          RitmoShellMetrics.calendarTabIndexFor(
                            AppModeService.instance.current,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ۲. تمرکز اکنون — تنها اقدام مهم این لحظه
                    _enter(2, HomeFocusHero(data: heroData)),
                    const SizedBox(height: 16),

                    // ۳. کارت قلمرو فعلی — بالای نبض امروز
                    _enter(
                      3,
                      RealmDashboardCard(
                        isDarkMode: isDarkMode,
                        realmState: _realmState,
                        activeZone: _activeZone,
                        activeZoneName: _activeZoneName,
                        activeZoneIcon: _activeZoneIcon,
                        activeZoneColorHex: _activeZoneColorHex,
                        activeZoneRoutinesCount: _activeZoneRoutinesCount,
                        activeZoneTimeRange: _activeZoneTimeRange,
                        onRealmChanged: _loadDashboardData,
                        schedules: _allSchedules,
                        realms: _allRealms,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ۴. نبض امروز — وضعیت روز در یک نگاه
                    _enter(
                      4,
                      HomePulseStrip(
                        progress: progress.ratio,
                        doneCount: progress.done,
                        totalCount: progress.total,
                        onMenuTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InsightsScreen(),
                          ),
                        ).then((_) => _loadDashboardData()),
                        metrics: [
                          HomePulseMetric(
                            label: 'انجام‌شده',
                            value: '${progress.done} از ${progress.total}',
                            icon: CupertinoIcons.checkmark_alt_circle_fill,
                            color: colors.success,
                          ),
                          HomePulseMetric(
                            label: 'زمان تمرکز',
                            value: _formatFocusTime(_focusMinutesToday),
                            icon: CupertinoIcons.timer,
                            color: const Color(0xFF2563EB),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InsightsScreen(),
                              ),
                            ).then((_) => _loadDashboardData()),
                          ),
                          HomePulseMetric(
                            label: 'امتیاز ریتم',
                            value: _rhythmScoreHasData
                                ? '$_rhythmScore٪'
                                : (progress.total > 0
                                    ? '${(progress.ratio * 100).round()}٪'
                                    : 'بدون داده'),
                            icon: CupertinoIcons.waveform_path_ecg,
                            color: const Color(0xFF8B5CF6),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const InsightsScreen(),
                              ),
                            ).then((_) => _loadDashboardData()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ۵. کارت انرژی فعلی — زیر نبض امروز
                    _enter(
                      5,
                      EnergyDashboardCard(
                        isDarkMode: isDarkMode,
                        currentEnergyPercent: _currentEnergyPercent,
                        currentEnergyLabel: _currentEnergyLabel,
                        currentEnergyDesc: _currentEnergyDesc,
                        energyFactors: _currentEnergyExplanation,
                        onEnergyTap: () =>
                            _showEnergyManagementSheet(isDarkMode),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ۶. میانبرهای سریع
                    _enter(
                      6,
                      HomeQuickActions(
                        actions: _quickActions(colors, isDarkMode),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ۷. کارت تجربهٔ امروز
                    _enter(7, const TodayExperienceCard()),
                    const SizedBox(height: 16),

                    // ۹. سیستمهای فعال (تیتر داخل خودش)
                    _enter(
                      9,
                      ModuleSummaryGrid(
                        summaries: _moduleSummaries,
                        onModuleTap: _openModuleScreen,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ۱۰. دستیار — فقط بریفینگ؛ ورود به گفتوگو کار داک پایین است
                    _enter(
                      10,
                      AssistantCard(
                        subtitle: 'خلاصهٔ امروز و پیشنهاد بعدی',
                        suggestedRoutine: _engineOutput?.suggestedRoutine,
                        suggestLightVersion:
                            _engineOutput?.suggestLightVersion ?? false,
                        activeZoneName: _activeZoneName ?? '',
                        defaultEnergyLevel:
                            _settingsMap['default_energy_level'] ??
                            'MEDIUM',
                        dailyBehavior: _dailyBehavior,
                        onStartTap: _showNiyyahSheet,
                        onWhyTap: _showWhySuggestionDialog,
                        briefing: _briefing,
                        isBriefingLoading: _isBriefingLoading,
                        onRefreshBriefing: _refreshBriefing,
                        showNextAction: false,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AdService.instance.getBannerAd(),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// G-2: عنوان خوانا برای تایمر فعال — بهجای نمایش itemId خام.
  String _titleForTimerItem(String itemId) {
    for (final i in _timelineItems) {
      if (i['id']?.toString() == itemId) {
        return i['title']?.toString() ?? '';
      }
    }
    for (final a in _agendaItems) {
      if (a.sourceId == itemId || a.id == itemId) return a.title;
    }
    return '';
  }

  /// G-2: برچسب فارسی حالت تایمر.
  static String _timerModeLabel(String mode) {
    switch (mode.toUpperCase()) {
      case 'LIGHT':
        return 'سبک';
      case 'MINIMAL':
        return 'حداقلی';
      default:
        return 'کامل';
    }
  }

  /// G-2: ادامهٔ تایمر فعال — بهجای no-op قبلی (onNavigateToTab(2)).
  Future<void> _resumeActiveTimer(String routineId, String mode) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'routines',
        where: 'id = ?',
        whereArgs: [routineId],
        limit: 1,
      );
      if (rows.isEmpty || !mounted) return;
      final routine = Routine.fromMap(rows.first);
      _startTimerFlow(routine, mode);
    } catch (e) {
      debugPrint('Error resuming active timer: $e');
    }
  }

  NextActionHeroData _buildNextActionHeroData() {
    final timers = RitmoTimerService.instance.activeTimers;
    final activeTimer = timers.isNotEmpty ? timers.first : null;

    // P2-2: تصمیم اولویت به رتبهبند خالص واگذار شده (قابلتست واحد — P2-3).
    // توجه: medicalCriticalCount فعلاً ۰ است تا محاسبهٔ واقعی بحران دارویی
    // (تداخل/minInterval/maxDoses/حیاتی) در فاز بعد سیم شود.
    final decision = HomeFocusRanker.decide(
      HomeFocusInput(
        now: DateTime.now(),
        hasActiveTimer: activeTimer != null,
        medicalCriticalCount: 0,
        pendingMedDoses: _pendingMedDoses,
        medicineModuleEnabled: ModuleGate.instance.isEnabledFrom(
          _settingsMap,
          'module_medicine_enabled',
        ),
        agendaItems: _agendaItems,
        fallbackTasksPending: _timelineItems.any(
          (i) => i['isCompleted'] != true,
        ),
        needCheckin: _needCheckin,
      ),
    );

    switch (decision.level) {
      // بحران/باقیماندهٔ دارویی
      case HomeFocusLevel.medicalCritical:
      case HomeFocusLevel.medicalDue:
        final isCritical = decision.level == HomeFocusLevel.medicalCritical;
        return NextActionHeroData(
          type: HeroPriorityType.medicalSafety,
          title: isCritical
              ? 'هشدار مهم دارویی'
              : 'دوز داروی امروز هنوز کامل نشده',
          subtitle: isCritical
              ? 'نیازمند بررسی فوری تداخل یا سقف دوز'
              : '${PersianDigits.convert(_pendingMedDoses.toString())} دوز باقی‌مانده',
          primaryCtaLabel: 'ثبت مصرف دارو',
          isMedicalAlert: true,
          onPrimaryTap: () => _openModuleScreen('medicine'),
        );

      // تایمر فعال
      case HomeFocusLevel.activeTimer:
        final t = activeTimer!;
        final timerTitle = _titleForTimerItem(t.itemId);
        final minutes = (t.durationSeconds / 60).round();
        return NextActionHeroData(
          type: HeroPriorityType.activeTimer,
          title: timerTitle.isNotEmpty ? timerTitle : 'کار در حال اجرا',
          subtitle:
              '${PersianDigits.convert(minutes.toString())} دقیقه · حالت ${_timerModeLabel(t.mode)}',
          primaryCtaLabel: 'ادامه / مشاهده',
          onPrimaryTap: () {
            unawaited(_resumeActiveTimer(t.itemId, t.mode));
          },
        );

      // آیتم Agenda (منبع واحد)
      case HomeFocusLevel.agendaItem:
        final chosen = decision.agendaItem!;
        final timeLabel = PersianDigits.convert(chosen.timeOfDay!);
        final isNow = decision.isCurrentActive;

        String subtitleText;
        if (isNow) {
          final parts = chosen.timeOfDay!.split(':');
          final startM =
              (int.tryParse(parts[0]) ?? 0) * 60 +
              (int.tryParse(parts[1]) ?? 0);
          final duration =
              (chosen.durationMinutes != null && chosen.durationMinutes! > 0)
              ? chosen.durationMinutes!
              : 30;
          final endM = startM + duration;
          final now = DateTime.now();
          final nowM = now.hour * 60 + now.minute;
          final remainingM = (endM - nowM).clamp(1, duration);
          subtitleText =
              'زمان: $timeLabel · ${PersianDigits.convert(remainingM.toString())} دقیقه باقی‌مانده از بازه';
        } else if (decision.isOverdue) {
          subtitleText = 'عقب‌افتاده · $timeLabel';
        } else {
          subtitleText = 'زمان: $timeLabel';
        }

        return NextActionHeroData(
          type: HeroPriorityType.overdueOrNextItem,
          title: chosen.title,
          subtitle: subtitleText,
          primaryCtaLabel: isNow
              ? 'تکمیل / ثبت'
              : (chosen.domain == AgendaDomain.routine
                    ? 'ثبت / شروع'
                    : 'مشاهده'),
          onPrimaryTap: () => _openAgendaItem(chosen),
          isCurrentActive: isNow,
          isOverdue: decision.isOverdue,
          domain: chosen.domain,
          category: chosen.category,
          previousTaskTitle: decision.previousItem?.title,
          isPreviousTaskCompleted: decision.previousItem?.isCompleted,
          nextTaskTitle: decision.nextItem?.title,
          nextTaskTime: decision.nextItem?.timeOfDay != null
              ? PersianDigits.convert(decision.nextItem!.timeOfDay!)
              : null,
        );

      // fallback روتینی (پنجرهٔ قبل از لود P1)
      case HomeFocusLevel.agendaFallback:
        final now = DateTime.now();
        final nowMinutes = now.hour * 60 + now.minute;
        final pendingTasks = _timelineItems
            .where((i) => i['isCompleted'] != true)
            .toList();
        Map<String, dynamic> chosen = pendingTasks.first;
        var foundUpcoming = false;
        for (final item in pendingTasks) {
          final t = item['time']?.toString() ?? '';
          final parts = t.split(':');
          if (parts.length == 2) {
            final m =
                (int.tryParse(parts[0]) ?? 0) * 60 +
                (int.tryParse(parts[1]) ?? 0);
            if (m >= nowMinutes) {
              chosen = item;
              foundUpcoming = true;
              break;
            }
          }
        }
        final title = chosen['title']?.toString() ?? 'برنامهٔ بعدی';
        final timeStr = chosen['time']?.toString() ?? '--:--';
        final routine = chosen['routine'] as Routine?;
        return NextActionHeroData(
          type: HeroPriorityType.overdueOrNextItem,
          title: title,
          subtitle: foundUpcoming
              ? 'زمان: ${PersianDigits.convert(timeStr)}'
              : 'عقب‌افتاده · ${PersianDigits.convert(timeStr)}',
          primaryCtaLabel: 'ثبت / شروع',
          onPrimaryTap: () {
            if (routine != null) _showNiyyahSheet(routine);
          },
          isOverdue: !foundUpcoming,
          category: routine?.category,
          domain: AgendaDomain.routine,
        );

      // چکاین صبحگاهی
      case HomeFocusLevel.morningCheckIn:
        return NextActionHeroData(
          type: HeroPriorityType.morningCheckIn,
          title: 'ارزیابی انرژی اول روز',
          subtitle: 'تنظیم ریتم فعالیت با چند پرسش کوتاه',
          primaryCtaLabel: 'شروع ارزیابی',
          onPrimaryTap: _showMorningCheckinSheet,
        );

      // حالت خالی صادقانه
      case HomeFocusLevel.emptyState:
        return NextActionHeroData(
          type: HeroPriorityType.emptyState,
          title: 'برنامهای برای این زمان ثبت نشده است',
          subtitle: 'با افزودن کار جدید، ریتم امروزتان را شکل دهید',
          primaryCtaLabel: 'افزودن برنامه',
          onPrimaryTap: () {
            UniversalPlannerSheet.show(context: context);
          },
        );
    }
  }

  /// G-2: بازکردن آیتم Agenda بر اساس دامنهٔ آن (deep-link به ماژول مالک).
  void _openAgendaItem(AgendaItem item) {
    switch (item.domain) {
      case AgendaDomain.routine:
        final raw = item.meta['routine'];
        if (raw is Map) {
          final routine = Routine.fromMap(Map<String, dynamic>.from(raw));
          _showNiyyahSheet(routine);
          return;
        }
        widget.onNavigateToTab?.call(4);
      case AgendaDomain.prayer:
      case AgendaDomain.mustahab:
      case AgendaDomain.worshipDebt:
        _openModuleScreen('worship');
      case AgendaDomain.medicine:
        _openModuleScreen('medicine');
      case AgendaDomain.sport:
        _openModuleScreen('sports');
      case AgendaDomain.course:
        _openModuleScreen('courses');
      case AgendaDomain.goalStep:
        _openModuleScreen('goals');
      case AgendaDomain.konkur:
        _openModuleScreen('konkur');
      case AgendaDomain.cycle:
        _openModuleScreen('cycle');
      case AgendaDomain.event:
      case AgendaDomain.task:
      case AgendaDomain.commitment:
      case AgendaDomain.appointment:
        widget.onNavigateToTab?.call(4);
    }
  }

  void _showMoreSheet() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => SettingsScreen(
          onFactoryReset: widget.onLogout,
          themeRepository: widget.themeRepository,
          localeRepository: widget.localeRepository,
        ),
      ),
    ).then((_) {
      if (mounted) _loadDashboardData();
    });
  }

  Future<void> _snoozeTask(Routine routine) async {
    RoutineSnoozeBottomSheet.show(
      context: context,
      routine: routine,
      onSnoozeSelected: (minutes) {
        _snoozeRoutineWithMinutes(routine, minutes);
      },
    );
  }

  Future<void> _snoozeRoutineWithMinutes(Routine routine, int snoozeMin) async {
    final todayStr = RitmoDate.now().value;
    final decision = SnoozePolicy.evaluate(
      itemId: routine.id,
      now: DateTime.now(),
      requestedMinutes: snoozeMin,
      currentDeferCount: 0,
      category: routine.category.name,
      isEssential: routine.isEssential ? 1 : 0,
    );

    final isBlocked =
        decision.verdict == SnoozeVerdict.exhausted ||
        decision.verdict == SnoozeVerdict.blockedMidnight;

    if (isBlocked) {
      if (mounted) {
        RitmoToast.show(
          context,
          decision.userMessage ?? 'امکان تعویق وجود ندارد.',
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
        );
      }
      return;
    }

    await RoutineActions.snoozeRoutine(
      context: context,
      routineId: routine.id,
      dateStr: todayStr,
      minutes: decision.allowedMinutes,
      onDone: () {
        if (mounted) _loadDashboardData();
      },
    );
  }

  void _showMorningCheckinSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MorningCheckinSheet(
        onSaved: () {
          final now = DateTime.now();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          CentralInboxService.markActionedForEntity(
            'system',
            'checkin_$dateStr',
          );
          _loadDashboardData();
        },
      ),
    );
  }

  void _showNiyyahSheet(Routine routine, {String initialMode = 'FULL'}) {
    RoutineNiyyahSheet.show(
      context: context,
      routine: routine,
      initialMode: initialMode,
      onStartTimer: (selectedMode) async {
        _startTimerFlow(routine, selectedMode);
      },
      onCompleteInstantly: (selectedMode, duration) async {
        await _completeTask(routine, selectedMode, duration);
      },
      onSnooze: () async {
        await _snoozeTask(routine);
      },
      onEdit: () async {
        final rMap = {
          'id': routine.id,
          'title': routine.title,
          'description': routine.description,
          'category': routine.category.name,
          'routineType': routine.routineType.name,
          'notificationLevel': routine.notificationLevel.name,
          'isEssential': routine.isEssential ? 1 : 0,
          'energyRule': routine.energyRule.name,
          'priority': routine.priority,
          'targetDurationMinutes': routine.targetDurationMinutes,
          'lightDurationMinutes': routine.lightDurationMinutes,
          'minimalDurationMinutes': routine.minimalDurationMinutes,
        };

        await Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            barrierDismissible: true,
            pageBuilder: (context, _, _) => UniversalPlannerSheet(
              routineToEdit: rMap,
              onSaved: _loadDashboardData,
            ),
          ),
        );
      },
      onViewDetails: () async {
        _showDetailsSheet(routine);
      },
    );
  }

  void _showDetailsSheet(Routine routine) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    RoutineDetailsSheet.show(
      context: context,
      routine: routine,
      targetDate: todayStr,
      onReverted: _loadDashboardData,
    );
  }

  void _startTimerFlow(Routine routine, String mode) {
    // T4: compute today's date explicitly and pass as dateStr
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActiveTimerOverlay(
          routine: routine,
          completionMode: mode,
          dateStr:
              todayStr, // T4: explicit, not hidden DateTime.now() inside overlay
          onCompleted: (outcome) {
            // T6: only on confirmed completion
            Navigator.pop(context);
            _loadDashboardData();
            if (outcome.didWrite) {
              RitmoToast.show(context, 'روتین با تایمر ثبت شد ✓');
            } else {
              RitmoToast.show(context, outcome.errorMessage ?? 'ثبت انجام نشد');
            }
          },
          onCancelled: () {
            // T6: neutral — no success message
            Navigator.pop(context);
            // No feedback — user chose not to complete
          },
        ),
      ),
    );
  }

  void _showWhySuggestionDialog(String titleText) {
    final l10n = AppLocalizations.of(context)!;
    var explanationText =
        'سیستم بر اساس موتور تحلیل بافت (Context Engine)، شرایط زمانی و انرژی فعلی شما را سنجیده است.';

    if (_engineOutput?.contextExplanation != null) {
      final exp = _engineOutput!.contextExplanation;
      final title = exp.params['title'] as String? ?? titleText;
      switch (exp.type) {
        case ContextExplanationType.rest:
          explanationText = l10n.contextExplanationRest;
        case ContextExplanationType.essential:
          explanationText = l10n.contextExplanationEssential(title);
        case ContextExplanationType.sick:
          explanationText = l10n.contextExplanationSick(title);
        case ContextExplanationType.exam:
          explanationText = l10n.contextExplanationExam(title);
        case ContextExplanationType.busy:
          explanationText = l10n.contextExplanationBusy(title);
        case ContextExplanationType.worship:
          explanationText = l10n.contextExplanationWorship(
            exp.params['season'] as String? ?? '',
            title,
          );
        case ContextExplanationType.zone:
          explanationText = l10n.contextExplanationZone(title);
        case ContextExplanationType.lowEnergy:
          explanationText = l10n.contextExplanationLowEnergy(title);
        case ContextExplanationType.dynamic:
          explanationText = l10n.contextExplanationDynamic(title);
        case ContextExplanationType.reflectionAware:
          explanationText =
              'با توجه به خودارزیابی اخیر و حال‌وهوای این روزهایت، نسخه‌ی سبک‌تر «$title» را پیشنهاد دادم تا با ملایمت پیش بروی. کارهای ضروری همچنان سرجای خود هستند. 🌿';
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.card,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(CupertinoIcons.sparkles, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'تحلیل هوشمند ریتمو',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              explanationText,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: colors.textPrimary.withValues(alpha: 0.9),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'فهمیدم',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEnergyManagementSheet(bool isDarkMode) async {
    await RitmoSheetScaffold.present(
      context: context,
      title: 'ثبت حال روحی و انرژی',
      builder: (_) => QuickLogSheet(
        onSaved: () {
          _loadDashboardData();
        },
      ),
    );
  }

  /// بازچینی هوشمند باقیماندهٔ روز — از میانبر و از کارت پیشنهاد.
  Future<void> _runReplanFlow() async {
    final draft = await MidDayReplanService.instance.computeReplan();
    if (!mounted) return;
    if (draft != null) {
      AiDayPlannerPreviewSheet.show(
        context,
        initialDraft: draft,
        onSaved: _loadDashboardData,
      );
    } else {
      RitmoToast.show(context, 'کار عقب‌افتاده‌ای یافت نشد ⚡');
    }
  }

  void _openReflectionSheet() {
    DailyReflectionSheet.show(
      context: context,
      onSaved: () {
        final now = DateTime.now();
        final dateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        CentralInboxService.markActionedForEntity(
          'system',
          'reflection_$dateStr',
        );
        _loadDashboardData();
      },
    );
  }

  /// G-4: هش پایدار FNV-1a — برخلاف hashCode دارت، بین اجراهای اپ ثابت میماند
  /// و باعث نمیشود هشدار یکسان بعد از ریاستارت دوباره push شود.
  static int _stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  Future<void> _pushCriticalAlerts() async {
    final alerts = _engineOutput?.criticalAlerts ?? [];
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    for (final alert in alerts) {
      final dedupeKey = 'alert_${dateStr}_${_stableHash(alert)}';
      await CentralInboxService.push(
        category: InboxCategory.INSIGHT,
        sourceSystem: 'intelligence_engine',
        entityId: dedupeKey,
        eventType: 'critical_alert',
        title: 'هشدار سیستم',
        body: alert,
        priority: 2,
        linkModule: 'insights',
        linkAction: 'view_alerts',
      );
    }
  }

  Future<void> _pushCheckinsAndReflections() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (_needCheckin) {
      final dedupeKey = 'checkin_$dateStr';
      await CentralInboxService.push(
        category: InboxCategory.REMINDER,
        sourceSystem: 'system',
        entityId: dedupeKey,
        eventType: 'morning_checkin',
        title: 'ارزیابی صبحگاهی 🌅',
        body:
            'روز خود را با ثبت ارزیابی صبحگاهی آغاز کنید تا وضعیت انرژی شما محاسبه شود.',
        priority: 1,
        linkModule: 'home',
        linkAction: 'open_checkin',
        dateBucket: dateStr,
      );
    }

    final reflectionAvailable =
        now.hour >= 22 && !_hasReflection && !_reflectionDismissed;
    if (reflectionAvailable) {
      final dedupeKey = 'reflection_$dateStr';
      await CentralInboxService.push(
        category: InboxCategory.REMINDER,
        sourceSystem: 'system',
        entityId: dedupeKey,
        eventType: 'daily_reflection',
        title: 'بازتاب روزانه 🌌',
        body: 'زمان مناسبی برای ثبت بازخورد روز و تحلیل فعالیت‌هاست.',
        priority: 1,
        linkModule: 'home',
        linkAction: 'open_reflection',
        dateBucket: dateStr,
      );
    }
  }
}


