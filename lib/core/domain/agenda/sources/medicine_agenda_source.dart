import 'dart:convert';

import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/engines/routine_occurrence_generator.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:sqflite/sqflite.dart';

/// AgendaSource for the Medicine domain.
///
/// Handles multi-slot daily doses, PRN actions, treatment course date filtering (C-04),
/// intelligent slot matching (H-08), and missed dose inference (H-09).
class MedicineAgendaSource implements AgendaSource {
  MedicineAgendaSource({
    required this.medicationRoutines,
    required this.logsByRoutineAndDate,
    required this.medicineEnabled,
  });

  /// `{routine, schedule, profile}` tuples for every non-archived medication.
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
        final schedules = await db.query('routine_schedules', orderBy: 'id ASC');
        final profiles = await db.query('medication_profiles');

        final schedulesByRoutine = <String, Map<String, dynamic>>{};
        for (final s in schedules) {
          final rId = (s['routineId'] ?? s['routine_id'])?.toString();
          if (rId != null && !schedulesByRoutine.containsKey(rId)) {
            schedulesByRoutine[rId] = s;
          }
        }

        final profilesByRoutine = <String, Map<String, dynamic>>{};
        for (final p in profiles) {
          final rId = p['routineId']?.toString();
          if (rId != null) {
            profilesByRoutine[rId] = p;
          }
        }

