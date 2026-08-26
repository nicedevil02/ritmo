import 'dart:async';

import 'package:flutter/cupertino.dart'; // برای CupertinoIcons
import 'package:flutter/material.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/ai/ai_briefing_service.dart';
import 'package:ritmo/core/analytics/energy_model.dart';
import 'package:ritmo/core/analytics/reflection_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/di/service_locator.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_snapshot_builder.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/engines/context_engine.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_engine_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_intelligence_engine.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/daily_behavior.dart';
import 'package:ritmo/core/domain/models/reflection_context.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session.dart';
import 'package:ritmo/core/domain/realm/sessions/zone_session_writer.dart';
import 'package:ritmo/core/platform/notification_platform.dart';
import 'package:ritmo/core/repositories/realm_repository.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:ritmo/core/modules/routine_visibility.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/utils/persian_digits.dart'; // toPersianDigits
import 'package:ritmo/core/utils/snapshot_helper.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/worship/logic/worship_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/konkur/logic/konkur_repository.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart'; // SleepLog, SleepQuality
import 'package:ritmo/features/today/presentation/widgets/dashboard/dashboard_module_summary.dart';
import 'package:sqflite/sqflite.dart';

class DashboardController {
  bool isLoading = true;
  // P2-4: مقدار اولیهٔ ۸۲ ساختگی بود؛ ۰ صادقانه است و با پرچم زیر از «بدون داده» تفکیک میشود.
  int rhythmScore = 0;
  bool rhythmScoreHasData = false;
  List<Map<String, dynamic>> completionsToday = [];
  RoutineTask? nextTask;
  AiBriefing? briefing;
  bool isBriefingLoading = false;

  // Timeline list representation
  //
  // P3-1: در P0 فقط از روتینهای دارای occurrence پر میشود (رنگآمیزی سریع اولین فریم)
  // و در P1 از روی همان Agenda بازسازی میشود تا تمرین ورزشی، کار ساده و دوز دارو
  // هم دیده شوند. قبلاً هر چیزی که مالکش ماژول دیگری بود اینجا گم میشد.
  List<Map<String, dynamic>> timelineItems = [];

  // 🔑 Single source of truth for "today" — fed by DayAgendaService.
  List<AgendaItem> agenda = [];

  // P1-1: اسنپشات «مسیر امروز» — از همان Agenda ساخته میشود (اکنون/بعدی/پیشنهاد).
  DayAgendaSnapshot? todaySnapshot;

  // P3-1: تعداد تداخلهای واقعی امروز؛ دکمهٔ «رفع تداخل» فقط با مقدار > 0 معنا دارد.
  int todayConflictCount = 0;

  // Typed adapter views over [agenda] so existing Home widgets keep working.
  List<Map<String, dynamic>> todaysGoalSteps = [];
  List<CourseSession> todaysCourseSessions = [];
  List<Course> allCourses = [];
  CycleEngineOutput? cycleEngineOutput;
  List<KonkurPlanItem> todaysKonkurPlanItems = [];
  List<KonkurSubject> konkurSubjects = [];
  List<KonkurTopic> konkurTopics = [];
  List<DashboardModuleSummary> moduleSummaries = [];

  // Specialized Dashboard state variables
  Map<String, String> settingsMap = {};
  List<Map<String, dynamic>> worshipDebts = [];
  Map<String, String> prayerTimes = {};
  List<Map<String, dynamic>> medicationRoutines = [];
  Map<String, int> medicationCompletionsToday = {};

  // P3-1: برای ساخت کارتهای «کارهای امروز» و برچسبگذاری دستهٔ تکمیلها.
  final Map<String, Routine> _routinesById = {};
  final Map<String, String> _categoryByRoutineId = {};

  int get pendingMedicationDoseCount {
    final totalDoses = medicationRoutines.fold<int>(
      0,
      (a, r) =>
          a +
          (((r['maxDosesPerDay'] as int?) ?? 1) <= 0
              ? 1
              : ((r['maxDosesPerDay'] as int?) ?? 1)),
    );
    final taken = medicationCompletionsToday.values.fold<int>(
      0,
      (a, c) => a + c,
    );
    final remaining = (totalDoses - taken) < 0 ? 0 : (totalDoses - taken);
    return remaining;
  }

  DailyBehavior? dailyBehavior;
  Map<String, dynamic>? activeZone;
  String? activeZoneName;
  String? activeZoneIcon;
  String? activeZoneTimeRange;
  String? activeZoneColorHex;
  int activeZoneRoutinesCount = 0;
  RitmoEngineOutput? engineOutput;
  bool needCheckin = true;
  bool hasReflection = false;
  bool reflectionDismissed = false;

  // Dynamic Energy State fields
  // G-3: null یعنی «هنوز دادهای برای تخمین نداریم» — عدد ساختگی نمایش داده نمیشود.
  double? currentEnergyPercent;
  String currentEnergyLabel = 'نامشخص';
  String currentEnergyDesc = 'برای شروع، یک بار سطح انرژی امروزت را ثبت کن';
  String currentEnergyTimeAgo = 'هنوز دادهای برای تخمین نداریم';
  List<String> currentEnergyExplanation = [];
  // P3-2: صادقانه بگوییم عدد از کجا آمده و چقدر پشتوانه دارد.
  bool currentEnergyIsEstimated = true;
  double currentEnergyConfidence = 0;
  String currentEnergyRecommendation = '';
  String? peakPerformanceWindow;
  String? mostFatiguedWindow;
  String? mostProductiveWeekday;

  // ─────────────────────────────────────────────────────────
  // POP v1.1 — Two-phase loading
  //
  //  loadP0()  ← critical path — everything needed for first paint
  //             (settings, routines, zone, RIE, timeline, score)
  //  loadP1()  ← deferred path — everything below the fold
  //             (agenda sections, energy, dailyBehavior, widgets, native)
  //
  //  loadDashboardData() calls both in sequence (backward-compatible).
  // ─────────────────────────────────────────────────────────

  Future<void> loadDashboardData() async {
    await loadP0();
    await loadP1();
  }

  /// Phase 0 — blocks until the timeline and rhythm score are ready.
  // G-1: سینک اسنپشات فقط یکبار در هر نشست اپ اجرا میشود؛ اجرای آن در هر
  // resume/refresh باعث اسکن کامل جدولها و کندشدن بازگشت به اپ میشد.
  static bool _snapshotSyncDoneThisSession = false;

