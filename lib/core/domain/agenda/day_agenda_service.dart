import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/agenda_source_registry.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/task_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/worship_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/sports_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/medicine_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/goal_steps_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/course_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/konkur_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/cycle_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/prayer_time_provider.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';

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

  @visibleForTesting
  DayAgendaService.test();

  static final DayAgendaService instance = DayAgendaService._();

  /// Small per-date cache (invalidated reactively via the event bus).
  ///
  /// C-FIX-4: only *non-empty* days are ever stored here. See [agendaForRange].
  final Map<String, DayAgenda> _cache = {};

  int _dataRevision = 0;
  static const int _maxEmptyDaysCache = 400;
  final Map<String, int> _emptyDays = {};

  int get dataRevision => _dataRevision;

  AgendaLoadStatus _lastStatus = const AgendaLoadStatus.ok();
  AgendaLoadStatus get lastLoadStatus => _lastStatus;

  /// Completion-style events fired outside the routine kernel. The kernel
  /// already refreshes the UI for its own routine events, so for these we both
  /// invalidate the cache *and* fan out a single UI refresh signal. Routine
  /// events only invalidate the cache (no double refresh).
  ///
  /// INVARIANT: an event that `RitmoEvents.notifyRoutineChanged()` itself emits
  /// must never appear in this set. Refreshing in response to our own signal is
  /// a cycle by construction, and no debounce can end it - only bound its rate.
  static const Set<String> _uiRefreshEvents = {
    'CourseSessionCompleted',
    'CourseCreated',
    'CourseUpdated',
    'GoalStepToggled',
    'GoalUpdated',
    'TaskToggled',
    'TaskUpdated',
    'TaskCreated',
    'task_created',
    'task_updated',
    'EventCreated',
    'PrayerCompleted',
    'WorshipUpdated',
    'WorshipPracticeChanged',
    'ReflectionChanged',
    'RoutineCreated',
    'RoutineEdited',
    'RoutineUpdated',
    // 'RoutineChanged' is deliberately absent: notifyRoutineChanged() fires it
    // (models.dart), so answering it with another notify closed the loop
    // notify -> bus -> here -> notify -> ... which froze the UI inside the
    // microtask queue and exhausted the heap. Cache invalidation below still
    // handles the event; invalidation is idempotent and emits nothing.
    'RoutineDeleted',
    'DataImported',
    'DayRolledOver',
    'completion_recorded',
    'AgendaItemToggled',
    'commitmentChanged',
    'planningCycleActivated',
    'ReshuffleApplied',
  };

  static const Set<String> _cacheInvalidatingEvents = {
    'CourseSessionCompleted',
    'CourseCreated',
    'CourseUpdated',
    'GoalStepToggled',
    'GoalUpdated',
    'TaskToggled',
    'TaskUpdated',
    'TaskCreated',
    'task_created',
    'task_updated',
    'EventCreated',
    'PrayerCompleted',
    'WorshipUpdated',
    'WorshipPracticeChanged',
    'ReflectionChanged',
    'RoutineCompleted',
    'RoutineSkipped',
    'RoutineCreated',
    'RoutineEdited',
    'RoutineUpdated',
    'RoutineChanged',
    'RoutineDeleted',
    'CycleStarted',
    'CycleEnded',
    'DayRolledOver',
    'DataImported',
    'completion_recorded',
    'AgendaItemToggled',
    'commitmentChanged',
    'planningCycleActivated',
    'ReshuffleApplied',
  };

  void _subscribeToEvents() {
    RitmoEventBus().onEvents.listen((event) {
      if (!_cacheInvalidatingEvents.contains(event.type)) return;

      final date =
          (event.payload['date'] ?? event.payload['dateStr']) as String?;
      if (event.type == 'DayRolledOver' || event.type == 'DataImported') {
        invalidateAll();
      } else if (date != null) {
        invalidateDate(date);
      } else {
        invalidateAll();
      }

      if (_uiRefreshEvents.contains(event.type)) {
        _scheduleUiRefresh();
      }
    });
  }

  // ۲۴ نوع رویداد به یک ValueNotifier استاتیک قیف میشوند که شنوندههایش
  // «همگام» یک لود کامل داشبورد را شروع میکنند. چون خودِ آن لود در DB
  // مینویسد و رویداد جدید fire میکند، نوتیفایکردن از داخل این callback
  // یک حلقهٔ خودتغذیه در صف microtask میسازد: event loop هرگز کنترل را
  // پس نمیگیرد (فریز) و هر دور یک کنترلر و snapshot نو میسازد (OOM).
  // سه قانون آن را برای همیشه میبندد:
  //   ۱) هرگز از داخل callback استریم نوتیفای نکن؛ به Timer (macrotask) بپر
  //      تا فریمها بین دورها رندر شوند.
  //   ۲) رویدادهایی که خودِ همین رفرش تولید میکند را بیاثر کن.
  //   ۳) و مهمتر از همه: به رویدادی که خودِ notifyRoutineChanged() صادر
  //      میکند («RoutineChanged») هرگز پاسخ نده. آن حلقه ذاتی است و
  //      debounce فقط نرخش را محدود میکند، تمامش نمیکند.
  static Timer? _uiRefreshTimer;
  static bool _uiRefreshInFlight = false;
  static const Duration _uiRefreshDebounce = Duration(milliseconds: 350);
  static const Duration _uiRefreshCooldown = Duration(milliseconds: 1500);

  void _scheduleUiRefresh() {
    if (_uiRefreshInFlight) return;
    _uiRefreshTimer?.cancel();
    _uiRefreshTimer = Timer(_uiRefreshDebounce, () {
      _uiRefreshInFlight = true;
      try {
        RitmoEvents.notifyRoutineChanged();
      } finally {
        Timer(_uiRefreshCooldown, () => _uiRefreshInFlight = false);
      }
    });
  }

  /// Drop the whole cache (e.g. on broad data changes).
  void invalidateAll() {
    _cache.clear();
    _emptyDays.clear();
    _dataRevision++;
  }

  /// Drop a single date's cached agenda.
  void invalidateDate(String dateStr) {
    _cache.remove(dateStr);
    _emptyDays.remove(dateStr);
    _dataRevision++;
  }

  Future<DayAgenda> agendaForDate(
    DateTime date, {
    AgendaQueryOptions? options,
  }) async {
    final ds = DateKey.of(date);
    final map = await agendaForRange(date, date, options: options);
    return map[ds] ?? DayAgenda.empty(ds);
  }

  Future<Map<String, DayAgenda>> agendaForRange(
    DateTime start,
    DateTime end, {
    AgendaQueryOptions? options,
  }) async {
    final opts = options ?? const AgendaQueryOptions();
    final result = <String, DayAgenda>{};

    final dates = <DateTime>[];
    var d = DateKey.dayOf(start);
    final endD = DateKey.dayOf(end);
    while (!d.isAfter(endD)) {
      dates.add(d);
      d = DateKey.addDays(d, 1);
    }

    final failures = <String>[];
    _AgendaContext ctx;
    try {
      ctx = await _buildContext(start, end, opts, failures);
    } catch (e, st) {
      RitmoLog.error('DayAgendaService', 'fatal context build failure', e, st);
      if (!failures.contains('context')) failures.add('context');
      _lastStatus = AgendaLoadStatus(failedSources: failures, fatal: true);
      for (final date in dates) {
        final ds = DateKey.of(date);
        result.putIfAbsent(
          ds,
          () => DayAgenda.empty(ds),
        );
      }
      return result;
    }

    DateTime? appStartDate;
    if (ctx.settingsMap['app_start_date'] != null) {
      final parsed = DateKey.parse(ctx.settingsMap['app_start_date']!) ?? DateTime.tryParse(ctx.settingsMap['app_start_date']!);
      if (parsed != null) {
        appStartDate = DateKey.dayOf(parsed);
      }
    }

    final cacheEligible = opts.domains.isEmpty && opts.includeCompleted;
    var servedFromCache = 0;

    for (final date in dates) {
      final ds = DateKey.of(date);

      // ROOT FIX: Avoid generating routines/prayers for days before the app was installed.
      if (appStartDate != null && date.isBefore(appStartDate)) {
        result[ds] = DayAgenda.empty(ds);
        continue;
      }

      // Cache only the full, unfiltered agenda; filtered queries are rebuilt.
      if (cacheEligible && _cache.containsKey(ds)) {
        result[ds] = _cache[ds]!;
        servedFromCache++;
        continue;
      }

      // Negative cache with data revision timestamp (CAL-40):
      // Empty days are remembered within the current data revision. Any data
      // mutation increments _dataRevision, invalidating all negative cache entries,
      // which preserves the C-FIX-4 invariant (never making empty days permanently sticky).
      if (cacheEligible && _emptyDays[ds] == _dataRevision) {
        result[ds] = DayAgenda.empty(ds);
        servedFromCache++;
        continue;
      }

      try {
        final agenda = await _assembleDay(date, ds, ctx, opts, failures);

        if (cacheEligible) {
          if (agenda.items.isNotEmpty) {
            _cache[ds] = agenda;
          } else {
            if (_emptyDays.length >= _maxEmptyDaysCache) {
              _emptyDays.clear();
            }
            _emptyDays[ds] = _dataRevision;
          }
        }
        result[ds] = agenda;
      } catch (e, st) {
        RitmoLog.error('DayAgendaService', 'assembleDay failed for $ds', e, st);
        failures.add('day:$ds');
        result[ds] = DayAgenda.empty(ds);
      }
    }
    _lastStatus = AgendaLoadStatus(failedSources: failures, fatal: false);

    // One greppable line that makes "why is the agenda empty?" answerable.
    var totalItems = 0;
    for (final agenda in result.values) {
      totalItems += agenda.items.length;
    }
    RitmoLog.info(
      'DayAgendaService',
      'range ${DateKey.of(start)}..${DateKey.of(end)} '
      'days=${result.length} items=$totalItems cached=$servedFromCache '
      'routines=${ctx.routineSource.routines.length} '
      'schedules=${ctx.routineSource.schedules.length} '
      'occurrences=${ctx.routineSource.occurrences.length} '
      'failures=$failures',
    );

    return result;
  }

  /// Counts uncompleted actionable items with date strictly before [cutoff].
  Future<int> countOverdueBefore(DateTime cutoff) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final cutoffStr = DateKey.of(cutoff);

      // 1. Simple tasks overdue
      final taskRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM simple_tasks WHERE isDone = 0 AND dueDate IS NOT NULL AND dueDate < ?',
        [cutoffStr],
      );
      int taskCount = 0;
      if (taskRes.isNotEmpty) {
        taskCount = (taskRes.first['cnt'] as num?)?.toInt() ?? 0;
      }

      // 2. Study topics overdue for review
      int studyCount = 0;
      try {
        final studyRes = await db.rawQuery(
          "SELECT COUNT(*) as cnt FROM konkur_topics WHERE nextReviewDate IS NOT NULL AND nextReviewDate < ? AND isArchived = 0",
          [cutoffStr],
        );
        if (studyRes.isNotEmpty) {
          studyCount = (studyRes.first['cnt'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      // 3. Course sessions overdue
      int courseCount = 0;
      try {
        final courseRes = await db.rawQuery(
          "SELECT COUNT(*) as cnt FROM course_sessions WHERE completionStatus = 'pending' AND plannedDate IS NOT NULL AND plannedDate < ?",
          [cutoffStr],
        );
        if (courseRes.isNotEmpty) {
          courseCount = (courseRes.first['cnt'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      return taskCount + studyCount + courseCount;
    } catch (e, st) {
      RitmoLog.error('DayAgendaService', 'countOverdueBefore error', e, st);
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Context (loaded once per range)
  // ---------------------------------------------------------------------------

  Future<_AgendaContext> _buildContext(
    DateTime start,
    DateTime end,
    AgendaQueryOptions opts,
    List<String> failures,
  ) async {
    final db = await DatabaseHelper.instance.database;

    final settings = await db.query('app_settings');
    final settingsMap = <String, String>{
      for (final s in settings)
        if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? '',
    };

    final routinesEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_today_routines',
    );
    final goalsEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_goals_enabled',
    );
    final commitmentsEnabled =
        goalsEnabled && settingsMap['calendar_show_commitments'] != 'false';
    final tasksEnabled =
        routinesEnabled && settingsMap['calendar_show_tasks'] != 'false';
    final eventsEnabled =
        routinesEnabled && settingsMap['calendar_show_events'] != 'false';
    final religionEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_religion_enabled',
    );
    final coursesEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_courses_enabled',
    );
    final konkurEnabled =
        ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_study_enabled',
        ) &&
        settingsMap['konkur_show_in_dashboard'] != 'false';
    final sportsEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_supplementary_sports_enabled',
    );
    final medicineEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_medicine_enabled',
    );
    final appointmentsEnabled =
        medicineEnabled && settingsMap['calendar_show_appointments'] != 'false';

    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_cycle_enabled',
    );
    final cycleConsent = settingsMap['cycle_consent_dashboard'] == 'true';
    final cycleSetupDone = settingsMap['cycle_setup_done'] == 'true';
    final showCycleInCalendar = settingsMap['show_cycle_in_calendar'] == 'true';
    final cycleAllowed =
        isFemale &&
        cycleEnabled &&
        cycleConsent &&
        cycleSetupDone &&
        showCycleInCalendar;

    final startStr = DateKey.of(start);
    final endStr = DateKey.of(end);
    final todayStr = DateKey.today();

    final loadCtx = AgendaSourceLoadContext(
      db: db,
      settingsMap: settingsMap,
      start: start,
      end: end,
      startStr: startStr,
      endStr: endStr,
      todayStr: todayStr,
      options: opts,
      failures: failures,
    );

    final sources = await AgendaSourceRegistry.instance.loadSources(loadCtx);

    // Defensive lookups: a wrong runtime type must degrade a single source,
    // never abort the whole range build with a cast error.
    final routineSource =
        _sourceOf<RoutineAgendaSource>(sources, 'routine') ??
        RoutineAgendaSource.disabled();
    final worshipSource =
        _sourceOf<WorshipAgendaSource>(sources, 'worship') ??
        WorshipAgendaSource.disabled(settingsMap, db);
    final sportsSource =
        _sourceOf<SportsAgendaSource>(sources, 'sports') ??
        SportsAgendaSource.disabled(db);
    final medicineSource =
        _sourceOf<MedicineAgendaSource>(sources, 'medicine') ??
        MedicineAgendaSource.disabled();
    final goalStepsSource =
        _sourceOf<GoalStepsAgendaSource>(sources, 'goalSteps') ??
        GoalStepsAgendaSource.empty();
    final taskSource = _sourceOf<TaskAgendaSource>(sources, 'task');
    final courseSource =
        _sourceOf<CourseAgendaSource>(sources, 'course') ??
        CourseAgendaSource.disabled();
    final konkurSource =
        _sourceOf<KonkurAgendaSource>(sources, 'konkur') ??
        KonkurAgendaSource.disabled();
    final cycleSource =
        _sourceOf<CycleAgendaSource>(sources, 'cycle') ??
        const CycleAgendaSource(cycleOutput: null, cycleAllowed: false);

    final cityId =
        settingsMap['prayer_city_id'] ??
        settingsMap['home_city_id'] ??
        'TEHRAN_TEHRAN';

    // This lookup used to run unguarded: any failure here (missing/locked table
    // on a fresh install) aborted the entire range as a fatal context failure.
    var cityResult = const <Map<String, Object?>>[];
    try {
      cityResult = await db.query(
        'iran_cities',
        where: 'id = ?',
        whereArgs: [cityId],
        limit: 1,
      );
    } catch (e, st) {
      RitmoLog.error(
        'DayAgendaService',
        'iran_cities lookup failed for $cityId',
        e,
        st,
      );
    }

    var latitude = 35.6892;
    var longitude = 51.3890;

    if (cityResult.isNotEmpty) {
      final lat = cityResult.first['latitude'];
      final lng = cityResult.first['longitude'];
      if (lat is num) latitude = lat.toDouble();
      if (lng is num) longitude = lng.toDouble();
    }

    final calcMethodStr =
        settingsMap['prayer_calculation_method'] ?? 'TEHRAN_GEOPHYSICS';

    final dayMarksByDate = <String, String>{};
    try {
      // day_marks فقط در migration v83 ساخته میشود، پس روی نصب تازه غایب است.
      // خودترمیمی، بهجای پرتکردن استکتریس در هر بار ساخت اجندا.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS day_marks (
            date TEXT PRIMARY KEY,
            kind TEXT NOT NULL DEFAULT 'NORMAL',
            note TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
        );
      ''');
      final markRows = await db.query(
        'day_marks',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startStr, endStr],
      );
      for (final r in markRows) {
        final d = r['date']?.toString();
        final k = r['kind']?.toString();
        if (d != null && k != null) dayMarksByDate[d] = k;
      }
    } catch (e) {
      RitmoLog.error('DayAgendaService', 'day_marks load failed', e);
    }

    Map<String, List<OccurrenceOverride>> overridesByDate = {};
    try {
      const overrideRepo = SqliteOccurrenceOverrideRepository();
      overridesByDate = await overrideRepo.forRange(startStr, endStr);
    } catch (e) {
      RitmoLog.error(
        'DayAgendaService',
        'Failed to load occurrence overrides',
        e,
      );
    }

    return _AgendaContext(
      settingsMap: settingsMap,
      routinesEnabled: routinesEnabled,
      goalsEnabled: goalsEnabled,
      commitmentsEnabled: commitmentsEnabled,
      tasksEnabled: tasksEnabled,
      eventsEnabled: eventsEnabled,
      religionEnabled: religionEnabled,
      coursesEnabled: coursesEnabled,
      konkurEnabled: konkurEnabled,
      cycleAllowed: cycleAllowed,
      sportsEnabled: sportsEnabled,
      medicineEnabled: medicineEnabled,
      appointmentsEnabled: appointmentsEnabled,
      taskSource: taskSource,
      routineSource: routineSource,
      worshipSource: worshipSource,
      sportsSource: sportsSource,
      medicineSource: medicineSource,
      goalStepsSource: goalStepsSource,
      courseSource: courseSource,
      konkurSource: konkurSource,
      cycleSource: cycleSource,
      allSources: sources,
      dayMarksByDate: dayMarksByDate,
      overridesByDate: overridesByDate,
      latitude: latitude,
      longitude: longitude,
      calcMethodStr: calcMethodStr,
    );
  }

  /// Type-safe registry lookup: returns null instead of throwing when a key is
  /// missing or holds an unexpected source type.
  static T? _sourceOf<T extends AgendaSource>(
    Map<String, AgendaSource> sources,
    String key,
  ) {
    final source = sources[key];
    if (source is T) return source;
    if (source != null) {
      RitmoLog.error(
        'DayAgendaService',
        'agenda source "$key" has unexpected type ${source.runtimeType}',
        StateError('unexpected agenda source type'),
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Per-day assembly
  // ---------------------------------------------------------------------------

  Future<DayAgenda> _assembleDay(
    DateTime date,
    String dateStr,
    _AgendaContext ctx,
    AgendaQueryOptions opts,
    List<String> failures,
  ) async {
    final todayStr = DateKey.today();
    final isToday = dateStr == todayStr;
    final prayerTimes = await ctx.prayerTimesFor(date);
    var items = <AgendaItem>[];

    final enabledDomains = <AgendaDomain, bool>{
      AgendaDomain.routine: ctx.routinesEnabled,
      AgendaDomain.event: ctx.eventsEnabled,
      AgendaDomain.prayer: ctx.religionEnabled,
      AgendaDomain.mustahab: ctx.religionEnabled,
      AgendaDomain.worshipDebt: ctx.religionEnabled && opts.includeWorshipDebt,
      AgendaDomain.course: ctx.coursesEnabled,
      AgendaDomain.goalStep: ctx.goalsEnabled,
      AgendaDomain.commitment: ctx.commitmentsEnabled,
      AgendaDomain.konkur: ctx.konkurEnabled,
      AgendaDomain.cycle: ctx.cycleAllowed,
      AgendaDomain.sport: ctx.sportsEnabled,
      AgendaDomain.medicine: ctx.medicineEnabled,
      AgendaDomain.appointment: ctx.appointmentsEnabled,
      AgendaDomain.task: ctx.tasksEnabled,
    };

    final agendaCtx = AgendaDayContext(
      date: date,
      dateStr: dateStr,
      isToday: isToday,
      prayerTimes: prayerTimes,
      options: opts,
    );

    final degradedDomains = <AgendaDomain>{};

    void safeCollect(
      String label,
      Set<AgendaDomain> domains,
      List<AgendaItem> Function() collect,
    ) {
      try {
        items.addAll(collect());
      } catch (e, st) {
        RitmoLog.error(
          'DayAgendaService',
          'source "$label" itemsForDate failed for $dateStr',
          e,
          st,
        );
        final key = 'items:$label';
        if (!failures.contains(key)) failures.add(key);
        degradedDomains.addAll(domains);
      }
    }

    // Apply the activeWorshipTitles filter for routineSource
    final activeWorshipTitles = <String>{};
    try {
      if (ctx.worshipSource.isEnabled) {
        for (final p in ctx.worshipSource.prayerPractices) {
          final title = p['title'] as String?;
          if (title != null) activeWorshipTitles.add(title.trim());
        }
        for (final p in ctx.worshipSource.mustahabPractices) {
          final title = p['title'] as String?;
          if (title != null) activeWorshipTitles.add(title.trim());
        }
      }
    } catch (e, st) {
      RitmoLog.error(
        'DayAgendaService',
        'worship title filter failed for $dateStr',
        e,
        st,
      );
    }

    safeCollect('routine', {AgendaDomain.routine}, () {
      final routines = ctx.routineSource.itemsForDate(agendaCtx);
      return routines
          .where((r) => !activeWorshipTitles.contains(r.title.trim()))
          .toList();
    });

    safeCollect('worship', {
      AgendaDomain.prayer,
      AgendaDomain.mustahab,
      AgendaDomain.worshipDebt,
    }, () => ctx.worshipSource.itemsForDate(agendaCtx));
    safeCollect('sports', {
      AgendaDomain.sport,
    }, () => ctx.sportsSource.itemsForDate(agendaCtx));
    safeCollect('medicine', {
      AgendaDomain.medicine,
    }, () => ctx.medicineSource.itemsForDate(agendaCtx));
    safeCollect('goalSteps', {
      AgendaDomain.goalStep,
    }, () => ctx.goalStepsSource.itemsForDate(agendaCtx));

    final taskSource = ctx.taskSource;
    if (taskSource != null) {
      safeCollect('task', {
        AgendaDomain.task,
      }, () => taskSource.itemsForDate(agendaCtx));
    }

    safeCollect('course', {
      AgendaDomain.course,
    }, () => ctx.courseSource.itemsForDate(agendaCtx));
    safeCollect('konkur', {
      AgendaDomain.konkur,
    }, () => ctx.konkurSource.itemsForDate(agendaCtx));
    safeCollect('cycle', {
      AgendaDomain.cycle,
    }, () => ctx.cycleSource.itemsForDate(agendaCtx));

    // Additional / custom registered sources (e.g. from tests or new modules)
    const standardKeys = {
      'routine',
      'worship',
      'sports',
      'medicine',
      'goalSteps',
      'task',
      'course',
      'konkur',
      'cycle',
    };
    for (final entry in ctx.allSources.entries) {
      if (!standardKeys.contains(entry.key)) {
        safeCollect(
          entry.key,
          entry.value.domains,
          () => entry.value.itemsForDate(agendaCtx),
        );
      }
    }

    // Apply occurrence overrides (single-day moves, resizes, skips)
    final dayOverrides =
        ctx.overridesByDate[dateStr] ?? const <OccurrenceOverride>[];
    if (dayOverrides.isNotEmpty) {
      final overrideMap = <String, OccurrenceOverride>{};
      for (final ovr in dayOverrides) {
        overrideMap[OccurrenceOverride.formatKey(ovr.sourceType, ovr.sourceId)] = ovr;
      }

      final matchedKeys = <String>{};
      items = items.map((item) {
        final key = OccurrenceOverride.formatKey(item.domain.name, item.sourceId);
        final ovr = overrideMap[key];
        if (ovr == null) return item;

        matchedKeys.add(key);
        var updated = item.copyWith(hasOverride: true);
        if (ovr.status == 'SKIPPED') {
          updated = updated.copyWith(completion: AgendaCompletion.skipped);
        }
        if (ovr.timeOfDay != null && ovr.timeOfDay!.isNotEmpty) {
          updated = updated.copyWith(
            timeOfDay: ovr.timeOfDay,
            itemType: AgendaItemType.fixed,
          );
        }
        if (ovr.durationMinutes != null && ovr.durationMinutes! > 0) {
          updated = updated.copyWith(durationMinutes: ovr.durationMinutes);
        }
        return updated;
      }).toList();

      // Bug 2 & Risk 1: Synthesize virtual occurrence ONLY for cross-day MOVED overrides
      for (final ovr in dayOverrides) {
        final key = OccurrenceOverride.formatKey(ovr.sourceType, ovr.sourceId);
        if (ovr.status == 'MOVED' && !matchedKeys.contains(key)) {
          // Check if this override originated from a different date
          final isCrossDayMove = ovr.note?.startsWith('from:') == true ||
              (ovr.note != null && ovr.note!.isNotEmpty && ovr.note != 'TIME_OVERRIDE');
          if (!isCrossDayMove) {
            // Intra-day override without host item should NOT synthesize a ghost item
            continue;
          }

          String title = 'رویداد انتقال‌یافته';
          if (ovr.note != null && !ovr.note!.startsWith('from:')) {
            title = ovr.note!;
          }
          int duration = ovr.durationMinutes ?? 30;
          if (ovr.sourceType.toLowerCase() == 'routine') {
            final rMatch = ctx.routineSource.routines.firstWhere(
              (r) => r['id']?.toString() == ovr.sourceId,
              orElse: () => const {},
            );
            if (rMatch.isEmpty) {
              // Routine was deleted or does not exist; do not synthesize ghost item
              continue;
            }
            if (rMatch['title'] != null) {
              title = rMatch['title'].toString();
              if (ovr.durationMinutes == null && rMatch['targetDuration'] is num) {
                duration = (rMatch['targetDuration'] as num).toInt();
              }
            }
          }

          final domainIndex = AgendaDomain.values.indexWhere(
            (d) => d.name.toLowerCase() == ovr.sourceType.toLowerCase(),
          );
          if (domainIndex == -1) {
            RitmoLog.warning(
              'DayAgendaService',
              'Unknown domain in override: ${ovr.sourceType}',
            );
            continue;
          }
          final domain = AgendaDomain.values[domainIndex];
          final virtualItem = AgendaItem(
            id: 'moved_${ovr.sourceType}_${ovr.sourceId}_$dateStr',
            domain: domain,
            sourceId: ovr.sourceId,
            title: title,
            dateStr: dateStr,
            timeOfDay: ovr.timeOfDay,
            durationMinutes: duration,
            category: Category.personal,
            deepLink: AgendaDeepLink(domain: domain, targetId: ovr.sourceId),
            itemType: (ovr.timeOfDay != null && ovr.timeOfDay!.isNotEmpty)
                ? AgendaItemType.fixed
                : AgendaItemType.flexible,
            completion: AgendaCompletion.pending,
            hasOverride: true,
          );
          items.add(virtualItem);
        }
      }
    }

    // K43: Apply REST/TRAVEL day effect — mark non-essential items as skipped.
    final dayMark = ctx.dayMarksByDate[dateStr];
    List<AgendaItem> finalItems = items;
    if (dayMark == 'REST' || dayMark == 'TRAVEL') {
      finalItems = items.map((item) {
        if (!item.isEssential &&
            (item.completion == AgendaCompletion.none ||
             item.completion == AgendaCompletion.pending)) {
          return item.copyWith(completion: AgendaCompletion.skipped);
        }
        return item;
      }).toList();
    }

    final filtered = opts.includeCompleted
        ? finalItems
        : finalItems.where((i) {
            return i.completion != AgendaCompletion.done &&
                i.completion != AgendaCompletion.partial &&
                i.completion != AgendaCompletion.skipped;
          }).toList();

    _sortItems(filtered);

    return DayAgenda(
      dateStr: dateStr,
      items: filtered,
      enabledDomains: enabledDomains,
      degradedSources: degradedDomains,
    );
  }

  /// Timed items first (by time), then untimed by descending priority.
  void _sortItems(List<AgendaItem> items) {
    items.sort((a, b) {
      int? aM;
      if (a.isTimed) {
        aM = TimeOfDayMinutes.tryParse(a.timeOfDay);
        if (aM == null) {
          RitmoLog.error('DayAgendaService', 'Invalid timeOfDay for item ${a.id}: "${a.timeOfDay}"');
        }
      }
      int? bM;
      if (b.isTimed) {
        bM = TimeOfDayMinutes.tryParse(b.timeOfDay);
        if (bM == null) {
          RitmoLog.error('DayAgendaService', 'Invalid timeOfDay for item ${b.id}: "${b.timeOfDay}"');
        }
      }
      if (aM != null && bM != null) {
        final cmp = aM.compareTo(bM);
        return cmp != 0 ? cmp : a.id.compareTo(b.id);
      }
      if (aM != null) return -1;
      if (bM != null) return 1;
      final pCmp = b.priority.compareTo(a.priority);
      return pCmp != 0 ? pCmp : a.id.compareTo(b.id);
    });
  }

  // ---------------------------------------------------------------------------
  // Collectors
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
}

/// Shared, range-scoped data loaded once and reused across every day.
class _AgendaContext {
  _AgendaContext({
    required this.settingsMap,
    required this.routinesEnabled,
    required this.goalsEnabled,
    required this.commitmentsEnabled,
    required this.tasksEnabled,
    required this.eventsEnabled,
    required this.religionEnabled,
    required this.coursesEnabled,
    required this.konkurEnabled,
    required this.cycleAllowed,
    required this.sportsEnabled,
    required this.medicineEnabled,
    required this.appointmentsEnabled,
    required this.taskSource,
    required this.routineSource,
    required this.worshipSource,
    required this.sportsSource,
    required this.medicineSource,
    required this.goalStepsSource,
    required this.courseSource,
    required this.konkurSource,
    required this.cycleSource,
    required this.allSources,
    required this.dayMarksByDate,
    required this.overridesByDate,
    required this.latitude,
    required this.longitude,
    required this.calcMethodStr,
  });
  final Map<String, String> settingsMap;
  final bool routinesEnabled;
  final bool goalsEnabled;
  final bool commitmentsEnabled;
  final bool tasksEnabled;
  final bool eventsEnabled;
  final bool religionEnabled;
  final bool coursesEnabled;
  final bool konkurEnabled;
  final bool cycleAllowed;
  final bool sportsEnabled;
  final bool medicineEnabled;
  final bool appointmentsEnabled;
  final TaskAgendaSource? taskSource;
  final RoutineAgendaSource routineSource;
  final WorshipAgendaSource worshipSource;
  final SportsAgendaSource sportsSource;
  final MedicineAgendaSource medicineSource;
  final GoalStepsAgendaSource goalStepsSource;
  final CourseAgendaSource courseSource;
  final KonkurAgendaSource konkurSource;
  final CycleAgendaSource cycleSource;
  final Map<String, AgendaSource> allSources;
  final Map<String, String> dayMarksByDate;
  final Map<String, List<OccurrenceOverride>> overridesByDate;

  final double latitude;
  final double longitude;
  final String calcMethodStr;

  /// Prayer-times cache keyed by `cityId|date`.
  final Map<String, Map<String, String>> _prayerCache = {};

  Future<Map<String, String>> prayerTimesFor(DateTime date) async {
    final cityId =
        settingsMap['prayer_city_id'] ??
        settingsMap['home_city_id'] ??
        'TEHRAN_TEHRAN';
    final ds = DateKey.of(date);
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
      RitmoLog.error('DayAgendaService', 'prayer times error', e);
      _prayerCache[key] = const {};
      return const {};
    }
  }
}
