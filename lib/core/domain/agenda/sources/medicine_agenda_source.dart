import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/engines/routine_occurrence_generator.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:sqflite/sqflite.dart';

/// AgendaSource for the Medicine domain.
///
/// MED-09: this source used to read `medication_logs` and nothing else, so a
/// dose only existed once it had already been taken. The one view whose entire
/// job is answering "did I take my pills today?" could never show an
/// outstanding dose. It now expands each medication's schedule into the
/// concrete slots of the requested day and folds the logged rows onto those
/// slots: an untaken dose is pending, a taken one flips to done.
class MedicineAgendaSource implements AgendaSource {
  MedicineAgendaSource({
    required this.medicationRoutines,
    required this.logsByRoutineAndDate,
    required this.medicineEnabled,
  });

  /// `{routine, schedule}` pairs for every non-archived medication.
  final List<Map<String, dynamic>> medicationRoutines;

  /// routineId -> `yyyy-MM-dd` -> that day's logs, ordered in time.
  final Map<String, Map<String, List<Map<String, dynamic>>>>
  logsByRoutineAndDate;

  final bool medicineEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.medicine};

  @override
  bool get isEnabled => medicineEnabled;

  /// Returns an empty, disabled source (fallback when module is off or load fails).
  static MedicineAgendaSource disabled() => MedicineAgendaSource(
    medicationRoutines: const [],
    logsByRoutineAndDate: const {},
    medicineEnabled: false,
  );

  static Future<MedicineAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
    DateTime start,
    DateTime end,
  ) async {
    final medicineEnabled = ModuleGate.instance.isEnabledFrom(
      settingsMap,
      'module_medicine_enabled',
    );
    if (!medicineEnabled) {
      return MedicineAgendaSource(
        medicationRoutines: const [],
        logsByRoutineAndDate: const {},
        medicineEnabled: false,
      );
    }

    final medicationRoutines = <Map<String, dynamic>>[];
    final logsByRoutineAndDate =
        <String, Map<String, List<Map<String, dynamic>>>>{};

    try {
      final routines = await db.query(
        'routines',
        where: 'isArchived = 0 AND ${MedicationIdentity.sqlPredicate}',
      );

      if (routines.isNotEmpty) {
        final schedules = await db.query('routine_schedules');
        for (final routine in routines) {
          final id = routine['id'] as String?;
          if (id == null) continue;
          final schedule = schedules.firstWhere(
            (s) => s['routineId'] == id,
            orElse: () => <String, Object?>{},
          );
          medicationRoutines.add({
            'routine': Map<String, dynamic>.from(routine),
            'schedule': Map<String, dynamic>.from(schedule),
          });
        }
      }

      // COALESCE, because rows written before scheduledTime was populated would
      // otherwise fall out of the range filter entirely and look untaken.
      final startMs = DateTime(
        start.year,
        start.month,
        start.day,
      ).millisecondsSinceEpoch;
      final endMs = DateTime(
        end.year,
        end.month,
        end.day,
      ).add(const Duration(days: 1)).millisecondsSinceEpoch;
      final logs = await db.rawQuery(
        '''
        SELECT m.*, r.title as medicationName
        FROM medication_logs m
        LEFT JOIN routines r ON m.routineId = r.id
        WHERE COALESCE(m.scheduledTime, m.takenTime, m.createdAt) >= ?
          AND COALESCE(m.scheduledTime, m.takenTime, m.createdAt) < ?
      ''',
        [startMs, endMs],
      );

      for (final row in logs) {
        final log = Map<String, dynamic>.from(row);
        final routineId = log['routineId'] as String?;
        if (routineId == null) continue;
        final ts = _logMs(log);
        if (ts == null) continue;
        final dayKey = (log['date'] as String?) ??
          DateKey.of(DateTime.fromMillisecondsSinceEpoch(ts));
        logsByRoutineAndDate
            .putIfAbsent(
              routineId,
              () => <String, List<Map<String, dynamic>>>{},
            )
            .putIfAbsent(
              dayKey,
              () => <Map<String, dynamic>>[],
            )
            .add(log);
      }

      for (final byDate in logsByRoutineAndDate.values) {
        for (final dayLogs in byDate.values) {
          dayLogs.sort((a, b) => (_logMs(a) ?? 0).compareTo(_logMs(b) ?? 0));
        }
      }
    } catch (e, st) {
      debugPrint('[MedicineAgendaSource] Load error: $e\n$st');
    }

    return MedicineAgendaSource(
      medicationRoutines: medicationRoutines,
      logsByRoutineAndDate: logsByRoutineAndDate,
      medicineEnabled: medicineEnabled,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.medicine)) return const [];
    if (!medicineEnabled) return const [];

    final items = <AgendaItem>[];

    for (final entry in medicationRoutines) {
      final routine = entry['routine']! as Map<String, dynamic>;
      final schedule = entry['schedule']! as Map<String, dynamic>;
      final routineId = routine['id'] as String?;
      if (routineId == null) continue;

      final dayLogs =
          logsByRoutineAndDate[routineId]?[ctx.dateStr] ??
          const <Map<String, dynamic>>[];
      final asNeeded = MedicationIdentity.isAsNeeded(routine);

      // PRN has no due time, so only what was actually taken is shown.
      final slots = asNeeded
          ? const <String>[]
          : _slotsForDate(schedule, ctx.date);

      if (slots.isEmpty) {
        if (asNeeded && ctx.isToday) {
          items.add(_buildPrnActionItem(ctx: ctx, routine: routine));
        }
        for (final log in dayLogs) {
          items.add(
            _buildItem(
              ctx: ctx,
              routine: routine,
              slot: _slotOfLog(log),
              log: log,
              asNeeded: asNeeded,
            ),
          );
        }
        continue;
      }

      final match = _matchLogsToSlots(slots, dayLogs);
      for (var i = 0; i < slots.length; i++) {
        items.add(
          _buildItem(
            ctx: ctx,
            routine: routine,
            slot: slots[i],
            log: match.perSlot[i],
            asNeeded: asNeeded,
          ),
        );
      }

      // Extra doses beyond the schedule (e.g. a rescue dose) stay visible
      // instead of being swallowed by the slot mapping.
      for (final log in match.extras) {
        items.add(
          _buildItem(
            ctx: ctx,
            routine: routine,
            slot: _slotOfLog(log),
            log: log,
            asNeeded: asNeeded,
          ),
        );
      }
    }

    return items;
  }

  AgendaItem _buildPrnActionItem({
    required AgendaDayContext ctx,
    required Map<String, dynamic> routine,
  }) {
    final routineId = routine['id']! as String;
    final title = routine['title'] as String? ?? 'داروی در صورت نیاز';

    return AgendaItem(
      id: buildAgendaItemId(
        AgendaDomain.medicine,
        '$routineId@prn_action',
        ctx.dateStr,
      ),
      sourceId: routineId,
      domain: AgendaDomain.medicine,
      itemType: AgendaItemType.flexible,
      title: title,
      subtitle: 'ثبت مصرف در صورت نیاز (الان مصرف کردم)',
      dateStr: ctx.dateStr,
      timeOfDay: null,
      durationMinutes: 5,
      category: Category.medical,
      priority: 1.0,
      isEssential: false,
      deepLink: AgendaDeepLink(
        domain: AgendaDomain.medicine,
        targetId: routineId,
      ),
      completion: AgendaCompletion.pending,
      meta: {'routineId': routineId, 'isPrnAction': true, 'isPrn': true},
    );
  }

  AgendaItem _buildItem({
    required AgendaDayContext ctx,
    required Map<String, dynamic> routine,
    required String? slot,
    required Map<String, dynamic>? log,
    required bool asNeeded,
  }) {
    final routineId = routine['id']! as String;
    final logId = log?['id']?.toString();
    final title =
        log?['medicationName'] as String? ??
        routine['title'] as String? ??
        'یادآور دارو';

    final status = log?['status'] as String?;
    var completion = AgendaCompletion.pending;
    if (status == 'TAKEN') {
      completion = AgendaCompletion.done;
    } else if (status == 'SKIPPED' || status == 'MISSED') {
      completion = AgendaCompletion.skipped;
    }

    // MED-02: the completion pipeline resolves the medication by `sourceId`, so
    // it has to be the routine id. The specific dose travels in `meta` and `deepLink.slot`.
    return AgendaItem(
      id: buildAgendaItemId(
        AgendaDomain.medicine,
        '$routineId@${slot ?? logId ?? 'dose'}',
        ctx.dateStr,
      ),
      sourceId: routineId,
      domain: AgendaDomain.medicine,
      itemType: slot != null ? AgendaItemType.fixed : AgendaItemType.flexible,
      title: title,
      subtitle: log?['note'] as String?,
      dateStr: ctx.dateStr,
      timeOfDay: slot,
      durationMinutes: 5,
      category: Category.medical,
      priority: 2.0,
      isEssential: !asNeeded,
      deepLink: AgendaDeepLink(
        domain: AgendaDomain.medicine,
        targetId: routineId,
        slot: slot,
      ),
      completion: completion,
      meta: {
        'medicationLog': ?log,
        'medicationLogId': ?logId,
        'routineId': routineId,
        'doseTime': ?slot,
        'isPrn': asNeeded,
      },
    );
  }

  /// Concrete `HH:mm` slots this medication is due at on [date].
  static List<String> _slotsForDate(
    Map<String, dynamic> schedule,
    DateTime date,
  ) {
    if (schedule.isEmpty) return const [];

    final rule = _ruleFor(schedule);
    if (!RoutineOccurrenceGenerator.shouldOccurOnDate(date, rule)) {
      return const [];
    }

    // reminderTimes is the multi-dose carrier: "08:00, 14:00, 20:00" means three
    // separate doses, not one routine that repeats.
    final times =
        rule.reminderTimes
            .map(_normalizeTime)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    if (times.isNotEmpty) return times;

    final fallback = _normalizeTime(schedule['timeOfDay'] as String?);
    return fallback == null ? const ['08:00'] : [fallback];
  }

  static RecurrenceRule _ruleFor(Map<String, dynamic> schedule) {
    final ruleStr = schedule['recurrenceRule'] as String?;
    if (ruleStr != null && ruleStr.isNotEmpty) {
      try {
        return RecurrenceRule.fromMap(
          jsonDecode(ruleStr) as Map<String, dynamic>,
        );
      } catch (e, st) {
        debugPrint('[MedicineAgendaSource] Invalid recurrenceRule: $e\n$st');
      }
    }

    final daysStr = schedule['daysOfWeek'] as String? ?? '6,7,1,2,3,4,5';
    final days = daysStr
        .split(',')
        .map((d) => int.tryParse(d.trim()))
        .whereType<int>()
        .toList();
    final time = _normalizeTime(schedule['timeOfDay'] as String?);
    return RecurrenceRule(
      weekdays: days,
      reminderTimes: time != null ? [time] : const ['08:00'],
    );
  }

  /// Attributes logged doses to slots.
  ///
  /// Exact matches win first (a log whose `scheduledTime` lands on the slot
  /// minute); the remaining logs fill the earliest free slots in order. That
  /// second pass exists because `ActionRouter` does not forward the tapped slot
  /// yet, so existing rows carry midnight instead of the real dose time —
  /// without it, a dose the user already confirmed keeps rendering as pending.
  static _SlotMatch _matchLogsToSlots(
    List<String> slots,
    List<Map<String, dynamic>> logs,
  ) {
    final perSlot = List<Map<String, dynamic>?>.filled(slots.length, null);
    final approximate = <Map<String, dynamic>>[];
    final extras = <Map<String, dynamic>>[];

    for (final log in logs) {
      final slot = _slotOfLog(log);
      final index = slot == null ? -1 : slots.indexOf(slot);
      if (index >= 0 && perSlot[index] == null) {
        perSlot[index] = log;
      } else {
        approximate.add(log);
      }
    }

    for (final log in approximate) {
      final index = perSlot.indexWhere((slot) => slot == null);
      if (index < 0) {
        extras.add(log);
      } else {
        perSlot[index] = log;
      }
    }

    return _SlotMatch(perSlot, extras);
  }

  static String? _slotOfLog(Map<String, dynamic> log) {
    final ts = _logMs(log);
    if (ts == null) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static int? _logMs(Map<String, dynamic> log) =>
      (log['scheduledTime'] as int?) ??
      (log['takenTime'] as int?) ??
      (log['createdAt'] as int?);

  static String? _normalizeTime(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour >= 24 || minute < 0 || minute >= 60) return null;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class _SlotMatch {
  _SlotMatch(this.perSlot, this.extras);

  final List<Map<String, dynamic>?> perSlot;
  final List<Map<String, dynamic>> extras;
}
