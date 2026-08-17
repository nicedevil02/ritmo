import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/modules/routine_visibility.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/engines/routine_occurrence_generator.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:sqflite/sqflite.dart';

/// Shared source of truth for "which routines are active on a given date".
///
/// Extracted from the duplicated inline logic that lived in
/// `calendar_screen.dart::_getActiveRoutinesForDate` and the dashboard
/// controller, so both the Calendar and `DayAgendaService` consume the same
/// resolution rules (DB occurrences first, then RecurrenceRule fallback).
///
/// Holds raw in-memory rows (loaded once) and resolves per-date without extra
/// queries, which keeps the month range view (31 days) cheap.
class RoutineAgendaSource implements AgendaSource {
  const RoutineAgendaSource({
    required this.routines,
    required this.schedules,
    required this.occurrences,
    required this.avgDurations,
    required this.categoryAvgDurations,
    required this.completionsByDate,
    required this.activeModules,
    this.eventsEnabled = true,
  });
  final List<Map<String, dynamic>> routines;
  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> occurrences;
  final Map<String, double> avgDurations;
  final Map<String, double> categoryAvgDurations;
  final Map<String, Map<String, Map<String, dynamic>>> completionsByDate;

  /// Module gates the routine list honors: keys `religion`, `medicine`, `courses`.
  final Map<String, bool> activeModules;

