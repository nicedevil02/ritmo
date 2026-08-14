import 'package:flutter/foundation.dart';
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
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/prayer_time_provider.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';

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
  ///
  /// C-FIX-4: only *non-empty* days are ever stored here. See [agendaForRange].
  final Map<String, DayAgenda> _cache = {};

  AgendaLoadStatus _lastStatus = const AgendaLoadStatus.ok();
  AgendaLoadStatus get lastLoadStatus => _lastStatus;

  /// Completion-style events fired outside the routine kernel. The kernel
  /// already refreshes the UI for its own routine events, so for these we both
  /// invalidate the cache *and* fan out a single UI refresh signal. Routine
  /// events only invalidate the cache (no double refresh).
  static const Set<String> _uiRefreshEvents = {
    'CourseSessionCompleted',
    'CourseCreated',
    'CourseUpdated',
    'GoalStepToggled',
    'GoalUpdated',
    'TaskToggled',
    'TaskUpdated',
    'TaskCreated',
    'PrayerCompleted',
    'WorshipUpdated',
    'WorshipPracticeChanged',
    'RoutineCreated',
    'RoutineEdited',
    'RoutineUpdated',
    'RoutineChanged',
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
    'PrayerCompleted',
    'WorshipUpdated',
    'WorshipPracticeChanged',
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

    final failures = <String>[];
    _AgendaContext ctx;
    try {
      ctx = await _buildContext(start, end, opts, failures);
    } catch (e, st) {
      RitmoLog.error('DayAgendaService', 'fatal context build failure', e, st);
      if (!failures.contains('context')) failures.add('context');
      _lastStatus = AgendaLoadStatus(failedSources: failures, fatal: true);
      for (final date in dates) {
        result.putIfAbsent(_dateStr(date), () => DayAgenda.empty(_dateStr(date)));
      }
      return result;
    }

    DateTime? appStartDate;
    if (ctx.settingsMap['app_start_date'] != null) {
      final parsed = DateTime.tryParse(ctx.settingsMap['app_start_date']!);
      if (parsed != null) {
        appStartDate = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    final cacheEligible = opts.domains.isEmpty && opts.includeCompleted;
    var servedFromCache = 0;

    for (final date in dates) {
      final ds = _dateStr(date);

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
      try {
        final agenda = await _assembleDay(date, ds, ctx, opts, failures);

        // C-FIX-4: NEVER cache an empty day.
        //
        // This cache is only consulted by default-option callers, which in
        // practice means the Calendar; Home always passes an explicit `domains`
        // set and therefore recomputes every time. So a single early assembly
        // (e.g. a startup/widget/alarm path running while onboarding had not
        // yet inserted the starter routines) used to pin an empty DayAgenda in
        // here, and the Calendar kept serving that empty day for the rest of
        // the session: no exception, no failedSources, no degraded banner, just
        // a permanently blank agenda while Home and the routine vault looked
        // perfectly fine. Empty days are cheap to rebuild, so we only memoize
        // days that actually produced items. Emptiness must never be sticky.
        if (cacheEligible && agenda.items.isNotEmpty) {
          _cache[ds] = agenda;
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
    debugPrint(
      '[DayAgendaService] range ${_dateStr(start)}..${_dateStr(end)} '
      'days=${result.length} items=$totalItems cached=$servedFromCache '
      'routines=${ctx.routineSource.routines.length} '
      'schedules=${ctx.routineSource.schedules.length} '
      'occurrences=${ctx.routineSource.occurrences.length} '
      'failures=$failures',
    );

    return result;
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
      for (final s in settings) if (s['key'] != null) s['key'].toString(): s['value']?.toString() ?? ''
    };

    final routinesEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_today_routines');
    final goalsEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_goals_enabled');
    final tasksEnabled = routinesEnabled && settingsMap['calendar_show_tasks'] != 'false';
    final eventsEnabled = routinesEnabled && settingsMap['calendar_show_events'] != 'false';
    final religionEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_religion_enabled');
    final coursesEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_courses_enabled');
    final konkurEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_study_enabled') &&
        settingsMap['konkur_show_in_dashboard'] != 'false';
    final sportsEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_supplementary_sports_enabled');
    final medicineEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_medicine_enabled');

    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_cycle_enabled');
    final cycleConsent = settingsMap['cycle_consent_dashboard'] == 'true';
    final cycleSetupDone = settingsMap['cycle_setup_done'] == 'true';
    final showCycleInCalendar = settingsMap['show_cycle_in_calendar'] == 'true';
    final cycleAllowed =
        isFemale && cycleEnabled && cycleConsent && cycleSetupDone && showCycleInCalendar;

    final startStr = _dateStr(start);
    final endStr = _dateStr(end);
    final todayStr = _dateStr(DateTime.now());

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
    final routineSource = _sourceOf<RoutineAgendaSource>(sources, 'routine') ?? RoutineAgendaSource.disabled();
    final worshipSource = _sourceOf<WorshipAgendaSource>(sources, 'worship') ?? WorshipAgendaSource.disabled(settingsMap, db);
    final sportsSource = _sourceOf<SportsAgendaSource>(sources, 'sports') ?? SportsAgendaSource.disabled(db);
    final medicineSource = _sourceOf<MedicineAgendaSource>(sources, 'medicine') ?? MedicineAgendaSource.disabled();
    final goalStepsSource = _sourceOf<GoalStepsAgendaSource>(sources, 'goalSteps') ?? GoalStepsAgendaSource.empty();
    final taskSource = _sourceOf<TaskAgendaSource>(sources, 'task');
    final courseSource = _sourceOf<CourseAgendaSource>(sources, 'course') ?? CourseAgendaSource.disabled();
    final konkurSource = _sourceOf<KonkurAgendaSource>(sources, 'konkur') ?? KonkurAgendaSource.disabled();
    final cycleSource = _sourceOf<CycleAgendaSource>(sources, 'cycle') ?? const CycleAgendaSource(cycleOutput: null, cycleAllowed: false);

    final cityId = settingsMap['prayer_city_id'] ??
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
      RitmoLog.error('DayAgendaService', 'iran_cities lookup failed for $cityId', e, st);
    }

    var latitude = 35.6892;
    var longitude = 51.3890;

    if (cityResult.isNotEmpty) {
      final lat = cityResult.first['latitude'];
      final lng = cityResult.first['longitude'];
      if (lat is num) latitude = lat.toDouble();
      if (lng is num) longitude = lng.toDouble();
    }

    final ihtiyatMinutes = int.tryParse(settingsMap['ihtiyat_minutes'] ?? '0') ?? 0;
    final calcMethodStr = settingsMap['prayer_calculation_method'] ?? 'TEHRAN_GEOPHYSICS';

    final dayMarksByDate = <String, String>{};
    try {
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
    } catch (e, st) {
      debugPrint('[AgendaDayMarks] day_marks load error: $e\n$st');
    }

    return _AgendaContext(
      settingsMap: settingsMap,
      routinesEnabled: routinesEnabled,
      goalsEnabled: goalsEnabled,
      tasksEnabled: tasksEnabled,
      eventsEnabled: eventsEnabled,
      religionEnabled: religionEnabled,
      coursesEnabled: coursesEnabled,
      konkurEnabled: konkurEnabled,
      cycleAllowed: cycleAllowed,
      sportsEnabled: sportsEnabled,
      medicineEnabled: medicineEnabled,
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
      latitude: latitude,
      longitude: longitude,
      ihtiyatMinutes: ihtiyatMinutes,
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
    final todayStr = _dateStr(DateTime.now());
    final isToday = dateStr == todayStr;
    final prayerTimes = await ctx.prayerTimesFor(date);
    final items = <AgendaItem>[];



    final enabledDomains = <AgendaDomain, bool>{
      AgendaDomain.routine: ctx.routinesEnabled,
      AgendaDomain.event: ctx.eventsEnabled,
      AgendaDomain.prayer: ctx.religionEnabled,
      AgendaDomain.mustahab: ctx.religionEnabled,
      AgendaDomain.worshipDebt: ctx.religionEnabled && opts.includeWorshipDebt,
      AgendaDomain.course: ctx.coursesEnabled,
      AgendaDomain.goalStep: ctx.goalsEnabled,
      AgendaDomain.konkur: ctx.konkurEnabled,
      AgendaDomain.cycle: ctx.cycleAllowed,
      AgendaDomain.sport: ctx.sportsEnabled,
      AgendaDomain.medicine: ctx.medicineEnabled,
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

    safeCollect(
      'worship',
      {AgendaDomain.prayer, AgendaDomain.mustahab, AgendaDomain.worshipDebt},
      () => ctx.worshipSource.itemsForDate(agendaCtx),
    );
    safeCollect(
      'sports',
      {AgendaDomain.sport},
      () => ctx.sportsSource.itemsForDate(agendaCtx),
    );
    safeCollect(
      'medicine',
      {AgendaDomain.medicine},
      () => ctx.medicineSource.itemsForDate(agendaCtx),
    );
    safeCollect(
      'goalSteps',
      {AgendaDomain.goalStep},
      () => ctx.goalStepsSource.itemsForDate(agendaCtx),
    );

    final taskSource = ctx.taskSource;
    if (taskSource != null) {
      safeCollect('task', {AgendaDomain.task}, () => taskSource.itemsForDate(agendaCtx));
    }

    safeCollect(
      'course',
      {AgendaDomain.course},
      () => ctx.courseSource.itemsForDate(agendaCtx),
    );
    safeCollect(
      'konkur',
      {AgendaDomain.konkur},
      () => ctx.konkurSource.itemsForDate(agendaCtx),
    );
    safeCollect(
      'cycle',
      {AgendaDomain.cycle},
      () => ctx.cycleSource.itemsForDate(agendaCtx),
    );

    // Additional / custom registered sources (e.g. from tests or new modules)
    const standardKeys = {'routine', 'worship', 'sports', 'medicine', 'goalSteps', 'task', 'course', 'konkur', 'cycle'};
    for (final entry in ctx.allSources.entries) {
      if (!standardKeys.contains(entry.key)) {
        safeCollect(entry.key, entry.value.domains, () => entry.value.itemsForDate(agendaCtx));
      }
    }

    // K43: Apply REST/TRAVEL day effect — mark non-essential items as skipped.
    final dayMark = ctx.dayMarksByDate[dateStr];
    List<AgendaItem> finalItems = items;
    if (dayMark == 'REST' || dayMark == 'TRAVEL') {
      finalItems = items.map((item) {
        if (!item.isEssential && item.completion == AgendaCompletion.none) {
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
      if (a.isTimed && b.isTimed) {
        final aM = _parseMinutes(a.timeOfDay);
        final bM = _parseMinutes(b.timeOfDay);
        final cmp = aM.compareTo(bM);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      }
      if (a.isTimed) return -1;
      if (b.isTimed) return 1;
      final pCmp = b.priority.compareTo(a.priority);
      if (pCmp != 0) return pCmp;
      return a.id.compareTo(b.id);
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
    required this.tasksEnabled,
    required this.eventsEnabled,
    required this.religionEnabled,
    required this.coursesEnabled,
    required this.konkurEnabled,
    required this.cycleAllowed,
    required this.sportsEnabled,
    required this.medicineEnabled,
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
    required this.latitude,
    required this.longitude,
    required this.ihtiyatMinutes,
    required this.calcMethodStr,
  });
  final Map<String, String> settingsMap;
  final bool routinesEnabled;
  final bool goalsEnabled;
  final bool tasksEnabled;
  final bool eventsEnabled;
  final bool religionEnabled;
  final bool coursesEnabled;
  final bool konkurEnabled;
  final bool cycleAllowed;
  final bool sportsEnabled;
  final bool medicineEnabled;
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
      RitmoLog.error('DayAgendaService', 'prayer times error', e);
      _prayerCache[key] = const {};
      return const {};
    }
  }
}