  Future<void> loadP0() async {
    try {
      isLoading = true;

      // Sync snapshots and run backfill engine — once per app session only.
      if (!_snapshotSyncDoneThisSession) {
        _snapshotSyncDoneThisSession = true;
        try {
          await SnapshotSyncService.syncAll();
        } catch (e) {
          // اجازه بده نشست بعدی دوباره تلاش کند.
          _snapshotSyncDoneThisSession = false;
          debugPrint('SnapshotSyncService.syncAll failed: $e');
        }
      }

      final db = await DatabaseHelper.instance.database;

      // Ensure dummy routine exists for worship debts
      await _ensureWorshipDebtRoutineExists(db);

      final settings = await db.query('app_settings');
      settingsMap = <String, String>{
        for (final s in settings) s['key']! as String: s['value']! as String,
      };

      // Load today's check-in status
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final checkins = await db.query(
        'daily_checkins',
        where: 'date = ?',
        whereArgs: [todayStr],
      );
      needCheckin = checkins.isEmpty;

      // Load today's reflection status
      final reflections = await db.query(
        'daily_reflections',
        where: 'date = ?',
        whereArgs: [todayStr],
      );
      hasReflection = reflections.isNotEmpty;

      // Check if reflection suggestion was dismissed today
      final dismissedReflectionDate =
          settingsMap['dismissed_reflection_date'] ?? '';
      reflectionDismissed = dismissedReflectionDate == todayStr;

      // 2. Load today's routine completions
      final completionsTodayRaw = await db.query(
        'routine_completions',
        where: 'completionDate = ?',
        whereArgs: [todayStr],
      );
      completionsToday = completionsTodayRaw
          .map(Map<String, dynamic>.from)
          .toList();

      final completedIds = completionsToday
          .where(
            (c) =>
                c['resultType'] != 'SNOOZED' &&
                c['resultType'] != 'CANNOT_NOW' &&
                c['resultType'] != 'SKIPPED',
          )
          .map((c) => c['routineId'] as String)
          .toSet();

      // Load today's routine occurrences
      final occurrencesToday = await db.query(
        'routine_occurrences',
        where: 'date = ?',
        whereArgs: [todayStr],
      );
      final occurrenceMap = {
        for (final o in occurrencesToday) o['routine_id']! as String: o,
      };

      // 3. Load all active routines and schedules
      final routinesMapListRaw = await db.query(
        'routines',
        where: 'isArchived = 0',
      );
      final routinesMapList = routinesMapListRaw
          .map(Map<String, dynamic>.from)
          .toList();
      final activeTasks = <RoutineTask>[];
      final medRoutines = <Map<String, dynamic>>[];
      final routineList = <Routine>[];
      _routinesById.clear();
      _categoryByRoutineId.clear();

      for (final rMap in routinesMapList) {
        final rId = rMap['id'] as String;
        final categoryStr = rMap['category'] as String;
        final category = Category.values.firstWhere(
          (e) => e.name.toLowerCase() == categoryStr.toLowerCase(),
          orElse: () => Category.custom,
        );
        _categoryByRoutineId[rId] = category.name;

        // Separate medical routines
        if (category == Category.medical) {
          medRoutines.add(rMap);
        }

        final moduleEnabled = RoutineVisibility.isVisible(
          routineId: rId,
          category: categoryStr,
          settings: settingsMap,
        );

        final routine = Routine(
          id: rId,
          title: rMap['title'] as String,
          description: rMap['description'] as String?,
          category: category,
          customCategoryId: rMap['customCategoryId'] as String?,
          zoneId: rMap['zoneId'] as String?,
          routineType: RoutineType.values.firstWhere(
            (e) =>
                e.name.toLowerCase() ==
                (rMap['routineType'] as String? ?? '').toLowerCase(),
            orElse: () => RoutineType.timeBased,
          ),
          notificationLevel: NotificationLevel.values.firstWhere(
            (e) =>
                e.name.toLowerCase() ==
                (rMap['notificationLevel'] as String? ?? '').toLowerCase(),
            orElse: () => NotificationLevel.none,
          ),
          isEssential: rMap['isEssential'] == 1,
          isEssentialLocked: (rMap['isEssentialLocked'] as int? ?? 0) == 1,
          energyRule: EnergyRule.values.firstWhere(
            (e) =>
                e.name.toLowerCase() ==
                (rMap['energyRule'] as String? ?? '').toLowerCase(),
            orElse: () => EnergyRule.none,
          ),

          priority: rMap['priority'] as double? ?? 1.0,
          targetDurationMinutes: rMap['targetDurationMinutes'] as int?,
          lightDurationMinutes: rMap['lightDurationMinutes'] as int?,
          minimalDurationMinutes: rMap['minimalDurationMinutes'] as int?,
          medStockCount: rMap['medStockCount'] as int? ?? 0,
          medRefillThreshold: rMap['medRefillThreshold'] as int? ?? 0,
          minIntervalHours: rMap['minIntervalHours'] as int? ?? 0,
          maxDosesPerDay: rMap['maxDosesPerDay'] as int? ?? 0,
          progressionMode: rMap['progressionMode'] as String? ?? 'NONE',
          progressionStart: rMap['progressionStart'] as int? ?? 0,
          progressionTarget: rMap['progressionTarget'] as int? ?? 0,
          progressionStep: rMap['progressionStep'] as int? ?? 0,
          progressionEveryN: rMap['progressionEveryN'] as int? ?? 1,
          progressionCurrent: rMap['progressionCurrent'] as int? ?? 0,
          progressionDoneSinceAdvance:
              rMap['progressionDoneSinceAdvance'] as int? ?? 0,
          itemType: rMap['itemType'] as String? ?? 'ROUTINE',
        );

        if (moduleEnabled) {
          routineList.add(routine);
          _routinesById[rId] = routine;
          final hasOccurrence = occurrenceMap.containsKey(rId);
          if (hasOccurrence) {
            final occ = occurrenceMap[rId]!;
            final timeOfDayStr = occ['scheduled_time'] as String? ?? '08:00';
            final parts = timeOfDayStr.split(':');
            final schedTime = DateTime.now().copyWith(
              hour: int.tryParse(parts[0]) ?? 8,
              minute: int.tryParse(parts[1]) ?? 0,
              second: 0,
              millisecond: 0,
              microsecond: 0,
            );

            activeTasks.add(
              RoutineTask(
                routine: routine,
                scheduleTimeStr: timeOfDayStr,
                scheduledTime: schedTime,
              ),
            );
          }
        }
      }

      medicationRoutines = medRoutines;

      // Load medication completions today
      final medCompletions = <String, int>{};
      for (final rMap in medicationRoutines) {
        final rId = rMap['id'] as String;
        final count = completionsToday
            .where((c) => c['routineId'] == rId)
            .length;
        medCompletions[rId] = count;
      }
      medicationCompletionsToday = medCompletions;

      // Calculate active zone name and parameters
      final actZone = await _resolveActiveZone(db, DateTime.now());
      activeZone = actZone;
      final activeZoneId = activeZone?['id'] as String?;
      final activeZoneMode = activeZone?['mode'] as String? ?? 'NORMAL';
      final actZoneName = activeZone?['name'] as String? ?? 'خارج از قلمرو';
      activeZoneName = actZoneName;
      activeZoneIcon = activeZone?['icon'] as String?;
      activeZoneColorHex = activeZone?['color'] as String?;
      final activeStart = activeZone?['startTime'] as String?;
      final activeEnd = activeZone?['endTime'] as String?;

      final isOverride = activeZone?['isOverride'] == true;
      if (isOverride) {
        final overrideUntilMs = activeZone?['overrideUntilMs'] as int? ?? 0;
        final remainingMs =
            overrideUntilMs - DateTime.now().millisecondsSinceEpoch;
        final remainingMin = (remainingMs / 60000).ceil();
        activeZoneTimeRange = 'فعال‌سازی دستی ($remainingMin دقیقه)';
      } else if (activeStart != null && activeEnd != null) {
        activeZoneTimeRange = '$activeStart - $activeEnd';
      } else {
        activeZoneTimeRange = null;
      }

      activeZoneRoutinesCount = 0;
      if (activeZoneId != null) {
        activeZoneRoutinesCount = routineList
            .where((r) => r.zoneId == activeZoneId)
            .length;
      }

      // Load current energy (default value — full analytics run in loadP1)
      final energyStr = settingsMap['default_energy_level'] ?? 'MEDIUM';
      final currentEnergy = EnergyLevel.values.firstWhere(
        (e) => e.name.toLowerCase() == energyStr.toLowerCase(),
        orElse: () => EnergyLevel.medium,
      );

      final isMenstruating = await DatabaseHelper.instance.isUserMenstruating();

      // Run RIE Pipeline
      final nowTime = DateTime.now();

      // Self-reflection signal → feeds the intelligence engine's gentle mode.
      final reflectionContext = await _buildReflectionContext(db, nowTime);

      engineOutput = await RitmoIntelligenceEngine.evaluate(
        routines: routineList,
        appSettings: settingsMap,
        activeZoneId: activeZoneId,
        activeZoneMode: activeZoneMode,
        currentEnergy: currentEnergy,
        isMenstruating: isMenstruating,
        now: nowTime,
        db: db,
        reflectionContext: reflectionContext,
      );

      // Map suggested routine to nextTask so existing UI is compatible
      final visibleIds =
          engineOutput?.visibleRoutines.map((r) => r.id).toSet() ?? {};
      if (engineOutput?.suggestedRoutine != null) {
        final sugg = engineOutput!.suggestedRoutine!;
        nextTask = activeTasks.firstWhere(
          (t) => t.routine.id == sugg.id,
          orElse: () => RoutineTask(
            routine: sugg,
            scheduleTimeStr: '--:--',
            scheduledTime: DateTime.now(),
          ),
        );
      } else {
        nextTask = null;
      }

      // Calculate weighted rhythmScore
      var totalWeight = 0.0;
      var completedWeight = 0.0;
      final completionMap = {
        for (final c in completionsToday) c['routineId'] as String: c,
      };

      for (final task in activeTasks) {
        final rId = task.routine.id;
        final routineType = task.routine.routineType;
        final completion = completionMap[rId];
        final isAsNeeded = routineType == RoutineType.asNeeded;
        final isSystemResult =
            completion != null && completion['resultSource'] == 'SYSTEM';

        if (!isAsNeeded && !isSystemResult) {
          totalWeight += task.routine.priority;
          if (completion != null) {
            final resType = completion['resultType'] as String? ?? 'FULL';
            var completionValue = 0.0;
            if (resType == 'FULL') {
              completionValue = 1.0;
            } else if (resType == 'LIGHT') {
              completionValue = 0.7;
            } else if (resType == 'MINIMAL') {
              completionValue = 0.4;
            }
            completedWeight += completionValue * task.routine.priority;
          }
        }
      }

      // G-3 + P2-4: مقدار ساختگی ۸۲ حذف شد؛ پرچم hasData «بدون داده» را از «۰٪» تفکیک میکند.
      rhythmScore = 0;
      rhythmScoreHasData = totalWeight > 0;
      if (totalWeight > 0) {
        rhythmScore = ((completedWeight / totalWeight) * 100).round();
      }

      // 7. Build timeline items (only show visible routines)
      final items = activeTasks
          .where((t) => visibleIds.contains(t.routine.id))
          .map((t) {
            final isCompleted = completedIds.contains(t.routine.id);
            return <String, dynamic>{
              'type': 'task',
              'id': t.routine.id,
              'title': t.routine.title,
              'time': t.scheduleTimeStr ?? '--:--',
              'status': isCompleted ? '✓ انجام' : 'منتظر',
              'isCompleted': isCompleted,
              'category': t.routine.category.name,
              'routine': t.routine,
              'domainLabel': 'روتین',
              'hasConflict': false,
            };
          })
          .toList();

      items.sort(
        (a, b) => (a['time'] as String).compareTo(b['time'] as String),
      );
      timelineItems = items;
    } catch (e, stack) {
      debugPrint('Error in loadP0: $e\n$stack');
    } finally {
      isLoading = false;
    }
  }