  /// Mirrors the `calendar_show_events` setting.
  ///
  /// Registry entry #10 already gates [EventAgendaSource] (the
  /// `temporary_events` pipeline) on this setting. This source emits the other
  /// half of the events — `routines` rows tagged itemType='EVENT' — so it must
  /// honour the same switch, otherwise turning events off hides only half of
  /// them. Defaults to true so callers that never set it keep prior behaviour.
  final bool eventsEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.routine, AgendaDomain.event};

  @override
  bool get isEnabled => true;

  /// Loads all routine rows once. Reuse the returned instance for a whole
  /// range; do not reload per day.
  static Future<RoutineAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
    String startStr,
    String endStr,
  ) async {
    final routines = await db.query('routines', where: 'isArchived = 0');
    final schedules = await db.query('routine_schedules');
    final occurrences = await db.query(
      'routine_occurrences',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startStr, endStr],
    );

    final completionsByDate = <String, Map<String, Map<String, dynamic>>>{};
    final comps = await db.query(
      'routine_completions',
      where: 'completionDate >= ? AND completionDate <= ?',
      whereArgs: [startStr, endStr],
    );
    for (final c in comps) {
      final resType = c['resultType'] as String?;
      if (resType == 'SNOOZED' || resType == 'CANNOT_NOW') continue;
      final dateStr = (c['completionDate'] ?? c['completion_date']) as String?;
      final routineId = (c['routineId'] ?? c['routine_id']) as String?;
      if (dateStr == null || routineId == null) continue;
      completionsByDate.putIfAbsent(dateStr, () => {})[routineId] =
          Map<String, dynamic>.from(c);
    }

    final avgDurations = <String, double>{};
    try {
      final list = await db.rawQuery('''
        SELECT routineId, AVG(COALESCE(actual_duration_minutes, durationMinutes)) as avgDur 
        FROM routine_completions 
        WHERE (actual_duration_minutes IS NOT NULL AND actual_duration_minutes > 0)
           OR (durationMinutes IS NOT NULL AND durationMinutes > 0)
        GROUP BY routineId
      ''');
      for (final row in list) {
        final rId = (row['routineId'] ?? row['routine_id'])! as String;
        final avg = (row['avgDur'] as num?)?.toDouble();
        if (avg != null && avg > 0) {
          avgDurations[rId] = avg;
        }
      }
    } catch (e, st) {
      debugPrint('[RoutineAgendaSource] avgDurations failed: $e\n$st');
    }

    final categoryAvgDurations = <String, double>{};
    try {
      final list = await db.rawQuery('''
        SELECT r.category, AVG(COALESCE(c.actual_duration_minutes, c.durationMinutes)) as avgDur 
        FROM routine_completions c
        JOIN routines r ON c.routineId = r.id
        WHERE (c.actual_duration_minutes IS NOT NULL AND c.actual_duration_minutes > 0)
           OR (c.durationMinutes IS NOT NULL AND c.durationMinutes > 0)
        GROUP BY r.category
      ''');
      for (final row in list) {
        final cat = row['category']?.toString();
        final avg = (row['avgDur'] as num?)?.toDouble();
        if (cat != null && avg != null && avg > 0) {
          categoryAvgDurations[cat] = avg;
        }
      }
    } catch (e, st) {
      debugPrint('[RoutineAgendaSource] categoryAvgDurations failed: $e\n$st');
    }

    return RoutineAgendaSource(
      routines: routines.map(Map<String, dynamic>.from).toList(),
      schedules: schedules.map(Map<String, dynamic>.from).toList(),
      occurrences: occurrences.map(Map<String, dynamic>.from).toList(),
      avgDurations: avgDurations,
      categoryAvgDurations: categoryAvgDurations,
      completionsByDate: completionsByDate,
      eventsEnabled: settingsMap['calendar_show_events'] != 'false',
      activeModules: {
        'religion': ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_religion_enabled',
        ),
        'medicine': ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_medicine_enabled',
        ),
        'courses': ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_courses_enabled',
        ),
        'study': ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_study_enabled',
        ),
        'sports':
            ModuleGate.instance.isEnabledFrom(
              settingsMap,
              'module_sports_enabled',
            ) ||
            ModuleGate.instance.isEnabledFrom(
              settingsMap,
              'module_supplementary_sports_enabled',
            ),
        'goals': ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_goals_enabled',
        ),
        'habits': ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_progressive_habits_enabled',
        ),
        'cycle': ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_cycle_enabled',
        ),
      },
    );
  }

  /// Returns an empty, non-functional source (used as fallback on load failure).
  static RoutineAgendaSource disabled() => const RoutineAgendaSource(
    routines: [],
    schedules: [],
    occurrences: [],
    avgDurations: {},
    categoryAvgDurations: {},
    completionsByDate: {},
    activeModules: {},
  );

  /// Builds a weekly rule from the plain `daysOfWeek` column.
  ///
  /// Used both when a schedule has no `recurrenceRule` and when the stored
  /// rule JSON cannot be parsed. Invalid weekday tokens are dropped instead of
  /// being coerced to Monday; an empty weekday list means "every day" in
  /// [RoutineOccurrenceGenerator.shouldOccurOnDate], which is the safe
  /// (visible) failure mode.
  static RecurrenceRule _ruleFromDaysOfWeek(Map<String, dynamic> s) {
    final daysStr = s['daysOfWeek']?.toString() ?? '6,7,1,2,3,4,5';
    final days = daysStr
        .split(',')
        .map((d) => int.tryParse(d.trim()))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toList();
    final rawTime = s['timeOfDay']?.toString();
    return RecurrenceRule(
      weekdays: days,
      reminderTimes: (rawTime != null && rawTime.isNotEmpty)
          ? [rawTime]
          : ['08:00'],
    );
  }

  /// Active routines (raw `{routine, schedule}` maps) for [date].
  ///
  /// Mirrors the previous `_getActiveRoutinesForDate` behavior exactly so the
  /// Calendar keeps the same output when it switches to this source.
  List<Map<String, dynamic>> activeForDate(DateTime date) {
    final active = <Map<String, dynamic>>[];
    final dateStr = DateKey.of(date);

    for (final r in routines) {
      final routineId = r['id']?.toString() ?? '';
      if (routineId.isEmpty) continue;
      final catStr = r['category']?.toString() ?? 'personal';
      // Build a settings-compatible map from the stored module flags.
      final settingsForVisibility = <String, String>{
        'module_religion_enabled': (activeModules['religion'] ?? false)
            .toString(),
        'module_medicine_enabled': (activeModules['medicine'] ?? false)
            .toString(),
        'module_courses_enabled': (activeModules['courses'] ?? false)
            .toString(),
        'module_study_enabled': (activeModules['study'] ?? false).toString(),
        'module_sports_enabled': (activeModules['sports'] ?? false).toString(),
        'module_supplementary_sports_enabled':
            (activeModules['sports'] ?? false).toString(),
        'module_goals_enabled': (activeModules['goals'] ?? false).toString(),
        'module_progressive_habits_enabled': (activeModules['habits'] ?? false)
            .toString(),
        'module_cycle_enabled': (activeModules['cycle'] ?? false).toString(),
      };
      if (!RoutineVisibility.isVisible(
        routineId: routineId,
        category: catStr,
        settings: settingsForVisibility,
      ))
        continue;

      Map<String, dynamic>? matchedSchedule;
      for (final sched in schedules) {
        final schedRoutineId = (sched['routineId'] ?? sched['routine_id'])
            ?.toString();
        if (schedRoutineId == routineId) {
          matchedSchedule = sched;
          break;
        }
      }

      // 1. Check database occurrences in memory (normalised comparison: the id
      //    may be int/String and the date may carry a time suffix).
      final hasOcc = occurrences.any((occ) {
        final occRoutineId = (occ['routine_id'] ?? occ['routineId'])
            ?.toString();
        if (occRoutineId != routineId) return false;
        final occDate = occ['date']?.toString();
        if (occDate == null || occDate.length < 10) return false;
        return occDate.substring(0, 10) == dateStr;
      });

      if (matchedSchedule == null || matchedSchedule.isEmpty) {
        // No schedule row: only include if there is an explicit occurrence for this date.
        if (hasOcc) {
          // Floating routine — synthesise a minimal schedule map.
          active.add({'routine': r, 'schedule': <String, dynamic>{}});
        }
        continue;
      }

      final s = matchedSchedule;

      if (hasOcc) {
        active.add({'routine': r, 'schedule': s});
        continue;
      }

      // 2. Fallback: RecurrenceRule calculation.
      //
      // C-FIX-3: this used to be `RecurrenceRule.fromMap(jsonDecode(ruleStr))`
      // with no guard. One malformed/legacy JSON row threw a TypeError all the
      // way up through itemsForDate into _assembleDay, which discarded the
      // entire day. Now a bad rule degrades to the daysOfWeek column.
      RecurrenceRule? rule;
      final ruleStr = s['recurrenceRule']?.toString();
      if (ruleStr != null && ruleStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(ruleStr);
          if (decoded is Map) {
            rule = RecurrenceRule.fromMap(Map<String, dynamic>.from(decoded));
          }
        } catch (e, st) {
          debugPrint(
            '[RoutineAgendaSource] bad recurrenceRule for $routineId: $e\n$st',
          );
        }
      }
      rule ??= _ruleFromDaysOfWeek(s);

      var occursToday = false;
      try {
        occursToday = RoutineOccurrenceGenerator.shouldOccurOnDate(date, rule);
      } catch (e, st) {
        debugPrint(
          '[RoutineAgendaSource] shouldOccurOnDate failed for $routineId: $e\n$st',
        );
      }

      if (occursToday) {
        active.add({'routine': r, 'schedule': s});
      }
    }

    return active;
  }

  static String _mapAnchorToKey(String anchor) {
    switch (anchor.toUpperCase()) {
      case 'FAJR':
        return 'fajr';
      case 'SUNRISE':
        return 'sunrise';
      case 'DHUHR':
        return 'dhuhr';
      case 'ASR':
        return 'asr';
      case 'MAGHRIB':
        return 'maghrib';
      case 'ISHA':
        return 'isha';
      default:
        return anchor.toLowerCase();
    }
  }

  static String? _normalizeTimeOfDay(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour >= 24 || minute < 0 || minute >= 60) return null;

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  /// Resolves the concrete `HH:mm` for a routine schedule, honoring prayer
  /// anchors (anchor time + offset) via [prayerTimes].
  static String? resolveTime(
    Map<String, dynamic> schedule,
    Map<String, String> prayerTimes,
  ) {
    final rawTime = schedule['timeOfDay'] as String?;
    final normalizedDirect = _normalizeTimeOfDay(rawTime);
    if (normalizedDirect != null) return normalizedDirect;

    final anchorEvent = schedule['anchorEvent'] as String?;
    if (anchorEvent != null) {
      final adhanTimeStr = prayerTimes[_mapAnchorToKey(anchorEvent)];
      final normalizedAnchor = _normalizeTimeOfDay(adhanTimeStr);

      if (normalizedAnchor != null) {
        final parts = normalizedAnchor.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);

        final offset = schedule['anchorOffsetMinutes'] as int? ?? 0;
        var total = h * 60 + m + offset;

        while (total < 0) {
          total += 24 * 60;
        }
        total = total % (24 * 60);

        final rh = total ~/ 60;
        final rm = total % 60;

        return '${rh.toString().padLeft(2, '0')}:${rm.toString().padLeft(2, '0')}';
      }
    }

    return null;
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    final wantsRoutine = ctx.options.wants(AgendaDomain.routine);
    final wantsEvent = ctx.options.wants(AgendaDomain.event);
    if (!wantsRoutine && !wantsEvent) return [];

    final dateStr = ctx.dateStr;
    final items = <AgendaItem>[];
    final dateCompletions = completionsByDate[dateStr] ?? {};

    final medicineOwnsDoses = ctx.options.wants(AgendaDomain.medicine);

    for (final entry in activeForDate(ctx.date)) {
      final r = entry['routine'] as Map<String, dynamic>;
      final s = entry['schedule'] as Map<String, dynamic>;
      final routineId = r['id']?.toString() ?? '';
      if (routineId.isEmpty) continue;

      // B-FIX-EVENT-2 — رویدادهایی که ریشه‌شان روتین است نباید از دامنهٔ
      // `routine` خارج شوند.
      //
      // پلنر («کار جدید ← رویداد») رویداد را به‌صورت یک ردیف در جدول
      // `routines` با برچسب itemType='EVENT' ذخیره می‌کند. پیش‌تر اینجا دامنهٔ
      // آیتم به AgendaDomain.event تغییر می‌کرد و همین باعث می‌شد آیتم در
      // تمام سطوح تقویم نامرئی شود، چون همهٔ مصرف‌کننده‌ها روی
      // AgendaDomain.routine کلید می‌خورند:
      //   • AgendaRendererRegistry فقط prayer و routine را ثبت کرده
      //   • مسیر تکمیل در JourneyController و TodayCalendarConvergenceHelper
      //   • DirectManipulationEligibility
      //   • domainColor / domainIcon / domainLabelFa مقدار `kind` را تنها وقتی
      //     اعمال می‌کنند که domain == AgendaDomain.routine باشد
      //
      // محور مستقل kind (AgendaItemKind.event) از پیش معنای «این یک رویداد
      // است» را حمل می‌کند؛ پس دامنه باید `routine` بماند.
      final isEvent = (r['itemType'] as String?) == 'EVENT';
      const itemDomain = AgendaDomain.routine;

      // معادل دروازهٔ `calendar_show_events` که EventAgendaSource رعایت می‌کند.
      if (isEvent && !eventsEnabled) continue;

      // درخواست‌های فقط‌رویداد یا فقط‌روتین بدون تغییر دامنه محترم شمرده می‌شوند.
      if (!(isEvent ? (wantsRoutine || wantsEvent) : wantsRoutine)) {
        continue;
      }

      if (medicineOwnsDoses && MedicationIdentity.isMedicationRoutine(r)) {
        continue;
      }

      final catStr = r['category']?.toString() ?? 'personal';
      final category = Category.values.firstWhere(
        (e) => e.name.toLowerCase() == catStr.toLowerCase(),
        orElse: () => Category.custom,
      );

      final resolvedTime = resolveTime(s, ctx.prayerTimes);

      final completion = dateCompletions[routineId];
      var completionState = AgendaCompletion.pending;
      if (completion != null) {
        final resType = completion['resultType'] as String? ?? 'FULL';
        switch (resType) {
          case 'FULL':
            completionState = AgendaCompletion.done;
          case 'LIGHT':
          case 'MINIMAL':
            completionState = AgendaCompletion.partial;
          case 'SKIPPED':
            completionState = AgendaCompletion.skipped;
          default:
            completionState = AgendaCompletion.pending;
        }
      }

      var dur = r['targetDurationMinutes'] as int?;
      var isEstimated = false;

      // Only estimate when duration is missing or invalid.
      // Do NOT replace legitimate long routines with a fake shorter average.
      if (dur == null || dur <= 0) {
        final avg =
            avgDurations[routineId] ?? categoryAvgDurations[catStr] ?? 30.0;
        dur = avg.round().clamp(DurationBounds.minMinutes, 120);
        isEstimated = true;
      } else {
        dur = DurationBounds.sanitize(dur);
      }

      final itemTypeStr = (r['itemType'] as String? ?? 'ROUTINE').toUpperCase();
      final AgendaItemKind kind;
      switch (itemTypeStr) {
        case 'REMINDER':
          kind = AgendaItemKind.reminder;
        case 'TASK':
          kind = AgendaItemKind.task;
        case 'REFLECT':
          kind = AgendaItemKind.reflection;
        case 'EVENT':
          kind = AgendaItemKind.event;
        case 'ROUTINE':
        default:
          kind = AgendaItemKind.routine;
      }

      items.add(
        AgendaItem(
          id: buildAgendaItemId(itemDomain, routineId, dateStr),
          domain: itemDomain,
          kind: kind,
          sourceId: routineId,
          title: r['title'] as String? ?? '',
          dateStr: dateStr,
          timeOfDay: resolvedTime,
          durationMinutes: dur,
          category: category,
          completion: completionState,
          priority: (r['priority'] as num?)?.toDouble() ?? 1.0,
          isEssential: r['isEssential'] == 1,
          deepLink: AgendaDeepLink(domain: itemDomain, targetId: routineId),
          meta: {
            'routine': r,
            'schedule': s,
            if (isEstimated) 'isAIEstimated': true,
          },
        ),
      );
    }

    return items;
  }
}
