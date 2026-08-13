// lib/features/supplementary_sports/movement/data/movement_slot_override_repository.dart

import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/routines/domain/routine_recurrence.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_reminder_service.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_slot_override.dart';
import 'package:sqflite/sqflite.dart';

class MovementSlotOverrideRepository {
  MovementSlotOverrideRepository._();
  static final MovementSlotOverrideRepository instance = MovementSlotOverrideRepository._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<List<MovementSlotOverride>> forDateRange(String startIso, String endIso) async {
    final db = await _db;
    final rows = await db.query(
      'movement_slot_overrides',
      where: '(dateIso >= ? AND dateIso <= ?) OR (newDateIso >= ? AND newDateIso <= ?)',
      whereArgs: <Object>[startIso, endIso, startIso, endIso],
      orderBy: 'createdAt ASC',
    );
    return rows.map(MovementSlotOverride.fromMap).toList();
  }

  Future<void> upsert(MovementSlotOverride override) async {
    final db = await _db;
    await db.delete(
      'movement_slot_overrides',
      where: 'routineId = ? AND dateIso = ?',
      whereArgs: <Object>[override.routineId, override.dateIso],
    );
    await db.insert('movement_slot_overrides', override.toMap());
  }

  Future<void> skip({
    required String routineId,
    required String dateIso,
  }) {
    return upsert(
      MovementSlotOverride(
        id: RitmoIdFactory.movementSlotOverride(),
        routineId: routineId,
        dateIso: dateIso,
        action: MovementSlotAction.skip,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> move({
    required String routineId,
    required String dateIso,
    required String newDateIso,
    String? newTime,
  }) {
    return upsert(
      MovementSlotOverride(
        id: RitmoIdFactory.movementSlotOverride(),
        routineId: routineId,
        dateIso: dateIso,
        action: MovementSlotAction.move,
        newDateIso: newDateIso,
        newTime: newTime,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> retime({
    required String routineId,
    required String dateIso,
    required String newTime,
  }) {
    return upsert(
      MovementSlotOverride(
        id: RitmoIdFactory.movementSlotOverride(),
        routineId: routineId,
        dateIso: dateIso,
        action: MovementSlotAction.retime,
        newTime: newTime,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> light({
    required String routineId,
    required String dateIso,
  }) {
    return upsert(
      MovementSlotOverride(
        id: RitmoIdFactory.movementSlotOverride(),
        routineId: routineId,
        dateIso: dateIso,
        action: MovementSlotAction.light,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// اعمال تغییرات جابه‌جایی و ساعت (MOVE / RETIME) بر روی قالب هفتگی دائمی
  /// و پاکسازی overrideهای مصرف‌شده.
  Future<void> permanentizeWeek(List<MovementSlotOverride> overrides) async {
    final db = await _db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      for (final o in overrides) {
        if (o.action == MovementSlotAction.move && o.newDateIso != null) {
          final oldDate = DateTime.tryParse(o.dateIso);
          final newDate = DateTime.tryParse(o.newDateIso!);
          if (oldDate == null || newDate == null) continue;

          final oldDartWeekday = oldDate.weekday;
          final newDartWeekday = newDate.weekday;

          // Search existing schedules for this routine
          final schedules = await txn.query(
            'routine_schedules',
            where: 'routineId = ?',
            whereArgs: [o.routineId],
          );

          for (final s in schedules) {
            final daysStr = s['daysOfWeek']?.toString() ?? '';
            final days = daysStr
                .split(',')
                .map((p) => int.tryParse(p.trim()))
                .whereType<int>()
                .toList();

            if (days.contains(oldDartWeekday)) {
              days.remove(oldDartWeekday);
              if (!days.contains(newDartWeekday)) {
                days.add(newDartWeekday);
              }
              days.sort();
              final newTime = (o.newTime != null && o.newTime!.isNotEmpty)
                  ? o.newTime!
                  : (s['timeOfDay']?.toString() ?? '18:30');

              final recurrence = WeekdaysRecurrence(weekdays: days.toSet());
              final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
              final recurrenceJson = encodeRecurrenceRule(
                recurrence: recurrence,
                startDate: DateTime.now(),
                reminderTimes: [newTime],
              );

              await txn.update(
                'routine_schedules',
                {
                  'scheduleType': schedType,
                  'daysOfWeek': daysOfWeek,
                  'timeOfDay': newTime,
                  'recurrenceRule': recurrenceJson,
                  'updatedAt': nowMs,
                },
                where: 'id = ?',
                whereArgs: [s['id']],
              );
            }
          }

          // Remove consumed override
          await txn.delete(
            'movement_slot_overrides',
            where: 'id = ?',
            whereArgs: [o.id],
          );
        } else if (o.action == MovementSlotAction.retime &&
            o.newTime != null &&
            o.newTime!.isNotEmpty) {
          final schedules = await txn.query(
            'routine_schedules',
            where: 'routineId = ?',
            whereArgs: [o.routineId],
          );

          for (final s in schedules) {
            final daysStr = s['daysOfWeek']?.toString() ?? '';
            final days = daysStr
                .split(',')
                .map((p) => int.tryParse(p.trim()))
                .whereType<int>()
                .toSet();

            final recurrence = WeekdaysRecurrence(
              weekdays: days.isEmpty ? {DateTime.now().weekday} : days,
            );
            final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
            final recurrenceJson = encodeRecurrenceRule(
              recurrence: recurrence,
              startDate: DateTime.now(),
              reminderTimes: [o.newTime!],
            );

            await txn.update(
              'routine_schedules',
              {
                'scheduleType': schedType,
                'daysOfWeek': daysOfWeek,
                'timeOfDay': o.newTime,
                'recurrenceRule': recurrenceJson,
                'updatedAt': nowMs,
              },
              where: 'id = ?',
              whereArgs: [s['id']],
            );
          }

          // Remove consumed override
          await txn.delete(
            'movement_slot_overrides',
            where: 'id = ?',
            whereArgs: [o.id],
          );
        }
      }
    });

    await MovementReminderService.rescheduleWeekReminders();
  }
}