  /// Phase 1 — deferred after first frame; loads below-fold data.
  Future<void> loadP1() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowTime = DateTime.now();
      final energyStr = settingsMap['default_energy_level'] ?? 'MEDIUM';
      final actZoneName = activeZoneName ?? 'خارج از قلمرو';

      // 4. Load Worship Debts if module enabled
      if (ModuleGate.instance.isEnabledFrom(
        settingsMap,
        'module_religion_enabled',
      )) {
        final worshipDebtsRaw = await db.query(
          'worship_debts',
          where: 'isArchived = 0',
        );
        worshipDebts = worshipDebtsRaw.map(Map<String, dynamic>.from).toList();

        // Load prayer times from central WorshipRepository
        prayerTimes = await WorshipRepository.instance.getPrayerTimesForDate(
          DateTime.now(),
          settingsMap: settingsMap,
        );
      } else {
        worshipDebts = [];
        prayerTimes = {};
      }

      // 🔑 Feed today's cross-section lists from the shared DayAgendaService.
      await _loadAgendaSections(nowTime, db);

      // Update current energy state dynamically from DB
      await updateCurrentEnergyState(db);

      // P3-2: سطح انرژی برای ویجت و نوتیفیکیشن از همان محاسبهٔ واقعی میآید،
      // نه از مقدار پیشفرض تنظیمات.
      final energyBandKey = currentEnergyPercent == null
          ? energyStr.toLowerCase()
          : EnergyModel.bandKey(currentEnergyPercent!);
      final energyBandLabel = currentEnergyPercent == null
          ? (energyStr == 'LOW'
                ? 'پایین'
                : (energyStr == 'HIGH' ? 'بالا' : 'متوسط'))
          : currentEnergyLabel;