        for (final routine in routines) {
          final id = routine['id']?.toString();
          if (id == null) continue;
          final schedule = schedulesByRoutine[id] ?? <String, Object?>{};
          final profile = profilesByRoutine[id];

          medicationRoutines.add({
            'routine': Map<String, dynamic>.from(routine),
            'schedule': Map<String, dynamic>.from(schedule),
            if (profile != null) 'profile': Map<String, dynamic>.from(profile),
          });
        }
      }

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
      RitmoLog.error('MedicineAgendaSource', 'Load failed', e, st);
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
    final currentDay = DateTime(ctx.date.year, ctx.date.month, ctx.date.day);

    for (final entry in medicationRoutines) {
      final routine = entry['routine']! as Map<String, dynamic>;
      final schedule = entry['schedule']! as Map<String, dynamic>;
      final profile = entry['profile'] as Map<String, dynamic>?;
      final routineId = routine['id'] as String?;
      if (routineId == null) continue;

      // C-04: بررسی دقیق بازه دوره درمان دارو (Start Date / End Date / Duration)
      if (profile != null) {
        final startDateMs = profile['startDate'] as int?;
        if (startDateMs != null) {
          final startDt = DateTime.fromMillisecondsSinceEpoch(startDateMs);
          final startDay = DateTime(startDt.year, startDt.month, startDt.day);
          if (currentDay.isBefore(startDay)) {
            continue; // هنوز دوره درمان شروع نشده است
          }
        }

        final isChronic = profile['isChronic'] == 1 || profile['isChronic'] == true;
        if (!isChronic) {
          final endDateMs = profile['endDate'] as int?;
          final durationDays = profile['durationDays'] as int?;
          DateTime? effectiveEnd;

          if (endDateMs != null) {
            final endDt = DateTime.fromMillisecondsSinceEpoch(endDateMs);
            effectiveEnd = DateTime(endDt.year, endDt.month, endDt.day);
          } else if (durationDays != null && durationDays > 0 && startDateMs != null) {
            final startDt = DateTime.fromMillisecondsSinceEpoch(startDateMs);
            effectiveEnd = DateTime(startDt.year, startDt.month, startDt.day)
                .add(Duration(days: durationDays));
          }

          if (effectiveEnd != null && currentDay.isAfter(effectiveEnd)) {
            continue; // دوره درمان پایان یافته است
          }
        }
      }

      final dayLogs =
          logsByRoutineAndDate[routineId]?[ctx.dateStr] ??
          const <Map<String, dynamic>>[];
      final asNeeded = MedicationIdentity.isAsNeeded(routine);

      final slots = asNeeded
          ? const <String>[]
          : _slotsForDate(schedule, ctx.date);

      if (slots.isEmpty) {
        if (asNeeded && ctx.isToday) {
          items.add(_buildPrnActionItem(ctx: ctx, routine: routine));
        } else if (!asNeeded && dayLogs.isEmpty && ctx.isToday) {
          // M-16: داروی بدون زمان‌بندی با راهنمای کاربر
          items.add(
            _buildUnscheduledItem(ctx: ctx, routine: routine),
          );
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

  AgendaItem _buildUnscheduledItem({
    required AgendaDayContext ctx,
    required Map<String, dynamic> routine,
  }) {
    final routineId = routine['id']! as String;
    final title = routine['title'] as String? ?? 'دارو';

    return AgendaItem(
      id: buildAgendaItemId(
        AgendaDomain.medicine,
        '$routineId@unscheduled',
        ctx.dateStr,
      ),
      sourceId: routineId,
      domain: AgendaDomain.medicine,
      itemType: AgendaItemType.flexible,
      title: title,
      subtitle: 'زمان‌بندی ساعت مشخص نشده است (کلیک جهت تنظیم)',
      dateStr: ctx.dateStr,
      timeOfDay: null,
      durationMinutes: 5,
      category: Category.medical,
      priority: 1.5,
      isEssential: true,
      deepLink: AgendaDeepLink(
        domain: AgendaDomain.medicine,
        targetId: routineId,
      ),
      completion: AgendaCompletion.pending,
      meta: {'routineId': routineId, 'isUnscheduled': true},
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
    String? subtitle = log?['note'] as String?;

    if (status == 'TAKEN') {
      completion = AgendaCompletion.done;
    } else if (status == 'SKIPPED' || status == 'MISSED') {
      completion = AgendaCompletion.skipped;
    } else if (log == null && slot != null) {
      // H-09: تشخیص دوزهای گذشته که لاگ ندارند (Overdue / Missed)
      if (ctx.isPast) {
        subtitle = subtitle ?? 'مصرف ثبت نشده (فراموش‌شده)';
      }
    }

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
      subtitle: subtitle,
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

    final times =
        rule.reminderTimes
            .map(_normalizeTime)
            .whereType<String>()
            .toSet()
            .toList()
          ..sort();
    if (times.isNotEmpty) return times;

    final fallback = _normalizeTime(schedule['timeOfDay'] as String?);
    return fallback != null ? [fallback] : const [];
  }

  static RecurrenceRule _ruleFor(Map<String, dynamic> schedule) {
    final ruleStr = schedule['recurrenceRule'] as String?;
    if (ruleStr != null && ruleStr.isNotEmpty) {
      try {
        return RecurrenceRule.fromMap(
          jsonDecode(ruleStr) as Map<String, dynamic>,
        );
      } catch (e, st) {
        RitmoLog.error('MedicineAgendaSource', 'Invalid recurrenceRule', e, st);
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
      reminderTimes: time != null ? [time] : const [],
    );
  }

  /// H-08: نگاشت دقیق لاگ‌ها به نزدیک‌ترین اسلات بر اساس کمترین فاصله زمانی (تا سقف ۳ ساعت)
  static _SlotMatch _matchLogsToSlots(
    List<String> slots,
    List<Map<String, dynamic>> logs,
  ) {
    final perSlot = List<Map<String, dynamic>?>.filled(slots.length, null);
    final unmatchedLogs = <Map<String, dynamic>>[];
    final extras = <Map<String, dynamic>>[];

    // ۱. تطبیق دقیق ابتدا (Exact matches)
    for (final log in logs) {
      final slot = _slotOfLog(log);
      final index = slot == null ? -1 : slots.indexOf(slot);
      if (index >= 0 && perSlot[index] == null) {
        perSlot[index] = log;
      } else {
        unmatchedLogs.add(log);
      }
    }

    // ۲. تطبیق نزدیک‌ترین اسلات خالی برای لاگ‌های تخمینی با حداکثر ۳ ساعت اختلاف
    for (final log in unmatchedLogs) {
      final logTimeStr = _slotOfLog(log);
      if (logTimeStr == null) {
        extras.add(log);
        continue;
      }

      final logMinutes = _timeToMinutes(logTimeStr);
      int bestIndex = -1;
      int minDiff = 181; // سقف ۳ ساعت = ۱۸۰ دقیقه

      for (var i = 0; i < slots.length; i++) {
        if (perSlot[i] != null) continue;
        final slotMinutes = _timeToMinutes(slots[i]);
        final diff = (logMinutes - slotMinutes).abs();
        if (diff < minDiff) {
          minDiff = diff;
          bestIndex = i;
        }
      }

      if (bestIndex >= 0) {
        perSlot[bestIndex] = log;
      } else {
        extras.add(log);
      }
    }

    return _SlotMatch(perSlot, extras);
  }

  static int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
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
