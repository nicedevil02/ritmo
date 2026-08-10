import 'package:ritmo/core/domain/agenda/sources/worship_agenda_source.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/routine_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/sports_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/task_agenda_source.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/prayer_time_provider.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/features/courses/logic/courses_repository.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/konkur/logic/konkur_repository.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';
import 'package:ritmo/features/worship/logic/worship_completion_repository.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:sqflite/sqflite.dart';

/// 🔑 The single source of truth for "what is on a day".
///
/// Aggregates every section (routine, prayer, mustahab, worship debt, course,
/// goal step, konkur, cycle) into a normalized [AgendaItem] list. Both the Home
/// dashboard and the Calendar feed from this service so the app stays coherent.
///
/// Each per-domain collector is module-gated and reuses the owning repo/engine
/// (no fresh raw SQL per section beyond what's needed). For a range, shared
/// data (settings, prayer times, worship rows, cycle output, course/konkur
/// lookups) is loaded once and bucketed in memory.
class DayAgendaService {
  DayAgendaService._() {
    _subscribeToEvents();
  }
  static final DayAgendaService instance = DayAgendaService._();

  /// Small per-date cache (invalidated reactively via the event bus).
  final Map<String, DayAgenda> _cache = {};

  /// Completion-style events fired outside the routine kernel. The kernel
  /// already refreshes the UI for its own routine events, so for these we both
  /// invalidate the cache *and* fan out a single UI refresh signal. Routine
  /// events only invalidate the cache (no double refresh).
  static const Set<String> _uiRefreshEvents = {
    'CourseSessionCompleted',
    'GoalStepToggled',
    'TaskToggled',
    'TaskUpdated',
    'PrayerCompleted',
    'WorshipUpdated',
    'RoutineDeleted',
    'completion_recorded',
    'AgendaItemToggled',
    'commitmentChanged',
    'planningCycleActivated',
  };

  static const Set<String> _cacheInvalidatingEvents = {
    'CourseSessionCompleted',
    'GoalStepToggled',
    'TaskToggled',
    'TaskUpdated',
    'PrayerCompleted',
    'WorshipUpdated',
    'RoutineCompleted',
    'RoutineSkipped',
    'RoutineCreated',
    'RoutineEdited',
    'RoutineDeleted',
    'CycleStarted',
    'CycleEnded',
    'DayRolledOver',
    'DataImported',
    'completion_recorded',
    'AgendaItemToggled',
    'commitmentChanged',
    'planningCycleActivated',
  };

  void _subscribeToEvents() {
    RitmoEventBus().onEvents.listen((event) {
      if (!_cacheInvalidatingEvents.contains(event.type)) return;

      final date = (event.payload['date'] ?? event.payload['dateStr']) as String?;
      if (event.type == 'DayRolledOver' || event.type == 'DataImported') {
        invalidateAll();
      } else if (date != null) {
        invalidateDate(date);
      } else {
        invalidateAll();
      }

      if (_uiRefreshEvents.contains(event.type)) {
        // Unified UI refresh notifier (Home + Calendar listen to this).
        RitmoEvents.notifyRoutineChanged();
      }
    });
  }

  /// Drop the whole cache (e.g. on broad data changes).
  void invalidateAll() => _cache.clear();

  /// Drop a single date's cached agenda.
  void invalidateDate(String dateStr) => _cache.remove(dateStr);

  static String _dateStr(DateTime dt) => dt.toIso8601String().substring(0, 10);

  Future<DayAgenda> agendaForDate(
    DateTime date, {
    AgendaQueryOptions? options,
  }) async {
    final map = await agendaForRange(date, date, options: options);
    return map[_dateStr(date)] ?? DayAgenda.empty(_dateStr(date));
  }