      // DailyBehavior (uses RIE gentle mode signal)
      dailyBehavior = await RitmoIntelligenceEngine.resolveDailyBehavior(
        date: nowTime,
        db: db,
        settings: settingsMap,
      );

      // Build widget snapshot
      await SnapshotHelper.updateWidgetSnapshot(
        nextActionTitle: nextTask?.routine.title ?? 'استراحت 🌿',
        // P2-4: بدون داده ⇒ null ⇒ در JSON بهصورت -1 (سنتینل «بدون داده»)
        rhythmScore: rhythmScoreHasData ? rhythmScore : null,
        currentEnergyLevel: energyBandKey,
      );

      // Update foreground service Status Notification if enabled
      final persistentNotifEnabled =
          settingsMap['persistent_status_notification_enabled'] != 'false';
      if (persistentNotifEnabled) {
        await sl<NotificationPlatform>().startStatusMode(
          zone: actZoneName,
          energy: energyBandLabel,
          proposedTask: nextTask?.routine.title ?? 'استراحت 🌿',
          proposedTaskId: nextTask?.routine.id,
        );
      } else {
        await sl<NotificationPlatform>().stopForegroundService();
      }

      // Load AI Daily Briefing asynchronously to avoid blocking initial load & Hot Restart
      briefing = await AiBriefingService.instance.getCached();
      isBriefingLoading = false;

      // Refresh in background with a 6-second timeout
      unawaited(
        AiBriefingService.instance
            .getOrRefresh()
            .timeout(const Duration(seconds: 6), onTimeout: () => briefing)
            .then((newBriefing) {
              if (newBriefing != null) {
                briefing = newBriefing;
              }
            })
            .catchError((e) {
              debugPrint('[BRIEFING] background refresh note: $e');
              return null;
            }),
      );

