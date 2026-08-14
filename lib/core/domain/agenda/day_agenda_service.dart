import 'package:flutter/foundation.dart' hide Category;
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
    'RoutineCreated',
    'RoutineEdited',
    'RoutineDeleted',
    'DataImported',
    'DayRolledOver',
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
      
      DateTime? appStartDate;
      if (ctx.settingsMap['app_start_date'] != null) {
        final parsed = DateTime.tryParse(ctx.settingsMap['app_start_date']!);
        if (parsed != null) {
          appStartDate = DateTime(parsed.year, parsed.month, parsed.day);
        }
      }

      for (final date in dates) {
        final ds = _dateStr(date);
        
        // ROOT FIX: Avoid generating routines/prayers for days before the app was installed.
        if (appStartDate != null && date.isBefore(appStartDate)) {
          result[ds] = DayAgenda.empty(ds);
          continue;
        }

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

    final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
    final cycleEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_cycle_enabled');
    final cycleConsent = settingsMap['cycle_consent_dashboard'] == 'true';
    final cycleSetupDone = settingsMap['cycle_setup_done'] == 'true';
    final showCycleInCalendar = settingsMap['show_cycle_in_calendar'] == 'true';
    final cycleAllowed =
        isFemale && cycleEnabled && cycleConsent && cycleSetupDone && showCycleInCalendar;

    final startStr = _dateStr(start);
    final endStr = _dateStr(end);

    final routineSource = await RoutineAgendaSource.load(db, settingsMap, startStr, endStr);
    final worshipSource = await WorshipAgendaSource.load(db, settingsMap, start, end);
    final sportsSource = await SportsAgendaSource.load(db, settingsMap);
    final medicineSource = await MedicineAgendaSource.load(db, settingsMap, start, end);
    final goalStepsSource = await GoalStepsAgendaSource.load(db, start, end);

    TaskAgendaSource? taskSource;
    final tasksEnabled = settingsMap['calendar_show_tasks'] != 'false';
    if (tasksEnabled && opts.wants(AgendaDomain.task)) {
      taskSource = await TaskAgendaSource.load(
        db, 
        start, 
        end, 
        _dateStr(DateTime.now()),
        settingsMap['app_start_date'],
      );
    }

    final courseSource = await CourseAgendaSource.load(db, coursesEnabled, startStr, endStr);

    final konkurSource = await KonkurAgendaSource.load(konkurEnabled);

    final cycleSource = await CycleAgendaSource.load(db, settingsMap, cycleAllowed);

    final cityId = settingsMap['prayer_city_id'] ??
        settingsMap['home_city_id'] ??
        'TEHRAN_TEHRAN';
    final cityResult = await db.query(
      'iran_cities',
      where: 'id = ?',
      whereArgs: [cityId],
      limit: 1,
    );

    var latitude = 35.6892;
    var longitude = 51.3890;

    if (cityResult.isNotEmpty) {
      latitude = cityResult.first['latitude']! as double;
      longitude = cityResult.first['longitude']! as double;
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
    } catch (e, st) { debugPrint('Error in day_agenda_service.dart: $e\n$st'); }

    return _AgendaContext(
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
      sportsSource: sportsSource,
      medicineSource: medicineSource,
      goalStepsSource: goalStepsSource,
      courseSource: courseSource,
      konkurSource: konkurSource,
      cycleSource: cycleSource,
      dayMarksByDate: dayMarksByDate,
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

    final agendaCtx = AgendaDayContext(
      date: date,
      dateStr: dateStr,
      isToday: isToday,
      prayerTimes: prayerTimes,
      options: opts,
    );

    // Apply the activeWorshipTitles filter for routineSource
    final activeWorshipTitles = <String>{};
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

    final routines = ctx.routineSource.itemsForDate(agendaCtx);
    final filteredRoutines = routines.where((r) => !activeWorshipTitles.contains(r.title.trim())).toList();

    items.addAll(filteredRoutines);
    items.addAll(ctx.worshipSource.itemsForDate(agendaCtx));
    items.addAll(ctx.sportsSource.itemsForDate(agendaCtx));
    items.addAll(ctx.medicineSource.itemsForDate(agendaCtx));
    items.addAll(ctx.goalStepsSource.itemsForDate(agendaCtx));

    if (ctx.taskSource != null) {
      items.addAll(ctx.taskSource!.itemsForDate(agendaCtx));
    }

    items.addAll(ctx.courseSource.itemsForDate(agendaCtx));
    items.addAll(ctx.konkurSource.itemsForDate(agendaCtx));
    items.addAll(ctx.cycleSource.itemsForDate(agendaCtx));

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
  // (time parsing helpers live in individual source/sheet files that need them)
}


/// Shared, range-scoped data loaded once and reused across every day.
class _AgendaContext {

  _AgendaContext({
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
    required this.sportsSource,
    required this.medicineSource,
    required this.goalStepsSource,
    required this.courseSource,
    required this.konkurSource,
    required this.cycleSource,
    required this.dayMarksByDate,
    required this.latitude,
    required this.longitude,
    required this.ihtiyatMinutes,
    required this.calcMethodStr,
  });
  final Map<String, String> settingsMap;
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
      debugPrint('DayAgendaService prayer times error: $e');
      _prayerCache[key] = const {};
      return const {};
    }
  }
}