  Future<Map<String, DayAgenda>> agendaForRange(
    DateTime start,
    DateTime end, {
    AgendaQueryOptions? options,
  }) async {
    final opts = options ?? const AgendaQueryOptions();
    final result = <String, DayAgenda>{};

    final dates = <DateTime>[];
    var d = DateTime(start.year, start.month, start.day);
    final endD = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(endD)) {
      dates.add(d);
      d = d.add(const Duration(days: 1));
    }

    try {
      final ctx = await _buildContext(start, end, opts);
      for (final date in dates) {
        final ds = _dateStr(date);
        // Cache only the full, unfiltered agenda; filtered queries are rebuilt.
        if (opts.domains.isEmpty && opts.includeCompleted && _cache.containsKey(ds)) {
          result[ds] = _cache[ds]!;
          continue;
        }
        final agenda = await _assembleDay(date, ds, ctx, opts);
        if (opts.domains.isEmpty && opts.includeCompleted) {
          _cache[ds] = agenda;
        }
        result[ds] = agenda;
      }
    } catch (e, st) {
      debugPrint('DayAgendaService.agendaForRange error: $e\n$st');
      for (final date in dates) {
        result.putIfAbsent(_dateStr(date), () => DayAgenda.empty(_dateStr(date)));
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Context (loaded once per range)
  // ---------------------------------------------------------------------------

  Future<_AgendaContext> _buildContext(
    DateTime start,
    DateTime end,
    AgendaQueryOptions opts,
  ) async {
    final db = await DatabaseHelper.instance.database;

    final settings = await db.query('app_settings');
    final settingsMap = <String, String>{
      for (final s in settings) if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? ''
    };

    final religionEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_religion_enabled');
    final coursesEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_courses_enabled');
    final konkurEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_study_enabled') &&
        settingsMap['konkur_show_in_dashboard'] != 'false';
    final sportsEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_supplementary_sports_enabled');
    final medicineEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_medicine_enabled');

    // Cycle gates mirror the Home dashboard (conservative: dashboard consent).
    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_cycle_enabled');
    final cycleConsent = settingsMap['cycle_consent_dashboard'] == 'true';
    final cycleSetupDone = settingsMap['cycle_setup_done'] == 'true';
    final showCycleInCalendar = settingsMap['show_cycle_in_calendar'] == 'true';
    final cycleAllowed =
        isFemale && cycleEnabled && cycleConsent && cycleSetupDone && showCycleInCalendar;

    final routineSource = await RoutineAgendaSource.load(db, settingsMap);

    // Routine completions keyed by date -> routineId -> row.
    final completionsByDate = <String, Map<String, Map<String, dynamic>>>{};
    if (opts.wants(AgendaDomain.routine)) {
      final comps = await db.query('routine_completions');
      for (final c in comps) {
        final resType = c['resultType'] as String?;
        if (resType == 'SNOOZED' || resType == 'CANNOT_NOW') continue;
        final dateStr = c['completionDate'] as String?;
        final routineId = c['routineId'] as String?;
        if (dateStr == null || routineId == null) continue;
        completionsByDate
            .putIfAbsent(dateStr, () => {})[routineId] =
            Map<String, dynamic>.from(c);
      }
    }

    // Worship practices (prayers + mustahab) and debts, loaded once.
    final prayerPractices = <Map<String, dynamic>>[];
    final mustahabPractices = <Map<String, dynamic>>[];
    var worshipDebts = <Map<String, dynamic>>[];
    if (religionEnabled) {
      final practices = await db.query(
        'worship_practices',
        where: 'isActive = 1',
      );
      for (final p in practices) {
        final type = p['practiceType'] as String? ?? '';
        if (type == 'PRAYER') {
          prayerPractices.add(Map<String, dynamic>.from(p));
        } else if (type == 'MUSTAHAB' || type == 'QURAN' || type == 'DHIKR') {
          if (p['reminderEnabled'] == 1) {
            mustahabPractices.add(Map<String, dynamic>.from(p));
          }
        }
      }
      // Worship debts are no longer shown in the calendar per user request
      worshipDebts = [];
    }

    // Courses: active course titles + all sessions bucketed by plannedDate.
    final courseTitles = <String, String>{};
    final coursesMap = <String, Course>{};
    final sessionsByDate = <String, List<CourseSession>>{};
    if (coursesEnabled && opts.wants(AgendaDomain.course)) {
      final courses = await CoursesRepository.instance.getActiveCourses();
      for (final c in courses) {
        courseTitles[c.id] = c.title;
        coursesMap[c.id] = c;
      }
      final activeIds = courseTitles.keys.toSet();
      final sessionRows = await db.query('course_sessions');
      for (final row in sessionRows) {
        final session = CourseSession.fromMap(row);
        if (session.plannedDate == null) continue;
        if (!activeIds.contains(session.courseId)) continue;
        sessionsByDate
            .putIfAbsent(session.plannedDate!, () => [])
            .add(session);
      }
    }

    // Konkur: plan items bucketed by date + subject names for subtitles.
    final konkurByDate = <String, List<KonkurPlanItem>>{};
    final konkurSubjectNames = <String, String>{};
    if (konkurEnabled && opts.wants(AgendaDomain.konkur)) {
      final repo = KonkurRepository.instance;
      final plan = await repo.getPlanItems();
      for (final item in plan) {
        konkurByDate.putIfAbsent(item.dateIso, () => []).add(item);
      }
      if (konkurByDate.isNotEmpty) {
        final subjects = await repo.getSubjects();
        for (final s in subjects) {
          konkurSubjectNames[s.id] = s.name;
        }
      }
    }

    // Cycle output computed once for "now" and classified per-date by window.
    CycleEngineOutput? cycleOutput;
    if (cycleAllowed && opts.wants(AgendaDomain.cycle)) {
      try {
        cycleOutput = await CycleEngine().calculate(CycleEngineInput(
          db: db,
          appSettings: settingsMap,
          now: DateTime.now(),
        ));
      } catch (e) {
        debugPrint('DayAgendaService cycle calc error: $e');
      }
    }

    // Coordinates lookup for cityId
    final cityId = settingsMap['prayer_city_id'] ??
        settingsMap['home_city_id'] ??
        'TEHRAN_TEHRAN';
    final cityResult = await db.query(
      'iran_cities',
      where: 'id = ?',
      whereArgs: [cityId],
      limit: 1,
    );

    var latitude = 35.6892; // default Tehran
    var longitude = 51.3890;

    if (cityResult.isNotEmpty) {
      latitude = cityResult.first['latitude']! as double;
      longitude = cityResult.first['longitude']! as double;
    }

    final ihtiyatMinutes = int.tryParse(settingsMap['ihtiyat_minutes'] ?? '0') ?? 0;
    final calcMethodStr = settingsMap['prayer_calculation_method'] ?? 'TEHRAN_GEOPHYSICS';

    // Preload goal steps and planning allocations for the range
    final goalStepsByDate = <String, List<Map<String, dynamic>>>{};
    if (opts.wants(AgendaDomain.goalStep)) {
      final startStr = _dateStr(start);
      final endStr = _dateStr(end);

      try {
        final res = await db.rawQuery('''
          SELECT gs.*, g.title as goalTitle
          FROM goal_steps gs
          JOIN goals g ON gs.goalId = g.id
          WHERE gs.scheduledDate >= ? AND gs.scheduledDate <= ? AND g.status = 'ACTIVE'
        ''', [startStr, endStr]);
        for (final row in res) {
          final dateStr = row['scheduledDate'] as String?;
          if (dateStr != null) {
            goalStepsByDate.putIfAbsent(dateStr, () => []).add(Map<String, dynamic>.from(row));
          }
        }
      } catch (_) {}

      try {
        final allocRes = await db.rawQuery('''
          SELECT a.id as allocId, a.dayKey, a.plannedMinutes, a.status as allocStatus,
                 c.id as commId, c.title as commTitle, c.importance, c.workKind
          FROM planning_allocations a
          JOIN planning_commitments c ON a.commitmentId = c.id
          WHERE a.dayKey >= ? AND a.dayKey <= ? AND a.status != 'DROPPED' AND c.status != 'DROPPED'
        ''', [startStr, endStr]);
        for (final row in allocRes) {
          final dateStr = row['dayKey'] as String?;
          if (dateStr != null) {
            goalStepsByDate.putIfAbsent(dateStr, () => []).add({
              'id': row['allocId'],
              'isPlanningAllocation': true,
              'title': row['commTitle'],
              'goalTitle': 'برنامه و تعهد',
              'isCompleted': row['allocStatus'] == 'DONE' ? 1 : 0,
              'durationMinutes': row['plannedMinutes'] ?? 30,
              'scheduledDate': dateStr,
            });
          }
        }
      } catch (_) {}
    }

    // Preload cached Hijri dates
    final cachedHijriDates = <String, HijriDate>{};
    if (religionEnabled) {
      final hijriSettings = await db.query(
        'app_settings',
        where: "key LIKE 'hijri_date_%'",
      );
      for (final row in hijriSettings) {
        try {
          final val = row['value']! as String;
          final decoded = json.decode(val) as Map<String, dynamic>;
          final dateKey = row['key']! as String;
          cachedHijriDates[dateKey] = HijriDate.fromMap(decoded);
        } catch (e) {
          debugPrint('Error decoding cached Hijri date in _buildContext: $e');
        }
      }
    }
    final sportsPlansByDay = <int, List<Map<String, dynamic>>>{};
    if (sportsEnabled && opts.wants(AgendaDomain.sport)) {
      try {
        final plans = await db.query('ss_workout_plan');
        for (final p in plans) {
          final dow = p['dayOfWeek'] as int?;
          if (dow != null) {
            sportsPlansByDay.putIfAbsent(dow, () => []).add(Map<String, dynamic>.from(p));
          }
        }
      } catch (e) {
        debugPrint('DayAgendaService sports query error: $e');
      }
    }

    // Preload medicine logs if enabled
    final medicineLogsByDate = <String, List<Map<String, dynamic>>>{};
    if (medicineEnabled && opts.wants(AgendaDomain.medicine)) {
      try {
        final logs = await db.query('medication_logs');
        for (final l in logs) {
          final schedTime = l['scheduledTime'] as int?;
          if (schedTime != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(schedTime);
            final ds = _dateStr(dt);
            medicineLogsByDate.putIfAbsent(ds, () => []).add(Map<String, dynamic>.from(l));
          }
        }
      } catch (e) {
        debugPrint('DayAgendaService medicine query error: $e');
      }
    }

    final tasksEnabled = settingsMap['calendar_show_tasks'] != 'false';
    TaskAgendaSource? taskSource;
    if (tasksEnabled && opts.wants(AgendaDomain.task)) {
      taskSource = await TaskAgendaSource.load(db, start, end, _dateStr(DateTime.now()));
    }

    final worshipSource = WorshipAgendaSource(
      prayerPractices: prayerPractices,
      mustahabPractices: mustahabPractices,
      worshipDebts: worshipDebts,
      settingsMap: settingsMap,
      religionEnabled: religionEnabled,
      db: db,
      cachedHijriDates: cachedHijriDates,
    );

    return _AgendaContext(
      db: db,
      settingsMap: settingsMap,
      religionEnabled: religionEnabled,
      coursesEnabled: coursesEnabled,
      konkurEnabled: konkurEnabled,
      cycleAllowed: cycleAllowed,
      sportsEnabled: sportsEnabled,
      medicineEnabled: medicineEnabled,
      taskSource: taskSource,
      routineSource: routineSource,
      worshipSource: worshipSource,
      completionsByDate: completionsByDate,
      courseTitles: courseTitles,
      coursesMap: coursesMap,
      sessionsByDate: sessionsByDate,
      konkurByDate: konkurByDate,
      konkurSubjectNames: konkurSubjectNames,
      cycleOutput: cycleOutput,
      goalStepsByDate: goalStepsByDate,
      sportsPlansByDay: sportsPlansByDay,
      medicineLogsByDate: medicineLogsByDate,
      latitude: latitude,
      longitude: longitude,
      ihtiyatMinutes: ihtiyatMinutes,
      calcMethodStr: calcMethodStr,
    );
  }

  // ---------------------------------------------------------------------------
  // Per-day assembly
  // ---------------------------------------------------------------------------

  Future<DayAgenda> _assembleDay(
    DateTime date,
    String dateStr,
    _AgendaContext ctx,
    AgendaQueryOptions opts,
  ) async {
    final todayStr = _dateStr(DateTime.now());
    final isToday = dateStr == todayStr;
    final prayerTimes = await ctx.prayerTimesFor(date);
    final items = <AgendaItem>[];



    final enabledDomains = <AgendaDomain, bool>{
      AgendaDomain.routine: true,
      AgendaDomain.prayer: ctx.religionEnabled,
      AgendaDomain.mustahab: ctx.religionEnabled,
      AgendaDomain.worshipDebt: ctx.religionEnabled && opts.includeWorshipDebt,
      AgendaDomain.course: ctx.coursesEnabled,
      AgendaDomain.goalStep: true,
      AgendaDomain.konkur: ctx.konkurEnabled,
      AgendaDomain.cycle: ctx.cycleAllowed,
      AgendaDomain.sport: ctx.sportsEnabled,
      AgendaDomain.medicine: ctx.medicineEnabled,
      AgendaDomain.task: ctx.taskSource != null,
    };

    if (opts.wants(AgendaDomain.routine)) {
      final routines = ctx.routineSource.agendaItemsForDate(
        date,
        prayerTimes: prayerTimes,
        completionsByRoutineId: ctx.completionsByDate[dateStr] ?? const {},
      );

      final activeWorshipTitles = <String>{};
      if (ctx.worshipSource.religionEnabled) {
        for (final p in ctx.worshipSource.prayerPractices) {
          final title = p['title'] as String?;
          if (title != null) activeWorshipTitles.add(title.trim());
        }
        for (final p in ctx.worshipSource.mustahabPractices) {
          final title = p['title'] as String?;
          if (title != null) activeWorshipTitles.add(title.trim());
        }
      }

      final filteredRoutines = routines.where((r) {
        final matches = activeWorshipTitles.contains(r.title.trim());
        return !matches;
      }).toList();

      items.addAll(filteredRoutines);
    }

    if (ctx.worshipSource.religionEnabled) {
      items.addAll(await ctx.worshipSource.itemsForDate(
        date, 
        dateStr, 
        prayerTimes, 
        opts.wants(AgendaDomain.prayer), 
        opts.wants(AgendaDomain.mustahab), 
        opts.wants(AgendaDomain.worshipDebt)
      ));
    }

    if (ctx.coursesEnabled && opts.wants(AgendaDomain.course)) {
      items.addAll(_collectCourses(ctx, dateStr));
    }

    if (opts.wants(AgendaDomain.goalStep)) {
      items.addAll(_collectGoalSteps(ctx, dateStr));
    }

    if (ctx.konkurEnabled && opts.wants(AgendaDomain.konkur)) {
      items.addAll(_collectKonkur(ctx, dateStr));
    }

    if (ctx.cycleAllowed && opts.wants(AgendaDomain.cycle)) {
      final cycleItem = _collectCycle(ctx, date, dateStr, isToday);
      if (cycleItem != null) items.add(cycleItem);
    }

    if (ctx.sportsEnabled && opts.wants(AgendaDomain.sport)) {
      items.addAll(_collectSports(ctx, dateStr, date));
    }

    if (ctx.medicineEnabled && opts.wants(AgendaDomain.medicine)) {
      items.addAll(_collectMedicine(ctx, dateStr, isToday));
    }

    if (ctx.taskSource != null && opts.wants(AgendaDomain.task)) {
      items.addAll(ctx.taskSource!.itemsForDate(dateStr, isToday: isToday));
    }

    final filtered = opts.includeCompleted
        ? items
        : items.where((i) {
            return i.completion != AgendaCompletion.done &&
                i.completion != AgendaCompletion.partial &&
                i.completion != AgendaCompletion.skipped;
          }).toList();

    _sortItems(filtered);

    return DayAgenda(
      dateStr: dateStr,
      items: filtered,
      enabledDomains: enabledDomains,
    );
  }

  /// Timed items first (by time), then untimed by descending priority.
  void _sortItems(List<AgendaItem> items) {
    items.sort((a, b) {
      if (a.isTimed && b.isTimed) {
        final aM = _parseMinutes(a.timeOfDay);
        final bM = _parseMinutes(b.timeOfDay);
        return aM.compareTo(bM);
      }
      if (a.isTimed) return -1;
      if (b.isTimed) return 1;
      return b.priority.compareTo(a.priority);
    });
  }

  static int _parseMinutes(String? timeOfDay) {
    if (timeOfDay == null) return 0;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeOfDay.trim());
    if (match == null) return 0;
    final h = int.tryParse(match.group(1)!) ?? 0;
    final m = int.tryParse(match.group(2)!) ?? 0;
    return (h * 60) + m;
  }

  // ---------------------------------------------------------------------------
  // Collectors
  // ---------------------------------------------------------------------------

  List<AgendaItem> _collectCourses(_AgendaContext ctx, String dateStr) {
    final sessions = ctx.sessionsByDate[dateStr] ?? const [];
    return sessions.map((s) {
      final course = ctx.coursesMap[s.courseId];
      return AgendaItem(
        id: 'course:${s.id}',
        domain: AgendaDomain.course,
        sourceId: s.id,
        title: s.sessionTitle ?? 'جلسه ${s.sessionNumber}',
        subtitle: course?.title,
        dateStr: dateStr,
        timeOfDay: course?.preferredTime,
        durationMinutes: course?.sessionDurationMinutes,
        category: Category.learning,
        completion:
            s.isCompleted ? AgendaCompletion.done : AgendaCompletion.pending,
        priority: 1.5,
        deepLink:
            AgendaDeepLink(domain: AgendaDomain.course, targetId: s.courseId),
        meta: {'session': s.toMap()},
      );
    }).toList();
  }

  List<AgendaItem> _collectGoalSteps(_AgendaContext ctx, String dateStr) {
    final rows = ctx.goalStepsByDate[dateStr] ?? const [];
    return rows.map((m) {
      final id = m['id'] as String;
      final goalId = m['goalId'] as String? ?? '';
      final completed = (m['isCompleted'] as int? ?? 0) == 1;
      final duration = (m['durationMinutes'] as int?) ?? 30;
      return AgendaItem(
        id: 'goalStep:$id',
        domain: AgendaDomain.goalStep,
        sourceId: id,
        title: m['title'] as String? ?? '',
        subtitle: m['goalTitle'] as String?,
        dateStr: dateStr,
        durationMinutes: duration,
        category: Category.personal,
        completion:
            completed ? AgendaCompletion.done : AgendaCompletion.pending,
        deepLink:
            AgendaDeepLink(domain: AgendaDomain.goalStep, targetId: goalId),
        meta: {'step': m},
      );
    }).toList();
  }

  List<AgendaItem> _collectKonkur(_AgendaContext ctx, String dateStr) {
    final plan = ctx.konkurByDate[dateStr] ?? const [];
    return plan.map((item) {
      AgendaCompletion completion;
      switch (item.status) {
        case 'DONE':
          completion = AgendaCompletion.done;
        case 'SKIPPED':
          completion = AgendaCompletion.skipped;
        default:
          completion = AgendaCompletion.pending;
      }
      final subjectName =
          item.subjectId != null ? ctx.konkurSubjectNames[item.subjectId] : null;
      return AgendaItem(
        id: 'konkur:${item.id}',
        domain: AgendaDomain.konkur,
        sourceId: item.id,
        title: subjectName ?? 'برنامه کنکور',
        subtitle: item.plannedMinutes > 0 ? '${item.plannedMinutes} دقیقه' : null,
        dateStr: dateStr,
        durationMinutes: item.plannedMinutes > 0 ? item.plannedMinutes : null,
        category: Category.konkur,
        completion: completion,
        priority: 1.2,
        deepLink:
            AgendaDeepLink(domain: AgendaDomain.konkur, targetId: item.id),
        meta: {'planItem': item.toMap()},
      );
    }).toList();
  }

  AgendaItem? _collectCycle(
    _AgendaContext ctx,
    DateTime date,
    String dateStr,
    bool isToday,
  ) {
    final out = ctx.cycleOutput;
    if (out == null || !out.hasData) return null;

    final day = DateTime(date.year, date.month, date.day);
    bool inWindow(DateTime start, DateTime end) {
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      return !day.isBefore(s) && !day.isAfter(e);
    }

    String? title;
    if (isToday && out.dayOfPeriod > 0) {
      title = 'چرخه ماهانه (روز ${out.dayOfPeriod})';
    } else if (inWindow(out.nextPeriodWindowStart, out.nextPeriodWindowEnd)) {
      title = 'پیش‌بینی شروع دوره';
    } else if (inWindow(out.pmsWindowStart, out.pmsWindowEnd)) {
      title = 'پنجره‌ی PMS';
    } else if (inWindow(out.fertileWindowStart, out.fertileWindowEnd)) {
      title = 'پنجره‌ی باروری';
    }

    if (title == null) return null;

    return AgendaItem(
      id: 'cycle:$dateStr',
      domain: AgendaDomain.cycle,
      sourceId: dateStr,
      title: title,
      dateStr: dateStr,
      category: Category.personal,
      priority: 0.8,
      deepLink: AgendaDeepLink(domain: AgendaDomain.cycle, targetId: dateStr),
    );
  }

  List<AgendaItem> _collectSports(
    _AgendaContext ctx,
    String dateStr,
    DateTime date,
  ) {
    final items = <AgendaItem>[];
    final plans = ctx.sportsPlansByDay[date.weekday] ?? const [];
    for (final plan in plans) {
      final id = plan['id'] as String;
      final estMins = plan['estimatedMinutes'] as int? ?? 45;
      final muscleGroups = plan['muscleGroups'] as String? ?? 'تمرین ورزشی';
      items.add(AgendaItem(
        id: 'sport:plan:$id',
        domain: AgendaDomain.sport,
        sourceId: id,
        title: 'برنامه ورزشی: $muscleGroups',
        subtitle: '$estMins دقیقه',
        dateStr: dateStr,
        durationMinutes: estMins,
        category: Category.fitness,
        priority: 1.4,
        deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: id),
        meta: {'workoutPlan': plan},
      ));
    }
    return items;
  }

