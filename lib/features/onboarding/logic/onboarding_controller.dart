import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/routine_occurrence_generator.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:ritmo/core/services/alarm_scheduler_service.dart';
import 'package:ritmo/core/services/central_inbox_service.dart';
import 'package:ritmo/core/services/premium_service.dart';
import 'package:ritmo/core/utils/snapshot_helper.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/onboarding/logic/day_arc_inferencer.dart';
import 'package:ritmo/features/onboarding/logic/onboarding_draft.dart';
import 'package:ritmo/features/onboarding/logic/onboarding_gate.dart';
import 'package:ritmo/features/onboarding/logic/onboarding_module_map.dart';
import 'package:ritmo/features/onboarding/logic/starter_pack_catalog.dart';
import 'package:ritmo/features/onboarding/models/focus_area.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:sqflite/sqflite.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController() {
    _initDefaults();
  }

  /// How long to wait before running post-save side effects.
  ///
  /// Covers the 650ms AnimatedSwitcher in `main.dart` plus the home shell's
  /// first frames, so the transition owns the isolate and the sqflite
  /// connection while it is on screen.
  static const Duration postSaveDelay = Duration(milliseconds: 1200);

  /// Hard ceilings for best-effort work. A platform channel that never answers
  /// must not be able to keep the app on the celebration screen.
  static const Duration widgetSnapshotTimeout = Duration(seconds: 8);
  static const Duration alarmSchedulingTimeout = Duration(seconds: 25);

  int currentIndex = 0;
  String userName = '';
  String gender = 'OTHER';
  int age = 25;
  String wakeTime = '07:00';
  String sleepTime = '23:00';
  bool isDayArcInferred = false;
  String dayArcReason = '';
  Set<FocusArea> focusAreas = {};
  List<StarterRoutineTemplate> selectedStarterRoutines = [];
  Set<String> skippedStepCodes = {};
  String energyProfile = 'MEDIUM';
  bool enableCycle = false;
  bool notifAsked = false;
  bool notifGranted = false;
  bool isSaving = false;
  String? errorMessage;

  static const List<String> simpleStepCodes = ['NAME', 'NOTIFICATIONS'];
  static const List<String> fullStepCodes = [
    'WELCOME',
    'IDENTITY',
    'DAY_ARC',
    'FOCUS',
    'STARTER_PACK',
    'NOTIFICATIONS',
    'CELEBRATION',
  ];

  List<String> get stepCodes => fullStepCodes;

  Future<void> _initDefaults() async {
    final suggestion = await DayArcInferencer.suggest();
    wakeTime = suggestion.wakeTime;
    sleepTime = suggestion.sleepTime;
    isDayArcInferred = suggestion.isInferred;
    dayArcReason = suggestion.reasonFa;

    selectedStarterRoutines = StarterPackCatalog.suggestFor(focusAreas);
    notifyListeners();
  }

  Future<void> checkAndLoadDraft() async {
    final draft = await OnboardingDraftStore.load();
    if (draft != null) {
      currentIndex = draft.stepIndex;
      final st = draft.state;
      userName = st['userName'] as String? ?? userName;
      gender = st['gender'] as String? ?? gender;
      age = st['age'] as int? ?? age;
      wakeTime = st['wakeTime'] as String? ?? wakeTime;
      sleepTime = st['sleepTime'] as String? ?? sleepTime;
      energyProfile = st['energyProfile'] as String? ?? energyProfile;
      enableCycle = st['enableCycle'] as bool? ?? enableCycle;

      final areaCodes = List<String>.from(st['focusAreas'] as List? ?? []);
      focusAreas = areaCodes.map((c) => FocusArea.parse(c)).whereType<FocusArea>().toSet();

      skippedStepCodes = Set<String>.from(st['skippedStepCodes'] as List? ?? []);
      selectedStarterRoutines = StarterPackCatalog.suggestFor(focusAreas);
      notifyListeners();
    }
  }

  void _saveDraftDebounced() {
    final draft = OnboardingDraft(
      stepIndex: currentIndex,
      state: {
        'userName': userName,
        'gender': gender,
        'age': age,
        'wakeTime': wakeTime,
        'sleepTime': sleepTime,
        'energyProfile': energyProfile,
        'enableCycle': enableCycle,
        'focusAreas': focusAreas.map((a) => a.code).toList(),
        'skippedStepCodes': skippedStepCodes.toList(),
      },
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    OnboardingDraftStore.save(draft);
  }

  void next() {
    if (currentIndex < stepCodes.length - 1) {
      currentIndex++;
      _saveDraftDebounced();
      notifyListeners();
    }
  }

  void prev() {
    if (currentIndex > 0) {
      currentIndex--;
      _saveDraftDebounced();
      notifyListeners();
    }
  }

  Future<void> skipCurrentStep() async {
    final code = stepCodes[currentIndex];
    skippedStepCodes.add(code);

    switch (code) {
      case 'IDENTITY':
        await CentralInboxService.push(
          category: InboxCategory.SUGGESTION,
          sourceSystem: 'onboarding_skip',
          entityId: 'skip_identity',
          eventType: 'setup_profile',
          title: 'تکمیل پروفایل کاربری',
          body: 'نام و مشخصات خود را در تنطیمات تکمیل کنید.',
          priority: 1,
        );
      case 'DAY_ARC':
        await CentralInboxService.push(
          category: InboxCategory.SUGGESTION,
          sourceSystem: 'onboarding_skip',
          entityId: 'skip_day_arc',
          eventType: 'setup_day_arc',
          title: 'تنطیم قوس روز',
          body: 'ساعات خواب و بیداری خود را تنطیم کنید.',
          priority: 1,
        );
      case 'FOCUS':
        await CentralInboxService.push(
          category: InboxCategory.SUGGESTION,
          sourceSystem: 'onboarding_skip',
          entityId: 'skip_focus',
          eventType: 'setup_focus',
          title: 'انتخاب حوزه‌های تمرکز',
          body: 'حوزه‌های اصلی تمرکز زندگی خود را مشخص کنید.',
          priority: 1,
        );
      case 'STARTER_PACK':
        await CentralInboxService.push(
          category: InboxCategory.SUGGESTION,
          sourceSystem: 'onboarding_skip',
          entityId: 'skip_starter_pack',
          eventType: 'create_first_routine',
          title: 'ساخت اولین روتین',
          body: 'اولین عادت/روتین خود را ایجاد کنید.',
          priority: 1,
        );
    }

    next();
  }

  void toggleFocusArea(FocusArea area) {
    if (focusAreas.contains(area)) {
      focusAreas.remove(area);
    } else {
      focusAreas.add(area);
    }
    selectedStarterRoutines = StarterPackCatalog.suggestFor(focusAreas);
    notifyListeners();
  }

  void toggleStarterRoutine(StarterRoutineTemplate template) {
    if (selectedStarterRoutines.any((t) => t.id == template.id)) {
      selectedStarterRoutines.removeWhere((t) => t.id == template.id);
    } else {
      selectedStarterRoutines.add(template);
    }
    notifyListeners();
  }

  Future<void> save({required VoidCallback onFinished}) async {
    if (isSaving) return;
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    try {
      final db = await DatabaseHelper.instance.database.timeout(
        const Duration(seconds: 10),
      );

      var createdCount = 0;
      final expectedCount = selectedStarterRoutines.length;

      // Perform all onboarding insertions atomically in one fast native batch
      final batch = db.batch();

      // 1. Create starter routines with deterministic IDs to ensure idempotency
      for (final t in selectedStarterRoutines) {
        final rId = 'onboarding_routine_${t.id}';
        final duration = DurationBounds.sanitize(t.durationMinutes);

        final routineData = {
          'id': rId,
          'title': t.titleFa,
          'category': t.category.name,
          'routineType': 'timeBased',
          'notificationLevel': 'normal',
          'isEssential': 0,
          'energyRule': 'NONE',
          'priority': 1.0,
          'targetDurationMinutes': duration,
          'displayOrder': 1,
          'description': 'اولین روتین روتین ثبت‌شده در آنبوردینگ',
          'createdAt': nowMs,
          'updatedAt': nowMs,
        };

        final rule = RecurrenceRule(
          startDate: DateTime.now(),
          weekdays: const [1, 2, 3, 4, 5, 6, 7],
          reminderTimes: [t.defaultTime],
        );

        final scheduleData = {
          'id': 'sched_$rId',
          'routineId': rId,
          'scheduleType': 'DAILY',
          'timeOfDay': t.defaultTime,
          'daysOfWeek': '1,2,3,4,5,6,7',
          'recurrenceRule': jsonEncode(rule.toMap()),
          'createdAt': nowMs,
          'updatedAt': nowMs,
        };

        batch.insert(
          'routines',
          routineData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        batch.insert(
          'routine_schedules',
          scheduleData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Add future occurrences to batch
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        for (var i = 0; i < 30; i++) {
          final targetDate = today.add(Duration(days: i));
          final dateStr = targetDate.toIso8601String().substring(0, 10);
          if (RoutineOccurrenceGenerator.shouldOccurOnDate(targetDate, rule)) {
            final timeStr = rule.reminderTimes.isNotEmpty
                ? rule.reminderTimes.first
                : '08:00';
            batch.insert('routine_occurrences', {
              'routine_id': rId,
              'date': dateStr,
              'scheduled_time': timeStr,
              'status': 'pending',
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }

        createdCount++;
      }

      // 2. Perform main onboarding completion settings update
      final canCourses = PremiumService.instance.can(PremiumFeature.coursesModule);

      final moduleStates = OnboardingModuleMap.resolveModuleStates(
        chosenAreas: focusAreas,
        isFemale: gender == 'FEMALE',
        enableCycle: enableCycle,
        canUseCourses: canCourses,
      );

      for (final entry in moduleStates.entries) {
        batch.insert(
          'app_settings',
          {
            'key': entry.key,
            'value': entry.value,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final btParts = sleepTime.split(':');
      final wtParts = wakeTime.split(':');
      final btMin = (int.tryParse(btParts[0]) ?? 23) * 60 + (int.tryParse(btParts.length > 1 ? btParts[1] : '0') ?? 0);
      final wtMin = (int.tryParse(wtParts[0]) ?? 7) * 60 + (int.tryParse(wtParts.length > 1 ? wtParts[1] : '0') ?? 0);
      var durationMins = wtMin - btMin;
      if (durationMins <= 0) durationMins += 1440;

      final focusCodes = focusAreas.map((a) => a.code).toList();
      final settingsToSave = {
        if (userName.isNotEmpty) 'user_name': userName,
        'user_gender': gender,
        'user_age': age.toString(),
        'sleep_target_bedtime': sleepTime,
        'sleep_target_wake': wakeTime,
        'sleep_target_duration_minutes': durationMins.toString(),
        'sleep_setup_done': 'true',
        'module_sleep_enabled': 'true',
        'primary_focus_areas': jsonEncode(focusCodes),
        'energy_profile': energyProfile,
        'default_energy_level': energyProfile,
        'notif_permission_asked': 'true',
        'notif_permission_granted': notifGranted ? 'true' : 'false',
        'onboarding_skipped_steps': jsonEncode(skippedStepCodes.toList()),
        'onboarding_completed': 'true',
        'onboarding_version': OnboardingGate.currentVersion.toString(),
      };

      for (final entry in settingsToSave.entries) {
        batch.insert(
          'app_settings',
          {
            'key': entry.key,
            'value': entry.value,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true).timeout(const Duration(seconds: 15));

      if (createdCount < expectedCount) {
        isSaving = false;
        errorMessage = '$createdCount مورد از $expectedCount روتین ساخته شد. لطفاً دوباره تلاش کنید.';
        notifyListeners();
        return;
      }

      // ── C-FIX-4: drop any agenda assembled BEFORE these routines existed ──
      //
      // Anything that touched DayAgendaService while onboarding was still open
      // (widget snapshot, alarm scheduling, a background refresh) cached an
      // empty day for today. The Calendar reads that cache (it queries with
      // default options); Home does not (it passes an explicit domain set).
      // If we leave the stale entries in place the Calendar stays blank for the
      // whole session while Home looks correct. This MUST run synchronously,
      // before onFinished() lets the user navigate, and it must never depend on
      // the best-effort side effects below, which can throw on a fresh install.
      DayAgendaService.instance.invalidateAll();

      // Clear draft store immediately after successful transaction
      await OnboardingDraftStore.clear();

      // Dual redundancy sync to SharedPreferences outside transaction
      unawaited(OnboardingGate.syncToPrefs(
        version: OnboardingGate.currentVersion,
        userName: userName,
      ));

      // ── CRITICAL STEP COMPLETED: Release user navigation immediately ──
      isSaving = false;
      notifyListeners();
      debugPrint('[OnboardingController] Calling onFinished() navigation callback');
      onFinished();

      // ── BEST-EFFORT SIDE EFFECTS: must not compete with the first frames ──
      //
      // onFinished() swaps the widget tree through a 650ms AnimatedSwitcher, so
      // for about a second the onboarding tree (BackdropFilter + a repeating
      // ambient animation) and the whole home shell are mounted and painting
      // together while the dashboard runs its first queries. Starting the side
      // effects here used to drop alarm scheduling into exactly that window:
      // dozens of writes plus one platform channel call per reminder, on the
      // same isolate and the same sqflite connection, which starves the
      // transition and reads as a freeze on the celebration screen.
      //
      // Let the app settle first, then run them with hard timeouts.
      unawaited(
        Future<void>.delayed(postSaveDelay, _postSaveBestEffort),
      );
    } catch (e, st) {
      debugPrint('[OnboardingController] Failed to save onboarding data: $e\n$st');
      RitmoLog.error('OnboardingController', 'Failed to save onboarding data', e, st);
      isSaving = false;
      errorMessage = 'ذخیرهٔ اطلاعات ناموفق بود. لطفاً دوباره تلاش کنید.';
      notifyListeners();
    }
  }

  /// Post-save side effects. Every step is isolated and time-boxed: a failure
  /// or a hang in one (missing widget channel, denied alarm permission, a
  /// platform call that never answers, …) must never prevent the agenda refresh
  /// signals that follow it, and must never leave the user staring at a frozen
  /// screen.
  Future<void> _postSaveBestEffort() async {
    // 1. Agenda cache + refresh signals first — these are what make the newly
    //    created routines visible on Home and in the Calendar.
    try {
      DayAgendaService.instance.invalidateAll();
      RitmoEvents.notifyRoutineChanged();

      RitmoEventBus().fire(RitmoEvent(
        type: 'DataImported',
        timestamp: DateTime.now(),
        payload: {},
      ));
      RitmoEventBus().fire(RitmoEvent(
        type: 'RoutineCreated',
        timestamp: DateTime.now(),
        payload: {},
      ));
    } catch (e, st) {
      RitmoLog.error('OnboardingController', 'Agenda invalidation/refresh failed', e, st);
    }

    // 2. Home-screen widget snapshot (platform channel — may be unavailable).
    try {
      final firstRoutineTitle = selectedStarterRoutines.isNotEmpty
          ? selectedStarterRoutines.first.titleFa
          : 'ریتمو';

      await SnapshotHelper.updateWidgetSnapshot(
        nextActionTitle: firstRoutineTitle,
        rhythmScore: 100,
        currentEnergyLevel: energyProfile,
      ).timeout(widgetSnapshotTimeout);
    } catch (e, st) {
      RitmoLog.error('OnboardingController', 'Widget snapshot update failed', e, st);
    }

    // 3. Alarm scheduling (needs notification / exact-alarm permission, and
    //    performs one platform call per reminder).
    try {
      await AlarmSchedulerService.scheduleNextAlarms().timeout(alarmSchedulingTimeout);
    } catch (e, st) {
      RitmoLog.error('OnboardingController', 'Alarm scheduling failed', e, st);
    }
  }
}