      await _buildModuleSummaries(db);
    } catch (e, stack) {
      debugPrint('Error in loadP1: $e\n$stack');
    }
  }

  Future<void> _buildModuleSummaries(DatabaseExecutor db) async {
    final out = <DashboardModuleSummary>[];
    final s = settingsMap;
    String fa(Object v) => toPersianDigits(v.toString());

    // حال و تعادل — انرژی، خواب و بازتاب در یک نگاه
    if (ModuleGate.instance.isEnabledFrom(s, 'module_energy_enabled') ||
        ModuleGate.instance.isEnabledFrom(s, 'module_sleep_enabled')) {
      final rows = await db.query(
        'bedtime_diagnostics',
        orderBy: 'date DESC',
        limit: 1,
      );
      final SleepLog? lastSleep = rows.isNotEmpty
          ? SleepLog.fromMap(rows.first)
          : null;

      String primaryText;
      String secondaryText;

      if (currentEnergyPercent != null) {
        primaryText = '${fa(currentEnergyPercent!.round())}٪ انرژی';
        if (lastSleep != null) {
          final h = lastSleep.durationMinutes ~/ 60;
          final m = lastSleep.durationMinutes % 60;
          secondaryText =
              'خواب دیشب: ${fa(h)}:${fa(m.toString().padLeft(2, '0'))} · $currentEnergyLabel';
        } else {
          secondaryText = currentEnergyIsEstimated
              ? 'تخمینی · سطح: $currentEnergyLabel'
              : 'ثبت خودت · سطح: $currentEnergyLabel';
        }
      } else if (lastSleep != null) {
        final h = lastSleep.durationMinutes ~/ 60;
        final m = lastSleep.durationMinutes % 60;
        primaryText = '${fa(h)}:${fa(m.toString().padLeft(2, '0'))} ساعت خواب';
        secondaryText =
            'کیفیت دیشب: ${lastSleep.quality.emoji} ${lastSleep.quality.label}';
      } else {
        primaryText = '—';
        secondaryText = 'انرژی، خواب و بازتاب در یک نگاه';
      }

      out.add(
        DashboardModuleSummary(
          moduleId: 'wellbeing',
          title: 'حال و تعادل',
          icon: CupertinoIcons.waveform_path_ecg,
          accentColor: const Color(0xff8B5CF6),
          primary: primaryText,
          secondary: secondaryText,
          backgroundImage: 'assets/images/energy_card_top.png',
        ),
      );
    }

    // ورزش — جلسات و دقایق این هفته از workout_logs
    if (ModuleGate.instance.isEnabledFrom(s, 'module_sports_enabled') ||
        ModuleGate.instance.isEnabledFrom(
          s,
          'module_supplementary_sports_enabled',
        )) {
      final weekAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;
      final rows = await db.query(
        'workout_logs',
        where: 'loggedAt >= ?',
        whereArgs: [weekAgo],
      );
      final sessions = rows.length;
      final minutes = rows.fold<int>(
        0,
        (a, r) => a + ((r['durationMinutes'] as int?) ?? 0),
      );
      out.add(
        DashboardModuleSummary(
          moduleId: 'sports',
          title: 'ورزش',
          icon: Icons.fitness_center,
          accentColor: const Color(0xff10B981),
          primary: '${fa(sessions)} جلسه',
          secondary: 'این هفته: ${fa(minutes)} دقیقه',
          backgroundImage: 'assets/images/sports_card_top.png',
        ),
      );
    }

    // دارو — پایبندی امروز از medicationRoutines + medicationCompletionsToday
    if (ModuleGate.instance.isEnabledFrom(s, 'module_medicine_enabled')) {
      final totalDoses = medicationRoutines.fold<int>(
        0,
        (a, r) =>
            a +
            (((r['maxDosesPerDay'] as int?) ?? 1) <= 0
                ? 1
                : ((r['maxDosesPerDay'] as int?) ?? 1)),
      );
      final taken = medicationCompletionsToday.values.fold<int>(
        0,
        (a, c) => a + c,
      );
      final pct = totalDoses > 0
          ? ((taken / totalDoses) * 100).round().clamp(0, 100)
          : 0;
      final remaining = (totalDoses - taken) < 0 ? 0 : (totalDoses - taken);
      out.add(
        DashboardModuleSummary(
          moduleId: 'medicine',
          title: 'دارو',
          icon: CupertinoIcons.bandage_fill,
          accentColor: const Color(0xffEF4444),
          primary: '${fa(pct)}٪',
          secondary: 'پایبندی امروز · ${fa(remaining)} باقی‌مانده',
          backgroundImage: 'assets/images/medicine_card_top.png',
        ),
      );
    }

    // عبادت — تعداد قضاها از worshipDebts (نماز بعدی از prayerTimes اختیاری است)
    if (ModuleGate.instance.isEnabledFrom(s, 'module_religion_enabled')) {
      final debts = worshipDebts.length;

      // استخراج نماز بعدی از prayerTimes
      var secondaryText = 'برنامهٔ عبادی';
      try {
        final now = DateTime.now();
        final currentMinutes = now.hour * 60 + now.minute;

        final fajrMin = TimeOfDayMinutes.tryParse(prayerTimes['fajr']);
        final dhuhrMin = TimeOfDayMinutes.tryParse(prayerTimes['dhuhr']);
        final maghribMin = TimeOfDayMinutes.tryParse(prayerTimes['maghrib']);
        final ishaMin = TimeOfDayMinutes.tryParse(prayerTimes['isha']);

        String? nextName;
        String? nextTime;

        if (fajrMin != null && currentMinutes < fajrMin) {
          nextName = 'اذان صبح';
          nextTime = prayerTimes['fajr'];
        } else if (dhuhrMin != null && currentMinutes < dhuhrMin) {
          nextName = 'اذان ظهر';
          nextTime = prayerTimes['dhuhr'];
        } else if (maghribMin != null && currentMinutes < maghribMin) {
          nextName = 'اذان مغرب';
          nextTime = prayerTimes['maghrib'];
        } else if (ishaMin != null && currentMinutes < ishaMin) {
          nextName = 'نماز عشا';
          nextTime = prayerTimes['isha'];
        } else if (fajrMin != null) {
          nextName = 'اذان صبح فردا';
          nextTime = prayerTimes['fajr'];
        }

        if (nextName != null && nextTime != null) {
          secondaryText = '$nextName: ${toPersianDigits(nextTime)}';
        }
      } catch (e) {
        // fallback to default
      }

      out.add(
        DashboardModuleSummary(
          moduleId: 'worship',
          title: 'عبادت',
          icon: CupertinoIcons.circle_grid_hex,
          accentColor: const Color(0xffFBBF24),
          primary: debts > 0 ? '${fa(debts)} قضا' : 'به‌روز ✓',
          secondary: secondaryText,
          backgroundImage: 'assets/images/worship_card_top.png',
        ),
      );
    }

    // چرخه — فاز فعلی از cycleEngineOutput (فقط با رعایت حریم خصوصی و فعال بودن ماژول)
    final isCycleEnabled = ModuleGate.instance.isEnabledFrom(
      s,
      'module_cycle_enabled',
    );
    final isFemale = CyclePrivacyGuard.isVisible(s);
    final cycleConsent = s['cycle_consent_dashboard'] == 'true';
    if (cycleEngineOutput != null &&
        isCycleEnabled &&
        isFemale &&
        cycleConsent) {
      final p = cycleEngineOutput!.currentPhase;
      final label = p == CyclePhase.menstrual
          ? 'قاعدگی'
          : p == CyclePhase.follicular
          ? 'فولیکولار'
          : p == CyclePhase.ovulation
          ? 'تخمک‌گذاری'
          : 'لوتئال';
      out.add(
        DashboardModuleSummary(
          moduleId: 'cycle',
          title: 'چرخه بدن',
          icon: CupertinoIcons.heart_fill,
          accentColor: const Color(0xffEC4899),
          primary: label,
          secondary: 'فاز کنونی بدن',
          backgroundImage: 'assets/images/cycle_card_top.png',
        ),
      );
    }

    // اهداف — گام‌های امروز از todaysGoalSteps
    if (ModuleGate.instance.isEnabledFrom(s, 'module_goals_enabled')) {
      final total = todaysGoalSteps.length;
      final done = todaysGoalSteps
          .where(
            (g) =>
                g['isCompleted'] == 1 ||
                g['isCompleted'] == true ||
                g['completedAt'] != null,
          )
          .length;
      out.add(
        DashboardModuleSummary(
          moduleId: 'goals',
          title: 'اهداف',
          icon: CupertinoIcons.flag_fill,
          accentColor: const Color(0xffF59E0B),
          primary: total > 0 ? '${fa(done)}/${fa(total)}' : '—',
          secondary: 'گام‌های امروز',
          backgroundImage: 'assets/images/konkur_card_top.png',
        ),
      );
    }

    // دوره‌ها — جلسات مطالعهٔ امروز
    if (ModuleGate.instance.isEnabledFrom(s, 'module_courses_enabled')) {
      out.add(
        DashboardModuleSummary(
          moduleId: 'courses',
          title: 'دوره‌ها',
          icon: CupertinoIcons.book_fill,
          accentColor: const Color(0xff3B82F6),
          primary: '${fa(todaysCourseSessions.length)} جلسه',
          secondary: 'مطالعهٔ امروز',
          backgroundImage: 'assets/images/courses_card_top.png',
        ),
      );
    }

    // درس و مطالعه — مباحث امروز
    if (ModuleGate.instance.isEnabledFrom(s, 'module_study_enabled')) {
      out.add(
        DashboardModuleSummary(
          moduleId: 'konkur',
          title: 'درس و مطالعه',
          icon: CupertinoIcons.book_fill,
          accentColor: const Color(0xff8B5CF6),
          primary: '${fa(todaysKonkurPlanItems.length)} مبحث',
          secondary: 'برنامهٔ امروز',
          backgroundImage: 'assets/images/goals_card_top.png',
        ),
      );
    }

    moduleSummaries = out;
  }

  /// Runs the ReflectionEngine and maps it into a compact [ReflectionContext]

  /// for the intelligence engine. Returns null when there is no recent
  /// reflection signal, so the engine keeps its default (un-softened) behavior.
  Future<ReflectionContext?> _buildReflectionContext(
    Database db,
    DateTime now,
  ) async {
    try {
      final reflectionMaps = await db.query(
        'daily_reflections',
        orderBy: 'date DESC',
      );
      if (reflectionMaps.isEmpty) return null;
      final checkinMaps = await db.query(
        'daily_checkins',
        orderBy: 'date DESC',
      );
      final energyLogs = await db.query('energy_logs');
      final moodLogs = await db.query('mood_logs');

      final out = await RitmoEngineBus.instance
          .execute<ReflectionEngineInput, ReflectionEngineOutput>(
            ReflectionEngine,
            ReflectionEngineInput(
              dailyReflections: reflectionMaps,
              dailyCheckins: checkinMaps,
              energyLogs: energyLogs,
              moodLogs: moodLogs,
              today: now,
            ),
          );

      // No entries inside the horizon → no actionable signal.
      if (out.entryCount == 0) return null;

      var direction = MoodTrendDirection.flat;
      final trend = out.moodTrend;
      if (trend.length >= 2) {
        final delta = trend.last - trend.first;
        if (delta > 0.3) {
          direction = MoodTrendDirection.up;
        } else if (delta < -0.3) {
          direction = MoodTrendDirection.down;
        }
      }

      return ReflectionContext(
        avgMoodScore: out.avgMoodScore,
        moodTrendDirection: direction,
        currentStreak: out.currentStreak,
        reflectionEnergyCorrelation: out.reflectionEnergyCorrelation,
      );
    } catch (e) {
      debugPrint('Error building reflection context: $e');
      return null;
    }
  }

  /// Loads today's cross-section agenda once and derives the typed lists the
  /// Home widgets consume. Replaces the inline goal/course/konkur/cycle DB
  /// queries that used to live in `now_dashboard_screen._loadDashboardData`.
  Future<void> _loadAgendaSections(DateTime now, Database db) async {
    try {
      final dayAgenda = await DayAgendaService.instance.agendaForDate(
        now,
        options: const AgendaQueryOptions(),
      );
      agenda = dayAgenda.items;

      // P1-1: ساخت اسنپشات از همان Agenda — بدون هیچ کوئری اضافهٔ جدید.
      try {
        todaySnapshot = const DayAgendaSnapshotBuilder().buildSnapshot(
          dayAgenda,
          now: now,
        );
      } catch (e) {
        debugPrint('Error building today snapshot: $e');
        todaySnapshot = null;
      }

      // Goal steps: raw rows (with goalTitle) — Home shows all, completed too.
      todaysGoalSteps = agenda
          .where((i) => i.domain == AgendaDomain.goalStep)
          .map((i) => Map<String, dynamic>.from(i.meta['step'] as Map))
          .toList();

      // Course sessions: Home shows only the not-yet-completed ones.
      todaysCourseSessions = agenda
          .where((i) => i.domain == AgendaDomain.course && !i.isCompleted)
          .map(
            (i) => CourseSession.fromMap(
              Map<String, dynamic>.from(i.meta['session'] as Map),
            ),
          )
          .toList();
      if (todaysCourseSessions.isNotEmpty &&
          ModuleGate.instance.isEnabledFrom(
            settingsMap,
            'module_courses_enabled',
          )) {
        allCourses = await CoursesRepository.instance.getActiveCourses();
      } else {
        allCourses = [];
      }

      // Konkur plan items: Home shows only PENDING.
      todaysKonkurPlanItems = agenda
          .where(
            (i) =>
                i.domain == AgendaDomain.konkur &&
                i.completion == AgendaCompletion.pending,
          )
          .map(
            (i) => KonkurPlanItem.fromMap(
              Map<String, dynamic>.from(i.meta['planItem'] as Map),
            ),
          )
          .toList();
      if (todaysKonkurPlanItems.isNotEmpty) {
        final repo = KonkurRepository.instance;
        konkurSubjects = await repo.getSubjects();
        konkurTopics = await repo.getTopics();
      } else {
        konkurSubjects = [];
        konkurTopics = [];
      }

      // Cycle: the Home cycle widget needs the full engine output, which the
      // agenda only summarizes — compute it here under the same gates.
      final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
      final cycleEnabled = ModuleGate.instance.isEnabledFrom(
        settingsMap,
        'module_cycle_enabled',
      );
      final dashboardConsent = settingsMap['cycle_consent_dashboard'] == 'true';
      final setupDone = settingsMap['cycle_setup_done'] == 'true';
      if (isFemale && cycleEnabled && dashboardConsent && setupDone) {
        cycleEngineOutput = await RitmoEngineBus.instance
            .execute<CycleEngineInput, CycleEngineOutput>(
              CycleEngine,
              CycleEngineInput(db: db, appSettings: settingsMap, now: now),
            );
      } else {
        cycleEngineOutput = null;
      }

      // P3-1: «کارهای امروز» از همین Agenda ساخته میشود + تشخیص تداخل واقعی.
      var tempEvents = const <Map<String, Object?>>[];
      try {
        tempEvents = await db.query(
          'temporary_events',
          where: 'date = ?',
          whereArgs: [now.toIso8601String().substring(0, 10)],
        );
      } catch (e) {
        debugPrint('temporary_events query note: $e');
      }
      _buildTodayTaskCards(tempEvents);
    } catch (e, st) {
      debugPrint('Error loading agenda sections: $e\n$st');
    }
  }

  // دامنههایی که واقعاً «کارِ قابل انجام امروز» هستند. دوره، کنکور و گامهای هدف
  // کارت اختصاصی خودشان را دارند و عبادت هم بخش جداگانه دارد، پس تکرارشان نمیکنیم.
  static const Set<AgendaDomain> _taskListDomains = <AgendaDomain>{
    AgendaDomain.routine,
    AgendaDomain.sport,
    AgendaDomain.task,
    AgendaDomain.medicine,
    AgendaDomain.event,
  };

  static String _domainLabel(AgendaDomain domain) {
    switch (domain) {
      case AgendaDomain.sport:
        return 'ورزش';
      case AgendaDomain.medicine:
        return 'دارو';
      case AgendaDomain.task:
        return 'کارها';
      case AgendaDomain.event:
        return 'رویداد';
      case AgendaDomain.routine:
        return 'روتین';
      default:
        return 'برنامه';
    }
  }

  static int? _minutesOfTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// تداخلهای واقعی امروز: همپوشانی دو آیتم زماندار، یا همپوشانی یک آیتم با
  /// رویداد موقتِ ثبتشده. خروجی: شناسهٔ آیتم → عنوان چیزی که با آن تداخل دارد.
  Map<String, String> _detectConflicts(
    List<AgendaItem> items,
    List<Map<String, Object?>> tempEvents,
  ) {
    final out = <String, String>{};
    final timed = items
        .where((i) => i.hasValidTimeOfDay && !i.isCompleted)
        .toList(growable: false);

    for (var a = 0; a < timed.length; a++) {
      final aStart = _minutesOfTime(timed[a].timeOfDay);
      if (aStart == null) continue;
      final aEnd = aStart + (timed[a].durationMinutes ?? 30);

      for (var b = a + 1; b < timed.length; b++) {
        final bStart = _minutesOfTime(timed[b].timeOfDay);
        if (bStart == null) continue;
        final bEnd = bStart + (timed[b].durationMinutes ?? 30);
        if (bStart < aEnd && aStart < bEnd) {
          out.putIfAbsent(timed[a].id, () => timed[b].title);
          out.putIfAbsent(timed[b].id, () => timed[a].title);
        }
      }

      for (final event in tempEvents) {
        final eStart = _minutesOfTime(event['startTime'] as String?);
        if (eStart == null) continue;
        final eEnd = eStart + ((event['durationMinutes'] as int?) ?? 60);
        if (eStart < aEnd && aStart < eEnd) {
          out[timed[a].id] = (event['title'] as String?) ?? 'رویداد موقت';
        }
      }
    }

    return out;
  }

  /// بازسازی «کارهای امروز» از Agenda. ساختار Map عمداً مثل قبل است تا صفحه و
  /// ویجت بدون تغییر کار کنند؛ فقط کلیدهای تازه (agendaItem/domainLabel/…) اضافه شده.
  void _buildTodayTaskCards(List<Map<String, Object?>> tempEvents) {
    final actionable = agenda
        .where((i) => _taskListDomains.contains(i.domain))
        .toList(growable: false);

    final conflicts = _detectConflicts(actionable, tempEvents);
    todayConflictCount = conflicts.length;

    if (actionable.isEmpty) {
      // Agenda چیزی ندارد؛ لیست P0 (روتینهای occurrence دار) را نگه میداریم.
      return;
    }

    final completedRoutineIds = completionsToday
        .where(
          (c) =>
              c['resultType'] != 'SNOOZED' &&
              c['resultType'] != 'CANNOT_NOW' &&
              c['resultType'] != 'SKIPPED',
        )
        .map((c) => c['routineId'] as String)
        .toSet();

    final cards = <Map<String, dynamic>>[];
    for (final item in actionable) {
      final routine = item.domain == AgendaDomain.routine
          ? _routinesById[item.sourceId]
          : null;
      final isCompleted =
          item.isCompleted ||
          (routine != null && completedRoutineIds.contains(routine.id));

      cards.add(<String, dynamic>{
        'type': 'task',
        'id': item.id,
        'title': item.title,
        'subtitle': item.subtitle,
        'time': item.hasValidTimeOfDay ? item.timeOfDay : '--:--',
        'durationMinutes': item.durationMinutes,
        'status': isCompleted ? '✓ انجام' : 'منتظر',
        'isCompleted': isCompleted,
        'category': item.category.name,
        'domain': item.domain.name,
        'domainLabel': _domainLabel(item.domain),
        'routine': routine,
        'agendaItem': item,
        'hasConflict': conflicts.containsKey(item.id),
        'conflictWith': conflicts[item.id],
      });
    }

    // Agenda از قبل مرتب است (زماندارها به ترتیب ساعت، بعد بدونزمانها).
    timelineItems = cards;
  }

  /// محاسبهٔ سطح انرژی فعلی.
  ///
  /// P3-2: مسیر قبلی کل تاریخچهٔ energy_logs / routine_completions / daily_rhythm
  /// را در هر بار لود میخواند و بعد آن را به مسیر سادهٔ موتور آنالیتیکس میداد؛
  /// مسیری که خواب را نادیده میگرفت، «تعویق» را مثل «انجامشده» مثبت حساب میکرد و
  /// وقتی هیچ لاگی نبود هم ادعا میکرد «آخرین ثبت شما…». حالا پنجرهٔ ۳۰ روزه
  /// میخوانیم و محاسبه در [EnergyModel] انجام میشود.
  Future<void> updateCurrentEnergyState(DatabaseExecutor db) async {
    try {
      final now = DateTime.now();
      final validityMinutes =
          int.tryParse(settingsMap['energy_validity_minutes'] ?? '180') ?? 180;
      final defaultLevel = settingsMap['default_energy_level'] ?? 'MEDIUM';

      final windowStartMs = now
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;

      final energyLogsRaw = await db.query(
        'energy_logs',
        where: 'loggedAt >= ?',
        whereArgs: [windowStartMs],
        orderBy: 'loggedAt DESC',
      );
      final energyLogs = energyLogsRaw.map(Map<String, dynamic>.from).toList();

      final completionsRaw = await db.query(
        'routine_completions',
        where: 'completionTime >= ?',
        whereArgs: [windowStartMs],
      );
      // دستهٔ روتین را ضمیمه میکنیم تا مدل بتواند اثر ورزش را از اثر کار جدا کند.
      final completions = completionsRaw.map((c) {
        final m = Map<String, dynamic>.from(c);
        m['category'] ??= _categoryByRoutineId[m['routineId']];
        return m;
      }).toList();

      final threeHoursAgo = now
          .subtract(const Duration(hours: 3))
          .millisecondsSinceEpoch;
      final recentCompletions = completions
          .where((c) => ((c['completionTime'] as int?) ?? 0) >= threeHoursAgo)
          .toList();

      // خواب دیشب — قبلاً کوئری میشد ولی هیچوقت در محاسبه استفاده نمیشد.
      final oneDayAgo = now
          .subtract(const Duration(hours: 24))
          .millisecondsSinceEpoch;
      final sleepRows = await db.query(
        'bedtime_diagnostics',
        where: 'createdAt >= ?',
        whereArgs: [oneDayAgo],
        orderBy: 'createdAt DESC',
        limit: 1,
      );

      final peak = EnergyModel.peakWindow(
        energyLogs: energyLogs,
        completions: completions,
      );

      final estimate = EnergyModel.estimate(
        now: now,
        energyLogs: energyLogs,
        recentCompletions: recentCompletions,
        todayCompletionCount: completionsToday.length,
        lastNightSleep: sleepRows.isEmpty
            ? null
            : Map<String, dynamic>.from(sleepRows.first),
        validityMinutes: validityMinutes,
        defaultLevel: defaultLevel,
        peakWindow: peak,
      );

      peakPerformanceWindow = peak;
      mostFatiguedWindow = EnergyModel.fatigueWindow(
        energyLogs: energyLogs,
        completions: completions,
      );
      mostProductiveWeekday = EnergyModel.productiveWeekday(
        completions: completions,
      );

      final trustworthy = estimate.isTrustworthy;
      currentEnergyPercent = trustworthy ? estimate.percent : null;
      currentEnergyLabel = trustworthy ? estimate.label : 'نامشخص';
      currentEnergyDesc = trustworthy
          ? estimate.description
          : 'برای شروع، یک بار سطح انرژی امروزت را ثبت کن';
      currentEnergyRecommendation = trustworthy ? estimate.recommendation : '';
      currentEnergyIsEstimated = estimate.isEstimated;
      currentEnergyConfidence = estimate.confidence;
      currentEnergyExplanation = estimate.explanationLines;
      currentEnergyTimeAgo = estimate.sourceLine;
    } catch (e, st) {
      debugPrint('Error updating energy state: $e\n$st');
    }
  }

  Future<Map<String, String?>> loadEnergyAnalyticsData() async {
    return {
      'peak': peakPerformanceWindow,
      'fatigued': mostFatiguedWindow,
      'productive': mostProductiveWeekday,
    };
  }

  // G-1: این کوئری در هر loadP0 اجرا میشد؛ یکبار در نشست کافی است.
  static bool _worshipDebtRoutineEnsured = false;

  Future<void> _ensureWorshipDebtRoutineExists(DatabaseExecutor db) async {
    if (_worshipDebtRoutineEnsured) return;
    _worshipDebtRoutineEnsured = true; // قبل از اولین await — ضد ورود مجدد
    try {
      // Check if user actually has active remaining debts
      final activeDebts = await db.query(
        'worship_debts',
        where: 'isArchived = 0 AND remainingCount > 0',
        limit: 1,
      );
      final hasActiveDebts = activeDebts.isNotEmpty;

      final results = await db.query(
        'routines',
        where: 'id = ?',
        whereArgs: ['worship_debt_routine'],
      );
      final now = DateTime.now().millisecondsSinceEpoch;

      if (results.isEmpty) {
        // Only insert if user actually has debts, otherwise insert as archived
        await db.insert('routines', {
          'id': 'worship_debt_routine',
          'title': 'بدهی عبادی',
          'category': 'religious',
          'routineType': 'asNeeded',
          'notificationLevel': 'none',
          'isEssential': 0,
          'energyRule': 'NONE',
          'priority': 1.0,
          'isArchived': hasActiveDebts ? 0 : 1,
          'isPrivate': 0,
          'displayOrder': 999,
          'createdAt': now,
          'updatedAt': now,
        });
      } else {
        // Synchronize archive state with active debts
        final isCurrentlyArchived =
            (results.first['isArchived'] as int? ?? 0) == 1;
        if (hasActiveDebts && isCurrentlyArchived) {
          await db.update(
            'routines',
            {'isArchived': 0, 'updatedAt': now},
            where: 'id = ?',
            whereArgs: ['worship_debt_routine'],
          );
        } else if (!hasActiveDebts && !isCurrentlyArchived) {
          await db.update(
            'routines',
            {'isArchived': 1, 'updatedAt': now},
            where: 'id = ?',
            whereArgs: ['worship_debt_routine'],
          );
        }
      }

      // If no active debts, also clean up any orphaned tasks for worship debt
      if (!hasActiveDebts) {
        await db.delete(
          'simple_tasks',
          where:
              "linkedRoutineId = 'worship_debt_routine' OR title = 'بدهی عبادی'",
        );
      }
    } catch (e) {
      _worshipDebtRoutineEnsured = false; // فقط در خطای واقعی اجازهٔ تلاش مجدد
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _resolveActiveZone(
    Database db,
    DateTime now,
  ) async {
    final realmState = await RealmRepository().getActiveRealmState();

    // Reconcile zone presence session (F-02)
    final sessionSource = switch (realmState) {
      ManualRealmState() => ZoneSource.manual,
      ScheduledRealmState s => s.isDefaultFallback ? ZoneSource.defaultRealm : ZoneSource.schedule,
      TriggeredRealmState() => ZoneSource.trigger,
      FreeRealmState() => ZoneSource.schedule,
      RealmErrorState() => ZoneSource.schedule,
    };
    await ZoneSessionWriter().reconcile(
      realmState,
      source: sessionSource,
      now: now,
      executor: db,
    );

    return switch (realmState) {
      ManualRealmState m => {
          ...m.realm.toMap(),
          'isOverride': true,
          'overrideUntilMs': m.expireAt.millisecondsSinceEpoch,
        },
      ScheduledRealmState s => {
          ...s.realm.toMap(),
          'startTime': s.schedule.startTime,
          'endTime': s.schedule.endTime,
        },
      TriggeredRealmState t => {
          ...t.realm.toMap(),
          'isTriggered': true,
        },
      FreeRealmState() => null,
      RealmErrorState() => null,
    };
  }
}