  List<AgendaItem> _collectMedicine(
    _AgendaContext ctx,
    String dateStr,
    bool isToday,
  ) {
    final items = <AgendaItem>[];
    final logs = ctx.medicineLogsByDate[dateStr] ?? const [];
    for (final log in logs) {
      final id = log['id'] as String;
      final status = log['status'] as String? ?? 'TAKEN';
      final isDone = status == 'TAKEN';
      items.add(AgendaItem(
        id: 'medicine:log:$id',
        domain: AgendaDomain.medicine,
        sourceId: id,
        title: 'یادآور دارو',
        subtitle: log['note'] as String?,
        dateStr: dateStr,
        durationMinutes: 5,
        category: Category.medical,
        completion: isDone ? AgendaCompletion.done : AgendaCompletion.pending,
        priority: 2.0,
        isEssential: true,
        deepLink: AgendaDeepLink(domain: AgendaDomain.medicine, targetId: id),
        meta: {'medicationLog': log},
      ));
    }
    return items;
  }

  DateTime? _parseDateTime(String dateStr, String? timeStr, {bool nextDayIfBefore = false, DateTime? referenceTime}) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      final date = DateTime.parse(dateStr);
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      var dt = DateTime(date.year, date.month, date.day, hour, minute);
      if (nextDayIfBefore && referenceTime != null && dt.isBefore(referenceTime)) {
        dt = dt.add(const Duration(days: 1));
      }
      return dt;
    } catch (_) {
      return null;
    }
  }
}

/// Shared, range-scoped data loaded once and reused across every day.
class _AgendaContext {

  _AgendaContext({
    required this.db,
    required this.settingsMap,
    required this.religionEnabled,
    required this.coursesEnabled,
    required this.konkurEnabled,
    required this.cycleAllowed,
    required this.sportsEnabled,
    required this.medicineEnabled,
    this.taskSource,
    required this.routineSource,
    required this.worshipSource,
    required this.completionsByDate,
    required this.courseTitles,
    required this.coursesMap,
    required this.sessionsByDate,
    required this.konkurByDate,
    required this.konkurSubjectNames,
    required this.cycleOutput,
    required this.goalStepsByDate,
    required this.sportsPlansByDay,
    required this.medicineLogsByDate,
    required this.latitude,
    required this.longitude,
    required this.ihtiyatMinutes,
    required this.calcMethodStr,
  });
  final Database db;
  final Map<String, String> settingsMap;
  final bool religionEnabled;
  final bool coursesEnabled;
  final bool konkurEnabled;
  final bool cycleAllowed;
  final bool sportsEnabled;
  final bool medicineEnabled;
  final TaskAgendaSource? taskSource;
  final RoutineAgendaSource routineSource;
  final Map<String, Map<String, Map<String, dynamic>>> completionsByDate;
  final WorshipAgendaSource worshipSource;
  final Map<String, String> courseTitles;
  final Map<String, Course> coursesMap;
  final Map<String, List<CourseSession>> sessionsByDate;
  final Map<String, List<KonkurPlanItem>> konkurByDate;
  final Map<String, String> konkurSubjectNames;
  final CycleEngineOutput? cycleOutput;
  final Map<String, List<Map<String, dynamic>>> goalStepsByDate;
  final Map<int, List<Map<String, dynamic>>> sportsPlansByDay;
  final Map<String, List<Map<String, dynamic>>> medicineLogsByDate;

  final double latitude;
  final double longitude;
  final int ihtiyatMinutes;
  final String calcMethodStr;

  /// Prayer-times cache keyed by `cityId|date`.
  final Map<String, Map<String, String>> _prayerCache = {};

  Future<Map<String, String>> prayerTimesFor(DateTime date) async {
    final cityId = settingsMap['prayer_city_id'] ??
        settingsMap['home_city_id'] ??
        'TEHRAN_TEHRAN';
    final ds = date.toIso8601String().substring(0, 10);
    final key = '$cityId|$ds';
    final cached = _prayerCache[key];
    if (cached != null) return cached;
    try {
      final times = PrayerTimeProvider.instance.computePrayerTimesLocally(
        latitude: latitude,
        longitude: longitude,
        calcMethodStr: calcMethodStr,
        date: date,
      );
      _prayerCache[key] = times;
      return times;
    } catch (e) {
      debugPrint('DayAgendaService prayer times error: $e');
      _prayerCache[key] = const {};
      return const {};
    }
  }
}
